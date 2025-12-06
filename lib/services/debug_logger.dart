/// ABS Platform - Debug Logger Service
/// 
/// Purpose: Rolling debug log for troubleshooting crashes and errors
/// Key Components:
///   - Single log file (auto-rotates on app start)
///   - Timestamped entries
///   - Automatic old log deletion
///   - Easy access from anywhere in app
/// 
/// Usage:
///   DebugLogger.log('Something happened');
///   DebugLogger.error('Error occurred', error, stackTrace);
/// 
/// Last Modified: December 5, 2025

import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Global debug logger for troubleshooting
class DebugLogger {
  static File? _logFile;
  static bool _initialized = false;

  /// Initialize the logger (call once at app start)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${appDir.path}/abs_platform_logs');
      
      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Delete old log if it exists
      final oldLog = File('${logsDir.path}/debug.log');
      if (await oldLog.exists()) {
        await oldLog.delete();
      }

      // Create new log file
      _logFile = File('${logsDir.path}/debug.log');
      _initialized = true;

      // Log initialization
      await log('=== Debug Logger Initialized ===');
      await log('Timestamp: ${DateTime.now()}');
      await log('Platform: ${Platform.operatingSystem}');
      await log('=====================================\n');
    } catch (e) {
      print('Failed to initialize debug logger: $e');
    }
  }

  /// Log a regular message
  static Future<void> log(String message) async {
    if (!_initialized) await initialize();
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] $message\n';
      
      // Write to file
      await _logFile?.writeAsString(logMessage, mode: FileMode.append);
      
      // Also print to console
      print(logMessage.trim());
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  /// Log an error with stack trace
  static Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    if (!_initialized) await initialize();
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = StringBuffer();
      logMessage.writeln('[$timestamp] ERROR: $message');
      
      if (error != null) {
        logMessage.writeln('Error: $error');
      }
      
      if (stackTrace != null) {
        logMessage.writeln('Stack trace:');
        logMessage.writeln(stackTrace.toString());
      }
      
      logMessage.writeln('---');
      
      // Write to file
      await _logFile?.writeAsString(logMessage.toString(), mode: FileMode.append);
      
      // Also print to console
      print(logMessage.toString().trim());
    } catch (e) {
      print('Failed to write error log: $e');
    }
  }

  /// Get the log file path for user access
  static Future<String?> getLogPath() async {
    if (!_initialized) await initialize();
    return _logFile?.path;
  }

  /// Read the current log contents
  static Future<String> readLog() async {
    if (!_initialized) await initialize();
    
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return 'Failed to read log: $e';
    }
    
    return 'No log file found';
  }
}
