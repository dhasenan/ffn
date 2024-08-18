module common;

import adapter.core;
import cleaner;
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
    string adapterName = null;
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
    import adapter.royalroad;
    import adapter.tth;
    import adapter.wordpress;
    import adapter.xenforo;
    import adapter.xenforo2;

    return [
        cast(Adapter)new AO3Adapter,
        new FFNAdapter,
        new RoyalRoadAdapter,
        new TTHAdapter,
        new WordpressAdapter,
        new XenforoAdapter,
        new Xenforo2Adapter,
    ];
}

void clean(Element elem)
{
    import std.container.dlist;

    auto queue = new DList!Element;
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

private Document fetchWithCurl(ref DownloadInfo info, URL u)
{
    auto http = HTTP(u.toString);
    http.setUserAgent("Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:85.0) Gecko/20100101 Firefox/85.0");
    http.addRequestHeader("Accept",
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
    http.addRequestHeader("Accept-Encoding", "gzip");
    http.addRequestHeader("Accept-Language", "en-US,en;q=0.5");
    http.addRequestHeader("Connection", "keep-alive");
    http.addRequestHeader("DNT", "1");
    http.addRequestHeader("Sec-GPC", "1");
    http.addRequestHeader("Upgrade-Insecure-Requests", "1");
    http.operationTimeout = 5.seconds;
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
    URL redirect;
    http.onReceiveHeader = delegate void(in char[] key, in char[] val) {
        import std.uni;
        auto lkey = toLower(key);

        switch (lkey)
        {
            case "content-type":
                enum CHARSET_INFO = "charset=";
                auto f = val.indexOf(CHARSET_INFO);
                if (f >= 0)
                {
                    charset = val[(f + CHARSET_INFO.length) .. $].idup;
                }
                break;
            case "content-encoding":
                if (val.indexOf("gzip") >= 0)
                {
                    gzip = true;
                    infof("gzip!");
                }
                break;
            case "location":
                redirect = val.idup.parseURL;
                tracef("redirect to %s detected", redirect);
                break;
            default:
                break;
        }
    };
    infof("http getting! from %s", u);
    http.perform;
    infof("http gotten! %s bytes", ap.data.length);
    if (redirect !is URL.init)
    {
        auto childPage = info.fetchWithCurl(redirect);
        tracef("returning document from redirect: %s -> %s", u, redirect);
        return childPage;
    }
    auto data = ap.data;
    tracef("have %s bytes of data from %s", data.length, u);
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
    return doc;
}

private Document fetchHTML(ref DownloadInfo info, URL u, bool cloudflare)
{
    auto base = u;
    base.fragment = null;
    version (fsCache)
    {
        auto cachedFileName = "/tmp/ffn-cache/" ~ u.toString.replace("/", "");
        if (exists(cachedFileName))
        {
            auto data = cachedFileName.readText;
            return new Document(data);
        }
    }
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
    auto doc = fetchWithCurl(info, u);

    info.downloaded[base] = doc;
    info.lastDownload = Clock.currTime(UTC());
    version (fsCache) write(cachedFileName, doc.toString);
    return doc;
}

Adapter detectAdapter(URL u, ref DownloadInfo info)
{
    import std.uni : icmp;
    if (Options.adapterName)
    {
        foreach (s; seriesAdapters ~ allAdapters)
        {
            if (icmp(Options.adapterName, s.name) == 0)
            {
                return s;
            }
        }
    }
    foreach (s; seriesAdapters ~ allAdapters)
    {
        if (s.accepts(u)) return s;
    }
    Document doc;
    try
    {
        doc = info.fetchHTML(u, false);
    }
    catch (Exception e)
    {
        try
        {
            doc = info.fetchHTML(u, true);
        }
        catch (Exception e)
        {
            return null;
        }
    }
    foreach (s; allAdapters)
    {
        try
        {
            auto a = s.chapterURLs(doc.root, u);
            if (a.length > 1)
            {
                return s;
            }
        }
        catch (Exception e)
        {
            // ok
        }
    }
    return null;
}

/**
    Fetch the book using the given adapter.
*/
Fic fetch(URL u)
{
    infof("grabbing %s", u);
    mkdirRecurse("/tmp/ffn-cache");
    DownloadInfo info;
    auto adapter = detectAdapter(u, info);
    if (!adapter)
    {
        throw new NoAdapterException("no matching adapter for " ~ u.toString);
    }
    u = adapter.canonicalize(u);
    info.betweenDownloads = adapter.betweenDownloads;

    if (adapter.isSeries)
    {
        auto tmp = Options.adapterName;
        scope (exit) Options.adapterName = tmp;
        Options.adapterName = null;

        auto seriesDoc = info.fetchHTML(u, adapter.useCfscrape).root;
        auto bookURLs = adapter.chapterURLs(seriesDoc, u);
        if (bookURLs.length == 0) return null;

        string title = adapter.title(seriesDoc);
        if (title.length == 0) title = seriesDoc.querySelector("title").innerText;
        title = title.strip;

        Fic[] parts;
        foreach (url; bookURLs)
        {
            parts ~= fetch(url);
            infof("series %s book %s found at %s with %s chapters", title,
                    parts[$-1].title, url, parts[$-1].chapters.length);
        }

        return stitchIntoOneBook(parts, adapter.author(seriesDoc), title, adapter.slug(seriesDoc));
    }

    infof("about to grab main file %s with adapter %s", u, adapter);
    auto mainDoc = info.fetchHTML(u, adapter.useCfscrape);
    infof("got main file");
    Fic b = new Fic;
    b.url = u;
    b.author = adapter.author(mainDoc.root);
    b.title = adapter.title(mainDoc.root);
    if (b.title.length == 0)
    {
        b.title = "Unknown";
    }
    b.slug = adapter.slug(mainDoc.root);
    auto urls = adapter.chapterURLs(mainDoc.root, u);
    foreach (url; urls)
    {
        auto chapsDoc = info.fetchHTML(url, adapter.useCfscrape);
        tracef("fetched html for chapter at %s", url);
        auto chaps = adapter.chapters(chapsDoc.root, u);
        tracef("found chapters: %s", chaps.length);
        foreach (i, chapter; chaps)
        {
            chapter.url = url;
            if (chapter.title.length == 0)
                chapter.title = adapter.chapterTitle(chapter.content).strip;
            if (chapter.title.length == 0)
                chapter.title = "Chapter %s".format(i + 1);
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
                    "image_" ~ urlToPath.length.to!string ~ suffix,
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

Fic stitchIntoOneBook(Fic[] parts, string author, string title, string slug)
{
    auto stitched = new Fic;
    stitched.author = author;
    stitched.title = title;
    stitched.slug = slug;
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

    infof("assembled series %s with %s chapters total", stitched.title, stitched.chapters.length);

    return stitched;
}

unittest
{
    Fic[] parts;
    auto fic1 = new Fic;
    fic1.author = "author1";
    fic1.title = "title1";
    fic1.chapters ~= new Episode;
    fic1.chapters ~= new Episode;
    fic1.chapters ~= new Episode;
    fic1.chapters[0].title = "1";
    fic1.chapters[1].title = "2";
    fic1.chapters[2].title = "3";
    auto fic2 = new Fic;
    fic2.author = "author2";
    fic2.title = "title2";
    fic2.chapters ~= new Episode;
    fic2.chapters ~= new Episode;
    fic2.chapters ~= new Episode;
    fic2.chapters[0].title = "1";
    fic2.chapters[1].title = "2";
    fic2.chapters[2].title = "3";
    auto fic3 = stitchIntoOneBook([fic1, fic2], "author!", "title?", "slug");
    assert(fic3.chapters.length == 6);
    assert(fic3.chapters[0].title == "title1 1");
    assert(fic3.chapters[1].title == "title1 2");
    assert(fic3.chapters[2].title == "title1 3");
    assert(fic3.chapters[3].title == "title2 1");
    assert(fic3.chapters[4].title == "title2 2");
    assert(fic3.chapters[5].title == "title2 3");
}
