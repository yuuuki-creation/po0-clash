package io.github.yuuukicreation.po0clash

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import io.github.yuuukicreation.po0clash.ui.App
import io.github.yuuukicreation.po0clash.ui.Po0Theme
import io.github.yuuukicreation.po0clash.vpn.Po0VpnService

class MainActivity : ComponentActivity() {
    private val vpnPermission = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        if (it.resultCode == RESULT_OK) startVpn()
    }
    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val app = application as Po0App
        setContent {
            Po0Theme {
                if (app.engine != null) {
                    App(onConnect = ::connect)
                } else {
                    StartupError(app.startupError.orEmpty())
                }
            }
        }
        if (savedInstanceState == null) handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        if (intent?.action == ACTION_CONNECT) connect()
    }

    private fun connect() {
        val request = VpnService.prepare(this)
        if (request != null) vpnPermission.launch(request) else startVpn()
    }

    private fun startVpn() {
        Po0VpnService.start(this)
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(permission)
        }
    }

    companion object {
        const val ACTION_CONNECT = "io.github.yuuukicreation.po0clash.CONNECT"
    }
}

@androidx.compose.runtime.Composable
private fun StartupError(message: String) {
    Surface(Modifier.fillMaxSize()) {
        Box(Modifier.padding(24.dp), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.startup_failed, message), style = MaterialTheme.typography.bodyLarge)
        }
    }
}
