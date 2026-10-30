package io.github.yuuukicreation.po0clash

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.github.yuuukicreation.po0clash.vpn.Po0VpnService

/** Invisible, so an automation app's START counts as a foreground start; without VPN permission the app asks for it. */
class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val engine = engine
        val action = intent?.action.orEmpty().substringAfterLast('.')
        val start = when (action) {
            START -> true
            STOP -> false
            TOGGLE -> engine?.vpnActive?.value != true
            else -> null
        }
        when {
            start == false -> Po0VpnService.stop(this)
            start == true && VpnService.prepare(this) == null -> Po0VpnService.start(this)
            start == true -> startActivity(
                Intent(this, MainActivity::class.java).setAction(MainActivity.ACTION_CONNECT).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
        finish()
    }

    companion object {
        private const val START = "START"
        private const val STOP = "STOP"
        private const val TOGGLE = "TOGGLE"

        fun actions(packageName: String) = listOf(START, STOP, TOGGLE).map { "$packageName.action.$it" }
    }
}
