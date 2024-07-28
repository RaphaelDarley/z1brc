const std = @import("std");

const StationInfo = struct {
    min: i16,
    max: i16,
    num: u32,
    sum: i64,

    pub fn update(self: *StationInfo, temp: i16) void {
        self.min = @min(self.min, temp);
        self.max = @max(self.max, temp);
        self.num += 1;
        self.sum += temp;
    }
    pub fn new(temp: i16) StationInfo {
        return StationInfo{
            .min = temp,
            .max = temp,
            .num = 1,
            .sum = temp,
        };
    }
    pub fn format(self: StationInfo, name: []const u8, writer: std.io.AnyWriter, comptime comma_prefix: bool) !void {
        // notes: https://codapi.org/embed/?sandbox=zig&code=data%3A%3Bbase64%2Cpc%2FNCoJAFIbhvVfxNasRTLKiRSK46gpatnE8FgPNjMyMbsR7DwyJfi3ansPDx1sa7TycJ2TIpaqN9Zw5TyxMg6BuBI4aqpCah2iNJHQBAJSDKraQmzUyzJPlKh0ezlNMlWhOcW2l9pwpQxE66mcHzSLEXa4M8SJCsgj78I0h2e5to8t7OF6ntK3UPbSV%2BmJxdzbGPi0O1wd9jRdj%2FI%2Ft4q%2F2Cf2yfXrxU%2FtNB%2F0F

        const split_min = split(self.min);
        const split_max = split(self.max);
        const mean: i16 = @intCast(@divTrunc(self.sum, self.num));
        const split_mean = split(mean);

        // name;<min>/<mean>/<max>
        if (comma_prefix) {
            const fmt_str = ", {s};{d}.{d}/{d}.{d}/{d}.{d}";
            try writer.print(fmt_str, .{
                name,
                split_min.@"0",
                split_min.@"1",
                split_mean.@"0",
                split_mean.@"1",
                split_max.@"0",
                split_max.@"1",
            });
        } else {
            const fmt_str = "{s};{d}.{d}/{d}.{d}/{d}.{d}";
            try writer.print(fmt_str, .{
                name,
                split_min.@"0",
                split_min.@"1",
                split_mean.@"0",
                split_mean.@"1",
                split_max.@"0",
                split_max.@"1",
            });
        }
    }
};

// TODO: fix rounding
fn div_round(x: i64, y: u32) i16 {
    const y2: i64 = @intCast(y / 2);

    if (y > 0) {
        return @intCast(@divTrunc(x + y2, y));
    } else {
        return @intCast(@divFloor(x - y2, y));
    }

    // return @intCast(x / y);
}

test "div_round" {
    try std.testing.expectEqual(div_round(3, 2), 2);
    try std.testing.expectEqual(div_round(4, 2), 2);
    try std.testing.expectEqual(div_round(4, 3), 1);

    try std.testing.expectEqual(div_round(-3, 2), -2);
    try std.testing.expectEqual(div_round(-4, 2), -2);
    try std.testing.expectEqual(div_round(-4, 3), -1);
}

fn split(num: i16) struct { i16, i16 } {
    const first = @divTrunc(num, 10);
    var second = @rem(num, 10);
    if (second < 0) second *= -1;

    return .{ first, second };
}

test "split" {
    try std.testing.expectEqual(split(123), .{ 12, 3 });
    try std.testing.expectEqual(split(-123), .{ -12, 3 });
}

pub fn main() !void {
    const measurement_path = "/Users/rd/Coding/Rust/one_br/1brc/measurements.txt";
    // const measurement_path = "/Users/rd/Coding/Rust/one_br/1brc/measurements_10.txt";
    // const measurement_path = "/Users/rd/Coding/Rust/one_br/1brc/measurements_1m.txt";

    std.debug.print("using measurement file: {s}\n", .{measurement_path});

    const measurement_file = try std.fs.openFileAbsolute(measurement_path, .{});
    defer measurement_file.close();

    const measurement_meta = try measurement_file.metadata();
    const measurement_size = measurement_meta.size();

    const alloc = std.heap.page_allocator;
    // var buffer = try alloc.alloc(u8, measurement_size);
    const contents = try measurement_file.readToEndAlloc(alloc, measurement_size);

    // { // print line by line
    //     var line_buff: [100]u8 = undefined;
    //     var line_buff_idx: usize = 0;

    //     for (contents) |c| {
    //         line_buff[line_buff_idx] = c;

    //         line_buff_idx += 1;
    //         if (c == '\n') {
    //             // line_buff[line_buff_idx] = c;
    //             std.debug.print("{s}", .{line_buff[0..line_buff_idx]});
    //             line_buff_idx = 0;
    //         }
    //     }
    //     std.debug.print("\nprinted lines \n\n", .{});
    // }

    var map_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer map_arena.deinit();

    const map_alloc = map_arena.allocator();

    const Map = std.StringHashMap(StationInfo);

    var station_map = Map.init(map_alloc);

    var station_num: usize = 0;

    var i: usize = 0;
    while (i + 1 < contents.len) {
        var name: [32]u8 = undefined;
        var name_idx: usize = 0;
        var neg = false;

        var digits: [3]u8 = undefined;
        var digits_idx: usize = 0;
        var temp: i16 = 0;

        while (contents[i] != ';') {
            name[name_idx] = contents[i];
            name_idx += 1;
            i += 1;
        }
        name[name_idx] = 0;
        // skip semicolon
        i += 1;
        if (contents[i] == '-') {
            neg = true;
            i += 1;
        }
        while (contents[i] != '\n') {
            if (contents[i] == '.') i += 1;
            digits[digits_idx] = contents[i] - 48;
            digits_idx += 1;
            i += 1;
        }
        var place_val: i16 = 1;
        var j = digits_idx;
        while (j > 0) {
            j -= 1;
            temp += digits[j] * place_val;
            place_val *= 10;
        }
        if (neg) temp *= -1;
        i += 1;
        station_num += 1;

        if (station_map.getEntry(name[0..name_idx])) |entry| {
            entry.value_ptr.update(temp);
        } else {
            const key_str = try map_alloc.dupeZ(u8, name[0..name_idx]);
            try station_map.put(key_str, StationInfo.new(temp));
        }
    }
    std.debug.print("number of lines: {d}\n", .{station_num});

    var station_iter = station_map.iterator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("{{", .{});

    if (station_iter.next()) |entry| {
        try entry.value_ptr.format(entry.key_ptr.*, stdout.any(), false);
    }

    while (station_iter.next()) |entry| {
        try entry.value_ptr.format(entry.key_ptr.*, stdout.any(), true);
    }
    try stdout.print("}}", .{});
    try bw.flush();
}
