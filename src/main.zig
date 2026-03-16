const std = @import("std");

pub fn main() !void {
    std.debug.print("", .{});
}

const Token = union(enum) {
    pub const Type = std.meta.Tag(@This());

    start,
    newline,
    end,
    comma,
    colon,

    register: u8, // x0..x31
    label: u8, // L0..L10

    // Keywords
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

const Scanner = struct {
    fn scan() []Token {
    }
};
