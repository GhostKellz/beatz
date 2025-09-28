const std = @import("std");
const testing = std.testing;

/// Lock-free ring buffer for audio streaming
/// Uses atomic operations for thread-safe single-producer, single-consumer operations
pub fn RingBuffer(comptime T: type) type {
    return struct {
        buffer: []T,
        capacity: usize,
        write_index: std.atomic.Value(usize),
        read_index: std.atomic.Value(usize),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            // Ensure capacity is power of 2 for efficient modulo operations
            const actual_capacity = std.math.ceilPowerOfTwo(usize, capacity) catch return error.InvalidCapacity;

            const buffer = try allocator.alloc(T, actual_capacity);

            return Self{
                .buffer = buffer,
                .capacity = actual_capacity,
                .write_index = std.atomic.Value(usize).init(0),
                .read_index = std.atomic.Value(usize).init(0),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buffer);
        }

        /// Get the number of elements available to read
        pub fn readAvailable(self: *const Self) usize {
            const write_idx = self.write_index.load(.acquire);
            const read_idx = self.read_index.load(.acquire);
            return (write_idx -% read_idx) & (self.capacity - 1);
        }

        /// Get the number of elements available to write
        pub fn writeAvailable(self: *const Self) usize {
            const write_idx = self.write_index.load(.acquire);
            const read_idx = self.read_index.load(.acquire);
            return (self.capacity - 1) - ((write_idx -% read_idx) & (self.capacity - 1));
        }

        /// Check if the buffer is empty
        pub fn isEmpty(self: *const Self) bool {
            const write_idx = self.write_index.load(.acquire);
            const read_idx = self.read_index.load(.acquire);
            return write_idx == read_idx;
        }

        /// Check if the buffer is full
        pub fn isFull(self: *const Self) bool {
            return self.writeAvailable() == 0;
        }

        /// Write a single element to the buffer
        /// Returns true if successful, false if buffer is full
        pub fn write(self: *Self, item: T) bool {
            const write_idx = self.write_index.load(.acquire);
            const next_write = (write_idx + 1) & (self.capacity - 1);
            const read_idx = self.read_index.load(.acquire);

            if (next_write == read_idx) {
                return false; // Buffer is full
            }

            self.buffer[write_idx] = item;
            self.write_index.store(next_write, .release);
            return true;
        }

        /// Write multiple elements to the buffer
        /// Returns the number of elements actually written
        pub fn writeSlice(self: *Self, items: []const T) usize {
            const available = self.writeAvailable();
            const to_write = @min(items.len, available);

            if (to_write == 0) return 0;

            const write_idx = self.write_index.load(.acquire);
            const end_idx = (write_idx + to_write) & (self.capacity - 1);

            if (end_idx > write_idx) {
                // Contiguous write
                @memcpy(self.buffer[write_idx..write_idx + to_write], items[0..to_write]);
            } else {
                // Wrapped write
                const first_chunk = self.capacity - write_idx;
                @memcpy(self.buffer[write_idx..], items[0..first_chunk]);
                @memcpy(self.buffer[0..to_write - first_chunk], items[first_chunk..to_write]);
            }

            self.write_index.store(end_idx, .release);
            return to_write;
        }

        /// Read a single element from the buffer
        /// Returns null if buffer is empty
        pub fn read(self: *Self) ?T {
            const read_idx = self.read_index.load(.acquire);
            const write_idx = self.write_index.load(.acquire);

            if (read_idx == write_idx) {
                return null; // Buffer is empty
            }

            const item = self.buffer[read_idx];
            const next_read = (read_idx + 1) & (self.capacity - 1);
            self.read_index.store(next_read, .release);
            return item;
        }

        /// Read multiple elements from the buffer
        /// Returns the number of elements actually read
        pub fn readSlice(self: *Self, buffer: []T) usize {
            const available = self.readAvailable();
            const to_read = @min(buffer.len, available);

            if (to_read == 0) return 0;

            const read_idx = self.read_index.load(.acquire);
            const end_idx = (read_idx + to_read) & (self.capacity - 1);

            if (end_idx > read_idx) {
                // Contiguous read
                @memcpy(buffer[0..to_read], self.buffer[read_idx..read_idx + to_read]);
            } else {
                // Wrapped read
                const first_chunk = self.capacity - read_idx;
                @memcpy(buffer[0..first_chunk], self.buffer[read_idx..]);
                @memcpy(buffer[first_chunk..to_read], self.buffer[0..to_read - first_chunk]);
            }

            self.read_index.store(end_idx, .release);
            return to_read;
        }

        /// Clear the buffer by resetting indices
        pub fn clear(self: *Self) void {
            self.read_index.store(0, .release);
            self.write_index.store(0, .release);
        }

        /// Get buffer capacity
        pub fn getCapacity(self: *const Self) usize {
            return self.capacity - 1; // Usable capacity is capacity - 1
        }

        /// Check for buffer overrun (write caught up to read)
        pub fn hasOverrun(self: *const Self) bool {
            return self.isFull();
        }

        /// Check for buffer underrun (read caught up to write)
        pub fn hasUnderrun(self: *const Self) bool {
            return self.isEmpty();
        }
    };
}

