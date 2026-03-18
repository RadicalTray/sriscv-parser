const std = @import("std");
const gpa = std.heap.smp_allocator;

pub fn main() !void {
    const args = try std.process.argsAlloc(gpa);
    if (args.len != 2) {
        std.debug.print("Usage: {s} <file path>", .{args[0]});
        return;
    }
    const code =
        std.fs.cwd().readFileAlloc(gpa, args[1], std.math.maxInt(usize)) catch |e| switch (e) {
            error.FileNotFound => return std.log.err("File \"{s}\" not found!", .{args[1]}),
            else => return e,
        };
    var scanner: Scanner = try .init(code, 128);
    const tokens = scanner.scan() catch |e| {
        switch (e) {
            error.InvalidCharacter => {
                std.log.err(
                    "Invalid character \"{c}\" at line {}",
                    .{ scanner.source[scanner.current - 1], scanner.line },
                );
            },
            else => std.log.err("{} at line {}", .{ e, scanner.line }),
        }
        return;
    };

    Parser.parse(tokens) catch |e| {
        std.debug.print("Parsing failed: {}\n", .{e});
        std.debug.print("Invalid SRISCV!\n", .{});
        return;
    };
    std.debug.print("Parsing success!\n", .{});
    std.debug.print("Valid SRISCV!\n", .{});
}

const Token = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    // Single character
    newline,
    comma,
    colon,
    left_paren,
    right_paren,

    // Multi character
    register: u8, // x0..x31
    label: u8, // L0..L10
    number: i64,

    // start & end
    @".code",
    @".end",
    // arithmetic
    add,
    sub,
    @"and",
    @"or",
    // move
    ld,
    sd,
    lw,
    sw,
    // branch
    beq,
    bne,
    blt,
    bge,
};

const Node = struct {};

const Symbol = enum {
    // Variable
    program,
    A,
    B,
    label_block,
    instruction,
    arithmetic,
    move,
    branch,

    // Terminal
    // special
    epsilon,
    arithmetic_const, // this conflicts with register and number
    // single token
    start,
    end,
    newline,
    colon,
    comma,
    number,
    left_paren,
    right_paren,
    register,
    label,
    // multiple tokens
    arithmetic_ops,
    move_ops,
    branch_ops,

    fn isTerminal(s: Symbol) bool {
        return switch (s) {
            .epsilon,
            .start,
            .end,
            .newline,
            .colon,
            .comma,
            .number,
            .left_paren,
            .right_paren,
            .register,
            .label,
            .arithmetic_ops,
            .move_ops,
            .branch_ops,
            .arithmetic_const,
            => true,
            else => false,
        };
    }
};

fn symbolFromToken(t: Token) Symbol {
    return switch (t) {
        // Single character
        .newline => .newline,
        .comma => .comma,
        .colon => .colon,
        .left_paren => .left_paren,
        .right_paren => .right_paren,

        // Multi character
        .register => .register,
        .label => .label,
        .number => .number,

        // start & end
        .@".code" => .start,
        .@".end" => .end,
        // arithmetic
        .add,
        .sub,
        .@"and",
        .@"or",
        => .arithmetic_ops,
        // move
        .ld,
        .sd,
        .lw,
        .sw,
        => .move_ops,
        // branch
        .beq,
        .bne,
        .blt,
        .bge,
        => .branch_ops,
    };
}

const Parser = struct {
    fn parse(source: []const Token) !void {
        // SETUP PARSING TABLE
        // FIXME: Use actual tokens like a real LL(1) parser.
        //  Epsilon can be added as another token tag.
        const Key = struct {
            v: Symbol,
            t: Symbol,
        };
        var parsing_table: std.AutoHashMap(Key, []const Symbol) = .init(gpa);

        try parsing_table.put(.{ .v = .program, .t = .start }, &.{ .start, .newline, .A, .B, .end });

        try parsing_table.put(.{
            .v = .A,
            .t = .arithmetic_ops,
        }, &.{ .instruction, .A });
        try parsing_table.put(.{
            .v = .A,
            .t = .move_ops,
        }, &.{ .instruction, .A });
        try parsing_table.put(.{
            .v = .A,
            .t = .branch_ops,
        }, &.{ .instruction, .A });
        try parsing_table.put(.{
            .v = .A,
            .t = .label,
        }, &.{.epsilon});
        try parsing_table.put(.{
            .v = .A,
            .t = .end,
        }, &.{.epsilon});

        try parsing_table.put(.{
            .v = .B,
            .t = .label,
        }, &.{ .label_block, .B });
        try parsing_table.put(.{
            .v = .B,
            .t = .end,
        }, &.{.epsilon});

        try parsing_table.put(.{
            .v = .label_block,
            .t = .label,
        }, &.{ .label, .colon, .newline, .A });

        try parsing_table.put(.{
            .v = .instruction,
            .t = .arithmetic_ops,
        }, &.{ .arithmetic, .newline });
        try parsing_table.put(.{
            .v = .instruction,
            .t = .move_ops,
        }, &.{ .move, .newline });
        try parsing_table.put(.{
            .v = .instruction,
            .t = .branch_ops,
        }, &.{ .branch, .newline });

        try parsing_table.put(.{
            .v = .arithmetic,
            .t = .arithmetic_ops,
        }, &.{ .arithmetic_ops, .register, .comma, .register, .comma, .arithmetic_const });

        try parsing_table.put(.{
            .v = .move,
            .t = .move_ops,
        }, &.{ .move_ops, .register, .comma, .number, .left_paren, .register, .right_paren });

        try parsing_table.put(.{
            .v = .branch,
            .t = .branch_ops,
        }, &.{ .branch_ops, .register, .comma, .register, .comma, .label });
        // ----

        var stack: std.ArrayList(Symbol) = try .initCapacity(gpa, 128);
        try stack.append(gpa, .program);

        var src_idx: u32 = 0;
        while (stack.items.len > 0) {
            const sym = stack.items[stack.items.len - 1];
            const in = symbolFromToken(source[src_idx]);
            std.debug.print(
                "Symbol: {} from stack {any}\nInput: {} from token {}\n\n",
                .{ sym, stack.items, in, source[src_idx] },
            );

            if (sym.isTerminal()) {
                // since our grammar rules are atrocious,
                // arithmetic_const has to be handled separately.
                if (sym == in or (sym == .arithmetic_const and (in == .register or in == .number))) {
                    stack.items.len -= 1;
                    src_idx += 1;
                    continue;
                }

                if (sym == .epsilon) {
                    stack.items.len -= 1;
                    continue;
                }

                std.log.err("Parsing error -> Expected {}, got {}", .{ sym, in });
                return error.UnexpectedToken;
            } else {
                if (parsing_table.get(.{ .v = sym, .t = in })) |symbols| {
                    stack.items.len -= 1;
                    var i: usize = symbols.len;
                    while (i > 0) {
                        i -= 1;
                        try stack.append(gpa, symbols[i]);
                    }
                    continue;
                }
                std.log.err("Parsing error -> ({}, {}) not found in the parsing table", .{ sym, in });
                return error.NotFoundInParsingTable;
            }
        }
    }
};

