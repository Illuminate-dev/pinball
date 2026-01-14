const std = @import("std");
const c = @import("c.zig").c;

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

pub fn renderRoundedRect(renderer: *c.SDL_Renderer, rect: c.SDL_FRect, r: f32, comptime quality: usize) !void {
    const points = [_]c.SDL_FPoint{
        .{ .x = rect.x, .y = rect.y + r },
    } ++
        generateArc(quality, rect.x + r, rect.y + rect.h - r, r, std.math.pi, std.math.pi / 2.0) ++
        generateArc(quality, rect.x + rect.w - r, rect.y + rect.h - r, r, std.math.pi / 2.0, 0) ++
        generateArc(quality, rect.x + rect.w - r, rect.y + r, r, 0, -std.math.pi / 2.0) ++
        generateArc(quality, rect.x + r, rect.y + r, r, 3.0 * std.math.pi / 2.0, std.math.pi);

    _ = c.SDL_RenderLines(renderer, &points, points.len);
}

pub fn renderText(ttf_text_engine: *c.TTF_TextEngine, font: *c.TTF_Font, text: []const u8, x: f32, y: f32, color: c.SDL_Color) !void {
    const fps_text = c.TTF_CreateText(ttf_text_engine, font, text.ptr, text.len);
    defer c.TTF_DestroyText(fps_text);
    _ = c.TTF_SetTextColor(fps_text, color.r, color.g, color.b, color.a);
    _ = c.TTF_DrawRendererText(fps_text, x, y);
}
