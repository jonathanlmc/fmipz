const std = @import("std");
const mecha = @import("mecha");
const parse = @import("parse.zig");
const fmipz = @import("fmipz.zig");

comptime {
    std.testing.refAllDecls(@This());
}

const ParseError = fmipz.ParseError;

pub fn Single(comptime SeriesFmt: type) type {
    fmipz.typecheckSeriesFormats(SeriesFmt);

    return struct {
        const Self = @This();

        /// The episode number parsed from the filename.
        number: u32,
        /// A hint indicating which season this episode may belong to,
        /// based off the filename.
        season: ?u16,
        /// A hint indicating which series format this episode may belong to,
        /// based off the filename.
        format: ?SeriesFmt,

        /// Attempt to extract episode and/or series information from a given filename stem.
        ///
        /// The provided filename **must** have its extension stripped with a function like
        /// `std.fs.path.stem` before being passed to this function, or parsing may fail.
        ///
        /// Filenames that contain explicit markers (such as `S01E01` or `Episode 01`)
        /// are virtually guaranteed to always parse. Filenames with implicit
        /// markers (such as `Series Title 01`) can also *generally* be parsed,
        /// unless the location of the episode number is nonsensical.
        ///
        /// See the tests for this function to get a general idea of the types of formats
        /// that are explicitly supported.
        pub fn fromFilenameStem(filename_stem: []const u8) ParseError!Self {
            if (filename_stem.len == 0) return ParseError.Unmatched;

            // none of the parsers allocate, so provide an allocator without any backing capacity
            // to them
            const alloc = blk: {
                var buffer = [0]u8{};
                var fba: std.heap.FixedBufferAllocator = .init(&buffer);
                break :blk fba.allocator();
            };

            const parsed_result = try parse
                .episode
                .parsedFilename(SeriesFmt)
                .parse(alloc, filename_stem);

            const format = blk: {
                switch (parsed_result.value) {
                    .ok => |v| if (v.format != null) break :blk v.format,
                    .err => {},
                }

                const hint_result = try parse
                    .episode
                    .isolatedSeriesFormatLabel(SeriesFmt)
                    .parse(alloc, filename_stem);

                break :blk switch (hint_result.value) {
                    .ok => |hint| hint,
                    .err => null,
                };
            };

            return switch (parsed_result.value) {
                .ok => |parsed| .{
                    .number = parsed.number,
                    .season = parsed.season,
                    .format = format,
                },
                // if we at least have a type hint, treat it as a one-off
                .err => if (format != null) .{
                    .number = 1,
                    .season = null,
                    .format = format,
                } else ParseError.Unmatched,
            };
        }
    };
}

fn FilenameTest(comptime SeriesFmt: type) type {
    return struct {
        const T = SeriesFmt;
        const Episode = Single(SeriesFmt);

        fn okNum(input: []const u8, ep_num: u32) !void {
            try std.testing.expectEqualDeep(
                Episode{
                    .number = ep_num,
                    .season = null,
                    .format = null,
                },
                try Episode.fromFilenameStem(input),
            );
        }

        fn okNumAndSeason(input: []const u8, ep_num: u32, season: u16) !void {
            try std.testing.expectEqualDeep(
                Episode{
                    .number = ep_num,
                    .season = season,
                    .format = null,
                },
                try Episode.fromFilenameStem(input),
            );
        }

        fn okNumSeasonAndFmt(
            input: []const u8,
            ep_num: u32,
            season: ?u16,
            format: SeriesFmt,
        ) !void {
            try std.testing.expectEqualDeep(
                Episode{
                    .number = ep_num,
                    .season = season,
                    .format = if (SeriesFmt == void) null else format,
                },
                try Episode.fromFilenameStem(input),
            );
        }

        fn unmatched(input: []const u8) !void {
            try std.testing.expectError(
                error.Unmatched,
                Episode.fromFilenameStem(input),
            );
        }
    };
}

const FilenameTestImpl = union(enum) {
    const BasicFormat = enum { tv, movie };

    const impls = [_]FilenameTestImpl{
        .{ .basic_fmts = .{} },
        .{ .no_fmt = .{} },
    };

    basic_fmts: FilenameTest(BasicFormat),
    no_fmt: FilenameTest(void),

    fn okNum(self: @This(), input: []const u8, ep_num: u32) !void {
        return switch (self) {
            inline else => |impl| @TypeOf(impl).okNum(input, ep_num),
        };
    }

    fn okNumAndSeason(
        self: @This(),
        input: []const u8,
        ep_num: u32,
        season: u16,
    ) !void {
        return switch (self) {
            inline else => |impl| @TypeOf(impl).okNumAndSeason(
                input,
                ep_num,
                season,
            ),
        };
    }

    fn okNumSeasonAndFmt(
        self: @This(),
        input: []const u8,
        ep_num: u32,
        season: ?u16,
        format: BasicFormat,
    ) !void {
        return switch (self) {
            inline else => |impl| @TypeOf(impl).okNumSeasonAndFmt(
                input,
                ep_num,
                season,
                if (@TypeOf(impl).T == void) {} else format,
            ),
        };
    }
};

