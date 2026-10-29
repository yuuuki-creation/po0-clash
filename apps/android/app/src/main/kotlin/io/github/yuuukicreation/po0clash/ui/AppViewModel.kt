package io.github.yuuukicreation.po0clash.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Change
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.engine
import io.github.yuuukicreation.po0clash.userMessage
import io.github.yuuukicreation.po0clash.vpn.Po0VpnService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

class AppViewModel(private val app: Application) : AndroidViewModel(app) {
    val engine = checkNotNull(app.engine)
    private val core = engine.core

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()
    private val _busy = MutableStateFlow(emptySet<String>())
    val busy = _busy.asStateFlow()

    private fun launch(key: String, block: () -> String?) {
        if (key in _busy.value) return
        _busy.update { it + key }
        viewModelScope.launch(Dispatchers.IO) {
            try {
                block()?.let { _messages.send(it) }
            } catch (e: Exception) {
                _messages.send(e.userMessage())
            } finally {
                _busy.update { it - key }
            }
        }
    }

    private fun refresh(vararg changes: Change) = changes.forEach(engine::refresh)

    fun disconnect() = Po0VpnService.stop(app)

    fun setMode(mode: Mode) = launch(BUSY_MODE) {
        core.setMode(mode)
        refresh(Change.STATUS, Change.GROUPS)
        null
    }

    fun selectNode(group: String, node: String) = launch("node:$group") {
        core.selectNode(group, node)
        refresh(Change.GROUPS, Change.STATUS)
        null
    }

    fun testDelay(group: String) = launch(busyDelay(group)) {
        engine.replaceGroup(core.testDelay(group))
        null
    }

    fun addSubscription(url: String) = launch(BUSY_PROFILES) {
        core.addSubscription(url.trim())
        refresh(Change.PROFILES)
        null
    }

    fun importLinks(text: String) = launch(BUSY_PROFILES) {
        val result = core.importLinks(text)
        refresh(Change.PROFILES)
        app.resources.getQuantityString(R.plurals.imported_links, result.added.toInt(), result.added.toInt())
    }

    fun updateProfile(id: String) = launch(busyProfile(id)) {
        core.updateProfile(id)
        refresh(Change.PROFILES, Change.GROUPS)
        null
    }

    fun removeProfile(id: String) = launch(busyProfile(id)) {
        core.removeProfile(id)
        refresh(Change.PROFILES, Change.STATUS, Change.GROUPS)
        null
    }

    fun selectProfile(id: String) = launch(BUSY_PROFILES) {
        core.selectProfile(id)
        refresh(Change.PROFILES, Change.STATUS, Change.GROUPS)
        null
    }

    fun setWhitelistEnabled(enabled: Boolean) = launch(BUSY_WHITELIST) {
        core.setWhitelistEnabled(enabled)
        refresh(Change.WHITELIST)
        null
    }

    fun addWhitelist(text: String, name: String) = launch(BUSY_WHITELIST) {
        core.addWhitelistEntries(text, name.trim())
        refresh(Change.WHITELIST)
        null
    }

    fun removeWhitelist(id: String) = launch("whitelist:$id") {
        core.removeWhitelistEntry(id)
        refresh(Change.WHITELIST)
        null
    }

    fun whitelistNow() = launch(BUSY_WHITELIST_NOW) {
        core.whitelistNow()
        refresh(Change.WHITELIST)
        null
    }

    fun exportDiagnostics(uri: Uri) = launch(BUSY_DIAGNOSTICS) {
        val file = File(app.cacheDir, "diagnostics.txt")
        try {
            core.exportDiagnostics(file.path)
            checkNotNull(app.contentResolver.openOutputStream(uri)).use { out -> file.inputStream().use { it.copyTo(out) } }
        } finally {
            file.delete()
        }
        app.getString(R.string.export_done)
    }

    companion object {
        const val BUSY_MODE = "mode"
        const val BUSY_PROFILES = "profiles"
        const val BUSY_WHITELIST = "whitelist"
        const val BUSY_WHITELIST_NOW = "whitelist-now"
        const val BUSY_DIAGNOSTICS = "diagnostics"
        fun busyDelay(group: String) = "delay:$group"
        fun busyProfile(id: String) = "profile:$id"
    }
}
