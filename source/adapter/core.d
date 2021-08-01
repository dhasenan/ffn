module adapter.core;

import arsd.dom;
import core.time;
import domain;
import std.experimental.logger;
import std.string;
import url;

/**
 * The core interface for a site-specific adapter.
 */
interface Adapter
{
    /// Whether this adapter can handle this URL.
    bool accepts(URL u);

    /// Transform the input URL into a canonical form to work off.
    URL canonicalize(URL u);

    /**
       The URLs of each chapter.

       These might contain multiple values that map to the same page. If that's convenient, do it
       that way. If it's more convenient to provide a minimal list of pages containing chapters, do
       it that way.
     */
    URL[] chapterURLs(Element doc, URL u);

    /**
      Extract chapters from a document containing one or more.
      This should at least fill in the contents field, but other fields are optional.
     */
    Episode[] chapters(Element doc, URL u);

    /// The title for the work.
    string title(Element doc);

    /// The author for the work.
    string author(Element doc);

    /// The short description of the work.
    string slug(Element doc);

    /// The title of this chapter. Always called before chapterBody.
    string chapterTitle(Element doc);

    /// The body of the chapter. Always called after chapterTitle.
    Element chapterBody(Element doc);

    /// How long to wait between new page downloads
    Duration betweenDownloads();

    /// Do any fixups to finish off the book.
    void postprocess(Fic book);

    /// Whether this adapter requires us to use a cloudflare-specific scraper.
    bool useCfscrape();

    /// Whether this adapter is a series-style adapter. Really ugly hack.
    bool isSeries();

    /// The name of this adapter
    string name();
}

/**
  A site Adapter that assumes one chapter per page, where everything is accessible with CSS
  selectors.

  This is probably a good starting point for any adapter you want to write.
*/
class SimpleAdapter : Adapter
{
    protected
    {
        string acceptedDomain;
        string chapterURLSelector;
        string chapterURLAttribute;
        string titleSelector;
        string authorSelector;
        string slugSelector;
        string chapterTitleSelector;
        string chapterBodySelector;
        string adapterName;
    }

    bool accepts(URL u)
    {
        return u.host == acceptedDomain;
    }

    URL canonicalize(URL u)
    {
        return u;
    }

    URL[] chapterURLs(Element doc, URL u)
    {
        auto elems = doc.getElementsBySelector(chapterURLSelector);
        URL[] urls;
        foreach (elem; elems)
        {
            string unparsed;
            if (chapterURLAttribute)
            {
                unparsed = elem.getAttribute(chapterURLAttribute);
            }
            else
            {
                unparsed = elem.innerText;
            }
            URL u2;
            if (tryParseURL(unparsed, u2))
            {
                urls ~= u2;
            }
            else
            {
                infof("failed to parse '%s' as a chapter URL; skipping", unparsed);
            }
        }
        return urls;
    }

    Element[] chapters(Document doc, URL u)
    {
        return [doc.mainBody];
    }

    string title(Element doc)
    {
        return innerText(doc, titleSelector);
    }

    string author(Element doc)
    {
        return innerText(doc, authorSelector);
    }

    string slug(Element doc)
    {
        return innerText(doc, slugSelector);
    }

    string chapterTitle(Element doc)
    {
        return innerText(doc, chapterTitleSelector);
    }

    Episode[] chapters(Element doc, URL u)
    {
        auto ch = chapterElements(doc, u);
        Episode[] cc;
        foreach (c; ch)
        {
            Episode chap = new Episode;
            chap.content = c;
            cc ~= chap;
        }
        return cc;
    }

    Element[] chapterElements(Element doc, URL u)
    {
        auto b = chapterBody(doc);
        if (b) return [b];
        return [];
    }

    Element chapterBody(Element doc)
    {
        auto elems = doc.getElementsBySelector(chapterBodySelector);
        if (elems.length == 0)
            return null;
        if (elems.length == 1)
            return elems[0];
        auto e = Element.make("div");
        e.appendChildren(elems);
        return e;
    }

    protected string innerText(Element doc, string selector)
    {
        if (doc is null)
        {
            errorf("tried to get selector %s on null document", selector);
            return "";
        }
        auto f = doc.getElementsBySelector(selector);
        if (f.length == 0)
            return "";
        return f[0].innerText.strip;
    }

    Duration betweenDownloads()
    {
        return dur!"msecs"(250);
    }

    void postprocess(Fic b) {}

    bool useCfscrape() { return false; }
    bool isSeries() { return false; }
    string name() { return this.adapterName; }
}
