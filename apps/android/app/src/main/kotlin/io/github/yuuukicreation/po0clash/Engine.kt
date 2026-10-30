package io.github.yuuukicreation.po0clash

import android.app.Application
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.github.yuuukicreation.po0clash.core.Change
import io.github.yuuukicreation.po0clash.core.CoreListener
import io.github.yuuukicreation.po0clash.core.CoreOptions
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.ExitIp
import io.github.yuuukicreation.po0clash.core.Platform
import io.github.yuuukicreation.po0clash.core.Po0Core
import io.github.yuuukicreation.po0clash.core.ProxyGroup
import io.github.yuuukicreation.po0clash.vpn.Po0VpnService
import io.github.yuuukicreation.po0clash.vpn.VpnTileService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

class Engine(private val app: Application) {
    val core = Po0Core(
        CoreOptions(
            dataDir = File(app.filesDir, "core").path,
            platform = Platform.ANDROID,
            mihomoPath = null,
            legacyPrefs = File(app.dataDir, "shared_prefs/FlutterSharedPreferences.xml").takeIf(File::isFile)?.path,
            legacyDatabase = File(app.filesDir, "database.sqlite").takeIf(File::isFile)?.path,
            appVersion = BuildConfig.VERSION_NAME,
        ),
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val serial = Dispatchers.IO.limitedParallelism(1)
    private var exitJob: Job? = null
    private var networkJob: Job? = null
    private val physical = mutableSetOf<Network>()
    private var reportedNetworks: Set<Network>? = null

    private val _status = MutableStateFlow(core.status())
    val status = _status.asStateFlow()
    private val _profiles = MutableStateFlow(core.profiles())
    val profiles = _profiles.asStateFlow()
    private val _groups = MutableStateFlow(emptyList<ProxyGroup>())
    val groups = _groups.asStateFlow()
    private val _whitelist = MutableStateFlow(core.whitelist())
    val whitelist = _whitelist.asStateFlow()
    private val _exitIp = MutableStateFlow<ExitIp?>(null)
    val exitIp = _exitIp.asStateFlow()
    private val _connectedAt = MutableStateFlow<Long?>(null)

    /** [SystemClock.elapsedRealtime] when the engine last reached Running, or null while it is not running. */
    val connectedAt = _connectedAt.asStateFlow()

    val vpnActive = MutableStateFlow(false)
    val vpnError = MutableStateFlow<String?>(null)
    val settings = AndroidSettingsStore(app)
    private val _ssid = MutableStateFlow<String?>(null)

    /** The Wi-Fi the device is on, when location permission lets us read its name. */
    val ssid = _ssid.asStateFlow()
    private var wifi: Network? = null
    private var pausedOnWifi = false

    /** Reads [read] once a second while collected; the engine's monitor refreshes at that pace while the screen is on. */
    fun <T> poll(read: Po0Core.() -> T): Flow<T> = flow {
        while (true) {
            emit(core.read())
            delay(1000)
        }
    }.flowOn(Dispatchers.IO)

    init {
        core.setListener(object : CoreListener {
            override fun onChange(change: Change) {
                scope.launch(serial) { refresh(change) }
            }
        })
        scheduleExitIp(0)
        watchNetwork()
        watchWifi()
        watchScreen()
        restoreConnection()
    }

    fun restoreConnection() {
        if (vpnActive.value || !core.wasConnected() || VpnService.prepare(app) != null) return
        runCatching { Po0VpnService.start(app) }
    }

    fun refresh(change: Change) {
        when (change) {
            Change.STATUS -> {
                val old = _status.value
                val new = core.status()
                _status.value = new
                if (new.engine != EngineState.Running) {
                    _connectedAt.value = null
                } else if (_connectedAt.value == null) {
                    _connectedAt.value = SystemClock.elapsedRealtime()
                }
                if (old.engine != new.engine || old.currentNode != new.currentNode || old.mode != new.mode) {
                    scheduleExitIp()
                    updateTile()
                }
            }
            Change.PROFILES -> _profiles.value = core.profiles()
            Change.GROUPS -> _groups.value = if (core.status().engine == EngineState.Running) {
                runCatching { core.groups() }.getOrDefault(emptyList())
            } else {
                emptyList()
            }
            Change.WHITELIST -> _whitelist.value = core.whitelist()
        }
    }

    fun replaceGroup(group: ProxyGroup) {
        _groups.update { groups -> groups.map { if (it.name == group.name) group else it } }
    }

    fun updateTile() {
        runCatching { TileService.requestListeningState(app, ComponentName(app, VpnTileService::class.java)) }
    }

    fun refreshExitIp() = scheduleExitIp(0)

    fun setNodeDelay(node: String, delay: UInt) {
        _groups.update { groups ->
            groups.map { group -> group.copy(nodes = group.nodes.map { if (it.name == node) it.copy(delay = delay) else it }) }
        }
    }

    private fun scheduleExitIp(delayMillis: Long = 1000) {
        exitJob?.cancel()
        exitJob = scope.launch {
            delay(delayMillis)
            val ip = runCatching { core.exitIp() }.getOrNull()
            ensureActive()
            _exitIp.value = ip
        }
    }

    // The app's default-network callback follows our own VPN, so watch the set of physical networks instead.
    private fun watchNetwork() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        app.getSystemService(ConnectivityManager::class.java).registerNetworkCallback(
            request,
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = physicalChanged { add(network) }

                override fun onLost(network: Network) = physicalChanged { remove(network) }
            },
        )
    }

    // Since API 31 a callback sees the SSID only when it asks for location info; before that WifiManager still has it.
    private inner class WifiCallback : ConnectivityManager.NetworkCallback {
        constructor() : super()

        @RequiresApi(31)
        constructor(flags: Int) : super(flags)

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            wifi = network
            val info = if (Build.VERSION.SDK_INT >= 31) caps.transportInfo as? WifiInfo else null
            wifiChanged(info?.ssid ?: legacySsid())
        }

        override fun onLost(network: Network) {
            if (wifi == network) wifiChanged(null)
        }
    }

    private fun watchWifi() {
        val request = NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build()
        val callback = if (Build.VERSION.SDK_INT >= 31) {
            WifiCallback(ConnectivityManager.NetworkCallback.FLAG_INCLUDE_LOCATION_INFO)
        } else {
            WifiCallback()
        }
        app.getSystemService(ConnectivityManager::class.java).registerNetworkCallback(request, callback)
        scope.launch {
            combine(_ssid, settings.state) { ssid, settings -> ssid != null && ssid in settings.excludedSsids }
                .distinctUntilChanged()
                .collect(::onExcludedWifi)
        }
    }

    fun refreshSsid() {
        if (wifi != null && Build.VERSION.SDK_INT < 31) wifiChanged(legacySsid())
    }

    @Suppress("DEPRECATION")
    private fun legacySsid(): String? = app.getSystemService(WifiManager::class.java)?.connectionInfo?.ssid

    private fun wifiChanged(raw: String?) {
        _ssid.value = raw?.removeSurrounding("\"")?.takeUnless { it.isBlank() || it == WifiManager.UNKNOWN_SSID }
    }

    private fun onExcludedWifi(excluded: Boolean) {
        if (excluded && vpnActive.value) {
            pausedOnWifi = true
            Po0VpnService.stop(app)
        } else if (!excluded && pausedOnWifi) {
            pausedOnWifi = false
            if (VpnService.prepare(app) == null) runCatching { Po0VpnService.start(app) }
        }
    }

    private fun physicalChanged(edit: MutableSet<Network>.() -> Unit) {
        val current = synchronized(physical) { physical.edit(); physical.toSet() }
        networkJob?.cancel()
        networkJob = scope.launch(serial) {
            delay(1000)
            val previous = reportedNetworks
            reportedNetworks = current
            if (previous != null && previous != current) networkChanged()
        }
    }

    private fun networkChanged() {
        scope.launch { core.networkChanged() }
        scheduleExitIp()
    }

    private fun watchScreen() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val on = intent.action == Intent.ACTION_SCREEN_ON
                scope.launch { core.setActive(on) }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        ContextCompat.registerReceiver(app, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        val interactive = app.getSystemService(PowerManager::class.java).isInteractive
        scope.launch { core.setActive(interactive) }
    }
}

fun Throwable.userMessage(): String = message?.takeIf(String::isNotBlank) ?: toString()
