module adapter.xenforo2;

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
import std.json;
import std.typecons;
import arsd.dom;
import url;

class Xen2Data
{
    string nextThreadmark;
    string lastThreadmark;
    string threadmark;
    string postAuthor;
}

class Xenforo2Adapter : Adapter
{
    bool includeSpoilers = false;

    bool accepts(URL u)
    {
        return u.host.endsWith("sufficientvelocity.com");
    }

    URL canonicalize(URL u)
    {
        enum reader = "/reader/";
        // ex:
        // /threads/with-this-ring-young-justice-si-thread-twelve.25032/reader/page-2059
        auto base = u;
        base.fragment = "";
        auto s = base.path["/threads/".length .. $];
        infof("path fragment a: %s", s);
        s = s[0 .. s.indexOf('/')];
        infof("path fragment b: %s", s);
        base.path = "/threads/" ~ s ~ "/reader/";
        infof("canonicalized url: %s", base);
        return base;
    }

    URL[] chapterURLs(Element doc, URL u)
    {
        auto nav = doc.querySelector("input.js-pageJumpPage");
        if (!nav) return [u];
        if (!("max" in nav.attributes)) return [u];
        auto count = nav.getAttribute("max").to!int;
        auto arr = new URL[count];
        foreach (i; 0 .. count)
        {
            arr[i] = u.resolve("page-" ~ (i + 1).to!string);
        }
        return arr;
    }

    /**
       Extract chapters from a document containing one or more.
    */
    Episode[] chapters(Element doc, URL u)
    {
        Episode[] ret;
        foreach (tm; doc.querySelectorAll("article.message"))
        {
            bool threadmark = tm.querySelector("span.threadmarkLabel") !is null;
            if (threadmark)
            {
                Episode c = new Episode;
                c.content = tm;
                auto data = new Xen2Data;
                data.postAuthor = tm.getAttribute("data-author");
                data.threadmark = tm.querySelector("label").getAttribute("for");
                c.data = data;
                ret ~= c;
            }
        }
        return ret;
    }

    /// The title for the work.
    string title(Element doc)
    {
        foreach (elem; doc.querySelectorAll("meta"))
        {
            if (elem.getAttribute("property") == "og:title")
            {
                return elem.getAttribute("content");
            }
        }
        auto t = doc.querySelector("title").innerText;
        t = t[0 .. t.lastIndexOf("|")].strip;
        return t;
    }

    /// The author for the work.
    string author(Element doc)
    {
        return doc.querySelector("article.message--post").getAttribute("data-author");
    }

    string slug(Element doc)
    {
        return null;
    }

    string chapterTitle(Element doc)
    {
        auto label = doc.querySelector("span.threadmarkLabel");
        if (label is null)
            return null;
        return label.directText.strip;
    }

    Element chapterBody(Element doc)
    {
        assert(false);
    }

    Duration betweenDownloads()
    {
        return dur!"msecs"(250);
    }

    void postprocess(Fic book)
    {
        if (book.chapters.length == 0) return;
        foreach (ref chapter; book.chapters)
        {
            chapter.content = chapter.content.querySelector("article.message-body");
        }
    }
}
