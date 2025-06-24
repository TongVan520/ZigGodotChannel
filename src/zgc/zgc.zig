const std = @import("std");
const signal = @import("signal");
const data_type = @import("data_type.zig");

pub const Address = struct {};
pub const Port = struct {};
const Thread = std.Thread;

// Zig与Godot可在同一连接中同时收发数据

/// 服务端
pub const Server = struct {
    received: signal.SignalOne(data_type.Data) = undefined,

    /// 在新线程中监听客户端
    pub fn listenWithNewThread(self: *Server, address: Address, port: Port) !Thread {
        _ = self;
        _ = address;
        _ = port;
        return undefined;
    }

    /// 关闭服务端
    pub fn close(self: *Server) !void {
        _ = self;
    }

    /// 发送数据
    pub fn send(self: Server, data: data_type.Data) !void {
        _ = self;
        _ = data;
    }
};

/// 客户端
pub const Client = struct {
    received: signal.SignalOne(data_type.Data) = undefined,

    /// 在新线程中连接服务器
    pub fn connectWithNewThread(self: *Client, address: Address, port: Port) !Thread {
        _ = self;
        _ = address;
        _ = port;
        return undefined;
    }

    /// 关闭客户端
    pub fn close(self: *Client) !void {
        _ = self;
    }

    /// 发送数据
    pub fn send(self: Client, data: data_type.Data) !void {
        _ = self;
        _ = data;
    }
};
