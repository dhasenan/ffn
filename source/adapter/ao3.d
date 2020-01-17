module adapter.ao3;

import adapter.core;
import arsd.dom;
import core.time;
import domain;
import std.experimental.logger;
import url;

/// Adapter for archiveofourown.org
class AO3Adapter : SimpleAdapter
{
    this()
    {
        super.acceptedDomain = "archiveofourown.org";
        super.authorSelector = "a[rel=author]";
        super.chapterBodySelector = "div#chapters";
        super.titleSelector = "h2.title";
        super.chapterTitleSelector = "h3.title";
        super.slugSelector = "div.summary";
    }

    override URL[] chapterURLs(Element doc, URL u)
    {
        URL[] urls;
        auto s = doc.querySelector("select#selected_id");
        if (s !is null)
        {
            foreach (o; s.querySelectorAll("option"))
            {
                urls ~= u.resolve(o.getAttribute("value"));
            }
        }
        if (urls.length == 0)
            return [u];
        return urls;
    }

    override Element chapterBody(Element doc)
    {
        auto e = super.chapterBody(doc);
        if (e is null)
            return e;
        // Special thing here: the chapter title is inside the chapter.
        // That conflicts with what we do later (insert the chapter title manually) and
        // probably messes up calibre's chapter detection (h3.title -> book title?).
        // So remove it.
        auto header = e.querySelector("h3.title");
        if (header !is null)
        {
            header.removeFromTree();
        }
        return e;
    }

    override Duration betweenDownloads()
    {
        return dur!"msecs"(400);
    }
}

class AO3SeriesAdapter : SimpleAdapter
{
    this()
    {
        super.acceptedDomain = "archiveofourown.org";
        super.authorSelector = "a[rel=author]";
        super.titleSelector = "h2.heading";
        super.slugSelector = "blockquote.userstuff";
    }

    override bool accepts(URL u)
    {
        import std.string : startsWith, endsWith;
        infof("trying to accept url %s: host: [%s] path: [%s]", u, u.host, u.path);
        return u.host.endsWith("archiveofourown.org")
            && u.path.startsWith("/series");
    }

    override URL[] chapterURLs(Element doc, URL u)
    {
        URL[] urls;
        auto s = doc.querySelector("ul.series.work");
        if (s !is null)
        {
            foreach (o; s.querySelectorAll("h4.heading"))
            {
                auto a = o.querySelector("a");
                if (a) urls ~= u.resolve(a.getAttribute("href"));
            }
        }
        return urls;
    }

    override Element chapterBody(Element doc)
    {
        auto e = super.chapterBody(doc);
        if (e is null)
            return e;
        // Special thing here: the chapter title is inside the chapter.
        // That conflicts with what we do later (insert the chapter title manually) and
        // probably messes up calibre's chapter detection (h3.title -> book title?).
        // So remove it.
        auto header = e.querySelector("h3.title");
        if (header !is null)
        {
            header.removeFromTree();
        }
        return e;
    }
}

unittest
{
    auto doc = new Document(import("ao3seriestest.html"));
    auto s = new AO3SeriesAdapter;
    assert(s.title(doc.root) == "Ashen Skies", s.title(doc.root));
    assert(s.author(doc.root) == "Xenobia");
    auto chapterURLs = s.chapterURLs(doc.root, "https://example.org/foo/bar".parseURL);
    assert(chapterURLs == [
            parseURL("https://example.org/works/470820"),
            parseURL("https://example.org/works/425213"),
            parseURL("https://example.org/works/638088"),
            parseURL("https://example.org/works/638102"),
            parseURL("https://example.org/works/775113"),
    ]);
}
