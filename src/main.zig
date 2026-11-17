// TODO: Sound timer useless, make it not

const std = @import("std");
const rl = @import("raylib");

const Chip8VM = @import("vm.zig").Chip8VM;
const color_from_hex = @import("color.zig").color_from_hex;
const color_to_hex = @import("color.zig").color_to_hex;

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

pub fn main(init: std.process.Init) !void {
    // CLI arguments
    var rom_path: ?[:0]const u8 = null;
    var target_tickrate = DEFAULT_TICK_RATE;
    var raylib_logging = false;
    var scale = DEFAULT_SCALE;
    var foreground = DEFAULT_FOREGROUND;
    var background = DEFAULT_BACKGROUND;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    var args = init.minimal.args.iterate();
    const executable = std.fs.path.stem(args.next().?);
    while (args.next()) |arg| {
        if (std.ascii.eqlIgnoreCase(arg, "--help") or std.ascii.eqlIgnoreCase(arg, "-h")) {
            print_help(executable, &stdout.interface) catch {
                std.log.err("failed to write help message", .{});
                std.process.exit(1);
            };
            std.process.exit(0);
        }

        if (std.ascii.eqlIgnoreCase(arg, "--enable-raylib-logging")) {
            raylib_logging = true;
            continue;
        }

        if (std.ascii.eqlIgnoreCase(arg, "--fg")) {
            if (args.next()) |hex| {
                foreground = color_from_hex(hex) catch {
                    std.log.err("invalid hex string for foreground", .{});
                    std.process.exit(1);
                };
                continue;
            } else {
                std.log.err("no color found for foreground", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--bg")) {
            if (args.next()) |hex| {
                background = color_from_hex(hex) catch {
                    std.log.err("invalid hex string for background", .{});
                    std.process.exit(1);
                };
                continue;
            } else {
                std.log.err("no color found for background", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--scale") or std.ascii.eqlIgnoreCase(arg, "-s")) {
            if (args.next()) |valuestr| {
                scale = std.fmt.parseInt(@TypeOf(scale), valuestr, 10) catch |err|
                    switch (err) {
                        error.Overflow => {
                            std.log.err("scale must be an unsigned 8 bit integer", .{});
                            std.process.exit(1);
                        },
                        error.InvalidCharacter => {
                            std.log.err("invalid scale", .{});
                            std.process.exit(1);
                        },
                    };
                if (scale <= 0) {
                    std.log.err("scale must be an unsigned 8 bit integer", .{});
                    std.process.exit(1);
                }
                continue;
            } else {
                std.log.err("no scale found for option", .{});
                std.process.exit(1);
            }
        }

        if (std.ascii.eqlIgnoreCase(arg, "--target-tickrate") or std.ascii.eqlIgnoreCase(arg, "-t")) {
            if (args.next()) |valuestr| {
                target_tickrate = std.fmt.parseInt(@TypeOf(target_tickrate), valuestr, 10) catch |err|
                    switch (err) {
                        error.Overflow => {
                            std.log.err("target tick rate must be a 32 bit integer", .{});
                            std.process.exit(1);
                        },
                        error.InvalidCharacter => {
                            std.log.err("invalid tick rate", .{});
                            std.process.exit(1);
                        },
                    };
                continue;
            } else {
                std.log.err("no tick rate found for option", .{});
                std.process.exit(1);
            }
        }

        if (rom_path) |_| {
            std.log.err("only one argument for file should be shown", .{});
            std.process.exit(1);
        } else {
            rom_path = arg;
        }
    }

    if (rom_path == null) {
        std.log.err("no rom given in arguments", .{});
        std.process.exit(1);
    }

    // Initialize chip8
    var prng: std.Random.DefaultPrng = .init(0);
    var chip8: Chip8VM = .{ .rand = prng.random() };
    chip8.init_sprites();

    // Initialize the rom
    var buf: [4096 - 512]u8 = undefined;
    const rom_path_type = std.fs.path.parsePath(rom_path.?);
    const rom = (if (rom_path_type.kind == .absolute)
        std.Io.Dir.openFileAbsolute(init.io, rom_path.?, .{ .allow_directory = false })
    else
        std.Io.Dir.cwd().openFile(init.io, rom_path.?, .{ .allow_directory = false })) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("rom not found", .{});
            std.process.exit(1);
        },
        error.IsDir => {
            std.log.err("given rom path is not a file", .{});
            std.process.exit(1);
        },
        else => {
            std.log.err("failed to open rom, {}", .{err});
            std.process.exit(1);
        },
    };
    defer rom.close(init.io);
    var rom_reader = rom.reader(init.io, &buf);
    chip8.init_rom(&rom_reader.interface) catch |err| {
        std.log.err("failed to read rom, {}", .{err});
        std.process.exit(1);
    };

    const screenWidth = @as(i32, 64) * scale;
    const screenHeight = @as(i32, 32) * scale;

    if (!raylib_logging)
        rl.setTraceLogLevel(.none);
    rl.initWindow(screenWidth, screenHeight, "Chopped emulator");
    defer rl.closeWindow(); // js close as it ends lol

    rl.setTargetFPS(target_tickrate);

    var since_last_tick: f64 = 0;

    const display_buffer = rl.loadRenderTexture(screenWidth, screenHeight) catch {
        std.log.err("failed to create dispaly texture", .{});
        std.process.exit(1);
    };
    defer rl.unloadRenderTexture(display_buffer);

    while (!rl.windowShouldClose()) {
        since_last_tick += rl.getFrameTime();

        // 1234     123C
        // QWER     456D
        // ASDF ==> 789E
        // ZXCV     A0BF

        chip8.poll_input(0x1, rl.isKeyDown(.one));
        chip8.poll_input(0x2, rl.isKeyDown(.two));
        chip8.poll_input(0x3, rl.isKeyDown(.three));
        chip8.poll_input(0xC, rl.isKeyDown(.four));

        chip8.poll_input(0x4, rl.isKeyDown(.q));
        chip8.poll_input(0x5, rl.isKeyDown(.w));
        chip8.poll_input(0x6, rl.isKeyDown(.e));
        chip8.poll_input(0xD, rl.isKeyDown(.r));

        chip8.poll_input(0x7, rl.isKeyDown(.a));
        chip8.poll_input(0x8, rl.isKeyDown(.s));
        chip8.poll_input(0x9, rl.isKeyDown(.d));
        chip8.poll_input(0xE, rl.isKeyDown(.f));

        chip8.poll_input(0xA, rl.isKeyDown(.z));
        chip8.poll_input(0x0, rl.isKeyDown(.x));
        chip8.poll_input(0xB, rl.isKeyDown(.c));
        chip8.poll_input(0xF, rl.isKeyDown(.v));

        if (since_last_tick >= 1.0 / 60.0) {
            chip8.tick_timers();
            since_last_tick = 0;
        }

        // chip8.step() catch |err| switch (err) {
        //     error.StackOverflow => {
        //         // TODO: Maybe add like diagnostics here too
        //         std.log.err("stack overflow detected", .{});
        //         std.process.exit(1);
        //     },
        //     error.UnknownInstruction => {
        //         std.log.err("unknown instruction found at address 0x{x:0>3}", .{chip8.PC});
        //         std.process.exit(1);
        //     },
        // };

        chip8.step() catch |err| {
            std.log.err("failed to step chip8 program, {}", .{err});
            std.process.exit(1);
        };

        if (chip8.needs_redraw) {
            rl.beginTextureMode(display_buffer);
            defer {
                rl.endTextureMode();
                chip8.needs_redraw = false;
            }

            rl.clearBackground(background);

            var y: usize = 0;
            while (y < 32) : (y += 1) {
                var x: usize = 0;
                while (x < 64) : (x += 1) {
                    const mask = @as(u64, 1) << @intCast(63 - x);
                    if ((chip8.display[y] & mask) != 0) rl.drawRectangle(
                        @intCast(x * scale),
                        @intCast(y * scale),
                        scale,
                        scale,
                        foreground,
                    );
                }
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing(); // ok nvm this is cool asf
        rl.drawTextureRec(
            display_buffer.texture,
            .init(
                0,
                0,
                @floatFromInt(display_buffer.texture.width),
                @floatFromInt(-display_buffer.texture.height),
            ),
            .init(0, 0),
            .white,
        );
    }
}

test {
    std.testing.refAllDecls(@This());
}
