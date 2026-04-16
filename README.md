## *F*ilename *M*edia *I*nfo *P*arser _for_ *Z*ig

This is a Zig library to parse strings / filenames such as `Series Name - S01E01` for its identifying media information.

## Features

There are currently two distinct parsers available, each of which are intended for use on different types of strings / filenames:

- [Series](#series-parser) parser for directory names that reference a series.
- [Episode](#episode-parser) parser for filenames that contain episode information.

Additionally:

- No allocations. Each parser returns slices of the original input when needed.
- Parser combinators used by each high-level parser are publicly exported and can be used to build custom parsers for more esoteric filename layouts.
- Extensions to the `mecha` library that are used internally are available in a separate `mecha_ext` module.

This library was made for my own [anup](https://github.com/jonathanlmc/anup) project that is being rewritten in Zig.
Additions to functionality / data extracted for this library are generally based off that project's requirements, although
I am open to adding more extracted data to each parser (as long as the request is reasonable).

### Series Parser

For directory names that reference a series, such as `[Tag] Series Name 1080p`. This parser attempts to extract the following data:

| Data | Description |
| ---- | ----------- |
| Trimmed name | The series name without any tags (including resolution tags). For the example above, the trimmed name would be `Series Name`. |

For a list of file layouts explicitly supported by this parser, see its tests [here](https://github.com/jonathanlmc/fmipz/blob/18e923b97fc0018e7c3aa62fbe247f7c1f8d275d/fmipz/src/series.zig#L59-L83).

### Episode Parser

For files that contain episode information, such as `[Tag] Series Name - S01E01.mp4`. This parser attempts to extract the following data:

| Data          | Description | Optional |
| ------------- | ------------- | -- |
| Episode number  | This can either appear explicitly (i.e. marked with something like `E01` or `Episode 01`) or implicitly (i.e. arbitrarily in the filename, such as `Series Name 01.mp4`). | No |
| Season number | Must appear explicitly (i.e. as `S01` or `Season 01`). | Yes |
| Series format | Only parsed if the episode parser was created with an `enum` describing which formats to look for. This can be used to help identify if an episode belongs to a specific format of a series (such as a TV season or movie). This is not inferred from the presence of a season number since some media like anime can have multiple seasons of a show for specific formats (such as multiple special or OVA seasons). | Yes |

For a list of file layouts explicitly supported by this parser, see its tests [here](https://github.com/jonathanlmc/fmipz/blob/18e923b97fc0018e7c3aa62fbe247f7c1f8d275d/fmipz/src/episode.zig#L198-L321).

## Dependencies

The only dependency is [`mecha`](https://github.com/Hejsil/mecha).

## Usage

Requires Zig 0.16.

First, fetch the library via `zig fetch`:

```bash
zig fetch --save git+https://github.com/jonathanlmc/fmipz
```

And then add the `fmipz` module to `build.zig`:

```zig
const fmipz = b.dependency("fmipz", .{});
exe.root_module.addImport("fmipz", fmipz.module("fmipz"));
```

## Example Usage

```zig
const std = @import("std");
const fmipz = @import("fmipz");

const BasicFormat = enum {
    // case-insensitive
    tv,
    movie,
};

const AnimeFormat = enum {
    tv,
    ova,
    ona,
};

pub fn main(_: std.process.Init) !void {
    // initialize a series parser that will detect each format in the `BasicFormat` enum
    const basic_series = fmipz.Series(BasicFormat);

    // series parsing does not currently have format detection
    const parsed_basic_series = basic_series.fromFilename(
        "[Tag 1] Series Title 2160p [Tag 2]",
    ) catch |err| switch (err) {
        error.Unmatched => @panic("series name was unable to be parsed"),
        else => @panic("internal mecha parser error"),
    };

    // output: Series Title
    std.debug.print("{s}\n", .{parsed_basic_series.trimmed_name});

    // `Episode` will inherit the formats for parsing
    const basic_ep = basic_series.Episode.fromFilenameStem(
        "Series Title TV - S01E02",
    ) catch |err| switch (err) {
        error.Unmatched => @panic("no episode number could be determined"),
        else => @panic("internal mecha parser error"),
    };

    // output:
    // episode number = 2
    // season = 1
    // format = tv
    std.debug.print("episode number = {d}\nseason = {?d}\nformat = {?t}\n", .{
        basic_ep.number,
        basic_ep.season,
        basic_ep.format,
    });

    // episodes can also be parsed directly, without going through `fmipz.Series`
    const anime_ep = try fmipz.Episode(AnimeFormat).fromFilenameStem(
        "Series Title OVA - 100",
    );

    // output:
    // episode number = 100
    // season = null
    // format = ova
    std.debug.print("episode number = {d}\nseason = {?d}\nformat = {?t}\n", .{
        anime_ep.number,
        anime_ep.season,
        anime_ep.format,
    });

    // initialize a series parser without any formats
    // this can also be done with `fmipz.Episode`
    const no_format_series = fmipz.Series(void);

    const no_format_ep = try no_format_series.Episode.fromFilenameStem(
        "E10 - Series Title TV",
    );

    // output:
    // episode number = 10
    // season = null
    // format = null
    std.debug.print("episode number = {d}\nseason = {?d}\nformat = {any}\n", .{
        no_format_ep.number,
        no_format_ep.season,
        no_format_ep.format,
    });
}
```
