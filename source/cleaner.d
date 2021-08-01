module cleaner;

import arsd.dom;
import std.string : strip;
import std.algorithm;
import std.array : array;

void clean(Element elem)
{
    import std.container.dlist;

    auto queue = new DList!Element;
    queue.insert(elem);

    while (!queue.empty)
    {
        auto e = queue.front;
        queue.removeFront;
        cleanSingleElement(e);
        queue.insert(e.children);
    }
}

private void cleanSingleElement(Element elem)
{
    // Don't trust inline styles I guess?
    elem.attributes.remove("style");

    // Remove some tags that aren't allowed in XHTML.
    switch (elem.tagName)
    {
        case "i":
            elem.tagName = "em";
            break;
        case "b":
            elem.tagName = "strong";
            break;
        case "article":
            elem.tagName = "div";
            elem.addClass("article");
            break;
        case "button":
            elem.tagName = "span";
            elem.addClass("button");
            break;
        case "s":
            elem.tagName = "span";
            elem.attrs["style"] = "text-decoration: line-through";
            break;
        case "u":
            elem.tagName = "span";
            elem.attrs["style"] = "text-decoration: underline";
            break;
        default:
            break;
    }

    // <br><br> should become <p>
    // <br>\s+<br> should become <p>
    size_t[] boundaries;
    auto childNodes = elem.childNodes.dup;
    foreach (i; 0..childNodes.length)
    {
        if (i >= childNodes.length - 2) break;
        if (childNodes[i].tagName == "br" && childNodes[i + 1].tagName == "br")
        {
            boundaries ~= i;
            childNodes[i] = null;
            childNodes[i + 1] = null;
            continue;
        }
        if (
                childNodes[i].tagName == "br" &&
                cast(TextNode)childNodes[i + 1] &&
                childNodes[i + 1].directText.strip == "" &&
                childNodes[i + 2].tagName == "br")
        {
            boundaries ~= i;
            childNodes[i] = null;
            childNodes[i + 1] = null;
            childNodes[i + 2] = null;
        }
    }
    if (boundaries.length > 0)
    {
        Element[][] paragraphs;
        size_t start = 0;
        foreach (b; boundaries)
        {
            paragraphs ~= childNodes[start .. b];
            start = b;
        }
        paragraphs ~= childNodes[start .. $];

        foreach (para; paragraphs)
        {
            if (!para.canFind!(x => !!x)) continue;
            auto p = new Element(elem.parentDocument, "p");
            foreach (line; para)
                if (line)
                    line.reparent(p);
            elem.appendChild(p);
        }
    }
}
