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
import std.getopt;
import std.net.curl;
import std.stdio;
import std.string;

import arsd.characterencodings;
import arsd.dom;
import url;

Adapter[] allAdapters()
{
    import adapter.ao3;
    import adapter.ffn;
    import adapter.xenforo;
    Adapter a = new XenforoAdapter;
    return [new AO3Adapter, new FFNAdapter, a];
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
    auto next = info.lastDownload + info.betweenDownloads;
    if (next > now)
    {
        Thread.sleep(next - now);
    }
	auto http = HTTP(u.toString);
	string charset;
	Appender!(ubyte[]) ap;
	http.onReceive = delegate ulong(ubyte[] buf) { ap ~= buf; return buf.length; };
	http.onReceiveHeader = delegate void(in char[] key, in char[] val) {
		import std.uni;
		if (toLower(key) == "content-type")
		{
			enum CHARSET_INFO = "charset=";
			auto f = val.indexOf(CHARSET_INFO);
			if (f >= 0)
			{
				charset = val[(f+CHARSET_INFO.length)..$].idup;
			}
		}
	};
	http.perform;
	auto doc = new Document;
	const data = ap.data;
	const detectedEncoding = tryToDetermineEncoding(data);
	if (detectedEncoding != null)
	{
		charset = detectedEncoding;
	}
	doc.parse(cast(string)data.idup, false, false, charset);
	info.downloaded[base] = doc;
	return doc;
}

/**
    Fetch the book using the given adapter.
*/
Book fetch(URL u)
{
    Adapter adapter;
    foreach (a; allAdapters)
    {
        if (a.accepts(u))
        {
            adapter = a;
            break;
        }
    }
    if (adapter is null)
    {
        throw new NoAdapterException("no adapter for url " ~ u.toHumanReadableString);
    }

    DownloadInfo info = {betweenDownloads: adapter.betweenDownloads};
	auto mainDoc = info.fetchHTML(u);
	Book b;
	b.author = adapter.author(mainDoc.root);
	b.title = adapter.title(mainDoc.root);
	b.slug = adapter.slug(mainDoc.root);
	auto urls = adapter.chapterURLs(mainDoc.root, u);
	foreach (url; urls)
	{
		auto chapsDoc = info.fetchHTML(url);
		infof("fetched html for chapter at %s", url);
		foreach (chapter; adapter.chapters(chapsDoc.root, u))
		{
			Chapter c;
			c.title = adapter.chapterTitle(chapter);
			// TODO filters (curly quotes, mote-it-not, etc)
			c.content = adapter.chapterBody(chapter);
			b.chapters ~= c;
		}
	}
	return b;
}

class NoAdapterException : Exception
{
    this(string msg) { super(msg); }
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
