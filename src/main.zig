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

fn renderRoundedRect(renderer: ?*c.SDL_Renderer, rect: c.SDL_FRect, r: f32, comptime quality: usize) !void {
    const points = [_]c.SDL_FPoint{
        .{ .x = rect.x, .y = rect.y + r },
    } ++
        generateArc(quality, rect.x + r, rect.y + rect.h - r, r, std.math.pi, std.math.pi / 2.0) ++
        generateArc(quality, rect.x + rect.w - r, rect.y + rect.h - r, r, std.math.pi / 2.0, 0) ++
        generateArc(quality, rect.x + rect.w - r, rect.y + r, r, 0, -std.math.pi / 2.0) ++
        generateArc(quality, rect.x + r, rect.y + r, r, 3.0 * std.math.pi / 2.0, std.math.pi);

    _ = c.SDL_RenderLines(renderer, &points, points.len);
}

fn drawUI(renderer: ?*c.SDL_Renderer) !void {
    const r_frame = c.SDL_FRect{
        .x = WIDTH * 0.75,
        .y = 50,
        .w = WIDTH - 50 - (WIDTH * 0.75),
        .h = HEIGHT - 100,
    };
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    try renderRoundedRect(renderer, r_frame, 20, 10);
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
