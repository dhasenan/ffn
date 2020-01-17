module common;

import adapter.core;
import domain;

import core.thread;
import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.experimental.logger;
import std.file;
import std.getopt;
import std.net.curl;
import std.path;
import std.string;

import arsd.characterencodings;
import arsd.dom;
import url;

struct Options
{
static:
    string saveRawPath = null;
    Duration extraTimeBetweenChapters = 0.seconds;
}

Adapter[] seriesAdapters()
{
    import adapter.ao3;
    return [new AO3SeriesAdapter];
}

Adapter[] allAdapters()
{
    import adapter.ao3;
    import adapter.ffn;
    import adapter.xenforo;
    import adapter.xenforo2;

    Adapter a = new XenforoAdapter;
    return [new AO3Adapter, new FFNAdapter, a, new Xenforo2Adapter];
}

int elemCmp(const Element a, const Element b)
{
    int aa = cast(int) cast(void*) a;
    int bb = cast(int) cast(void*) b;
    return aa - bb;
}

void clean(Element elem)
{
    import std.container.rbtree;

    auto queue = new RedBlackTree!(Element, elemCmp, false);
    queue.insert(elem);

    while (!queue.empty)
    {
        auto e = queue.front;
        queue.removeFront;
        e.attributes.remove("style");
        queue.insert(e.children);
    }
}

struct DownloadInfo
{
    SysTime lastDownload;
    Document[URL] downloaded;
    Duration betweenDownloads;
}

private Document fetchHTML(ref DownloadInfo info, URL u)
{
    auto base = u;
    base.fragment = null;
    if (auto p = base in info.downloaded)
    {
        return *p;
    }
    auto now = Clock.currTime(UTC());
    auto next = info.lastDownload + info.betweenDownloads + Options.extraTimeBetweenChapters;
    if (next > now)
    {
        auto d = next - now;
        infof("sleeping %s for rate limit", d);
        Thread.sleep(d);
    }
    auto http = HTTP(u.toString);
    http.setUserAgent("Windows / IE 11: Mozilla/5.0 " ~
            "(Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko");
    string charset;
    Appender!(ubyte[]) ap;
    bool gzip;
    import std.zlib : UnCompress;
    auto uncompress = new UnCompress;
    http.onReceive = delegate ulong(ubyte[] buf)
    {
        if (gzip)
            ap ~= cast(ubyte[])uncompress.uncompress(buf);
        else
            ap ~= buf;
        return buf.length;
    };
    http.onReceiveHeader = delegate void(in char[] key, in char[] val) {
        import std.uni;
        auto lkey = toLower(key);

        if (lkey == "content-type")
        {
            enum CHARSET_INFO = "charset=";
            auto f = val.indexOf(CHARSET_INFO);
            if (f >= 0)
            {
                charset = val[(f + CHARSET_INFO.length) .. $].idup;
            }
        }
        else if (lkey == "content-encoding")
        {
            if (val.indexOf("gzip") >= 0)
            {
                gzip = true;
                infof("gzip!");
            }
        }
    };
    http.perform;
    auto data = ap.data;
    if (Options.saveRawPath != "")
    {
        auto path = chainPath(Options.saveRawPath, u.path.baseName);
        std.file.write(path, data);
    }

    const detectedEncoding = tryToDetermineEncoding(data);
    if (detectedEncoding != null)
    {
        charset = detectedEncoding;
    }
    auto doc = new Document;
    doc.parse(cast(string) data.idup, false, false, charset);

    info.downloaded[base] = doc;
    info.lastDownload = Clock.currTime(UTC());
    return doc;
}