// Tests
test "RingBuffer - basic operations" {
    var buffer = try RingBuffer(f32).init(testing.allocator, 4);
    defer buffer.deinit();

    // Test empty buffer
    try testing.expect(buffer.isEmpty());
    try testing.expect(!buffer.isFull());
    try testing.expectEqual(@as(usize, 0), buffer.readAvailable());
    try testing.expectEqual(@as(usize, 3), buffer.writeAvailable()); // capacity - 1

    // Test single write/read
    try testing.expect(buffer.write(1.0));
    try testing.expect(!buffer.isEmpty());
    try testing.expectEqual(@as(usize, 1), buffer.readAvailable());

    const value = buffer.read();
    try testing.expect(value != null);
    try testing.expectEqual(@as(f32, 1.0), value.?);
    try testing.expect(buffer.isEmpty());
}

test "RingBuffer - slice operations" {
    var buffer = try RingBuffer(f32).init(testing.allocator, 8);
    defer buffer.deinit();

    const write_data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const written = buffer.writeSlice(&write_data);
    try testing.expectEqual(@as(usize, 5), written);

    var read_data: [10]f32 = undefined;
    const read_count = buffer.readSlice(&read_data);
    try testing.expectEqual(@as(usize, 5), read_count);

    for (0..5) |i| {
        try testing.expectEqual(write_data[i], read_data[i]);
    }
}

test "RingBuffer - wrap around" {
    var buffer = try RingBuffer(u32).init(testing.allocator, 4);
    defer buffer.deinit();

    // Fill buffer
    try testing.expect(buffer.write(1));
    try testing.expect(buffer.write(2));
    try testing.expect(buffer.write(3));
    try testing.expect(!buffer.write(4)); // Should fail, buffer full

    // Read and write to test wrap
    try testing.expectEqual(@as(u32, 1), buffer.read().?);
    try testing.expect(buffer.write(4));

    try testing.expectEqual(@as(u32, 2), buffer.read().?);
    try testing.expectEqual(@as(u32, 3), buffer.read().?);
    try testing.expectEqual(@as(u32, 4), buffer.read().?);
    try testing.expect(buffer.read() == null);
}

test "RingBuffer - overflow/underflow detection" {
    var buffer = try RingBuffer(i32).init(testing.allocator, 4);
    defer buffer.deinit();

    // Test underrun
    try testing.expect(buffer.hasUnderrun());

    // Fill buffer
    try testing.expect(buffer.write(1));
    try testing.expect(buffer.write(2));
    try testing.expect(buffer.write(3));

    // Test overrun
    try testing.expect(buffer.hasOverrun());
    try testing.expect(!buffer.hasUnderrun());
}