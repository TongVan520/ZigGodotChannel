const std = @import("std");

// 支持的数据类型：Bool, Number, String, Object, Array, Dictionary, Signal, Callable, Variant

/// 数据
///
/// 是所有支持传递的数据类型的 *接口*
pub const Data = struct {
    userdata: *const anyopaque,
    interface: struct {
        toU8Span: *const fn (userdata: *const anyopaque) []u8,
    },

    pub fn toU8Span(self: *const Data) []u8 {
        return self.interface.toU8Span(self.userdata);
    }
};

pub const Bool = struct {
    pub fn makeData(self: *const Bool) Data {
        return .{
            .userdata = self,
            .interface = .{
                .toU8Span = struct {
                    fn f(userdata: *const anyopaque) []u8 {
                        const s: *const Bool = @ptrCast(@alignCast(userdata));
                        _ = s;
                    }
                }.f,
            },
        };
    }

    pub fn toU8Span(self: Bool) []u8 {
        _ = self;
        // 实现
    }
};

pub const Number = struct {};
pub const String = struct {};
pub const Object = struct {};
pub const Array = struct {};
pub const Dictionary = struct {};
pub const Signal = struct {};
pub const Callable = struct {};
pub const Variant = struct {};