/**
    Fetch the book using the given adapter.
*/
Fic fetch(URL u)
{
    DownloadInfo info;
    Adapter adapter;
    infof("%s series adapters", seriesAdapters.length);
    foreach (s; seriesAdapters)
    {
        if (!s.accepts(u)) continue;

        info.betweenDownloads = s.betweenDownloads;
        auto seriesDoc = info.fetchHTML(u);
        auto bookURLs = s.chapterURLs(seriesDoc.root, u);

        if (bookURLs.length == 0) continue;
        Fic[] parts;
        infof("book urls: %s", bookURLs);
        infof("title: %s author: %s", s.title(seriesDoc.root), s.author(seriesDoc.root));
        foreach (url; bookURLs)
        {
            //parts ~= fetch(url);
        }

        // Stitch them together into one book.
        Fic stitched = new Fic;
        stitched.author = s.author(seriesDoc.root);
        stitched.title = s.title(seriesDoc.root);
        stitched.slug = s.slug(seriesDoc.root);

        foreach (part; parts)
        {
            if (stitched.author.length == 0) stitched.author = part.author;
            if (stitched.slug.length == 0) stitched.slug = part.slug;
            foreach (chapter; part.chapters)
            {
                chapter.title = part.title ~ " " ~ chapter.title;
            }
            stitched.chapters ~= part.chapters;
            stitched.attachments ~= part.attachments;
        }

        if (stitched.title.length == 0)
        {
            stitched.title = seriesDoc.root.querySelector("title").innerText;
        }

        return stitched;
    }

    foreach (a; allAdapters)
    {
        if (a.accepts(u))
        {
            adapter = a;
            u = adapter.canonicalize(u);
            break;
        }
    }
    if (adapter is null)
    {
        throw new NoAdapterException("no adapter for url " ~ u.toHumanReadableString);
    }

    info.betweenDownloads = adapter.betweenDownloads;
    auto mainDoc = info.fetchHTML(u);
    Fic b = new Fic;
    b.url = u;
    b.author = adapter.author(mainDoc.root);
    b.title = adapter.title(mainDoc.root);
    b.slug = adapter.slug(mainDoc.root);
    auto urls = adapter.chapterURLs(mainDoc.root, u);
    foreach (url; urls)
    {
        auto chapsDoc = info.fetchHTML(url);
        tracef("fetched html for chapter at %s", url);
        auto chaps = adapter.chapters(chapsDoc.mainBody, u);
        tracef("found chapters: %s", chaps.length);
        foreach (chapter; chaps)
        {
            chapter.url = url;
            chapter.title = adapter.chapterTitle(chapter.content);
            // TODO filters (curly quotes, mote-it-not, etc)
            chapter.content.clean;
            b.chapters ~= chapter;
        }
    }
    adapter.postprocess(b);
    tracef("finished book text; got %s chapters", b.chapters.length);

    fetchImages(b);

    return b;
}

void fetchImages(ref Fic b)
{
    static ulong numImages = 0;

    import epub.books : Attachment;
    string[URL] urlToPath;
    foreach (episode; b.chapters)
    {
        foreach (img; episode.content.querySelectorAll("img"))
        {
            if (img.getAttribute("src").startsWith("data:image")) continue;
            import std.conv : to;
            import std.array : Appender;
            import std.net.curl : HTTP;

            URL src;
            try
            {
                src = episode.url.resolve(img.getAttribute("src"));
            }
            catch (Exception e)
            {
                continue;
            }
            if (src in urlToPath) continue;
            try
            {
                auto client = HTTP(src);
                client.maxRedirects = 10;
                Appender!(ubyte[]) appender;
                string mimeType;
                client.onReceiveHeader = (k, v)
                {
                    import std.uni : sicmp;
                    if (sicmp(k, "Content-Type") == 0)
                    {
                        mimeType = v.idup;
                    }
                };
                client.onReceive = delegate ulong(ubyte[] b) { appender ~= b; return b.length; };
                client.perform;
                if (client.statusLine.code >= 400)
                {
                    warningf("failed to download %s at an attachment: code %s, %s", src,
                            client.statusLine.code, client.statusLine.reason);
                    continue;
                }
                auto lastSlash = src.path.lastIndexOf("/");
                auto lastDot = src.path.lastIndexOf(".");
                string suffix;
                if (lastDot >= 0 && lastDot > lastSlash)
                {
                    suffix = src.path[lastDot .. $];
                }
                auto attachment = Attachment(
                    null,
                    "image_" ~ numImages.to!string ~ suffix,
                    mimeType,
                    appender.data);
                urlToPath[src] = attachment.filename;
                b.attachments ~= attachment;
                img.setAttribute("src", attachment.filename);
                infof("grabbed %s into %s", src, attachment.filename);
            }
            catch (Exception e)
            {
                warningf("failed to download image as attachment: %s", src, e);
            }
        }
    }

    // For later use, store a map of images we grabbed.
    import std.json;
    JSONValue map;
    foreach (k, v; urlToPath)
    {
        map[k.toString] = v;
    }
    b.attachments ~= Attachment(
            null, "image_index.json", "application/json", cast(const(ubyte)[])map.toPrettyString);
}

class NoAdapterException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

unittest
{
    auto doc = new Document();
    doc.parse(`<html>
    <body>
        <div class="foo">text</div>
        <div id="bar">
            <div id="inside_bar">more text</div>
        </div>
        <div id="third" class="fourth">text</div>
		<select>
			<option value="0"></option>
			<option value="1" selected></option>
			<option value="2"></option>
		</select>
    </body>
</html>`);
    assert(doc.querySelectorAll(".foo").length == 1, "by class only failed");
    assert(doc.querySelectorAll("div.foo").length == 1, "by tag and class failed");
    assert(doc.querySelectorAll("div#bar").length == 1, "by tag and id failed");
    assert(doc.querySelectorAll("div#bar #inside_bar").length == 1, "nesting");
    assert(doc.querySelectorAll("option[selected]").length == 1, "selected");
}
