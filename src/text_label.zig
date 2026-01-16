const std = @import("std");
const c = @import("c.zig").c;
const ru = @import("render_util.zig");
const sdlValueCheck = @import("utils.zig").sdlValueCheck;

pub const TextLabel = struct {
    allocator: std.mem.Allocator,
    font: *c.TTF_Font,
    ttf_text: [*c]c.TTF_Text,
    text_engine: *c.TTF_TextEngine,
    last_content: []u8,

    pub fn init(allocator: std.mem.Allocator, font: *c.TTF_Font, text_engine: *c.TTF_TextEngine, init_content: []const u8, color: c.SDL_Color) !@This() {
        const last_content = try allocator.dupe(u8, init_content);

        const ttf_text = c.TTF_CreateText(text_engine, font, init_content.ptr, init_content.len);

        try sdlValueCheck(c.TTF_SetTextColor(ttf_text, color.r, color.g, color.b, color.a), "TTF_SetTextColor");

        return .{
            .allocator = allocator,
            .font = font,
            .ttf_text = ttf_text,
            .text_engine = text_engine,
            .last_content = last_content,
        };
    }

    pub fn deinit(self: *TextLabel) void {
        self.allocator.free(self.last_content);
        c.TTF_DestroyText(self.ttf_text);
    }

    pub fn update(self: *TextLabel, content: []const u8) !void {
        if (std.mem.eql(u8, content, self.last_content)) {
            return;
        }

        self.allocator.free(self.last_content);
        self.last_content = try self.allocator.dupe(u8, content);

        try sdlValueCheck(c.TTF_SetTextString(self.ttf_text, self.last_content.ptr, self.last_content.len), "TTF_SetTextString");
    }

    pub fn draw(self: TextLabel, x: f32, y: f32) !void {
        try sdlValueCheck(c.TTF_DrawRendererText(self.ttf_text, x, y), "TTF_DrawRendererText");
    }
};

pub fn TextLabelFmt(comptime T: type, comptime fmt_string: []const u8) type {
    return struct {
        allocator: std.mem.Allocator,
        text_label: TextLabel,
        last_args: T,

        pub fn init(allocator: std.mem.Allocator, font: *c.TTF_Font, text_engine: *c.TTF_TextEngine, init_args: T, color: c.SDL_Color) !@This() {
            const content = try std.fmt.allocPrint(allocator, fmt_string, init_args);
            defer allocator.free(content);

            return .{
                .allocator = allocator,
                .text_label = try TextLabel.init(allocator, font, text_engine, content, color),
                .last_args = init_args,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.text_label.deinit();
        }

        pub fn update(self: *@This(), args: T) !void {
            if (std.meta.eql(self.last_args, args)) {
                return;
            }

            const new_content = try std.fmt.allocPrint(self.allocator, fmt_string, args);
            defer self.allocator.free(new_content);

            try self.text_label.update(new_content);
        }

        pub fn draw(self: @This(), x: f32, y: f32) !void {
            return self.text_label.draw(x, y);
        }
    };
}
