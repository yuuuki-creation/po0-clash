package io.github.yuuukicreation.po0clash.ui

import android.app.Application
import android.net.Uri
import android.provider.OpenableColumns
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import io.github.yuuukicreation.po0clash.AndroidSettings
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Change
import io.github.yuuukicreation.po0clash.core.EngineOptions
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.ProfileEdit
import io.github.yuuukicreation.po0clash.core.ProviderKind
import io.github.yuuukicreation.po0clash.engine
import io.github.yuuukicreation.po0clash.userMessage
import io.github.yuuukicreation.po0clash.vpn.Po0VpnService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.updateAndGet
import kotlinx.coroutines.launch
import java.io.File

class AppViewModel(private val app: Application) : AndroidViewModel(app) {
    val engine = checkNotNull(app.engine)
    private val core = engine.core

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()
    private val _busy = MutableStateFlow(emptySet<String>())
    val busy = _busy.asStateFlow()
    private val _options = MutableStateFlow(core.engineOptions())
    val options = _options.asStateFlow()
    val androidSettings = engine.settings.state
    private val optionWriter = Dispatchers.IO.limitedParallelism(1)

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

    fun testNodeDelay(node: String) = launch(busyNodeDelay(node)) {
        engine.setNodeDelay(node, core.testNodeDelay(node))
        null
    }

    /** Applies at once on screen; the core gets only the latest options when several changes queue up. */
    fun setOptions(change: (EngineOptions) -> EngineOptions) {
        val next = _options.updateAndGet(change)
        viewModelScope.launch(optionWriter) {
            if (_options.value != next) return@launch
            try {
                core.setEngineOptions(next)
            } catch (e: Exception) {
                _options.value = core.engineOptions()
                _messages.send(e.userMessage())
            }
        }
    }

    fun updateAndroid(change: (AndroidSettings) -> AndroidSettings) = engine.settings.update(change)

    fun toast(message: String) {
        _messages.trySend(message)
    }

    fun exportText(uri: Uri, text: String) = launch("export-text") {
        checkNotNull(app.contentResolver.openOutputStream(uri)).use { it.write(text.encodeToByteArray()) }
        app.getString(R.string.export_done_short)
    }

    fun updateGeo() = launch(BUSY_GEO) {
        core.updateGeo()
        app.getString(R.string.geo_updated)
    }

    fun updateProvider(kind: ProviderKind, name: String) = launch(busyProvider(name)) {
        core.updateProvider(kind, name)
        null
    }

    fun closeConnection(id: String) = launch("connection:$id") {
        core.closeConnection(id)
        null
    }

    fun closeAllConnections() = launch(BUSY_CONNECTIONS) {
        core.closeAllConnections()
        null
    }

    fun clearRequests() = launch("clear-requests") {
        core.clearRequests()
        null
    }

    fun clearLogs() = launch("clear-logs") {
        core.clearLogs()
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

    fun importFile(uri: Uri) = launch(BUSY_PROFILES) {
        val resolver = app.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
            .orEmpty()
        val content = checkNotNull(resolver.openInputStream(uri)).use { it.readBytes().decodeToString() }
        val profile = core.importFile(name, content)
        refresh(Change.PROFILES, Change.STATUS, Change.GROUPS)
        app.getString(R.string.imported_file, profile.name)
    }

    fun editProfile(id: String, edit: ProfileEdit) = launch(busyProfile(id)) {
        core.editProfile(id, edit)
        refresh(Change.PROFILES)
        null
    }

    fun exportProfile(id: String, uri: Uri) = launch(busyProfile(id)) {
        val content = core.profileContent(id)
        checkNotNull(app.contentResolver.openOutputStream(uri)).use { it.write(content.encodeToByteArray()) }
        app.getString(R.string.profile_exported)
    }

    fun moveProfile(id: String, by: Int) = launch(BUSY_PROFILES) {
        val ids = engine.profiles.value.map { it.id }.toMutableList()
        val from = ids.indexOf(id)
        val to = from + by
        if (from >= 0 && to in ids.indices) {
            ids.add(to, ids.removeAt(from))
            core.reorderProfiles(ids)
            refresh(Change.PROFILES)
        }
        null
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
        const val BUSY_CONNECTIONS = "connections"
        const val BUSY_GEO = "geo"
        fun busyProvider(name: String) = "provider:$name"
        fun busyDelay(group: String) = "delay:$group"
        fun busyNodeDelay(node: String) = "node-delay:$node"
        fun busyProfile(id: String) = "profile:$id"
    }
}
