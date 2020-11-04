const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// TODO list:
//  - non-void return type

fn GenOf(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        frame: anyframe, // *@Frame(_G().@""),
        _value: ?T = null,

        fn _F() type {
            return @TypeOf(_G());
        }
        fn _G() type {
            return struct {
                fn @""(g: *Self) void {
                    unreachable;
                }
            };
        }

        pub fn create(allocator: *Allocator, comptime F: anytype) !*Self {
            var self = try allocator.create(Self);
            const frame = try allocator.create(@Frame(F.@""));
            self.* = Self{ .allocator = allocator, .frame = frame };
            frame.* = async F.@""(self);
            return self;
        }
        pub fn deinit(self: *Self) void {
            //self.allocator.destroy(self.frame);
            self.allocator.destroy(self);
        }
        pub fn next(self: *Self) ?T {
            if (self._value) |v| {
                self._value = null;
                return v;
            }
            return null;
        }

        pub fn yield(self: *Self, value: T) void {
            self._value = value;
            suspend;
        }
    };
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

var reached0 = false;
var reached1 = false;
fn nats(gen: *GenOf(u16), n: u16) void {
    reached0 = true;
    gen.yield(0);
    reached1 = true;
}

test "" {
    const nrs = try GenOf(u16).create(std.testing.allocator, struct {
        fn @""(g: *GenOf(u16)) void {
            return nats(g, 1);
        }
    });
    defer nrs.deinit();

    assert(reached0);
    assert(nrs.next().? == 0);

    //assert(reached1);
}
