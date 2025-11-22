package com.example.wallet_mitra

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.example.wallet_mitra/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeNotifications" -> {
                        initializeNotificationChannel()
                        result.success(null)
                    }
                    "showNotification" -> {
                        val title = call.argument<String>("title") ?: "Wallet Mitra"
                        val message = call.argument<String>("message") ?: ""
                        showNotification(title, message)
                        result.success(null)
                    }
                    "scheduleReminder" -> {
                        val amount = call.argument<Double>("amount") ?: 0.0
                        showReminderNotification(amount)
                        result.success(null)
                    }
                    "testSms" -> {
                        // For testing - simulates receiving SMS
                        testSmsReceived()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "wallet_mitra_channel",
                "Wallet Mitra",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Transaction notifications"
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(title: String, message: String) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "wallet_mitra_channel")
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun showReminderNotification(amount: Double) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "wallet_mitra_channel")
            .setContentTitle("🎯 Wallet Mitra Reminder")
            .setContentText("✨ Subah se ₹${String.format("%.2f", amount)} kiye ho, uske labels to krdo! 💰")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(999, notification)
    }
    
    // TEST METHOD - Simulate SMS received
    private fun testSmsReceived() {
        Log.i("TEST", "Simulating SMS for testing...")
        val intent = Intent("android.provider.Telephony.SMS_RECEIVED").apply {
            val pdus = arrayOf(byteArrayOf())
            putExtra("pdus", pdus)
            putExtra("format", "3gpp")
        }
        
        val smsReceiver = SmsReceiver()
        smsReceiver.onReceive(this, intent)
    }
}
