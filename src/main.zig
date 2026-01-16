const std = @import("std");
const c = @import("c.zig").c;

const TimerNS = @import("timer.zig").TimerNS;

const tl = @import("text_label.zig");
const TextLabel = tl.TextLabel;
const TextLabelFmt = tl.TextLabelFmt;

const render_utils = @import("render_util.zig");
const renderRoundedRect = render_utils.renderRoundedRect;
// const createText = render_utils.createText;

const utils = @import("utils.zig");
const sdlValueCheck = utils.sdlValueCheck;
const WHITE = utils.WHITE;

const WIDTH = 800;
const HEIGHT = 500;
const TARGET_FPS = 60;
const PADDLE_WIDTH = 25.0;
const PADDLE_HEIGHT = 5;
const PADDLE_Y = HEIGHT - 40;
const PADDLE_PIXELS_PER_S = 300;

const GAME_AREA_LEFT = 150.0;
const GAME_AREA_RIGHT = WIDTH * 0.75 - 50.0;

const UIManager = struct {
    allocator: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    score_label: ScoreTextLabel,

    const ScoreTextLabel = TextLabelFmt(struct { u32 }, "{d: >9}");

    fn init(allocator: std.mem.Allocator, font: *c.TTF_Font, text_engine: *c.TTF_TextEngine, renderer: *c.SDL_Renderer) !UIManager {
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .score_label = try ScoreTextLabel.init(
                allocator,
                font,
                text_engine,
                .{0},
                WHITE,
            ),
        };
    }

    fn draw(self: UIManager) !void {
        const v_pad = 50.0;
        const h_pad = 25.0;

        const r_frame = c.SDL_FRect{
            .x = WIDTH * 0.75,
            .y = v_pad,
            .w = WIDTH - h_pad - (WIDTH * 0.75),
            .h = HEIGHT - v_pad * 2.0,
        };
        _ = c.SDL_SetRenderDrawColor(self.renderer, WHITE.r, WHITE.g, WHITE.b, WHITE.a);
        try renderRoundedRect(self.renderer, r_frame, 20, 20);

        const v_text_pad = 15.0;
        const h_text_pad = 15.0;

        try self.score_label.draw(WIDTH * 0.75 + h_text_pad, v_pad + v_text_pad);
    }

    fn deinit(self: *UIManager) void {
        self.score_label.deinit();
    }
};

const AppContext = struct {
    allocator: std.mem.Allocator,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    ttf_text_engine: *c.TTF_TextEngine,
    font: *c.TTF_Font,
    key_state: [*c]const bool,

    ui: UIManager,

    state: struct {
        score: u32,
        x: u32,
    },

    fn init(allocator: std.mem.Allocator) !AppContext {
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

        const font = c.TTF_OpenFont("assets/B612Mono-Regular.ttf", 24);
        try sdlValueCheck(font, "TTF_OpenFont");
        errdefer c.TTF_CloseFont(font);

        const key_state = c.SDL_GetKeyboardState(null);

        return AppContext{
            .allocator = allocator,
            .window = window.?,
            .renderer = renderer.?,
            .ttf_text_engine = ttf_text_engine.?,
            .font = font.?,
            .key_state = key_state,
            .ui = try UIManager.init(allocator, font.?, ttf_text_engine.?, renderer.?),
            .state = .{
                .score = 0,
                .x = WIDTH / 2.0,
            },
        };
    }

    fn deinit(self: *AppContext) void {
        self.ui.deinit();
        c.TTF_CloseFont(self.font);
        c.TTF_DestroyRendererTextEngine(self.ttf_text_engine);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
};

fn drawGame(ctx: *AppContext) !void {
    _ = c.SDL_SetRenderDrawColor(ctx.renderer, WHITE.r, WHITE.g, WHITE.b, WHITE.a);
    _ = c.SDL_RenderLine(ctx.renderer, GAME_AREA_LEFT, 0, GAME_AREA_LEFT, HEIGHT);
    _ = c.SDL_RenderLine(ctx.renderer, GAME_AREA_RIGHT, 0, GAME_AREA_RIGHT, HEIGHT);

    // draw paddle
    const paddle_rect = c.SDL_FRect{
        .x = @as(f32, @floatFromInt(ctx.state.x)) - PADDLE_WIDTH / 2.0,
        .y = PADDLE_Y,
        .w = PADDLE_WIDTH,
        .h = PADDLE_HEIGHT,
    };
    _ = c.SDL_RenderFillRect(ctx.renderer, &paddle_rect);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ctx = try AppContext.init(allocator);
    defer ctx.deinit();

    var running = true;
    var event: c.SDL_Event = undefined;

    var timer = TimerNS.init();
    var delta_ns: u64 = 1;

    while (running) {
        timer.start();
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    ctx.state.score += 1;
                },
                else => {},
            }
        }

        try ctx.ui.score_label.update(.{ctx.state.score});

        if (ctx.key_state[c.SDL_SCANCODE_LEFT]) {
            ctx.state.x = std.math.clamp(
                ctx.state.x - @as(u32, @intCast(PADDLE_PIXELS_PER_S * delta_ns / 1_000_000_000)),
                @as(u32, @intFromFloat(GAME_AREA_LEFT + PADDLE_WIDTH / 2.0)),
                @as(u32, @intFromFloat(GAME_AREA_RIGHT - PADDLE_WIDTH / 2.0)),
            );
        }
        if (ctx.key_state[c.SDL_SCANCODE_RIGHT]) {
            ctx.state.x = std.math.clamp(
                ctx.state.x + @as(u32, @intCast(PADDLE_PIXELS_PER_S * delta_ns / 1_000_000_000)),
                @as(u32, @intFromFloat(GAME_AREA_LEFT + PADDLE_WIDTH / 2.0)),
                @as(u32, @intFromFloat(GAME_AREA_RIGHT - PADDLE_WIDTH / 2.0)),
            );
        }

        const actual_fps = 1_000_000_000.0 / @as(f32, @floatFromInt(delta_ns));
        var buf: [20]u8 = undefined;
        const actual_fps_str = try std.fmt.bufPrint(&buf, "FPS: {d:.0}", .{actual_fps});
        const fps_text = c.TTF_CreateText(ctx.ttf_text_engine, ctx.font, actual_fps_str.ptr, actual_fps_str.len);
        _ = c.TTF_SetTextColor(fps_text, WHITE.r, WHITE.g, WHITE.b, WHITE.a);

        // Draw
        _ = c.SDL_SetRenderDrawColor(ctx.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(ctx.renderer);

        try ctx.ui.draw();
        try drawGame(&ctx);
        _ = c.TTF_DrawRendererText(fps_text, 10, 10);

        _ = c.SDL_RenderPresent(ctx.renderer);

        // aim for TARGET_FPS
        const elapsed_ns = timer.getTicks();
        const ns_per_frame = 1_000_000_000 / TARGET_FPS;

        if (elapsed_ns < ns_per_frame) {
            const sleep_time = ns_per_frame - elapsed_ns;
            _ = c.SDL_DelayNS(sleep_time);
        }
        delta_ns = timer.getTicks();
    }
}
