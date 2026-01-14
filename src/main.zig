const std = @import("std");
const c = @import("c.zig").c;
const TimerNS = @import("timer.zig").TimerNS;
const render_utils = @import("render_util.zig");
const renderRoundedRect = render_utils.renderRoundedRect;
const renderText = render_utils.renderText;

const WIDTH = 800;
const HEIGHT = 500;
const TARGET_FPS = 60;

const WHITE = c.SDL_Color{ .r = 255, .b = 255, .g = 255, .a = 255 };

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

const AppContext = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    ttf_text_engine: *c.TTF_TextEngine,
    font: *c.TTF_Font,

    fn init() !AppContext {
        try sdlValueCheck(c.SDL_Init(c.SDL_INIT_VIDEO), "SDL_Init");
        errdefer c.SDL_Quit();

        try sdlValueCheck(c.TTF_Init(), "TTF_Init");
        errdefer c.TTF_Quit();

        const window = c.SDL_CreateWindow("Pinball", WIDTH, HEIGHT, c.SDL_WINDOW_OPENGL);
        try sdlValueCheck(window, "SDL_CreateWindow");
        errdefer c.SDL_DestroyWindow(window);

        const renderer = c.SDL_CreateRenderer(window, null);
        try sdlValueCheck(renderer, "SDL_CreateRenderer");
        errdefer c.SDL_DestroyRenderer(renderer);

        const ttf_text_engine = c.TTF_CreateRendererTextEngine(renderer);
        try sdlValueCheck(ttf_text_engine, "TTF_CreateRendererTextEngine");
        errdefer c.TTF_DestroyRendererTextEngine(ttf_text_engine);

        const font = c.TTF_OpenFont("assets/42dotSans.ttf", 24);
        try sdlValueCheck(font, "TTF_OpenFont");
        errdefer c.TTF_CloseFont(font);

        return AppContext{
            .window = window.?,
            .renderer = renderer.?,
            .ttf_text_engine = ttf_text_engine.?,
            .font = font.?,
        };
    }

    fn deinit(self: *AppContext) void {
        c.TTF_CloseFont(self.font);
        c.TTF_DestroyRendererTextEngine(self.ttf_text_engine);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
};

fn drawUI(ctx: *AppContext) !void {
    const r_frame = c.SDL_FRect{
        .x = WIDTH * 0.75,
        .y = 50,
        .w = WIDTH - 50 - (WIDTH * 0.75),
        .h = HEIGHT - 100,
    };
    _ = c.SDL_SetRenderDrawColor(ctx.renderer, 255, 255, 255, 255);
    try renderRoundedRect(ctx.renderer, r_frame, 20, 20);

    try renderText(ctx.ttf_text_engine, ctx.font, "Hi", 200, 200, WHITE);
}

pub fn main() !void {
    var ctx = try AppContext.init();
    defer ctx.deinit();

    var running = true;
    var event: c.SDL_Event = undefined;

    var timer = TimerNS.init();
    var prev_elapsed_ns: u64 = 1;

    while (running) {
        timer.start();
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_KEY_DOWN => {
                    running = false;
                },
                else => {},
            }
        }

        const actual_fps = 1_000_000_000.0 / @as(f32, @floatFromInt(prev_elapsed_ns));
        var buf: [20]u8 = undefined;
        const actual_fps_str = try std.fmt.bufPrint(&buf, "FPS: {d:.0}", .{actual_fps});

        // Draw
        _ = c.SDL_SetRenderDrawColor(ctx.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(ctx.renderer);

        try drawUI(&ctx);
        try renderText(ctx.ttf_text_engine, ctx.font, actual_fps_str, 10, 10, WHITE);

        _ = c.SDL_RenderPresent(ctx.renderer);

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
