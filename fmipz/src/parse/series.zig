const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");
const parse = @import("../parse.zig");

const Allocator = std.mem.Allocator;
const errBacktrack = mecha_ext.errBacktrack;

comptime {
    std.testing.refAllDecls(@This());
}

pub const parsed_filename = blk: {
    const many_tags = parse.any_tag_with_whitespace.many(
        .{ .collect = false },
    );

    const title_until_tag_or_end = mecha_ext.skipTill(
        mecha.oneOf(.{
            parse.any_tag_with_whitespace.discard(),
            season_label.discard(),
            mecha.eos,
        }),
        .slice,
    );

    break :blk mecha.combine(.{
        many_tags.discard(),
        title_until_tag_or_end,
    });
};

// todo: support ranges (ex. `S01-04` and `S01-S04`)
const season_label = errBacktrack(mecha.combine(.{
    parse.any_whitespace.discard(),
    mecha.utf8.char('S').discard(),
    mecha.intToken(.{ .parse_sign = false }),
    mecha.oneOf(.{ parse.any_whitespace, mecha.eos }).discard(),
}));
