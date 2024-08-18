module adapter.wordpress;

import adapter.core;
import domain;
import core.time;
import std.algorithm;
import std.array;
import std.experimental.logger;
import std.regex;
import arsd.dom;
import url;


/// Adapter for wordpress blogs
class WordpressAdapter : SimpleAdapter
{
    Regex!char tocRegex;

    this()
    {
        super.authorSelector = "span.author";
        super.titleSelector = "h1.site-title";
        super.chapterTitleSelector = "h3.title";
        super.adapterName = "wordpress";
        tocRegex = regex("table-of-contents");
    }

    override bool accepts(URL u)
    {
        return u.host.endsWith("wordpress.com");
    }

    override URL[] chapterURLs(Element doc, URL u)
    {
        Element e;
        foreach (selector; ["div.content", "div.entry-wrapper", "div.entry-content"])
        {
            e = doc.querySelector(selector);
            if (e) break;
        }
        if (!e)
        {
            errorf("failed to find entry at %s", u);
            return null;
        }
        auto results = e.querySelectorAll("a")
            .map!(e => e.getAttribute("href"))
            .filter!(href => !href.match(tocRegex))
            .map!(href => u.resolve(href))
            .array;
        infof("got %s chapter urls", results.length);
        return results;
    }

    override string chapterTitle(Element doc)
    {
        foreach (attempt; [".entry-title", "h3", "h1"])
        {
            auto title = doc.parentDocument.querySelector(attempt);
            if (title) return title.innerText;
        }
        return null;
    }

    override string title(Element doc)
    {
        foreach (attempt; [".site-title", "h1"])
        {
            auto title = doc.parentDocument.querySelector(attempt);
            if (title) return title.innerText;
        }
        return null;
    }

    override Element chapterBody(Element doc)
    {
        Element e = doc.querySelector("div.entry-wrapper");
        if (!e) e = doc.querySelector("div.entry-content");
        if (!e) return null;
        auto share = e.querySelector("div.sharedaddy");
        if (share !is null)
        {
            share.removeFromTree();
        }
        return e;
    }

    override Duration betweenDownloads()
    {
        // robots.txt
        return 1.seconds;
    }
}

