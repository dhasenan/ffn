module domain;

import arsd.dom;

import std.format;
import std.stdio;

/**
    A chapter from a story.
*/
struct Chapter
{
    /// The title of the chapter.
    string title;
    /// The HTML content of the chapter.
    Element content;
}

/**
    A book (a story) that may contain several chapters.
*/
struct Book
{
    /// The title of the book.
    string title;
    /// The author.
    string author;
    /// The short description.
    string slug;
    /// The chapters.
    Chapter[] chapters;

    /// The natural filename to use. Restricts to alphanum + whitespace.
    string naturalTitle(string ext)
    {
        import std.algorithm, std.array, std.uni, std.conv;

        return title.filter!(x => isAlphaNum(x) || isSpace(x)).array.to!string ~ "." ~ ext;
    }

    /// Write this book as HTML to the given file.
    void write(string filename)
    {
        auto f = File(filename, "w");
        f.write(`<html><head><title>`);
        f.write(title);
        f.write("</title></head>\n");
        f.write("<body>\n");
        f.write(`<h1 id="title">`);
        f.write(title);
        f.write("</h1>\n");
        f.write(`<h2 id="author">`);
        f.write(author);
        f.write("</h2>\n");
        f.write(`<div id="slug">`);
        f.write(slug);
        f.write("</div>\n");
        foreach (chap; chapters)
        {
            f.write(`<h2 class="chapter">`);
            f.write(chap.title);
            f.write("</h2>\n");
            if (chap.content)
            {
                f.write(chap.content.toString);
            }
            else
            {
                f.write("(missing chapter content)");
            }
        }
        f.flush;
        f.close;
    }

    void writeEpub(string filename)
    {
        static import epub;

        alias EBook = epub.Book;
        alias EChap = epub.Chapter;
        alias Cover = epub.Cover;

        auto eb = new EBook();
        eb.title = title;
        eb.author = author;
        eb.chapters ~= EChap("Title page", true,
            format(`<?xml version='1.0' encoding='utf-8'?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    </head>
    <body>
        <h1 class="bookTitle">%s</h1>
        <h2 class="author">%s</h1>
        <div class="slug">%s</div>
    </body>
<html>`,
            title, author, slug));
        foreach (size_t i, Chapter c; chapters)
        {
            import std.format : format;

            EChap ec = EChap(c.title, true,
                // Chapter has to be an xhtml document. Build it!
                // ...do I want default CSS?
                format(`<?xml version='1.0' encoding='utf-8'?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    </head>
    <body>
        <h1 class="chapterTitle">%s</h1>
        %s
    </body>
<html>`,
                c.title, c.content.toString));
            eb.chapters ~= ec;
        }

        import std.uuid : randomUUID;
        eb.id = randomUUID.toString;

        enum VERSION = "1.0.0";
        Cover cover = {
          generator: "ffn-" ~ VERSION,
          book: eb,
        };
        //eb.coverImage = epub.render(cover);
        epub.toEpub(eb, filename);
    }
}
