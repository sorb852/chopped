/// Instruction set for the Chip-8
/// Used as arguments between the VM.
const Instruction = union(enum) {
    CLS,
    RET,

    JP: struct { addr: u12 },
    CALL: struct { addr: u12 },
    SE: struct { x: u4, byte: u8 },
    SNE: struct { x: u4, byte: u8 },
    SEV: struct { x: u4, y: u4 },
    LD: struct { x: u4, byte: u8 },
    ADD: struct { x: u4, byte: u8 },

    LDV: struct { x: u4, y: u4 },
    OR: struct { x: u4, y: u4 },
    AND: struct { x: u4, y: u4 },
    XOR: struct { x: u4, y: u4 },
    ADDV: struct { x: u4, y: u4 },
    SUB: struct { x: u4, y: u4 },
    SHR: struct { x: u4, y: u4 },
    SUBN: struct { x: u4, y: u4 },
    SHL: struct { x: u4, y: u4 },

    SNEV: struct { x: u4, y: u4 },
    LDI: struct { addr: u12 },
    JPV: struct { addr: u12 },
    RND: struct { x: u4, byte: u8 },
    DRW: struct { x: u4, y: u4, nibble: u4 },

    SKP: struct { x: u4 },
    SKNP: struct { x: u4 },

    LDVDT: struct { x: u4 },
    LDVK: struct { x: u4 },
    LDDTV: struct { x: u4 },
    LDSTV: struct { x: u4 },
    ADDI: struct { x: u4 },
    LDIVX: struct { x: u4 },
    LDBVX: struct { x: u4 },
    LDIV0VX: struct { x: u4 },
    LDV0VXI: struct { x: u4 },

    fn parse(instruction: u16) error{UnknownInstruction}!Instruction {
        // oh right bit masks exist
        const header: u4 = @truncate((instruction & 0xF000) >> 12);
        const addr: u12 = @truncate((instruction & 0x0FFF) >> 0);
        const nibble: u4 = @truncate((instruction & 0x000F) >> 0);
        const x: u4 = @truncate((instruction & 0x0F00) >> 8);
        const y: u4 = @truncate((instruction & 0x00F0) >> 4);
        const byte: u8 = @truncate((instruction & 0x00FF) >> 0);

        // std.debug.print("[INFO] Matching instruction at 0x{x:0>3}: 0x{x:0>4}\n", .{ self.PC, instruction });
        // std.debug.print("[INFO] header: 0x{x}, addr: 0x{x:0>3}, nibble: {}, x: {}, y: {}, byte: 0b{b:0>8}\n", .{ header, addr, nibble, x, y, byte });

        const match: ?Instruction = switch (header) {
            0x0 => switch (instruction) {
                0x00E0 => .CLS,
                0x00EE => .RET,
                else => null,
            },
            0x1 => .{ .JP = .{ .addr = addr } },
            0x2 => .{ .CALL = .{ .addr = addr } },
            0x3 => .{ .SE = .{ .x = x, .byte = byte } },
            0x4 => .{ .SNE = .{ .x = x, .byte = byte } },
            0x5 => .{ .SEV = .{ .x = x, .y = y } },
            0x6 => .{ .LD = .{ .x = x, .byte = byte } },
            0x7 => .{ .ADD = .{ .x = x, .byte = byte } },
            0x8 => switch (nibble) {
                0x0 => .{ .LDV = .{ .x = x, .y = y } },
                0x1 => .{ .OR = .{ .x = x, .y = y } },
                0x2 => .{ .AND = .{ .x = x, .y = y } },
                0x3 => .{ .XOR = .{ .x = x, .y = y } },
                0x4 => .{ .ADDV = .{ .x = x, .y = y } },
                0x5 => .{ .SUB = .{ .x = x, .y = y } },
                0x6 => .{ .SHR = .{ .x = x, .y = y } },
                0x7 => .{ .SUBN = .{ .x = x, .y = y } },
                0xE => .{ .SHL = .{ .x = x, .y = y } },
                else => null,
            },
            0x9 => .{ .SNEV = .{ .x = x, .y = y } },
            0xA => .{ .LDI = .{ .addr = addr } },
            0xB => .{ .JPV = .{ .addr = addr } },
            0xC => .{ .RND = .{ .x = x, .byte = byte } },
            0xD => .{ .DRW = .{ .x = x, .y = y, .nibble = nibble } },
            0xE => switch (byte) {
                0x9E => .{ .SKP = .{ .x = x } },
                0xA1 => .{ .SKNP = .{ .x = x } },
                else => null,
            },
            0xF => switch (byte) {
                0x07 => .{ .LDVDT = .{ .x = x } },
                0x0A => .{ .LDVK = .{ .x = x } },
                0x15 => .{ .LDDTV = .{ .x = x } },
                0x18 => .{ .LDSTV = .{ .x = x } },
                0x1E => .{ .ADDI = .{ .x = x } },
                0x29 => .{ .LDIVX = .{ .x = x } },
                0x33 => .{ .LDBVX = .{ .x = x } },
                0x55 => .{ .LDIV0VX = .{ .x = x } },
                0x65 => .{ .LDV0VXI = .{ .x = x } },
                else => null,
            },
        };

        if (match) |inst| {
            return inst;
        } else {
            return error.UnknownInstruction;
        }
    }
};
