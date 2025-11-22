package com.example.wallet_mitra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.os.Build
import android.widget.Toast
import android.util.Log
import org.json.JSONObject
import java.io.File

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SMS_RX"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "🔥 SMS Received!")
        
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return
        
        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as Array<*>? ?: return
        
        Log.i(TAG, "✅ Got ${pdus.size} SMS")
        Toast.makeText(context, "📨 ${pdus.size} SMS", Toast.LENGTH_LONG).show()
        
    
        for (pdu in pdus) {
            try {
                val message = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    SmsMessage.createFromPdu(pdu as ByteArray, bundle.getString("format"))
                } else {
                    @Suppress("DEPRECATION")
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }
                
                val smsBody = message.messageBody ?: continue
                Log.i(TAG, "📱 Body: $smsBody")
                
                val amount = extractAmount(smsBody) ?: continue
                if (amount <= 0) continue
                
                Log.i(TAG, "💰 Amount: ₹$amount")
                
                val json = JSONObject().apply {
                    put("id", System.currentTimeMillis().toString())
                    put("amount", amount)
                    put("type", if (smsBody.contains("credit", ignoreCase = true)) "credit" else "debit")
                    put("name", JSONObject.NULL)
                    put("dateTime", message.timestampMillis)
                    put("smsBody", smsBody)
                }
                
                // ✅ WRITE TO FILE in app's private directory
                val appDir = context.getDir("wallet_data", Context.MODE_PRIVATE)
                val smsFile = File(appDir, "sms_transactions.txt")
                
                val existing = if (smsFile.exists()) smsFile.readText() else ""
                val newContent = if (existing.isEmpty()) {
                    json.toString()
                } else {
                    "${json.toString()}|||${existing}"
                }
                
                smsFile.writeText(newContent)
                
                Log.i(TAG, "✅ Saved to: ${smsFile.absolutePath}")
                Log.i(TAG, "📊 File size: ${newContent.length} chars")
                
                Toast.makeText(context, "✅ ₹$amount saved!", Toast.LENGTH_LONG).show()
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error: ${e.message}", e)
            }
        }
    }
    
    private fun extractAmount(text: String): Double? {
        val patterns = listOf(
            Regex("""(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)""", RegexOption.IGNORE_CASE),
            Regex("""(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupees?|INR|Rs)""", RegexOption.IGNORE_CASE),
        )
        
        for (pattern in patterns) {
            pattern.find(text)?.let {
                val amount = it.groupValues[1].replace(",", "").toDoubleOrNull()
                if (amount != null && amount > 0) return amount
            }
        }
        return null
    }
}
