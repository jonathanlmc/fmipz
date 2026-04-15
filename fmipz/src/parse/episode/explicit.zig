//! Parsers that look for episode and season numbers that are explicitly marked.
//!
//! For example:
//!
//! * `Title - S01E02`
//! * `Title - Episode 1`

const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");
const episode = @import("../episode.zig");
const parse = @import("../../parse.zig");
const root = @import("root");

const errBacktrack = mecha_ext.errBacktrack;

comptime {
    std.testing.refAllDecls(@This());
}

pub fn parsedFilename(comptime SeriesFmt: type) mecha.Parser(
    episode.Parsed(SeriesFmt),
) {
    return mecha.combine(.{
        parse.many_tags_with_whitespace,
        mecha_ext.skipTill(anyMarkerType(SeriesFmt), .parser),
    });
}

pub fn anyMarkerType(comptime SeriesFmt: type) mecha.Parser(
    episode.Parsed(SeriesFmt),
) {
    return mecha.oneOf(.{
        seasonFollowedByEpisode(SeriesFmt),
        episodeNumMarker(SeriesFmt).map(struct {
            fn map(res: EpisodeNumMarker(SeriesFmt)) episode.Parsed(SeriesFmt) {
                return .{
                    .number = res.number,
                    .format = res.series_format,
                    .season = null,
                };
            }
        }.map),
    });
}

pub fn seasonFollowedByEpisode(comptime SeriesFmt: type) mecha.Parser(
    episode.Parsed(SeriesFmt),
) {
    return mecha.combine(.{
        season_marker,
        parse.maybe_whitespace,
        mecha.utf8.char('-').opt().discard(),
        parse.maybe_whitespace,
        episodeHeader(SeriesFmt).opt(),
        episode.parsed_number,
    }).map(struct {
        fn map(res: @Tuple(
            &[_]type{ u16, ??SeriesFmt, u32 },
        )) episode.Parsed(SeriesFmt) {
            const season, const format, const ep_num = res;
            return .{
                .number = ep_num,
                .format = if (format) |fmt| fmt else null,
                .season = season,
            };
        }
    }.map);
}

const season_marker: mecha.Parser(u16) = errBacktrack(mecha.combine(.{
    mecha.oneOf(.{
        errBacktrack(mecha.combine(.{
            mecha_ext.stringIgnoreCase("season"),
            parse.any_whitespace,
        })).discard(),
        mecha_ext.charIgnoreCase('s').discard(),
    }),
    mecha.int(u16, .{ .parse_sign = false }),
}));

pub fn episodeHeader(comptime SeriesFmt: type) mecha.Parser(?SeriesFmt) {
    return mecha.oneOf(.{
        mecha.combine(.{
            mecha_ext.stringIgnoreCase("episode"),
            parse.any_whitespace,
        }).mapConst(@as(?SeriesFmt, null)),
        mecha.combine(.{
            mecha_ext.stringIgnoreCase("ep"),
            parse.maybe_whitespace,
        }).mapConst(@as(?SeriesFmt, null)),
        mecha_ext.charIgnoreCase('e').mapConst(@as(?SeriesFmt, null)),
        mecha_ext.optValueCast(episode.anyBareSeriesFormat(SeriesFmt)),
    });
}

pub fn EpisodeNumMarker(comptime SeriesFmt: type) type {
    return struct {
        series_format: ?SeriesFmt,
        number: u32,
    };
}

pub fn episodeNumMarker(comptime SeriesFmt: type) mecha.Parser(
    EpisodeNumMarker(SeriesFmt),
) {
    return errBacktrack(mecha.combine(.{
        episodeHeader(SeriesFmt),
        episode.separator.opt().discard(),
        episode.parsed_number,
    })).map(mecha.toStruct(EpisodeNumMarker(SeriesFmt)));
}
