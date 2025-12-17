import 'package:flutter/services.dart';
import 'dart:io';

/// Service to access additional HealthKit properties via native iOS bridge
/// This service reads HKWorkout.duration property which represents active workout time
class HealthKitBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.jared.pacelifter/healthkit');

  /// Get the active duration (excluding pauses) for a workout by UUID
  /// Returns duration in milliseconds, or null if:
  /// - Platform is not iOS
  /// - Workout not found
  /// - Authorization denied
  /// - Any error occurs
  Future<int?> getWorkoutDuration(String uuid) async {
    if (!Platform.isIOS) {
      return null;
    }

    try {
      final int? durationMs = await _channel.invokeMethod<int>(
        'getWorkoutDuration',
        {'uuid': uuid},
      );
      return durationMs;
    } on PlatformException catch (e) {
      print('⚠️ Failed to get workout duration: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('⚠️ Unexpected error getting workout duration: $e');
      return null;
    }
  }

  /// Get detailed workout information including active duration and elapsed time
  /// Returns a map with:
  /// - activeDuration: milliseconds (active workout time, excluding pauses)
  /// - elapsedTime: milliseconds (total time from start to end)
  /// - pausedDuration: milliseconds (time spent paused)
  /// - startDate: milliseconds since epoch
  /// - endDate: milliseconds since epoch
  ///
  /// Returns null if:
  /// - Platform is not iOS
  /// - Workout not found
  /// - Authorization denied
  /// - Any error occurs
  Future<Map<String, dynamic>?> getWorkoutDetails(String uuid) async {
    if (!Platform.isIOS) {
      return null;
    }

    try {
      final Map<dynamic, dynamic>? details = await _channel.invokeMethod(
        'getWorkoutDetails',
        {'uuid': uuid},
      );

      if (details == null) {
        return null;
      }

      // Convert to Map<String, dynamic>
      return Map<String, dynamic>.from(details);
    } on PlatformException catch (e) {
      print('⚠️ Failed to get workout details: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('⚠️ Unexpected error getting workout details: $e');
      return null;
    }
  }

  /// Convert workout details map to Duration objects
  /// Returns a record with (activeDuration, elapsedTime, pausedDuration)
  /// Returns null if details is null or missing required fields
  ({Duration activeDuration, Duration elapsedTime, Duration pausedDuration})?
      parseWorkoutDetails(Map<String, dynamic>? details) {
    if (details == null) {
      return null;
    }

    try {
      final int activeDurationMs = details['activeDuration'] as int;
      final int elapsedTimeMs = details['elapsedTime'] as int;
      final int pausedDurationMs = details['pausedDuration'] as int;

      return (
        activeDuration: Duration(milliseconds: activeDurationMs),
        elapsedTime: Duration(milliseconds: elapsedTimeMs),
        pausedDuration: Duration(milliseconds: pausedDurationMs),
      );
    } catch (e) {
      print('⚠️ Failed to parse workout details: $e');
      return null;
    }
  }
}
