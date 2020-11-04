const std = @import("std");

const Allocator = std.mem.Allocator;

fn SequenceIterator(comptime S: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const State = enum { empty, filled, uninitialized };

        _state: union(State) { uninitialized, empty: void, filled: V } = .uninitialized,
        _frame: @Frame(S.@"") = undefined,

        inline fn create() Self {
            return Self{};
        }

        inline fn init(self: *Self, sequence: *S) *Self {
            std.debug.assert(self._state == .uninitialized);
            self._frame = async sequence.@""(self); // can go to state .filled, in yielding()
            return self;
        }

        fn next(self: *Self) ?V {
            // run the generator again, if necessary
            if (self._state == .empty) {
                self._state = .uninitialized;
                resume self._frame; // can go to state .filled, in yielding()
            }
            std.debug.assert(self._state != .empty);
            // return the next result of the generator
            if (self._state == .filled) {
                const result = self._state.filled;
                self._state = .empty;
                return result;
            } else {
                std.debug.assert(self._state == .uninitialized);
                return null; // end of generator
            }
        }

        fn yielding(self: *Self, v: V) void {
            std.debug.assert(self._state != .filled);
            self._state = .{ .filled = v };
        }
    };
}
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

const expect = std.testing.expect;

const Range = struct {
    const Self = @This();
    m: usize,
    fn @""(self: *Self, gen: *SequenceIterator(Self, usize)) void {
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
    var it = SequenceIterator(Range, usize).create().init(&range(2));

    r = it.next();
    expect(r.? == 0);

    r = it.next();
    expect(r.? == 1);

    r = it.next();
    expect(r == null);

    r = it.next();
    expect(r == null);

    it = SequenceIterator(Range, usize).create().init(&range(0));

    r = it.next();
    expect(r == null);

    r = it.next();
    expect(r == null);
}
