const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");
const parse = @import("../parse.zig");

const Allocator = std.mem.Allocator;
const errBacktrack = mecha_ext.errBacktrack;

comptime {
    std.testing.refAllDecls(@This());
}

pub fn trimName(alloc: Allocator, name: []const u8) mecha.Error!mecha.Result([]const u8) {
    const many_tags = comptime parse.any_tag_with_whitespace.many(
        .{ .collect = false },
    );

    const title_until_tag_or_end = comptime mecha_ext.skipTill(
        mecha.oneOf(.{
            parse.any_tag_with_whitespace.discard(),
            season_label.discard(),
            mecha.eos,
        }),
        .slice,
    );

    const parse_title = comptime mecha.combine(.{
        many_tags.discard(),
        title_until_tag_or_end,
    });

    return parse_title.parse(alloc, name);
}

test trimName {
    // no allocations expected
    const gpa = std.testing.failing_allocator;

    try mecha.expectOk(
        []const u8,
        5,
        "Title",
        try trimName(gpa, "Title"),
    );

    try mecha.expectOk(
        []const u8,
        12,
        "Series Title",
        try trimName(gpa, "Series Title"),
    );

    try mecha.expectOk(
        []const u8,
        11,
        "Title",
        try trimName(gpa, "[Tag] Title"),
    );

    try mecha.expectOk(
        []const u8,
        28,
        "Series Title",
        try trimName(gpa, "(Tag 1) [Tag 2] Series Title"),
    );

    try mecha.expectOk(
        []const u8,
        20,
        "Series Title",
        try trimName(gpa, "Series Title [Tag 1]"),
    );

    try mecha.expectOk(
        []const u8,
        17,
        "Series Title",
        try trimName(gpa, "Series Title 720p"),
    );

    try mecha.expectOk(
        []const u8,
        15,
        "Series Title",
        try trimName(gpa, "Series Title S1"),
    );

    try mecha.expectOk(
        []const u8,
        16,
        "Series Title",
        try trimName(gpa, "Series Title S01"),
    );

    try mecha.expectOk(
        []const u8,
        27,
        "Series Title",
        try trimName(gpa, "[Tag 1] Series Title 1080p S02 (Tag 2)"),
    );
}

const season_label = errBacktrack(mecha.combine(.{
    parse.any_whitespace.discard(),
    mecha.utf8.char('S').discard(),
    mecha.intToken(.{ .parse_sign = false }),
    mecha.oneOf(.{ parse.any_whitespace, mecha.eos }).discard(),
}));

test season_label {
    // no allocations expected
    const gpa = std.testing.failing_allocator;

    const ok_value = " S01";

    try std.testing.expectEqualDeep(
        mecha.Result([]const u8).ok(ok_value.len, "01"),
        try season_label.parse(gpa, ok_value),
    );
}
