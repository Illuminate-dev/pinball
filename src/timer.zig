const std = @import("std");
const c = @import("c.zig").c;

pub const TimerNS = struct {
    paused: bool,
    started: bool,
    start_tick: u64,
    ticks_elapsed_paused: u64,

    pub fn init() TimerNS {
        return TimerNS{
            .paused = false,
            .started = false,
            .start_tick = 0,
            .ticks_elapsed_paused = 0,
        };
    }

    pub fn start(self: *TimerNS) void {
        self.start_tick = c.SDL_GetTicksNS();
        self.ticks_elapsed_paused = 0;

        self.started = true;
        self.paused = false;
    }

    pub fn stop(self: *TimerNS) void {
        self.start_tick = 0;
        self.ticks_elapsed_paused = 0;

        self.started = false;
        self.paused = false;
    }

    pub fn unpause(self: *TimerNS) void {
        if (self.started and self.paused) {
            self.start_tick = c.SDL_GetTicksNS() - self.ticks_elapsed_paused;
            self.ticks_elapsed_paused = 0;

            self.paused = false;
        }
    }

    pub fn pause(self: *TimerNS) void {
        if (self.started and !self.paused) {
            self.ticks_elapsed_paused = self.getTicks();
            self.start_tick = 0;

            self.paused = true;
        }
    }

    pub fn getTicks(self: TimerNS) u64 {
        if (self.paused) {
            return self.ticks_elapsed_paused;
        } else {
            return c.SDL_GetTicksNS() - self.start_tick;
        }
    }
};
