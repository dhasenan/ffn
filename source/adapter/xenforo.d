module adapter.xenforo;

import adapter.core;
import core.time;
import domain;
import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.range;
import std.stdio;
import std.string;
import std.typecons;
import arsd.dom;
import url;

class XenData
{
    string nextThreadmark;
    string lastThreadmark;
    string threadmark;
    string postAuthor;
}

class XenforoAdapter : Adapter
{
    bool accepts(URL u)
    {
        return u.host.endsWith("sufficientvelocity.com") || u.host.endsWith("spacebattles.com");
    }

    URL[] chapterURLs(Element doc, URL u)
    {
        // ex:
        // /threads/with-this-ring-young-justice-si-thread-twelve.25032/page-2059
        int count = 1;
        auto m = doc.querySelectorAll("div.PageNav");
        foreach (nav; m)
        {
            if (auto last = nav.getAttribute("data-last"))
            {
                count = last.to!int;
            }
        }
        auto arr = new URL[count];
        foreach (i; 0 .. count)
        {
            auto pn = u;
            pn.queryParams = pn.queryParams.dup;
            pn.queryParams.overwrite("page", (i + 1).to!string);
            arr[i] = pn;
        }
        return arr;
    }

    /**
       Extract chapters from a document containing one or more.
    */
    Episode[] chapters(Element doc, URL u)
    {
        Episode[] ret;
        foreach (tm; doc.querySelectorAll("li"))
        {
            bool threadmark = tm.getAttribute("class").canFind("hasThreadmark");
            if (threadmark)
            {
                Episode c;
                c.content = tm.querySelector("article");
                auto data = new XenData;
                data.postAuthor = tm.getAttribute("data-author");
                data.threadmark = tm.getAttribute("id").splitter("-").drop(1).front;
                data.lastThreadmark = getThreadmarkTarget(tm, ".previous");
                data.nextThreadmark = getThreadmarkTarget(tm, ".next");
                c.data = data;
                ret ~= c;
            }
        }
        return ret;
    }

    string getThreadmarkTarget(Element tm, string clazz)
    {
        auto a = tm
            .querySelector(".threadmarker_nav_top")
            .querySelector(clazz);
        if (a is null) return null;
        auto postURL = a
            .querySelector("a")
            .getAttribute("data-previewurl");
        return postURL.splitter("/").drop(1).front;
    }

    /// The title for the work.
    string title(Element doc)
    {
        auto t = doc.querySelector("title");
        if (t is null)
        {
            warningf("no title found");
            return "Unknown book";
        }
        auto e = t.innerText;
        auto last = e.lastIndexOf("|");
        if (last < 0)
            last = e.length;
        return e[0 .. last].strip;
    }

    /// The author for the work.
    string author(Element doc)
    {
        auto tm = doc.querySelectorAll("li[data-author]");
        foreach (t; tm)
        {
            // arsd-dom doesn't properly separate classes properly...
            if (t.getAttribute("class").canFind("hasThreadmark"))
            {
                return t.getAttribute("data-author");
            }
        }
        warningf("no author found");
        return "Unknown author";
    }

    string slug(Element doc)
    {
        return null;
    }

    string chapterTitle(Element doc)
    {
        auto label = doc.querySelector("div.threadmarker span.label");
        if (label is null)
            return null;
        return label.directText.strip;
    }

    Element chapterBody(Element doc)
    {
        return doc.querySelector("div.messageContent article");
    }

    Duration betweenDownloads()
    {
        return dur!"msecs"(250);
    }

    void postprocess(Fic book)
    {
        if (book.chapters.length == 0) return;
        Episode[string] byURL;
        Episode first;
        foreach (chapter; book.chapters)
        {
            auto data = cast(XenData)chapter.data;
            byURL[data.threadmark] = chapter;
            if (data.lastThreadmark == "")
            {
                first = chapter;
            }
        }
        assert(first != Episode.init);
        Episode[] chapters;
        while (true)
        {
            chapters ~= first;
            auto data = cast(XenData)first.data;
            if (data.nextThreadmark == "") break;
            first = byURL[data.nextThreadmark];
        }
        book.chapters = chapters;
    }
}

unittest
{
    enum html = import("xenforotest.html");
    auto doc = new Document;
    doc.parse(html, false, false, "utf-8");
    auto root = doc.root;
    auto xen = new XenforoAdapter;

    auto title = xen.title(root);
    assert(title == "Abracadabra (Worm/Harry Potter)", title);

    auto author = xen.author(root);
    assert(author == "Kolibrie", author);

    auto chapters = xen.chapters(doc.root, URL.init);
    assert(chapters.length == 1);

    auto chname = xen.chapterTitle(chapters[0].content);
    assert(chname == "1.1", chname);
}

unittest
{
    import std.conv;
    import std.stdio;
    import std.file;

    auto html = readText("import/xenforotest2.html");
    auto doc = new Document;
    doc.parse(html, false, false, "utf-8");
    auto root = doc.root;
    auto xen = new XenforoAdapter;
    auto url = "http://example.org/thread/xentest".parseURL;

    auto urls = xen.chapterURLs(root, url);
    assert(urls.length == 17, urls.length.to!string);
}

unittest
{
    import std.conv;
    import std.stdio;
    import std.file;

    auto html = readText("import/xenforotest3.html");
    auto doc = new Document;
    doc.parse(html, false, false, "utf-8");
    auto root = doc.mainBody;
    auto xen = new XenforoAdapter;
    auto url = "http://example.org/thread/xentest".parseURL;

    auto chaps = xen.chapters(root, url);
    assert(chaps.length == 10, chaps.length.to!string);

}
