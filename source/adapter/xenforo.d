module adapter.xenforo;

import adapter.core;

import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.range;
import std.stdio;
import std.string;

import arsd.dom;
import url;

class XenforoAdapter : Adapter
{
    bool accepts(URL u)
    {
        return u.host.endsWith("sufficientvelocity.com")
            || u.host.endsWith("spacebattles.com");
    }

    URL[] chapterURLs(Element doc, URL u)
    {
        // ex:
        // /threads/with-this-ring-young-justice-si-thread-twelve.25032/page-2059
        auto m = doc
            .querySelectorAll("a.gt999")
            .map!(x => x.innerText)
            .map!(to!int);
        auto count = reduce!((int a, int b) => max(a, b))(1, m);
        auto arr = new URL[count];
        foreach (i; 0..count)
        {
            auto pn = "page-" ~ (i+1).to!string;
            arr[i] = u.resolve(pn);
        }
        return arr;
    }

    /**
       Extract chapters from a document containing one or more.
    */
    Element[] chapters(Element doc, URL u)
    {
        auto tm = doc.querySelectorAll("li[data-author]");
        return tm
            .filter!(x => x.getAttribute("class").canFind("hasThreadmark"))
            .array;
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
        if (last < 0) last = e.length;
        return e[0..last].strip;
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
        if (label is null) return null;
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
    
    auto chname = xen.chapterTitle(chapters[0]);
    assert(chname == "1.1", chname);
}