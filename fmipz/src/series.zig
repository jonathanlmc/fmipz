const std = @import("std");
const fmipz = @import("fmipz.zig");
const parse = fmipz.parse;

const ParseError = fmipz.ParseError;

/// A single media series.
///
/// `SeriesFmt` defines the various formats (such as a TV show or special) that
/// this series and its child episodes will use during parsing to provide more
/// data on what format the series / specific episode belongs to. If this functionality
/// is not needed then `void` can be used for its type, otherwise an `enum` should be
/// provided with case-insensitive variants.
pub fn Single(comptime SeriesFmt: type) type {
    fmipz.typecheckSeriesFormats(SeriesFmt);

    return struct {
        const Self = @This();

        pub const Format = SeriesFmt;
        pub const Episode = fmipz.episode.Single(Self.Format);

        /// A slice of the provided filename that _should_ contain a cleaned
        /// version of the series name.
        ///
        /// Currently, cleaning the name just involves stripping out any supported
        /// tags (bracket or parenthesis based, and resolution tags) and season markers.
        trimmed_name: []const u8,

        /// Attempt to extract basic series information from a given filename.
        ///
        /// This is intended (but not required) to be used on directories.
        ///
        /// This does not currently do much beyond attempting to obtain a
        /// series name that has been trimmed / cleaned of noise. To obtain
        /// more detailed data such as season numbers, parsing individual episode
        /// files with this struct's `Episode.fromFilename` function can be used.
        pub fn fromFilename(filename: []const u8) ParseError!Self {
            if (filename.len == 0) return ParseError.Unmatched;

            // `parsed_filename` does not allocate, so provide an
            // allocator without any backing capacity to it
            const alloc = blk: {
                var buffer = [0]u8{};
                var fba: std.heap.FixedBufferAllocator = .init(&buffer);
                break :blk fba.allocator();
            };

            const result = try parse.series.parsed_filename.parse(alloc, filename);

            return switch (result.value) {
                .ok => |trimmed| .{ .trimmed_name = trimmed },
                .err => ParseError.Unmatched,
            };
        }
    };
}

test "Single.fromFilename" {
    const Expect = struct {
        fn okTrimmed(input: []const u8, expected_trim: []const u8) !void {
            try std.testing.expectEqualDeep(
                Single(void){
                    .trimmed_name = expected_trim,
                },
                try Single(void).fromFilename(input),
            );
        }
    };

    try Expect.okTrimmed("Title", "Title");
    try Expect.okTrimmed("Series Title", "Series Title");
    try Expect.okTrimmed("[Tag] Title", "Title");
    try Expect.okTrimmed("(Tag 1) [Tag 2] Series Title", "Series Title");
    try Expect.okTrimmed("Series Title [Tag 1]", "Series Title");
    try Expect.okTrimmed("Series Title 720p", "Series Title");
    try Expect.okTrimmed("Series Title S1", "Series Title");
    try Expect.okTrimmed("Series Title S01", "Series Title");
    try Expect.okTrimmed(
        "[Tag 1] Series Title 1080p S02 (Tag 2)",
        "Series Title",
    );
}
