const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn GenOf(comptime V: type, comptime F: type) type {
    return struct {
        const Self = @This();

        _allocator: *Allocator,
        _frame: F = undefined,
        _yielder: *Yielder(V),

        fn init(allocator: *Allocator, anonf: anytype) !Self {
            var y = try allocator.create(Yielder(V)); // TODO: somehow try to get rid of this allocation!
            y.* = Yielder(V){};
            var self = Self{
                ._allocator = allocator,
                ._yielder = y,
            };
            std.debug.assert(self._yielder._state == .uninitialized);
            self._frame = async anonf.@""(self._yielder);
            return self;
        }

        fn deinit(self: *Self) void {
            self._allocator.destroy(self._yielder);
        }

        fn next(self: *Self) ?V {
            // run the generator again, if necessary
            if (self._yielder._state == .empty) {
                self._yielder._state = .uninitialized;
                resume self._frame; // can go to state .filled, in yield()
            }
            std.debug.assert(self._yielder._state != .empty);
            // return the next result of the generator
            if (self._yielder._state == .filled) {
                const result = self._yielder._state.filled;
                self._yielder._state = .empty;
                return result;
            } else {
                std.debug.assert(self._yielder._state == .uninitialized);
                return null; // end of generator
            }
        }
    };
}

pub fn Yielder(comptime V: type) type {
    return struct {
        const Self = @This();
        const State = enum { empty, filled, uninitialized };

        __unusedValue: V = undefined, //TODO get rid of this, use type of _stage.filled instead
        _state: union(State) { uninitialized, empty: void, filled: V } = .uninitialized,

        pub fn yield(self: *Self, value: V) void {
            std.debug.print("yielding {}\n", .{value});
            self._state = .{ .filled = value };
        }
    };
}
fn ValueTypeOfYielder(comptime Y: type) type {
    return @typeInfo(Y).Struct.fields[0].field_type;
}

// TODO: Get rid of this duplicated type madness
pub fn gen_iterator(allocator: *Allocator, r: anytype) !GenOf(ValueTypeOfYielder(@typeInfo(@typeInfo(@TypeOf(r.@"")).BoundFn.args[1].arg_type.?).Pointer.child), @Frame(@TypeOf(r).@"")) {
    const F = @Frame(@TypeOf(r).@"");
    std.debug.print("F = {}\n", .{@typeInfo(F)});
    const V = ValueTypeOfYielder(@typeInfo(@typeInfo(@TypeOf(r.@"")).BoundFn.args[1].arg_type.?).Pointer.child);
    std.debug.print("V = {}\n", .{@typeInfo(V)});
    return GenOf(V, F).init(allocator, r);
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

const expect = std.testing.expect;

const Range = struct {
    const Self = @This();
    m: usize,
    /// A generator is any struct with a function `@""` of this signature,
    /// where `usize` can be any (non-optional) type.
    pub fn @""(self: *const Self, yielder: *Yielder(usize)) void {
        var i: usize = 0;
        while (i < self.m) : (i += 1) {
            suspend yielder.yield(i);
        }
    }
    pub fn init(n: usize) Self {
        return Self{ .m = n };
    }
};

test "" {
    std.debug.print("\n", .{});
    var it = try gen_iterator(std.testing.allocator, Range.init(2));
    defer it.deinit();
    expect(it.next().? == 0);
    expect(it.next().? == 1);
    expect(it.next() == null);
}
