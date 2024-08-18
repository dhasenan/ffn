module app;

import common;
import domain;

import core.time;
import std.experimental.logger;
import std.getopt;


import url;

int main(string[] args)
{
    version (linux)
    {
        import etc.linux.memoryerror : registerMemoryErrorHandler;
        registerMemoryErrorHandler;
    }
    double delay = 0;
    bool verbose = false;
    bool listAdapters;
    auto opts = getopt(args,
        "s|save-temp-dir", "save downloaded files in the given directory", &Options.saveRawPath,
        "d|delay", "seconds of extra delay between downloads", &delay,
        "v|verbose", "print verbose logging information", &verbose,
        "a|adapter", "which adapter to use", &Options.adapterName,
        "chapter-list", "file containing a list of chapters", &Options.chapterListFile,
        "title", "title (overrides autodetection)", &Options.title,
        "author", "author (overrides autodetection)", &Options.author,
        "list-adapters", "list the available adapters", &listAdapters);
    if (opts.helpWanted)
    {
        defaultGetoptPrinter("ffn: grab ebooks from fanfiction.net and more", opts.options);
        return 1;
    }

    if (listAdapters)
    {
        foreach (adapter; allAdapters ~ seriesAdapters)
        {
            import std.stdio;
            writefln(adapter.name);
        }
    }

    Options.extraTimeBetweenChapters = (cast(long)(delay * 1000)).dur!"msecs";
    if (verbose)
    {
        globalLogLevel = LogLevel.trace;
    }
    else
    {
        globalLogLevel = LogLevel.warning;
    }

    if (Options.chapterListFile)
    {
        Fic b = fetchFromChapterList();
        writeFic(b);
        return 0;
    }

    foreach (arg; args[1 .. $])
    {
        Fic b;
        try
        {
            b = fetch(arg.parseURL);
        }
        catch (Exception e)
        {
            errorf("error downloading book %s: %s", arg, e);
        }
        writeFic(b);
    }
    return 0;
}

void writeFic(Fic b)
{
    b.write(b.naturalTitle("html"));
    b.writeEpub(b.naturalTitle("epub"));
    import std.stdio;
    writefln("wrote ebooks to %s and %s", b.naturalTitle("html"), b.naturalTitle("epub"));
}
