package io.github.yuuukicreation.po0clash.vpn

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import io.github.yuuukicreation.po0clash.MainActivity
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.engine

class VpnTileService : TileService() {
    override fun onStartListening() {
        update()
    }

    override fun onClick() {
        val engine = engine ?: return
        when {
            engine.vpnActive.value -> Po0VpnService.stop(this)
            VpnService.prepare(this) != null -> openApp()
            else -> Po0VpnService.start(this)
        }
        update()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(MainActivity.ACTION_CONNECT)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun update() {
        val tile = qsTile ?: return
        val engine = engine
        val status = engine?.status?.value
        tile.state = if (engine?.vpnActive?.value == true) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = status?.currentNode?.takeIf { status.engine == EngineState.Running }
        }
        tile.updateTile()
    }
}
