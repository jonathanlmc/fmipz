pub const episode = @import("episode.zig");
pub const parse = @import("parse.zig");
pub const series = @import("series.zig");

pub const Episode = episode.Single;
pub const Series = series.Single;

const std = @import("std");
const mecha = @import("mecha");

comptime {
    std.testing.refAllDecls(@This());
}

pub const ParseError = error{
    Unmatched,
} || mecha.Error;

pub fn typecheckSeriesFormats(comptime SeriesFmt: type) void {
    switch (@typeInfo(SeriesFmt)) {
        .@"enum", .void => {},
        else => @compileError("series format type must be an enum or void"),
    }
}
