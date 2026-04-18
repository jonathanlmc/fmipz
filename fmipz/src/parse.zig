//! Low-level `mecha` parsers used to parse series and episode information
//! internally by the higher-level `Series` and `Episode` API.
//!
//! This is exported publicly so the parsers can be used as building blocks
//! for custom series / episode filename formats not supported out-of-the-box,
//! but please keep in mind that they are still treated as an internal-only API
//! and may be changed or removed at-will.

pub const episode = @import("parse/episode.zig");
pub const series = @import("parse/series.zig");

const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");

const Allocator = std.mem.Allocator;

comptime {
    std.testing.refAllDecls(@This());
}

pub fn tag(comptime open_char: u8, comptime close_char: u8) mecha.Parser([]const u8) {
    return mecha.combine(.{
        mecha.ascii.char(open_char).discard(),
        // note that this does not handle nested tags (such as "((value))")
        mecha.many(mecha.utf8.not(mecha.ascii.char(close_char)), .{
            .collect = false,
            .min = 1,
        }),
        mecha.ascii.char(close_char).discard(),
    });
}

pub const parens_tag = tag('(', ')');
pub const brackets_tag = tag('[', ']');

pub const resolution_tags = [_]mecha.Parser([]const u8){
    mecha_ext.stringIgnoreCase("480p"),
    mecha_ext.stringIgnoreCase("720p"),
    mecha_ext.stringIgnoreCase("1080p"),
    mecha_ext.stringIgnoreCase("2160p"),
    mecha_ext.stringIgnoreCase("4320p"),
};

pub const any_tag = mecha.oneOf(.{
    parens_tag,
    brackets_tag,
    mecha.oneOf(resolution_tags),
});

pub const any_tag_with_whitespace = mecha.combine(.{
    maybe_whitespace,
    any_tag,
    maybe_whitespace,
});

pub const many_tags_with_whitespace: mecha.Parser(void) = mecha.many(
    any_tag_with_whitespace,
    .{ .collect = false },
).discard();

pub const valid_whitespace_char = mecha.utf8.wrap(struct {
    fn pred(ch: u21) bool {
        return ch == ' ' or ch == '_' or ch == '.';
    }
}.pred);

pub const any_whitespace = valid_whitespace_char.many(.{
    .min = 1,
    .collect = false,
}).discard();

pub const maybe_whitespace = valid_whitespace_char.many(.{
    .min = 0,
    .collect = false,
}).discard();