test "fromFilenameStem: episode marker only" {
    inline for (FilenameTestImpl.impls) |impl| {
        try impl.okNum("Series Title - 12", 12);
        try impl.okNum("Series Title - E12", 12);
        try impl.okNum("Series Title.-.E12", 12);
        try impl.okNum("E12 - Series Title", 12);
        try impl.okNum("Episode 12 - Series Title", 12);
        try impl.okNum("12 - Series Title", 12);
        try impl.okNum("12v2 - Series Title", 12);
        try impl.okNum("E12v2 - Series Title", 12);
        try impl.okNum("Series Title - E12v2", 12);
        try impl.okNum("Series Title - 12v2", 12);
        try impl.okNum("[Tag 1] 12 - Series Title", 12);
        try impl.okNum("[Tag 1] 12 - 1 Series Title", 12);
        try impl.okNum("[Tag 1] Episode 12 - Series Title", 12);
        try impl.okNum("[Tag 1] Episode 12 - Series Title 02", 12);
        try impl.okNum("[Tag 1] Ep12 - 1 Series Title", 12);
        try impl.okNum("[Tag_1]_Series_Title_-_12", 12);
        try impl.okNum("[Tag 1] Series Title - 12", 12);
        try impl.okNum("[Tag 1][Tag 2] Series Title - 12", 12);
        try impl.okNum("[Tag 1] [Tag 2] Series Title - 12", 12);
        try impl.okNum("Series Title 2 12", 12);
        try impl.okNum("Series Title 2 E12", 12);
        try impl.okNum("Series Title 2 Ep 12", 12);
        try impl.okNum("Series Title 2 12_(Tag 1)", 12);
        try impl.okNum("Series Title - 001", 1);
        try impl.okNum("Series Title - E001", 1);
        try impl.okNum("Series Title - ep 001", 1);
        try impl.okNum("Series Title - episode 001", 1);
        try impl.okNum("Series_Title_12", 12);
        try impl.okNum("Series Title-12", 12);
        try impl.okNum("Series Title 12 (1080p)", 12);
        try impl.okNum("Series Title 2 12 - An Episode Description [1080p]", 12);
        try impl.okNum("[Tag 1] Series 2 Title - 12 [Tag 2]", 12);
        try impl.okNum("[Tag 1] 1 2 Series Title - 06 [Tag 2]", 6);
        try impl.okNum("[Tag 1] 1 2 Series Title 06 [Tag 2]", 6);
        try impl.okNum("[Tag 1] 1 2 Series Title 3 06 [Tag 2]", 6);
        try impl.okNum("[Tag 1] 1 2 Series Title 3 - 06 [Tag 2]", 6);
        try impl.okNum("[Tag 1] Mutli-Separated 1-Title 2 - E12 [10]", 12);
        try impl.okNum("[Tag 1] 12 - Multi - Title [10]", 12);
        try impl.okNum("06", 6);
        try impl.okNum("07 [Tag 1]", 7);
        try impl.okNum("[Tag 1] 08", 8);
        try impl.okNum(
            "[Tag 1] Episode 12 - Series Title - Description 123 [Tag 2]",
            12,
        );
    }
}

test "fromFilenameStem: season hint and episode marker" {
    inline for (FilenameTestImpl.impls) |impl| {
        try impl.okNumAndSeason("Series Title - S01E02", 2, 1);
        try impl.okNumAndSeason("Series Title - S01E02 [Tag 1]", 2, 1);
        try impl.okNumAndSeason("Series Title - S01E02v3", 2, 1);
        try impl.okNumAndSeason("S01E12 - Series Title", 12, 1);

        // test that `Episode 1` isn't parsed as the episode
        try impl.okNumAndSeason("S01E12 - Series Title - Episode 1 Description", 12, 1);

        try impl.okNumAndSeason("[Tag] Series Title S2E01 (Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title S02E01 (Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2_-_01_(Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2 Episode 01 (Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 02 Episode 01 (Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2_-_01_(Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2 - 01", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2-01 (Tag 2)", 1, 2);
        try impl.okNumAndSeason("[Tag] Series Title Season 2 Episode 1", 1, 2);
    }
}

test "fromFilenameStem: episode with format hint" {
    const fmt_impl: FilenameTestImpl = .{ .basic_fmts = .{} };

    try fmt_impl.okNumSeasonAndFmt("Series Title TV - 12", 12, null, .tv);
    try fmt_impl.okNumSeasonAndFmt("Series Title - 12 (TV)", 12, null, .tv);
    try fmt_impl.okNumSeasonAndFmt(
        "Series Title Movie - 12",
        12,
        null,
        .movie,
    );
    try fmt_impl.okNumSeasonAndFmt("Series Title - S01TV02", 2, 1, .tv);
    try fmt_impl.okNumSeasonAndFmt(
        "Series Title Movie - S00E01",
        1,
        0,
        .movie,
    );
    try fmt_impl.okNumSeasonAndFmt(
        "Series Title TVv50 - S01E06",
        6,
        1,
        .tv,
    );

    const no_fmt_impl = FilenameTest(void);

    try no_fmt_impl.okNumSeasonAndFmt("Series Title TV - 12", 12, null, {});
    try no_fmt_impl.okNumSeasonAndFmt("Series Title - 12 (TV)", 12, null, {});
    try no_fmt_impl.okNumSeasonAndFmt(
        "Series Title TVv50 - S01E06",
        6,
        1,
        {},
    );

    try no_fmt_impl.unmatched("Series Title - S01TV02");
}

test "fromFilenameStem: one off episode" {
    const fmt_impl: FilenameTestImpl = .{ .basic_fmts = .{} };

    try fmt_impl.okNumSeasonAndFmt("Series Title - TV", 1, null, .tv);
    try fmt_impl.okNumSeasonAndFmt("Series Title - TVv2", 1, null, .tv);
    try fmt_impl.okNumSeasonAndFmt("Series Title Movie", 1, null, .movie);

    const no_fmt_impl = FilenameTest(void);

    try no_fmt_impl.unmatched("Series Title - TV");
    try no_fmt_impl.unmatched("Series Title - TVv2");
    try no_fmt_impl.unmatched("Series Title Movie");
}
