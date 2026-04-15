const std = @import("std");
const fmipz = @import("fmipz.zig");
const parse = fmipz.parse;

const ParseError = fmipz.ParseError;

pub fn Single(comptime SeriesFmt: type) type {
    fmipz.typecheckSeriesFormats(SeriesFmt);

    return struct {
        const Self = @This();

        pub const Format = SeriesFmt;
        pub const Episode = fmipz.episode.Single(Self.Format);

        trimmed_name: []const u8,

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
