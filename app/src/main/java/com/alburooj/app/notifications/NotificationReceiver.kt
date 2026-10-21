package com.alburooj.app.notifications

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.alburooj.app.MainActivity
import android.app.PendingIntent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Shows the notification, then re-arms the next occurrence (no repeating alarms on Android). */
class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val channel = intent.getStringExtra(EXTRA_CHANNEL) ?: return
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(intent.getStringExtra(EXTRA_TITLE))
            .setSubText(intent.getStringExtra(EXTRA_SUBTITLE)?.takeIf { it.isNotEmpty() })
            .setContentText(intent.getStringExtra(EXTRA_BODY))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(intent.getIntExtra(EXTRA_ID, 0), notification)

        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try { NotificationScheduler(context).syncNotifications() } finally { pending.finish() }
        }
    }

    companion object {
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_BODY = "body"
        const val EXTRA_CHANNEL = "channel"
    }
}

/** Alarms are cleared on reboot or when exact-alarm access changes; rebuild them. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try { NotificationScheduler(context).syncNotifications() } finally { pending.finish() }
        }
    }
}