fn parse(tokens: []const Token) []Node {
    _ = tokens;
    return .{};
}

const Scanner = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    start: u32 = 0,
    current: u32 = 0,
    line: u32 = 1,

    fn init(source: []const u8, capacity: usize) !Scanner {
        return Scanner{
            .source = source,
            .tokens = try .initCapacity(gpa, capacity),
        };
    }

    fn deinit(sc: *Scanner) void {
        sc.tokens.deinit(gpa);
    }

    fn scan(sc: *Scanner) ![]Token {
        while (!sc.atEnd()) try sc.scanToken();
        return try sc.tokens.toOwnedSlice(gpa);
    }

    fn scanToken(sc: *Scanner) !void {
        defer sc.start = sc.current;
        const c = sc.peek();
        sc.advance();
        switch (c) {
            '(' => try sc.addToken(.left_paren),
            ')' => try sc.addToken(.right_paren),
            '\n' => {
                try sc.addToken(.newline);
                sc.line += 1;
            },
            ',' => try sc.addToken(.comma),
            ':' => try sc.addToken(.colon),
            ';' => while (sc.peek() != '\n' and !sc.atEnd()) sc.advance(), // line comment
            '-' => {
                if (isDigit(sc.peek())) {
                    try sc.number();
                } else {
                    return error.UnexpectedMinus;
                }
            },
            '.' => {
                if (isAlpha(sc.peek())) {
                    try sc.identifier();
                } else {
                    return error.UnexpectedDot;
                }
            },
            'x' => {
                while (isDigit(sc.peek())) sc.advance();
                const num = try std.fmt.parseInt(u8, sc.source[(sc.start + 1)..sc.current], 10);
                try sc.addToken(.{ .register = num });
            },
            'L' => {
                while (isDigit(sc.peek())) sc.advance();
                const num = try std.fmt.parseInt(u8, sc.source[(sc.start + 1)..sc.current], 10);
                try sc.addToken(.{ .label = num });
            },
            ' ', '\t', '\r' => {},
            else => if (isDigit(c)) {
                try sc.number();
            } else if (isAlpha(c)) {
                try sc.identifier();
            } else {
                return error.UnexpectedCharacter;
            },
        }
    }

    fn number(sc: *Scanner) !void {
        while (isDigit(sc.peek())) sc.advance();
        try sc.addToken(.{ .number = try std.fmt.parseInt(i64, sc.source[sc.start..sc.current], 0) });
    }

    fn identifier(sc: *Scanner) !void {
        while (isAlpha(sc.peek())) sc.advance();

        const Keywords = enum {
            // start & end
            @".code",
            @".end",
            // arithmetic
            add,
            sub,
            @"and",
            @"or",
            // move
            ld,
            sd,
            lw,
            sw,
            // branch
            beq,
            bne,
            blt,
            bge,
        };

        inline for (std.meta.fields(Keywords)) |f| {
            if (std.mem.eql(u8, sc.source[sc.start..sc.current], f.name)) {
                try sc.addToken(@field(Token.Tag, f.name));
                return;
            }
        }

        return error.UnexpectedKeyword;
    }

    fn peek(sc: Scanner) u8 {
        if (sc.atEnd()) return 0;
        return sc.source[sc.current];
    }

    // fn peekNext(sc: Scanner) u8 {
    //     if (sc.current + 1 >= sc.source.len) return 0;
    //     return sc.source[sc.current + 1];
    // }

    fn addToken(sc: *Scanner, token: Token) !void {
        try sc.tokens.append(gpa, token);
    }

    fn advance(sc: *Scanner) void {
        sc.current += 1;
    }

    fn atEnd(sc: *const Scanner) bool {
        return sc.current >= sc.source.len;
    }
};

fn isDigit(c: u8) bool {
    return '0' <= c and c <= '9';
}

fn isAlpha(c: u8) bool {
    return 'a' <= c and c <= 'z';
}
