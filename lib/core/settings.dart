// 平台相关的设置存储工厂：IO 平台用文件持久化，其余用内存实现。
export 'settings_stub.dart' if (dart.library.io) 'settings_io.dart';
