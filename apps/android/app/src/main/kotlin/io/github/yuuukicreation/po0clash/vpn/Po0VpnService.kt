package io.github.yuuukicreation.po0clash.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.Os
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.github.yuuukicreation.po0clash.Engine
import io.github.yuuukicreation.po0clash.MainActivity
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.Status
import io.github.yuuukicreation.po0clash.engine
import io.github.yuuukicreation.po0clash.userMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.net.InetAddress

class Po0VpnService : VpnService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val worker = Dispatchers.IO.limitedParallelism(1)
    private var tunFd = -1

    @Volatile
    private var latestStart = 0

    override fun onCreate() {
        super.onCreate()
        val engine = engine ?: return
        scope.launch {
            engine.status.collectLatest { status ->
                if (engine.vpnActive.value) notificationManager().notify(NOTIFICATION_ID, notification(status))
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStart = startId
        val engine = engine
        val restart = intent == null
        if (intent?.action == ACTION_STOP || engine == null || (restart && !engine.core.wasConnected())) {
            Log.i(TAG, "stop requested ($startId)")
            engine?.vpnActive?.value = false
            scope.launch(worker) {
                if (startId == latestStart) engine?.let(::disconnect)
                stopSelf(startId)
            }
            return START_NOT_STICKY
        }
        Log.i(TAG, "connect requested ($startId, restart=$restart)")
        engine.vpnActive.value = true
        engine.vpnError.value = null
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification(engine.status.value),
                if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0,
            )
        } catch (e: IllegalStateException) {
            fail(engine, startId, e.userMessage())
            return START_NOT_STICKY
        }
        scope.launch(worker) { connect(engine, startId) }
        return START_STICKY
    }

    private fun connect(engine: Engine, startId: Int) {
        if (startId != latestStart) return
        if (tunFd >= 0 && engine.core.status().engine == EngineState.Running) return
        disconnect(engine)
        val pfd = try {
            builder().establish()
        } catch (e: Exception) {
            return fail(engine, startId, e.userMessage())
        } ?: return fail(engine, startId, getString(R.string.error_vpn_permission))
        val fd = pfd.detachFd()
        try {
            engine.core.start(fd)
            tunFd = fd
            Log.i(TAG, "connected ($startId, fd $fd)")
        } catch (e: Exception) {
            releaseTun(fd)
            fail(engine, startId, e.userMessage())
        }
    }

    private fun disconnect(engine: Engine) {
        engine.core.stop()
        if (tunFd >= 0) releaseTun(tunFd)
        tunFd = -1
        engine.updateTile()
    }

    private fun fail(engine: Engine, startId: Int, message: String) {
        Log.w(TAG, "connect failed ($startId): $message")
        if (startId != latestStart) return
        engine.vpnError.value = message
        engine.vpnActive.value = false
        engine.updateTile()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
    }

    // mihomo owns the descriptor once it starts and closes it on stop; this closes it only if nobody did.
    private fun releaseTun(fd: Int) {
        val target = runCatching { Os.readlink("/proc/self/fd/$fd") }.getOrNull()
        if (target == "/dev/tun") {
            Log.i(TAG, "closing TUN fd $fd left open by the engine")
            ParcelFileDescriptor.adoptFd(fd).close()
        }
    }

    private fun builder(): Builder = Builder().apply {
        setSession(getString(R.string.app_name))
        setMtu(VpnRoutes.MTU)
        addAddress(VpnRoutes.ADDRESS4, VpnRoutes.PREFIX4)
        addAddress(VpnRoutes.ADDRESS6, VpnRoutes.PREFIX6)
        addDnsServer(VpnRoutes.DNS)
        if (Build.VERSION.SDK_INT >= 33) {
            addRoute("0.0.0.0", 0)
            excludeRoute(IpPrefix(InetAddress.getByName(VpnRoutes.PO0_API), 32))
        } else {
            VpnRoutes.ipv4Excluding(VpnRoutes.PO0_API).forEach { addRoute(it.address, it.prefix) }
        }
        addRoute("::", 0)
        addDisallowedApplication(packageName)
        if (Build.VERSION.SDK_INT >= 29) setMetered(false)
        setConfigureIntent(openAppIntent())
    }

    override fun onRevoke() {
        Log.i(TAG, "revoked")
        engine?.vpnActive?.value = false
        scope.launch(worker) {
            engine?.let(::disconnect)
            stopSelf()
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun notificationManager(): NotificationManager {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, getString(R.string.notification_channel), NotificationManager.IMPORTANCE_LOW),
        )
        return manager
    }

    private fun notification(status: Status): Notification {
        notificationManager()
        val text = when (val state = status.engine) {
            EngineState.Running -> status.currentNode?.let { getString(R.string.notification_running, it) }
                ?: getString(R.string.state_running)
            EngineState.Starting, EngineState.Stopped -> getString(R.string.state_starting)
            is EngineState.Failed -> state.message
        }
        val stop = PendingIntent.getService(
            this, 1, Intent(this, Po0VpnService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_po0)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(openAppIntent())
            .addAction(0, getString(R.string.disconnect), stop)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        private const val TAG = "po0-vpn"
        private const val ACTION_STOP = "io.github.yuuukicreation.po0clash.STOP"
        private const val CHANNEL_ID = "vpn"
        private const val NOTIFICATION_ID = 1

        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, Po0VpnService::class.java))
        }

        fun stop(context: Context) {
            runCatching {
                context.startService(Intent(context, Po0VpnService::class.java).setAction(ACTION_STOP))
            }
        }
    }
}
