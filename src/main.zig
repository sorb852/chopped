// TODO: Sound timer useless, make it not

const std = @import("std");
const rl = @import("raylib");

const Chip8VM = @import("vm.zig").Chip8VM;
const color_from_hex = @import("color.zig").color_from_hex;
const color_to_hex = @import("color.zig").color_to_hex;
const cli = @import("cli.zig");

const log = std.log.default;

const DEFAULT_SCALE: u8 = 16;
const DEFAULT_TICK_RATE: i32 = 240;
const DEFAULT_FOREGROUND: rl.Color = .white;
const DEFAULT_BACKGROUND: rl.Color = .black;

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = @splat(0);
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    const args = cli.parse(init.minimal.args, &stdout);

    log.debug("rom_path = {s}, target_tickrate = {}, raylib_logging = {}, scale = {}, foreground = {s}, background = {s}", .{
        args.rom_path,
        args.target_tickrate,
        args.raylib_logging,
        args.scale,
        color_to_hex(args.foreground),
        color_to_hex(args.background),
    });

    // Initialize chip8
    var prng: std.Random.DefaultPrng = .init(0);
    var chip8: Chip8VM = .{ .rand = prng.random() };
    chip8.init_sprites();

    // Initialize the rom
    var buf: [4096 - 512]u8 = undefined;
    const rom_path_type = std.fs.path.parsePath(args.rom_path);
    const rom = (if (rom_path_type.kind == .absolute)
        std.Io.Dir.openFileAbsolute(init.io, args.rom_path, .{ .allow_directory = false })
    else
        std.Io.Dir.cwd().openFile(init.io, args.rom_path, .{ .allow_directory = false })) catch |err| switch (err) {
        error.FileNotFound => {
            log.err("rom not found", .{});
            std.process.exit(1);
        },
        error.IsDir => {
            log.err("given rom path is not a file", .{});
            std.process.exit(1);
        },
        else => {
            log.err("failed to open rom, {}", .{err});
            std.process.exit(1);
        },
    };
    defer rom.close(init.io);
    var rom_reader = rom.reader(init.io, &buf);
    chip8.init_rom(&rom_reader.interface) catch |err| {
        log.err("failed to read rom, {}", .{err});
        std.process.exit(1);
    };

    const screenWidth = @as(i32, 64) * args.scale;
    const screenHeight = @as(i32, 32) * args.scale;

    if (!args.raylib_logging)
        rl.setTraceLogLevel(.none);
    log.info("creating window with size {}x{}", .{ screenWidth, screenHeight });
    rl.initWindow(screenWidth, screenHeight, "Chopped emulator");
    defer rl.closeWindow(); // js close as it ends lol

    rl.setTargetFPS(args.target_tickrate);

    var since_last_tick: f64 = 0;

    const display_buffer = rl.loadRenderTexture(screenWidth, screenHeight) catch {
        log.err("failed to create dispaly texture", .{});
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
        //         log.err("stack overflow detected", .{});
        //         std.process.exit(1);
        //     },
        //     error.UnknownInstruction => {
        //         log.err("unknown instruction found at address 0x{x:0>3}", .{chip8.PC});
        //         std.process.exit(1);
        //     },
        // };

        chip8.step() catch |err| {
            log.err("failed to step chip8 program, {}", .{err});
            std.process.exit(1);
        };

        if (chip8.needs_redraw) {
            rl.beginTextureMode(display_buffer);
            defer {
                rl.endTextureMode();
                chip8.needs_redraw = false;
            }

            rl.clearBackground(args.background);

            var y: usize = 0;
            while (y < 32) : (y += 1) {
                var x: usize = 0;
                while (x < 64) : (x += 1) {
                    const mask = @as(u64, 1) << @intCast(63 - x);
                    if ((chip8.display[y] & mask) != 0) rl.drawRectangle(
                        @intCast(x * args.scale),
                        @intCast(y * args.scale),
                        args.scale,
                        args.scale,
                        args.foreground,
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
