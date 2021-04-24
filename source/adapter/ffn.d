module adapter.ffn;

import adapter.core;
import domain;

import core.time;
import std.experimental.logger;
import std.string;

import arsd.dom;
import url;

/**
    An adapter for fanfiction.net.
*/
class FFNAdapter : SimpleAdapter
{
    this()
    {
        acceptedDomain = "www.fanfiction.net";
        super.authorSelector = "#profile_top a.xcontrast_txt[href]";
        super.titleSelector = "#profile_top b.xcontrast_txt";
        super.chapterTitleSelector = "select#chap_select option[selected]";
        super.slugSelector = "#profile_top div.xcontrast_txt";
        super.chapterBodySelector = "div.storytextp div.storytext";
    }

    override string chapterTitle(Element doc)
    {
        // So, the markup here is utter garbage.
        // Specifically:
        // <select>
        //   <option>look Ma, no closing tag!
        //   <option selected>still no closing tag!
        //   <option>...
        // </select>
        //
        // dom.d parses it as heavy nesting:
        // <select>
        //   <option>
        //     look Ma, no closing tag!
        //     <option>
        //       still no closing tag!
        //       <option>
        //         ...
        //       </option>
        //     </option>
        //   </option>
        // </select>
        auto roots = doc.querySelectorAll("select#chap_select option");

        foreach (root; roots)
        {
            if (root.hasAttribute("selected"))
            {
                return root.directText;
            }
        }
        return "(nameless chapter)";
    }

    /*
        We need some custom logic for chapter URLs because ffn doesn't have direct links
        in one page. It doesn't have *any* links, just javascript everywhere.
    */
    override URL[] chapterURLs(Element doc, URL u)
    {
        auto parts = u.path.split("/");
        auto basePath = "/" ~ parts[1] ~ "/" ~ parts[2] ~ "/";
        // We do it this way because there are two <select id="chap_select"> things.
        // There should only be one element with a given ID in a document...
        auto elems = doc.querySelector("select#chap_select").querySelectorAll("option");
        tracef("%s", elems.length);
        URL[] urls;
        foreach (elem; elems)
        {
            tracef("elem %s value is %s", elem, elem.getAttribute("value"));
            auto chap = u;
            chap.path = basePath ~ elem.getAttribute("value");
            urls ~= chap;
        }
        if (urls.length == 0)
        {
            // This is a single-chapter fic. The input URL is the only URL.
            urls ~= u;
        }
        return urls;
    }

    override Element[] chapterElements(Element doc, URL u)
    {
        // Return the whole doc here so we can fetch the chapter title later.
        // We'll extract the appropriate part during postprocessing
        return [doc];
    }

    override void postprocess(Fic fic)
    {
        foreach (e; fic.chapters)
        {
            e.content = e.content.querySelector(chapterBodySelector);
        }
    }

    override Duration betweenDownloads()
    {
        return 5200.msecs;
    }

    override bool useCfscrape() { return true; }
}

unittest
{
    import std.algorithm;
    import std.string : strip;
    auto adapter = new FFNAdapter;
    auto doc = new Document(import("ffntest-2020-01.html")).root;
    assert(adapter.chapterTitle(doc).canFind("Exploiting the Horizon"));
    assert(adapter.title(doc) == "Stygian Solace");
    assert(adapter.author(doc) == "Uzumaki-sama");
    assert(adapter.slug(doc).indexOf("By taking Riku's hand, Sora alters their destinies") >= 0);
    auto ch = adapter.chapterBody(doc);
    assert(ch.classes.canFind("storytext"));
    auto chBody = ch.innerText.strip;
    assert(!chBody.canFind("Cartoons"));
}
