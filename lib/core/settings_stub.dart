import 'app_config.dart';

/// Web / 其它非 IO 平台的存储工厂（不持久化，仅内存）。
SettingsStore createSettingsStore() => MemorySettingsStore();
