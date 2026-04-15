pub const episode = @import("episode.zig");
pub const parse = @import("parse.zig");

const std = @import("std");
const mecha = @import("mecha");

comptime {
    std.testing.refAllDecls(@This());
}

pub const ParseError = error{
    Unmatched,
} || mecha.Error;

pub fn Series(comptime Formats: type) type {
    typecheckSeriesFormats(Formats);

    return struct {
        const Self = @This();

        pub const Format = Formats;
        pub const Episode = episode.Single(Self.Format);

        pub fn fromFilename(filename: []const u8) Self {
            _ = filename;
            return .{};
        }
    };
}

pub fn typecheckSeriesFormats(comptime Format: type) void {
    switch (@typeInfo(Format)) {
        .@"enum", .void => {},
        else => @compileError("series format type must be an enum or void"),
    }
}
