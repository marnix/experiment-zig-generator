const std = @import("std");

fn GenOf(comptime T: type) type {
    return struct {
        const Self = @This();
        fn create(f: var) Self {
            return Self{};
        }
    };
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

test "" {
    const RetType = void;
    const nats = GenOf(u16).create(struct {
        fn @""(g: var) RetType {
            return nats(g, 3);
        }
    });
}
