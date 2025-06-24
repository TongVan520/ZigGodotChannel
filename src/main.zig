const std = @import("std");
const zgc = @import("zgc/zgc.zig");
const data_type = @import("zgc/data_type.zig");
const signal = @import("signal");

pub fn main() !void {
    std.debug.print("Hello World!\n", .{});
    try user();
}

fn user() !void {
    const fireflower = struct {
        pub fn server_user() !void {
            var server = zgc.Server{};
            var thread = try server.listenWithNewThread(.{}, .{});
            defer {
                thread.join();
                server.close() catch {};
            }

            try server.received.slots.append(signal.SlotOne(data_type.Data){
                .function = struct {
                    fn f(_: ?*anyopaque, data: data_type.Data) !void {
                        _ = data;
                        // 接收处理
                    }
                }.f,
            });
        }

        pub fn client_user() !void {
            var client = zgc.Client{};
            var thread = try client.connectWithNewThread(.{}, .{});
            defer {
                thread.join();
                client.close() catch {};
            }

            try client.received.slots.append(
                signal.SlotOne(data_type.Data){
                    .function = struct {
                        fn f(_: ?*anyopaque, data: data_type.Data) !void {
                            _ = data;
                            // 接收处理
                        }
                    }.f,
                },
            );
        }
    };

    try fireflower.server_user();
}
