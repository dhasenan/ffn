module adapter.core;

import core.time;
import std.experimental.logger;

import arsd.dom;
import url;

/**
	The core interface for a site-specific adapter.

	This assumes the site 
*/
interface Adapter
{
    /// Whether this adapter can handle this URL.
    bool accepts(URL u);

    /**
		The URLs of each chapter.

        These might contain multiple values that map to the same page. If that's convenient, do it
        that way. If it's more convenient to provide a minimal list of pages containing chapters, do
        it that way.
	*/
    URL[] chapterURLs(Element doc, URL u);

    /**
	   Extract chapters from a document containing one or more.
	*/
    Element[] chapters(Element doc, URL u);

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
}

/**
	A site Adapter that assumes one chapter per page, where everything is accessible with CSS selectors.

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
    }

    bool accepts(URL u)
    {
        return u.host == acceptedDomain;
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

    Element[] chapters(Element doc, URL u)
    {
        return [doc];
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
        return f[0].innerText;
    }

    Duration betweenDownloads()
    {
        return dur!"msecs"(250);
    }
}
