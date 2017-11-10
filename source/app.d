module app;

import common;
import domain;

import core.time;
import std.experimental.logger;
import std.getopt;

import url;

int main(string[] args)
{
    double delay = 0;
    bool verbose = false;
    auto opts = getopt(args, "s|save-temp-dir",
        "save downloaded files in the given directory", &Options.saveRawPath,
        "d|delay", "seconds of extra delay between downloads", &delay,
        "v|verbose", "print verbose logging information", &verbose);
    if (opts.helpWanted)
    {
        defaultGetoptPrinter("ffn: grab ebooks from fanfiction.net and more", opts.options);
        return 1;
    }

    Options.extraTimeBetweenChapters = (cast(long)(delay * 1000)).dur!"msecs";
    if (verbose)
    {
        globalLogLevel = LogLevel.warning;
    }

    foreach (arg; args[1 .. $])
    {
        Book b;
        try
        {
            b = fetch(arg.parseURL);
        }
        catch (Exception e)
        {
            errorf("error downloading book %s: %s", arg, e);
        }

        b.write(b.naturalTitle("html"));
        b.writeEpub(b.naturalTitle("epub"));
    }
    return 0;
}
