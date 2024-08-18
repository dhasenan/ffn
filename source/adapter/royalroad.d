module adapter.royalroad;

import arsd.dom;
import domain;
import adapter.core;
import std.experimental.logger;
import std.string;
import url;

class RoyalRoadAdapter : SimpleAdapter
{
    this()
    {
        super.acceptedDomain = "www.royalroad.com";
        super.authorSelector = "div.mt-card-content h3";
        super.chapterBodySelector = "div.chapter-content";
        super.titleSelector = "title";
        super.chapterTitleSelector = "h1";
        super.slugSelector = "div[property=description]";
        super.adapterName = "royalroad";
        super.chapterURLSelector = "#chapters a";
    }

    override URL[] chapterURLs(Element doc, URL u)
    {
        import std.algorithm.iteration : uniq;
        import std.array : array;
        return super.chapterURLs(doc, u).uniq.array;
    }

    override Episode[] chapters(Element doc, URL u)
    {
        auto chap = new Episode;
        chap.content = doc.querySelector("div.chapter-content");
        chap.url = u;
        chap.title = doc.querySelector("h1").innerText;
        return [chap];

    }

    override URL canonicalize(URL u)
    {
        // ex: /fiction/4242/world-seed/chapter/43722/chapter-19-grove-sweet-grove
        // should become: /fiction/4242/world-seed
        auto s = u.path.lastIndexOf("/chapter/");
        if (s >= 0)
        {
            u.path = u.path[0..s];
            infof("looks like an individual chapter url; shortening to %s", u);
        }
        else
        {
            infof("looks like %s is the main url", u);
        }
        return u;
    }
}
