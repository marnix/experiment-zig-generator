const std = @import("std");

const Allocator = std.mem.Allocator;

fn GenOf(comptime V: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        frame: anyframe,

        state: enum { empty, filled, invalid } = .empty, // TODO: better metaphor?
        // only defined if state == .filled
        current: V = undefined,

        fn yielding(self: *Self, value: V) void {
            self.current = value;
            self.state = .filled;
        }

        fn create(allocator: *Allocator, comptime f: anytype) !*Self {
            const frame = try allocator.create(@Frame(f));
            var self = try allocator.create(Self);
            self.* = Self{ .allocator = allocator, .frame = frame };
            self.state = .invalid;
            frame.* = async f(self);
            return self;
        }

        fn destroy(self: *Self) void {
            // self.allocator.destroy(self.frame);
            self.allocator.destroy(self);
        }

        fn next(self: *Self) ?V {
            // run the generator again, if necessary
            if (self.state == .empty) {
                self.state = .invalid;
                resume self.frame;
            }
            std.debug.assert(self.state != .empty);
            // return the next result of the generator
            if (self.state == .filled) {
                self.state = .empty;
                return self.current;
            } else {
                std.debug.assert(self.state == .invalid);
                return null; // end of generator
            }
        }
    };
}

const expect = std.testing.expect;

fn bits(gen: *GenOf(usize)) void {
    const m = 2;
    var i: usize = 0;
    while (i < m) : (i += 1) {
        suspend gen.yielding(i);
    }
}

test "" {
    var r: ?usize = null;

    var gen = try GenOf(usize).create(std.testing.allocator, bits);
    defer gen.destroy();

    r = gen.next();
    expect(r.? == 0);

    r = gen.next();
    expect(r.? == 1);

    r = gen.next();
    expect(r == null);

    r = gen.next();
    expect(r == null);
}
