const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// TODO list:
//  - non-void return type

fn GenOf(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        value: ?T = null,

        fn create(allocator: *Allocator, f: var) !*Self {
            var self = try allocator.create(Self);
            self.* = Self{ .allocator = allocator };
            _ = async f.@""(self);
            return self;
        }
        fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }

        fn yield(self: *Self, value: T) void {
            self.value = value;
            suspend;
        }
    };
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

var called = false;
fn nats(gen: var, n: u16) void {
    called = true;
    gen.yield(0);
}

test "" {
    const nrs = try GenOf(u16).create(std.testing.allocator, struct {
        fn @""(g: var) void {
            return nats(g, 1);
        }
    });
    defer nrs.deinit();

    assert(called);
}
