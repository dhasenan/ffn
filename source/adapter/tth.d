module adapter.tth;

import adapter.core;
import domain;

import core.time;
import std.conv : to;
import std.experimental.logger;
import std.string;

import arsd.dom;
import url;

/**
    An adapter for fanfiction.net.
*/
class TTHAdapter : SimpleAdapter
{
    this()
    {
        acceptedDomain = "www.tthfanfic.org";
        super.authorSelector = "table.verticaltable tr:last-child td:nth-child(2)";
        super.titleSelector = "h2";
        super.chapterTitleSelector = "h3";
        super.slugSelector = "div.storysummary p";
        super.chapterBodySelector = "div.storybody";
    }

    /*
        We need some custom logic for chapter URLs because ffn doesn't have direct links
        in one page. It doesn't have *any* links, just javascript everywhere.
    */
    override URL[] chapterURLs(Element doc, URL u)
    {
        auto count = doc.querySelector("table.verticaltable tr:last-child td:nth-child(4)")
            .innerText.to!int;
        auto id = u.path.split("/")[1].split("-")[1];
        URL[] urls;
        urls ~= u.resolve("/Story-" ~ id);
        foreach (i; 2..count)
        {
            urls ~= u.resolve("/Story-%s-%s/".format(id, i));
        }
        return urls;
    }

    override Duration betweenDownloads()
    {
        return 2100.msecs;
    }

    override bool useCfscrape() { return true; }
}

