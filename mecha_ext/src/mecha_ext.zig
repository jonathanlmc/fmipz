const std = @import("std");
const mecha = @import("mecha");

const Allocator = std.mem.Allocator;

pub const SkipTillOutput = enum {
    slice,
    parser,
    none,

    fn OutputType(self: SkipTillOutput, parser: anytype) type {
        return switch (self) {
            .slice => []const u8,
            .parser => parser,
            .none => void,
        };
    }
};

/// Skip input one byte at a time until `parser` succeeds.
///
/// No input will be consumed if the parser never succeeds.
pub fn skipTill(
    comptime parser: anytype,
    comptime output: SkipTillOutput,
) mecha.Parser(output.OutputType(ParserResult(@TypeOf(parser)))) {
    const Res = mecha.Result(output.OutputType(ParserResult(@TypeOf(parser))));

    return .{
        .parse = struct {
            fn parse(
                alloc: Allocator,
                str: []const u8,
            ) mecha.Error!Res {
                var match_idx: usize = 0;

                while (match_idx <= str.len) {
                    const parser_result = try parser.parse(
                        alloc,
                        str[match_idx..],
                    );

                    switch (parser_result.value) {
                        .err => match_idx += 1,
                        .ok => |parser_value| {
                            const ret = switch (output) {
                                .slice => str[0..match_idx],
                                .parser => parser_value,
                                .none => {},
                            };

                            // our final consumed input should include what
                            // the parser ate
                            match_idx += parser_result.index;

                            return Res.ok(match_idx, ret);
                        },
                    }
                }

                return Res.err(0);
            }
        }.parse,
    };
}

/// Obtain the inner result type for a parser.
///
/// This is a duplicate of `mecha`'s private `ParserResult` function.
fn ParserResult(comptime P: type) type {
    return switch (@typeInfo(P)) {
        .pointer => |p| p.child.T,
        else => P.T,
    };
}

/// Backtrack to the start of the given parser if it fails.
///
/// This is useful as a wrapper for the `mecha.combine` parser, since
/// it advances the input string if any of its provided parsers fail.
pub fn errBacktrack(comptime parser: anytype) mecha.Parser(ParserResult(@TypeOf(parser))) {
    const Res = mecha.Result(ParserResult(@TypeOf(parser)));

    return .{ .parse = struct {
        fn parse(alloc: Allocator, str: []const u8) mecha.Error!Res {
            const res = try parser.parse(alloc, str);

            return switch (res.value) {
                .ok => |value| Res.ok(res.index, value),
                .err => Res.err(0),
            };
        }
    }.parse };
}

/// Match an exact string, ignoring ASCII casing.
pub fn stringIgnoreCase(comptime str: []const u8) mecha.Parser([]const u8) {
    const Res = mecha.Result([]const u8);

    return .{
        .parse = struct {
            fn parse(_: Allocator, s: []const u8) mecha.Error!Res {
                if (!std.ascii.startsWithIgnoreCase(s, str))
                    return Res.err(0);

                return Res.ok(str.len, str);
            }
        }.parse,
    };
}

/// Match an exact character, ignoring ASCII casing.
///
/// If the provided `char` is a unicode character, the parser
/// will simply map to `mecha.utf8.char`. Unicode characters
/// parsed from the input will always match.
pub fn charIgnoreCase(comptime char: u21) mecha.Parser(u21) {
    // ignored casing for unicode is not supported
    comptime if (char > std.math.maxInt(u8))
        return mecha.utf8.char(char);

    const lower_char = comptime std.ascii.toLower(@intCast(char));

    return mecha.utf8.wrap(struct {
        fn pred(ch: u21) bool {
            return if (ch > std.math.maxInt(u8))
                true
            else
                std.ascii.toLower(@intCast(ch)) == lower_char;
        }
    }.pred);
}

/// Invert the result of the given parser.
///
/// In other words, if `parser` returns `.ok`, this parser will return `.err`,
/// and vice versa.
///
/// No input is consumed by this parser.
pub fn not(comptime parser: anytype) mecha.Parser(void) {
    return .{ .parse = struct {
        const Res = mecha.Result(void);

        fn parse(alloc: Allocator, str: []const u8) mecha.Error!Res {
            const res = try parser.parse(alloc, str);

            return switch (res.value) {
                .ok => Res.err(0),
                .err => Res.ok(0, {}),
            };
        }
    }.parse };
}

/// Map the result value of `parser` to an optional value.
///
/// This is similar to `mecha.opt`, except this parser still requires the provided
/// `parser` to succeed. This behavior can be particularly useful in `mecha.oneOf`
/// parsers that only produce a result value in specific cases.
pub fn optValueCast(comptime parser: anytype) mecha.Parser(?ParserResult(@TypeOf(parser))) {
    const Res = mecha.Result(?ParserResult(@TypeOf(parser)));

    return .{
        .parse = struct {
            fn parse(alloc: Allocator, str: []const u8) mecha.Error!Res {
                const res = try parser.parse(alloc, str);

                return switch (res.value) {
                    // implicit conversion
                    .ok => |value| Res.ok(res.index, value),
                    .err => Res.err(0),
                };
            }
        }.parse,
    };
}

/// Always return a parser error.
///
/// This does not consume any input.
pub fn err(comptime T: type) mecha.Parser(T) {
    return .{ .parse = struct {
        const Res = mecha.Result(T);

        fn parse(_: Allocator, _: []const u8) mecha.Error!Res {
            return Res.err(0);
        }
    }.parse };
}
