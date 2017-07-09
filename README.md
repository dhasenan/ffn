# ffn: fiction downloader

## Supported sites

* Archive of Our Own
* fanfiction.net
* XenForo: SufficientVelocity, SpaceBattles (using reader mode)

## Installing

1. Get a reasonably recent D compiler and Dub. The 2.074 DMD compiler distribution should have both.
2. Run `dub build`

## Using

`./ffn 'url'`

## Output

ffn produces html and epub output. If you need another format, I recommend the rather good
`ebook-convert` utility shipped with Calibre.

azw3 / mobi output is a planned addition.
