const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");
const parse = @import("../../parse.zig");
const episode = @import("../episode.zig");

const errBacktrack = mecha_ext.errBacktrack;

comptime {
    std.testing.refAllDecls(@This());
}

pub fn parsedFilename(comptime SeriesFmt: type) mecha.Parser(
    episode.Parsed(SeriesFmt),
) {
    return errBacktrack(mecha.combine(.{
        parse.many_tags_with_whitespace,
        mecha.oneOf(.{
            episode_in_middle_of_filename,
            episode_number_only,
            episode_number_at_start,
        }),
    })).map(struct {
        fn conv(number: u32) episode.Parsed(SeriesFmt) {
            return .{
                .number = number,
                .season = null,
                .format = null,
            };
        }
    }.conv);
}

pub const episode_in_middle_of_filename: mecha.Parser(u32) = blk: {
    const skip_desc_until_end = mecha.combine(.{
        episode.separator,
        // edge case: if there's digits right after the separator, this is likely the
        // real episode number, and not the digits that were already parsed with
        // `episode_number`, so fail the parser so these digits can be tried during
        // a later iteration
        //
        // example title with this case: `1 Series Title 2 - 06`
        mecha_ext.not(mecha.intToken(.{ .parse_sign = false })),
        mecha_ext.skipTill(
            episode.rest_of_filename_tags_only,
            .none,
        ),
    });

    break :blk mecha_ext.skipTill(
        mecha.combine(.{
            episode_number,
            mecha.oneOf(.{
                episode.rest_of_filename_tags_only,
                skip_desc_until_end,
            }),
        }),
        .parser,
    );
};

pub const episode_number_only: mecha.Parser(u32) = errBacktrack(mecha.combine(.{
    episode.parsed_number,
    episode.rest_of_filename_tags_only,
}));

pub const episode_number_at_start: mecha.Parser(u32) = errBacktrack(mecha.combine(.{
    episode.parsed_number,
    // version string
    mecha.oneOf(.{mecha.combine(.{
        parse.maybe_whitespace,
        episode.file_version,
    })}).opt().discard(),
    // require the separator, since this can be too ambiguous with
    // a series title otherwise
    episode.separator,
}));

pub const episode_number: mecha.Parser(u32) = errBacktrack(mecha.combine(.{
    mecha.oneOf(.{ parse.any_whitespace, episode.separator }),
    episode.parsed_number,
    // if there's more digits that follow closely after this set,
    // then the parsed digits above are likely a season number and not
    // the episode number we're actually looking for, so fail
    // the parser in that case
    mecha_ext.not(mecha.combine(.{
        mecha.oneOf(.{ parse.any_whitespace, episode.separator }),
        mecha.intToken(.{ .parse_sign = false }),
    })),
}));
