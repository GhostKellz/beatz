pub const enable_pipewire: bool = true;
pub const enable_alsa: bool = true;
pub const enable_mixer: bool = true;
pub const enable_hotplug: bool = true;
pub const enable_conversion: bool = true;
pub const @"build.build__enum_72367" = enum (u2) {
    performance = 0,
    balanced = 1,
    size = 2,
};
pub const performance_mode: @"build.build__enum_72367" = .balanced;
pub const buffer_sizes: []const u8 = "64,128,256,512,1024,2048,4096";
pub const sample_rates: []const u8 = "16000,22050,44100,48000,96000,192000";
