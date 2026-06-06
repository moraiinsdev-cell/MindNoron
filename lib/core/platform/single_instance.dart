import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Best-effort single-instance guard.
///
/// Phase 0: prevents two copies fighting over the same global hotkey by holding
/// an exclusive lock file. Proper IPC that *focuses* the already-running window
/// (instead of just refusing to start) is a Phase 1A task.
class SingleInstance {
  SingleInstance._();

  static RandomAccessFile? _lock;

  /// Returns `true` if this is the only running instance.
  static Future<bool> acquire() async {
    try {
      final lockPath = p.join(Directory.systemTemp.path, 'mindnoron.lock');
      final raf = await File(lockPath).open(mode: FileMode.write);
      try {
        await raf.lock(FileLock.exclusive);
        _lock = raf;
        return true;
      } on FileSystemException {
        await raf.close();
        return false;
      }
    } catch (e) {
      debugPrint('SingleInstance check skipped: $e');
      return true; // fail open — never block the app from starting.
    }
  }

  static Future<void> release() async {
    try {
      await _lock?.unlock();
      await _lock?.close();
    } catch (_) {}
    _lock = null;
  }
}
