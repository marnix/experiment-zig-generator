const std = @import("std");

const Allocator = std.mem.Allocator;

fn Sink(comptime V: type) type {
    return struct {
        const Self = @This();
        const State = enum { empty, filled, uninitialized };

        _state: union(State) { uninitialized, empty: void, filled: V } = .uninitialized,

        fn yielding(self: *Self, v: V) void {
            std.debug.assert(self._state != .filled);
            self._state = .{ .filled = v };
        }
    };
}

fn SequenceIterator(comptime S: type, comptime V: type) type {
    return struct {
        const Self = @This();

        _allocator: *Allocator,
        _sink: *Sink(V),
        _frame: @Frame(S.@""),

        inline fn create(allocator: *Allocator, sequence: *S) !Self {
            var sink = try allocator.create(Sink(V));
            sink.* = Sink(V){};
            std.debug.assert(sink._state == .uninitialized);
            const frame = async sequence.@""(sink); // can go to state .filled, in yielding()
            return Self{ ._allocator = allocator, ._sink = sink, ._frame = frame };
        }

        fn deinit(self: *Self) void {
            self._allocator.destroy(self._sink);
        }

        fn next(self: *Self) ?V {
            // run the generator again, if necessary
            if (self._sink._state == .empty) {
                self._sink._state = .uninitialized;
                resume self._frame; // can go to state .filled, in yielding()
            }
            std.debug.assert(self._sink._state != .empty);
            // return the next result of the generator
            if (self._sink._state == .filled) {
                const result = self._sink._state.filled;
                self._sink._state = .empty;
                return result;
            } else {
                std.debug.assert(self._sink._state == .uninitialized);
                return null; // end of generator
            }
        }
    };
}
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

const expect = std.testing.expect;

const Range = struct {
    const Self = @This();
    m: usize,
    fn @""(self: *Self, gen: *Sink(usize)) void {
        var i: usize = 0;
        while (i < self.m) : (i += 1) {
            suspend gen.yielding(i);
        }
    }
};

fn range(m: usize) Range {
    return Range{ .m = m };
}

test "" {
    var r: ?usize = null;

    // TODO: Can the type Range be inferred by SequenceIterator()?
    var it = try SequenceIterator(Range, usize).create(std.testing.allocator, &range(2));
    defer it.deinit();

    r = it.next();
    expect(r.? == 0);

    r = it.next();
    expect(r.? == 1);

    r = it.next();
    expect(r == null);

    r = it.next();
    expect(r == null);
}

test "2" {
    var r: ?usize = null;

    var it = try SequenceIterator(Range, usize).create(std.testing.allocator, &range(0));
    defer it.deinit();

    r = it.next();
    expect(r == null);

    r = it.next();
    expect(r == null);
}
