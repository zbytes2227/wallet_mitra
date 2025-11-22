import 'package:flutter/services.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const platform = MethodChannel(
    'com.example.wallet_mitra/notifications',
  );

  static DateTime? _lastReminderTime; // Track last reminder

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // Show notification when SMS received
  Future<void> showTransactionNotification(String title, String body) async {
    try {
      await platform.invokeMethod('showNotification', {
        'title': title,
        'message': body,
      });
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  // Schedule daily reminder - ONLY ONCE AT 9 PM
  Future<void> scheduleDailyReminder(double totalAmount) async {
    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, 21, 0); // 9 PM

    // ✅ Check if reminder already sent today
    if (_lastReminderTime != null &&
        _lastReminderTime!.year == now.year &&
        _lastReminderTime!.month == now.month &&
        _lastReminderTime!.day == now.day) {
      print('⏭️ Reminder already sent today, skipping');
      return; // Already sent today
    }

    // ✅ If current time is before 9 PM, schedule for later
    if (now.isBefore(reminderTime)) {
      final duration = reminderTime.difference(now);
      print(
        '⏰ Reminder scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m',
      );

      Timer(duration, () {
        _sendReminder(totalAmount);
      });
      return;
    }

    // ✅ If current time is after 9 PM, schedule for tomorrow 9 PM
    final tomorrowReminder = reminderTime.add(Duration(days: 1));
    final duration = tomorrowReminder.difference(now);
    print('🌙 Reminder scheduled for tomorrow in ${duration.inHours}h');

    Timer(duration, () {
      _sendReminder(totalAmount);
    });
  }

  // Send the actual reminder
  Future<void> _sendReminder(double totalAmount) async {
    try {
      _lastReminderTime = DateTime.now();
      print('🔔 Sending reminder at ${DateTime.now()}');

      await platform.invokeMethod('scheduleReminder', {'amount': totalAmount});
    } catch (e) {
      print('Error sending reminder: $e');
    }
  }

  Future<void> initialize() async {
    try {
      await platform.invokeMethod('initializeNotifications');
    } catch (e) {
      print('Error initializing: $e');
    }
  }
}
