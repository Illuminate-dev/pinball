const std = @import("std");
const c = @import("c.zig").c;

pub const WHITE = c.SDL_Color{ .r = 255, .b = 255, .g = 255, .a = 255 };

pub fn sdlValueCheck(value: anytype, comptime name: []const u8) !void {
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
