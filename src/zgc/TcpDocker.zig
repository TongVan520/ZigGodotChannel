const std = @import("std");
const signal = @import("signal");
const Self = @This();
const Allocator = std.mem.Allocator;

received: signal.SignalOne([]const u8),
private_data: *anyopaque,

/// 私有数据
const PrivateData = struct {
    /// 用于管理自己的内存分配器
    self_allocator: std.heap.ArenaAllocator,
    server: ?std.net.Server,
    connection: ?std.net.Server.Connection,
};

/// 空字符读取协议
///
/// 读取到 `'\0'` 字符时结束此次读取
pub const CharZeroReadProtocol = struct {
    /// 是否已完成此次读取
    pub fn isReadDone(_: CharZeroReadProtocol, readed_data: []const u8) bool {
        return readed_data.len > 0 and readed_data[readed_data.len - 1] == '\x00';
    }
};

/// 错误
const Error = error{
    /// 尚未启动
    NotStarted,

    /// 重复启动
    RepeatedStart,
};

pub fn init(allocator: Self.Allocator) !Self {
    var result = Self{
        .private_data = undefined,
        .received = signal.SignalOne([]const u8).init(allocator),
    };

    try result.initPrivateData(allocator);
    return result;
}

pub fn deinit(self: Self) void {
    self.received.deinit();
    self.deinitPrivateData();
}

fn initPrivateData(self: *Self, allocator: Self.Allocator) !void {
    var private_data = Self.PrivateData{
        .self_allocator = std.heap.ArenaAllocator.init(allocator),
        .connection = null,
        .server = null,
    };

    const arena_allocator = private_data.self_allocator.allocator();
    const pd = try arena_allocator.create(Self.PrivateData);
    defer arena_allocator.destroy(pd);

    pd.* = private_data;
    self.private_data = pd;
}

fn deinitPrivateData(self: Self) void {
    const pd = self.getPrivateData();
    pd.self_allocator.deinit();
}

fn getPrivateData(self: Self) Self.PrivateData {
    const pd: *const Self.PrivateData = @ptrCast(@alignCast(self.private_data));
    return pd.*;
}

fn getPrivateDataPtr(self: *Self) *Self.PrivateData {
    return @ptrCast(@alignCast(self.private_data));
}

/// 启动服务器
pub fn start(self: *Self, name: []const u8, port: u16) !void {
    try self.ensureStopped();

    const address = try std.net.Address.parseIp(name, port);

    var server = try address.listen(.{});
    const connection = try server.accept();

    const pd = self.getPrivateDataPtr();
    pd.server = server;
    pd.connection = connection;
}

/// 停止服务器
pub fn stop(self: *Self) Self.Error!void {
    try self.ensureStarted();

    const pd = self.getPrivateDataPtr();

    pd.connection.?.stream.close();
    pd.connection = null;

    pd.server.?.deinit();
    pd.server = null;
}

pub fn send(self: Self, data: []const u8) (Self.Error || std.net.Stream.WriteError)!void {
    try self.ensureStarted();

    const pd = self.getPrivateData();
    try pd.connection.?.stream.writeAll(data);
}

/// 接收
///
/// **阻塞函数** ，读取至 `\x00` 时返回
///
/// 调用者 **需要** 管理返回的内存
pub fn receive(self: Self, allocator: Self.Allocator) ![]u8 {
    try self.ensureStarted();

    const pd = self.getPrivateData();

    const reader = pd.connection.?.stream.reader();
    var string = std.ArrayList(u8).init(allocator);
    defer string.deinit();

    while (!Self.CharZeroReadProtocol.isReadDone(undefined, string.items)) {
        try string.append(try reader.readByte());
    }

    try self.received.emit(string.items);
    return string.toOwnedSlice();
}

pub fn canReceive(self: Self) bool {
    const pd = self.getPrivateData();
    return self.isStarted() and Self.isStreamReadable(pd.connection.?.stream) catch unreachable;
}

/// 检查 Stream 是否有数据可读（非阻塞）
fn isStreamReadable(stream: std.net.Stream) !bool {
    var poll_fds = [_]std.posix.pollfd{
        .{ .fd = stream.handle, .events = std.posix.POLL.IN, .revents = 0 },
    };
    const nevents = try std.posix.poll(&poll_fds, 0); // 0 = 立即返回
    return nevents > 0 and (poll_fds[0].revents & std.posix.POLL.IN != 0);
}

pub fn isStarted(self: Self) bool {
    const pd = self.getPrivateData();
    return pd.server != null or pd.connection != null;
}

fn ensureStarted(self: Self) Self.Error!void {
    if (!self.isStarted()) {
        return Self.Error.NotStarted;
    }
}

fn ensureStopped(self: Self) Self.Error!void {
    if (self.isStarted()) {
        return Self.Error.RepeatedStart;
    }
}
