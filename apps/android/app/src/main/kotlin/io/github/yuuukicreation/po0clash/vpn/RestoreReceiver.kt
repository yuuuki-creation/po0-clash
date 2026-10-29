package io.github.yuuukicreation.po0clash.vpn

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import io.github.yuuukicreation.po0clash.engine

// Android does not restart a killed VPN service, but this non-waking alarm (armed while connected) restarts the app.
class RestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.engine?.restoreConnection()
    }

    companion object {
        private const val INTERVAL = 60_000L

        fun arm(context: Context) {
            context.getSystemService(AlarmManager::class.java).setRepeating(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + INTERVAL,
                INTERVAL,
                pendingIntent(context),
            )
        }

        fun disarm(context: Context) {
            context.getSystemService(AlarmManager::class.java).cancel(pendingIntent(context))
        }

        private fun pendingIntent(context: Context) = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, RestoreReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
