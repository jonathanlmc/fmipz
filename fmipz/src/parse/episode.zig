pub const explicit = @import("episode/explicit.zig");
pub const implicit = @import("episode/implicit.zig");

const std = @import("std");
const mecha = @import("mecha");
const mecha_ext = @import("mecha_ext");
const parse = @import("../parse.zig");
const fmipz = @import("../fmipz.zig");

const Allocator = std.mem.Allocator;

comptime {
    std.testing.refAllDecls(@This());
}

pub fn Parsed(comptime SeriesFormat: type) type {
    return struct {
        number: u32,
        season: ?u16,
        format: ?SeriesFormat,
    };
}

pub fn parsedFilename(comptime SeriesFmt: type) mecha.Parser(Parsed(SeriesFmt)) {
    return mecha.oneOf(.{
        // look for an explicit marker first before falling back to an implicit one
        // to help avoid false positive matches
        parse.episode.explicit.parsedFilename(SeriesFmt),
        parse.episode.implicit.parsedFilename(SeriesFmt),
    });
}

pub fn anyBareSeriesFormat(comptime SeriesFmt: type) mecha.Parser(SeriesFmt) {
    return comptime blk: {
        if (@typeInfo(SeriesFmt) == .void) return mecha_ext.err(SeriesFmt);

        const fields = std.meta.fields(SeriesFmt);
        var fields_arr: [fields.len]mecha.Parser(SeriesFmt) = undefined;

        for (fields, 0..) |field, i| {
            fields_arr[i] = mecha_ext.stringIgnoreCase(field.name)
                .mapConst(@field(SeriesFmt, field.name));
        }

        break :blk mecha.oneOf(fields_arr);
    };
}

pub fn completeSeriesFormatLabel(comptime SeriesFmt: type) mecha.Parser(SeriesFmt) {
    if (@typeInfo(SeriesFmt) == .void) return mecha_ext.err(SeriesFmt);

    return mecha.combine(.{
        mecha.oneOf(.{
            anySeriesFormatInTag(SeriesFmt),
            anyBareSeriesFormat(SeriesFmt),
        }),
        file_version.opt().discard(),
    });
}

pub fn isolatedSeriesFormatLabel(comptime SeriesFmt: type) mecha.Parser(SeriesFmt) {
    if (@typeInfo(SeriesFmt) == .void) return mecha_ext.err(SeriesFmt);

    return mecha_ext.skipTill(
        mecha.combine(.{
            mecha.oneOf(.{ separator, parse.any_whitespace }),
            completeSeriesFormatLabel(SeriesFmt),
            mecha.oneOf(.{ separator, rest_of_filename_tags_only }),
        }),
        .parser,
    );
}

pub fn anySeriesFormatInTag(comptime SeriesFmt: type) mecha.Parser(SeriesFmt) {
    comptime if (@typeInfo(SeriesFmt) == .void) return mecha_ext.err(SeriesFmt);

    return parse.any_tag.convert(struct {
        fn conv(alloc: Allocator, str: []const u8) mecha.ConvertError!SeriesFmt {
            const res = try anyBareSeriesFormat(SeriesFmt).parse(
                alloc,
                str,
            );

            return switch (res.value) {
                .ok => |v| v,
                .err => mecha.ConvertError.ConversionFailed,
            };
        }
    }.conv);
}

pub const parsed_number = mecha.int(u32, .{ .parse_sign = false });

pub const separator = mecha.combine(.{
    parse.maybe_whitespace,
    mecha.utf8.char('-'),
    parse.maybe_whitespace,
}).discard();

pub const file_version: mecha.Parser(void) = mecha.combine(.{
    mecha_ext.charIgnoreCase('v'),
    mecha.intToken(.{ .parse_sign = false }),
}).discard();

pub const rest_of_filename_tags_only = mecha.combine(.{
    mecha.combine(.{ separator, parse.any_whitespace }).opt(),
    mecha.many(parse.any_tag_with_whitespace, .{ .collect = false }),
    parse.maybe_whitespace,
    mecha.eos,
}).discard();
