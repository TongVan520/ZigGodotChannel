const std = @import("std");
const TcpDocker = @import("zgc/TcpDocker.zig");

pub fn main() !void {
    std.debug.print("Hello World!\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tcp_docker = try TcpDocker.init(allocator);
    defer tcp_docker.deinit();

    try tcp_docker.start("127.0.0.1", 810);
    defer tcp_docker.stop() catch unreachable;

    const read_thread = try std.Thread.spawn(.{}, readThread, .{&tcp_docker});
    defer read_thread.join();

    const write_thread = try std.Thread.spawn(.{}, writeThread, .{&tcp_docker});
    defer write_thread.join();
}

pub fn readThread(tcp_docker: *TcpDocker) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const console_writer = std.io.getStdOut().writer();

    while (true) {
        if (!tcp_docker.canReceive()) {
            continue;
        }

        const data = tcp_docker.receive(allocator) catch unreachable;
        defer allocator.free(data);

        const message = std.fmt.allocPrint(
            allocator,
            "接收数据：\n{s}\n",
            .{data[0..(data.len - 2)]},
        ) catch unreachable;
        defer allocator.free(message);

        console_writer.writeAll(message) catch unreachable;

        if (std.mem.eql(u8, data, "exit\r\x00")) {
            break;
        }
    }
}

pub fn writeThread(tcp_docker: *TcpDocker) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const console_reader = std.io.getStdIn().reader();
    const console_writer = std.io.getStdOut().writer();

    while (true) {
        var message_string = std.ArrayList(u8).init(allocator);
        defer message_string.deinit();

        console_writer.writeAll("请输入需要发送的消息：\n") catch unreachable;

        console_reader.readUntilDelimiterArrayList(&message_string, '\n', std.math.maxInt(usize)) catch unreachable;
        message_string.append('\x00') catch unreachable;
        tcp_docker.send(message_string.items) catch unreachable;

        if (std.mem.eql(u8, message_string.items, "exit\r\x00")) {
            break;
        }
    }
}

test "带接口默认选项的结构体" {
    const Pixel = struct {
        const Self = @This();

        object: *anyopaque,
        interface: struct {
            render: *const fn (object: *const anyopaque) anyerror!void,
        },

        pub fn render(self: Self) !void {
            return self.interface.render(self.object);
        }
    };

    const EmptyPixel = struct {
        const Self = @This();

        pub fn makePixel(self: *Self) Pixel {
            return Pixel{
                .object = self,
                .interface = .{
                    .render = struct {
                        pub fn f(object: *const anyopaque) anyerror!void {
                            const s: *const Self = @ptrCast(@alignCast(object));
                            try s.render();
                        }
                    }.f,
                },
            };
        }

        pub fn render(_: Self) !void {
            std.debug.print("  ", .{});
        }
    };

    const OPixel = struct {
        const Self = @This();

        pub fn makePixel(self: *Self) Pixel {
            return Pixel{
                .object = self,
                .interface = .{
                    .render = struct {
                        pub fn f(object: *const anyopaque) anyerror!void {
                            const s: *const Self = @ptrCast(@alignCast(object));
                            try s.render();
                        }
                    }.f,
                },
            };
        }

        pub fn render(_: Self) !void {
            std.debug.print("()", .{});
        }
    };

    const Canvas = struct {
        const Self = @This();
        const Allocator = std.mem.Allocator;

        data: std.ArrayList(Pixel),
        size: Self.Size,

        /// 仅用于管理 ***不*** *由容器管理的内存*
        self_allocator: std.heap.ArenaAllocator,

        const Size = struct {
            width: usize,
            height: usize,
        };

        const Position = struct {
            x: usize,
            y: usize,
        };

        pub fn init(allocator: Self.Allocator, init_size: Self.Size) !Self {
            var result = Self{
                .data = std.ArrayList(Pixel).init(allocator),
                .size = init_size,
                .self_allocator = std.heap.ArenaAllocator.init(allocator),
            };

            const default_pixel = try result.self_allocator.allocator().create(EmptyPixel);
            defer result.self_allocator.allocator().destroy(default_pixel);
            for (0..(result.size.width * result.size.height)) |_| {
                try result.data.append(default_pixel.makePixel());
            }

            return result;
        }

        pub fn deinit(self: Self) void {
            self.data.deinit();
            self.self_allocator.deinit();
        }

        pub fn setPixel(self: *Self, position: Self.Position, pixel: Pixel) void {
            const index = self.positionToIndex(position);
            self.data.items[index] = pixel;
        }

        pub fn getPixel(self: Self, position: Self.Position) Pixel {
            const index = self.positionToIndex(position);
            return self.data.items[index];
        }

        pub fn show(self: Self) !void {
            for (self.data.items, 0..) |pixel, index| {
                try pixel.render();

                const position = self.indexToPosition(index);
                if (position.x == self.size.width - 1) {
                    std.debug.print("\n", .{});
                }
            }
        }

        fn indexToPosition(self: Self, index: usize) Self.Position {
            return Self.Position{
                .x = index % self.size.width,
                .y = index / self.size.width,
            };
        }

        fn positionToIndex(self: Self, position: Self.Position) usize {
            return position.y * self.size.width + position.x;
        }
    };

    var canvas = try Canvas.init(std.testing.allocator, .{
        .width = 10,
        .height = 5,
    });
    defer canvas.deinit();

    var o_pixel = OPixel{};
    canvas.setPixel(
        Canvas.Position{ .x = 7, .y = 3 },
        o_pixel.makePixel(),
    );

    try canvas.show();
}
