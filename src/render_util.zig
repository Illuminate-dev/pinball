const std = @import("std");
const c = @import("c.zig").c;
const utils = @import("utils.zig");

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

    try utils.sdlValueCheck(c.SDL_RenderLines(renderer, &points, points.len), "SDL_RenderLines");
}

fn renderQuadrants(renderer: *c.SDL_Renderer, x: f32, y: f32, dx: f32, dy: f32, fill: bool) !void {
    if (dx == 0) {
        if (dy == 0) {
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x, y), "SDL_RenderPoint");
        } else {
            if (fill) {
                try utils.sdlValueCheck(c.SDL_RenderLine(renderer, x, y - dy, x, y + dy), "SDL_RenderLine");
            } else {
                try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x, y - dy), "SDL_RenderPoint");
                try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x, y + dy), "SDL_RenderPoint");
            }
        }
    } else {
        if (fill) {
            try utils.sdlValueCheck(c.SDL_RenderLine(renderer, x - dx, y - dy, x - dx, y + dy), "SDL_RenderLine");
            try utils.sdlValueCheck(c.SDL_RenderLine(renderer, x + dx, y - dy, x + dx, y + dy), "SDL_RenderLine");
        } else {
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x - dx, y - dy), "SDL_RenderPoint");
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x + dx, y - dy), "SDL_RenderPoint");
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x - dx, y + dy), "SDL_RenderPoint");
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x + dx, y + dy), "SDL_RenderPoint");
        }
    }
}

pub fn renderElipse(renderer: *c.SDL_Renderer, x: f32, y: f32, rx: f32, ry: f32, fill: bool) !void {
    if (rx < 0 or ry < 0) {
        return error.InvalidRadius;
    }

    if (rx == 0) {
        if (ry == 0) {
            try utils.sdlValueCheck(c.SDL_RenderPoint(renderer, x, y), "SDL_RenderPoint");
        } else {
            try utils.sdlValueCheck(c.SDL_RenderLine(renderer, x, y - ry, x, y + ry), "SDL_RenderPoint");
        }
    } else if (ry == 0) {
        try utils.sdlValueCheck(c.SDL_RenderLine(renderer, x - rx, y, x + rx, y), "SDL_RenderLine");
    }

    var rx_adjusted = rx;
    var ry_adjusted = ry;
    if (rx > 0 and rx < 1) rx_adjusted = 1.0;
    if (ry > 0 and ry < 1) ry_adjusted = 1.0;

    var rxi = @as(i32, @intFromFloat(rx_adjusted));
    var ryi = @as(i32, @intFromFloat(ry_adjusted));

    const ellipse_overscan: i32 = if (rxi >= 512 or ryi >= 512)
        1
    else if (rxi >= 256 or ryi >= 256)
        2
    else
        4;

    var sx: i32 = 0;
    var sy = ryi;
    var ox: i32 = 0;
    var oy = ryi;

    rxi *= ellipse_overscan;
    ryi *= ellipse_overscan;

    try renderQuadrants(renderer, x, y, 0, ry_adjusted, fill);

    const rx2 = rxi * rxi;
    const rx22 = rx2 + rx2;
    const ry2 = ryi * ryi;
    const ry22 = ry2 + ry2;

    var cx: i32 = 0;
    var cy = ryi;
    var dx: i32 = 0;
    var dy = rx22 * cy;
    var err = ry2 - rx2 * ryi + @divFloor(rx2, 4);

    while (dx <= dy) {
        cx += 1;
        dx += ry22;
        err += dx + ry2;

        if (err >= 0) {
            cy -= 1;
            dy -= rx22;
            err -= dy;
        }

        sx = @divFloor(cx, ellipse_overscan);
        sy = @divFloor(cy, ellipse_overscan);

        if ((sx != ox and sy == oy) or (sx != ox and sy != oy)) {
            try renderQuadrants(renderer, x, y, @as(f32, @floatFromInt(sx)), @as(f32, @floatFromInt(sy)), fill);
            ox = sx;
            oy = sy;
        }
    }

    if (cy > 0) {
        const cxp1 = cx + 1;
        const cym1 = cy - 1;
        err = ry2 * cx * cxp1 + @divFloor(ry2 + 3, 4) + rx2 * cym1 * cym1 - rx2 * ry2;

        while (cy > 0) {
            cy -= 1;
            dy -= rx22;
            err += rx2;
            err -= dy;

            if (err <= 0) {
                cx += 1;
                dx += ry22;
                err += dx;
            }

            sx = @divFloor(cx, ellipse_overscan);
            sy = @divFloor(cy, ellipse_overscan);

            if ((sx != ox and sy == oy) or (sx != ox and sy != oy)) {
                oy -= 1;
                while (oy >= sy) : (oy -= 1) {
                    try renderQuadrants(renderer, x, y, @as(f32, @floatFromInt(sx)), @as(f32, @floatFromInt(sy)), fill);
                    if (fill) {
                        oy = sy - 1;
                    }
                }
                ox = sx;
                oy = sy;
            }
        }

        if (!fill) {
            oy -= 1;
            while (oy >= 0) : (oy -= 1) {
                try renderQuadrants(renderer, x, y, @as(f32, @floatFromInt(sx)), @as(f32, @floatFromInt(oy)), fill);
            }
        }
    }
}

pub fn renderFillCircle(renderer: *c.SDL_Renderer, r: f32, x: f32, y: f32) !void {
    try renderElipse(renderer, x, y, r, r, true);
}

// pub fn createText(ttf_text_engine: *c.TTF_TextEngine, font: *c.TTF_Font, text: []const u8, x: f32, y: f32, color: c.SDL_Color) ![*c]c.TTF_Text {
//     const fps_text = c.TTF_CreateText(ttf_text_engine, font, text.ptr, text.len);
//     _ = c.TTF_SetTextColor(fps_text, color.r, color.g, color.b, color.a);
//     return fps_text;
// }
