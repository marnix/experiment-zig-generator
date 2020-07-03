const std = @import("std");
const assert = std.debug.assert;

// TODO list:
//  - implement yield();
//  - non-void return type

fn GenOf(comptime T: type) type {
    return struct {
        const Self = @This();
        fn create(f: var) Self {
            var self = Self{};
            _ = async f.@""(self);
            return self;
        }
    };
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

var called = false;
fn nats(g: var, n: u16) void {
    called = true;
}

test "" {
    const nrs = GenOf(u16).create(struct {
        fn @""(g: var) void {
            return nats(g, 1);
        }
    });

    assert(called);
}
