module domain;

import arsd.dom;
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
        return title
            .filter!(x => isAlphaNum(x) || isSpace(x))
            .array
            .to!string
            ~ "." ~ ext;
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
			f.write(`<h2 id="chapter">`);
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
}
