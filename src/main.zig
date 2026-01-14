const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const TimerNS = @import("timer.zig").TimerNS;

const WIDTH = 800;
const HEIGHT = 500;
const TARGET_FPS = 60;

fn sdlValueCheck(value: anytype, comptime name: []const u8) !void {
    const T = @TypeOf(value);
    const is_ptr = @typeInfo(T) == .pointer or @typeInfo(T) == .optional;

    if (is_ptr) {
        if (value == null) {
            std.debug.print("{s} failed: {s}\n", .{ name, c.SDL_GetError() });
            return error.SDLCallFailed;
        }
    } else if (T == bool) {
        if (!value) {
            std.debug.print("{s} failed: {s}\n", .{ name, c.SDL_GetError() });
            return error.SDLCallFailed;
        }
    } else {
        if (value < 0) {
            std.debug.print("{s} failed: {s}\n", .{ name, c.SDL_GetError() });
            return error.SDLCallFailed;
        }
    }
}

fn generateArc(comptime num_points: usize, x: f32, y: f32, r: f32, angle_start: f32, angle_end: f32) [num_points]c.SDL_FPoint {
    var points: [num_points]c.SDL_FPoint = undefined;

    const angle_step = (angle_end - angle_start) / @as(f32, @floatFromInt(num_points - 1));

    for (0..num_points) |i| {
        const angle = angle_start + angle_step * @as(f32, @floatFromInt(i));

        points[i] = .{
            .x = x + r * @cos(angle),
            .y = y + r * @sin(angle),
        };
    }

    return points;
}

fn drawUI(renderer: ?*c.SDL_Renderer) !void {
    const radius = 20.0;
    const r_frame = [_]c.SDL_FPoint{
        .{ .x = WIDTH * 0.75, .y = 50 },
    } ++
        generateArc(10, WIDTH * 0.75 + radius, HEIGHT - 50 - radius, radius, std.math.pi, std.math.pi / 2.0) ++
        generateArc(10, WIDTH - 50 - radius, HEIGHT - 50 - radius, radius, std.math.pi / 2.0, 0) ++
        generateArc(10, WIDTH - 50 - radius, 50 + radius, radius, 0, -std.math.pi / 2.0) ++
        generateArc(10, WIDTH * 0.75 + radius, 50 + radius, radius, 3.0 * std.math.pi / 2.0, std.math.pi) ++ [_]c.SDL_FPoint{
        .{ .x = WIDTH * 0.75, .y = 50 },
    };

    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    _ = c.SDL_RenderLines(renderer, &r_frame, r_frame.len);

    const test_arc = generateArc(10, 100, 100, 20, std.math.pi / 2.0, std.math.pi);
    _ = c.SDL_RenderLines(renderer, &test_arc, test_arc.len);
}

pub fn main() !void {
    try sdlValueCheck(c.SDL_Init(c.SDL_INIT_VIDEO), "SDL_Init");
    defer c.SDL_Quit();

    try sdlValueCheck(c.TTF_Init(), "TTF_Init");
    defer c.TTF_Quit();

    const window = c.SDL_CreateWindow("Pinball", WIDTH, HEIGHT, c.SDL_WINDOW_OPENGL);
    try sdlValueCheck(window, "SDL_CreateWindow");
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null);
    try sdlValueCheck(renderer, "SDL_CreateRenderer");
    defer c.SDL_DestroyRenderer(renderer);

    const ttf_text_engine = c.TTF_CreateRendererTextEngine(renderer);
    try sdlValueCheck(ttf_text_engine, "TTF_CreateRendererTextEngine");
    defer c.TTF_DestroyRendererTextEngine(ttf_text_engine);

    const font = c.TTF_OpenFont("assets/42dotSans.ttf", 24);
    try sdlValueCheck(font, "TTF_OpenFont");
    defer c.TTF_CloseFont(font);

    var running = true;
    var event: c.SDL_Event = undefined;

    var timer = TimerNS.init();

    var prev_elapsed_ns: u64 = 1;

    while (running) {
        timer.start();
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_KEY_DOWN => {},
                else => {},
            }
        }

        const actual_fps = 1_000_000_000.0 / @as(f32, @floatFromInt(prev_elapsed_ns));
        var buf: [20]u8 = undefined;
        const actual_fps_str = try std.fmt.bufPrint(&buf, "FPS: {d:.0}", .{actual_fps});
        const fps_text = c.TTF_CreateText(ttf_text_engine, font, actual_fps_str.ptr, actual_fps_str.len);
        defer c.TTF_DestroyText(fps_text);
        _ = c.TTF_SetTextColor(fps_text, 255, 255, 255, 255);

        // Draw
        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(renderer);

        try drawUI(renderer);

        _ = c.TTF_DrawRendererText(fps_text, 10, 10);

        _ = c.SDL_RenderPresent(renderer);

        // aim for TARGET_FPS
        const elapsed_ns = timer.getTicks();
        const ns_per_frame = 1_000_000_000 / TARGET_FPS;

        if (elapsed_ns < ns_per_frame) {
            const sleep_time = ns_per_frame - elapsed_ns;
            _ = c.SDL_DelayNS(sleep_time);
        }
        prev_elapsed_ns = timer.getTicks();
    }
}
