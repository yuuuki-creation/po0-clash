package io.github.yuuukicreation.po0clash.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.IpPrefix
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.Os
import android.text.format.Formatter
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.github.yuuukicreation.po0clash.AccessMode
import io.github.yuuukicreation.po0clash.Engine
import io.github.yuuukicreation.po0clash.accessMode
import io.github.yuuukicreation.po0clash.MainActivity
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.Status
import io.github.yuuukicreation.po0clash.core.Traffic
import io.github.yuuukicreation.po0clash.engine
import io.github.yuuukicreation.po0clash.selected
import io.github.yuuukicreation.po0clash.userMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetAddress

class Po0VpnService : VpnService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val worker = Dispatchers.IO.limitedParallelism(1)
    private var tunFd = -1

    @Volatile
    private var latestStart = 0

    @Volatile
    private var foreground = false

    override fun onCreate() {
        super.onCreate()
        val engine = engine ?: return
        scope.launch {
            combine(engine.status, engine.appSettings, engine.screenOn) { status, _, on -> status to on }.collectLatest { (status, on) ->
                if (status.engine != EngineState.Running || !on) {
                    if (foreground) notificationManager().notify(NOTIFICATION_ID, notification(status))
                    return@collectLatest
                }
                while (true) {
                    val speed = withContext(Dispatchers.IO) { engine.core.traffic() }
                    if (foreground) notificationManager().notify(NOTIFICATION_ID, notification(status, speed))
                    delay(1000)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val reconcile = intent?.action == ACTION_RECONCILE
        if (!reconcile) latestStart = startId
        val generation = latestStart
        val engine = engine
        val restart = intent == null
        if (engine == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP || (restart && !engine.core.wasConnected())) {
            Log.i(TAG, "stop requested ($startId)")
            engine.vpnActive.value = false
            if (!restart) RestoreReceiver.disarm(this)
            scope.launch(worker) {
                if (startId == latestStart) {
                    disconnect(engine)
                    stopSelf()
                }
            }
            return START_NOT_STICKY
        }
        val fromApp = intent?.getBooleanExtra(EXTRA_FROM_APP, false) == true
        Log.i(TAG, "connect requested ($startId, action=${intent?.action}, fromApp=$fromApp)")
        if (!reconcile) engine.vpnActive.value = true
        engine.vpnError.value = null
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification(engine.status.value),
                if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0,
            )
            foreground = true
        } catch (e: IllegalStateException) {
            fail(engine, generation, e.userMessage(), fromApp)
            return START_NOT_STICKY
        }
        if (reconcile && !engine.vpnActive.value) {
            scope.launch(worker) { if (!engine.vpnActive.value) stopSelf() }
            return START_NOT_STICKY
        }
        scope.launch(worker) {
            if (generation != latestStart) return@launch
            try {
                if (!reconcile && !restart) engine.core.requestConnection()
                if (!engine.core.wasConnected()) return@launch
                RestoreReceiver.arm(this@Po0VpnService)
                connect(engine, generation, fromApp)
            } catch (e: Exception) {
                fail(engine, generation, e.userMessage(), fromApp)
            }
        }
        return START_STICKY
    }

    private fun connect(engine: Engine, startId: Int, fromApp: Boolean) {
        synchronized(engine.vpnOptionsLock) { connectLocked(engine, startId, fromApp) }
    }

    private fun connectLocked(engine: Engine, startId: Int, fromApp: Boolean) {
        if (startId != latestStart) return
        when (vpnAction(engine.vpnActive.value, engine.onExcludedWifi, tunFd >= 0)) {
            VpnAction.NONE -> return
            VpnAction.PAUSE -> {
                pause(engine)
                notificationManager().notify(NOTIFICATION_ID, notification(engine.status.value))
                return
            }
            VpnAction.START -> Unit
        }
        pause(engine)
        val pfd = try {
            builder().establish()
        } catch (e: Exception) {
            if (startId == latestStart) disconnect(engine)
            return fail(engine, startId, e.userMessage(), fromApp)
        } ?: run {
            if (startId == latestStart) disconnect(engine)
            return fail(engine, startId, getString(R.string.error_vpn_permission), fromApp)
        }
        val fd = pfd.detachFd()
        try {
            engine.core.start(fd)
            tunFd = fd
            Log.i(TAG, "connected ($startId, fd $fd)")
            notificationManager().cancel(FAILURE_ID)
            RestoreReceiver.arm(this)
        } catch (e: Exception) {
            releaseTun(fd)
            if (startId == latestStart) disconnect(engine)
            fail(engine, startId, e.userMessage(), fromApp)
        }
    }

    private fun disconnect(engine: Engine) {
        engine.core.stop()
        releaseTun()
        engine.updateTile()
    }

    private fun pause(engine: Engine) {
        engine.core.pause()
        releaseTun()
        engine.updateTile()
    }

    private fun releaseTun() {
        if (tunFd >= 0) releaseTun(tunFd)
        tunFd = -1
    }

    // Starts without the app on screen (always-on VPN, the tile, a restart) report their failure as a notification.
    private fun fail(engine: Engine, startId: Int, message: String, fromApp: Boolean) {
        Log.w(TAG, "connect failed ($startId): $message")
        if (startId != latestStart) return
        engine.vpnError.value = message
        engine.vpnActive.value = false
        RestoreReceiver.disarm(this)
        engine.updateTile()
        foreground = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        if (!fromApp) notificationManager().notify(FAILURE_ID, failureNotification(message))
        stopSelf()
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
        val settings = checkNotNull(engine).appSettings.value.androidVpn
        if (settings.ipv6) addAddress(VpnRoutes.ADDRESS6, VpnRoutes.PREFIX6)
        addDnsServer(VpnRoutes.DNS)
        if (Build.VERSION.SDK_INT >= 33) {
            addRoute("0.0.0.0", 0)
            excludeRoute(IpPrefix(InetAddress.getByName(VpnRoutes.PO0_API), 32))
        } else {
            VpnRoutes.ipv4Excluding(VpnRoutes.PO0_API).forEach { addRoute(it.address, it.prefix) }
        }
        if (settings.ipv6) addRoute("::", 0)
        val access = engine?.appSettings?.value?.accessControl
        val mode = access?.accessMode ?: AccessMode.OFF
        val others = access?.selected.orEmpty() - packageName
        if (mode == AccessMode.ALLOW) {
            val added = addAvailableApplications(others) { name ->
                try {
                    addAllowedApplication(name)
                    true
                } catch (_: PackageManager.NameNotFoundException) {
                    false
                }
            }
            check(added) { getString(R.string.error_no_allowed_apps) }
        } else {
            addDisallowedApplication(packageName)
            if (mode == AccessMode.DENY) others.forEach { runCatching { addDisallowedApplication(it) } }
        }
        if (settings.allowBypass) allowBypass()
        if (settings.systemProxy && Build.VERSION.SDK_INT >= 29) {
            engine?.let { setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", it.core.mixedProxyPort().toInt())) }
        }
        if (Build.VERSION.SDK_INT >= 29) setMetered(false)
        setConfigureIntent(openAppIntent())
    }

    override fun onRevoke() {
        Log.i(TAG, "revoked")
        latestStart = -1
        engine?.vpnActive?.value = false
        RestoreReceiver.disarm(this)
        scope.launch(worker) {
            if (latestStart == -1) {
                engine?.let(::disconnect)
                stopSelf()
            }
        }
    }

    override fun onDestroy() {
        foreground = false
        scope.cancel()
        notificationManager().cancel(NOTIFICATION_ID)
        super.onDestroy()
    }

    private fun notificationManager(): NotificationManager {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannels(
            listOf(
                NotificationChannel(CHANNEL_ID, getString(R.string.notification_channel), NotificationManager.IMPORTANCE_LOW),
                NotificationChannel(
                    ALERT_CHANNEL_ID,
                    getString(R.string.notification_channel_alerts),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            ),
        )
        return manager
    }

    /** FlClash's ongoing notification; [speed] adds the current rates while the screen is on. */
    private fun notification(status: Status, speed: Traffic? = null): Notification {
        notificationManager()
        val text = if (engine?.onExcludedWifi == true && engine?.vpnActive?.value == true) {
            getString(R.string.vpn_paused_wifi)
        } else when (val state = status.engine) {
            EngineState.Running -> listOfNotNull(
                status.currentNode?.let { getString(R.string.notification_running, it) } ?: getString(R.string.state_running),
                speed?.let { "↑ ${rate(it.up)} ↓ ${rate(it.down)}" },
            ).joinToString(" · ")
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
            .apply { if (engine?.appSettings?.value?.notificationStopButton != false) addAction(0, getString(R.string.disconnect), stop) }
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun rate(bytes: ULong) = Formatter.formatShortFileSize(this, bytes.toLong()) + "/s"

    private fun failureNotification(message: String): Notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_po0)
        .setContentTitle(getString(R.string.notification_failed))
        .setContentText(message)
        .setStyle(NotificationCompat.BigTextStyle().bigText(message))
        .setContentIntent(openAppIntent())
        .setAutoCancel(true)
        .build()

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        private const val TAG = "po0-vpn"
        private const val ACTION_STOP = "io.github.yuuukicreation.po0clash.STOP"
        private const val ACTION_RECONCILE = "io.github.yuuukicreation.po0clash.RECONCILE"
        private const val CHANNEL_ID = "vpn"
        private const val ALERT_CHANNEL_ID = "alerts"
        private const val NOTIFICATION_ID = 1
        private const val FAILURE_ID = 2
        private const val EXTRA_FROM_APP = "from_app"

        fun start(context: Context, fromApp: Boolean = false) {
            val intent = Intent(context, Po0VpnService::class.java).putExtra(EXTRA_FROM_APP, fromApp)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            runCatching {
                context.startService(Intent(context, Po0VpnService::class.java).setAction(ACTION_STOP))
            }
        }

        fun reconcile(context: Context) {
            runCatching {
                ContextCompat.startForegroundService(context, Intent(context, Po0VpnService::class.java).setAction(ACTION_RECONCILE))
            }
        }
    }
}
