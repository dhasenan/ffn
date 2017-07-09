module app;

import common;
import domain;

import std.stdio;
import std.getopt;

import url;


void main(string[] args)
{
	foreach (arg; args[1..$])
	{
		Book b;
		try
		{
			b = fetch(arg.parseURL);
		}
		catch (Exception e)
		{
			writefln("error downloading book %s: %s", arg, e);
		}
		
		b.write(b.naturalTitle("html"));
		b.writeEpub(b.naturalTitle("epub"));
	}
}
