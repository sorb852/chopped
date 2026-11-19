const std = @import("std");
const rl = @import("raylib");

const color_from_hex = @import("color.zig").color_from_hex;
const color_to_hex = @import("color.zig").color_to_hex;

const log = std.log.scoped(.cli);

const DEFAULT_SCALE: u8 = 16;
const DEFAULT_TICK_RATE: i32 = 240;
const DEFAULT_FOREGROUND: rl.Color = .white;
const DEFAULT_BACKGROUND: rl.Color = .black;

/// Prints the help information onto stdout
fn print_help(executable: []const u8, writer: *std.Io.Writer) !void {
    try writer.print("Usage: {s} [OPTIONS] <FILE>\n", .{executable});
    try writer.print("\n", .{});
    try writer.print("Arguments:\n", .{});
    try writer.print("\t<FILE>   The chip8 file to be executed.\n", .{});
    try writer.print("\n", .{});
    try writer.print("Options:\n", .{});
    try writer.print("\t--help, -h                            Display help information.\n", .{});
    try writer.print("\t--fg <HEX_COLOR>                      Change the foreground of the program. Default {s}.\n", .{color_to_hex(DEFAULT_FOREGROUND)});
    try writer.print("\t--bg <HEX_COLOR>                      Change the background of the program. Default {s}.\n", .{color_to_hex(DEFAULT_BACKGROUND)});
    try writer.print("\t--enable-raylib-logging               Enable raylib logs.\n", .{});
    try writer.print("\t--scale <SCALE>, -s <SCALE>           Change the size of each pixel. Default {}px.\n", .{DEFAULT_SCALE});
    try writer.print("\t--target-tickrate <RATE>, -t <RATE>   Change the tick rate of the emulator. Default {}Hz.\n", .{DEFAULT_TICK_RATE});
    try writer.flush();
}

pub const Args = struct {
    rom_path: [:0]const u8,
    target_tickrate: i32 = DEFAULT_TICK_RATE,
    raylib_logging: bool = false,
    scale: u8 = DEFAULT_SCALE,
    foreground: rl.Color = DEFAULT_FOREGROUND,
    background: rl.Color = DEFAULT_BACKGROUND,
};

pub fn parse(args: std.process.Args, stdout: *std.Io.File.Writer) Args {
    // CLI arguments
    var rom_path: ?[:0]const u8 = null;
    var target_tickrate = DEFAULT_TICK_RATE;
    var raylib_logging = false;
    var scale = DEFAULT_SCALE;
    var foreground = DEFAULT_FOREGROUND;
    var background = DEFAULT_BACKGROUND;

    var iterator = args.iterate();
    const executable = std.fs.path.stem(iterator.next().?);
    while (iterator.next()) |arg| {
        if (std.ascii.eqlIgnoreCase(arg, "--help") or std.ascii.eqlIgnoreCase(arg, "-h")) {
            print_help(executable, &stdout.interface) catch {
                log.err("failed to write help message", .{});
                std.process.exit(1);
            };
            std.process.exit(0);
        }

        if (std.ascii.eqlIgnoreCase(arg, "--enable-raylib-logging")) {
            raylib_logging = true;
            continue;
        }

        if (std.ascii.eqlIgnoreCase(arg, "--fg")) {
            if (iterator.next()) |hex| {
                foreground = color_from_hex(hex) catch {
                    log.err("invalid hex string for foreground", .{});
                    std.process.exit(1);
                };
                continue;
            } else {
                log.err("no color found for foreground", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--bg")) {
            if (iterator.next()) |hex| {
                background = color_from_hex(hex) catch {
                    log.err("invalid hex string for background", .{});
                    std.process.exit(1);
                };
                continue;
            } else {
                log.err("no color found for background", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--scale") or std.ascii.eqlIgnoreCase(arg, "-s")) {
            if (iterator.next()) |valuestr| {
                scale = std.fmt.parseInt(@TypeOf(scale), valuestr, 10) catch |err|
                    switch (err) {
                        error.Overflow => {
                            log.err("scale must be an unsigned 8 bit integer", .{});
                            std.process.exit(1);
                        },
                        error.InvalidCharacter => {
                            log.err("invalid scale", .{});
                            std.process.exit(1);
                        },
                    };
                if (scale <= 0) {
                    log.err("scale must be an unsigned 8 bit integer", .{});
                    std.process.exit(1);
                }
                continue;
            } else {
                log.err("no scale found for option", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--target-tickrate") or std.ascii.eqlIgnoreCase(arg, "-t")) {
            if (iterator.next()) |valuestr| {
                target_tickrate = std.fmt.parseInt(@TypeOf(target_tickrate), valuestr, 10) catch |err|
                    switch (err) {
                        error.Overflow => {
                            log.err("target tick rate must be a 32 bit integer", .{});
                            std.process.exit(1);
                        },
                        error.InvalidCharacter => {
                            log.err("invalid tick rate", .{});
                            std.process.exit(1);
                        },
                    };
                continue;
            } else {
                log.err("no tick rate found for option", .{});
                std.process.exit(1);
            }
        }

        if (rom_path) |_| {
            log.err("only one argument for file should be shown", .{});
            std.process.exit(1);
        } else {
            rom_path = arg;
        }
    }

    if (rom_path == null) {
        log.err("no rom given in arguments", .{});
        std.process.exit(1);
    }

    return .{
        .rom_path = rom_path.?,
        .target_tickrate = target_tickrate,
        .raylib_logging = raylib_logging,
        .scale = scale,
        .foreground = foreground,
        .background = background,
    };
}
