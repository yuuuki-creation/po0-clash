// Layout and styling follow FlClash v0.8.92 (https://github.com/chen08209/FlClash, GPL-3.0), lib/views/tools.dart.
package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.Ballot
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material.icons.filled.DeveloperBoard
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Style
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.accessMode
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.ThemeMode
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.flowOf

enum class Tool(@param:StringRes val label: Int, val icon: ImageVector) {
    ACTIVITY(R.string.activity, Icons.Filled.Ballot),
    BASIC(R.string.basic_config, Icons.Filled.Edit),
    NETWORK(R.string.network, Icons.Filled.VpnKey),
    DNS(R.string.dns, Icons.Filled.Dns),
    ADVANCED(R.string.advanced, Icons.Filled.Build),
    ON_DEMAND(R.string.on_demand, Icons.Filled.Wifi),
    APPEARANCE(R.string.appearance, Icons.Filled.Style),
    LANGUAGE(R.string.language, Icons.Filled.Language),
    APPLICATION(R.string.application, Icons.Filled.Settings),
    ACCESS(R.string.access_control, Icons.AutoMirrored.Filled.ViewList),
    RESOURCES(R.string.resources, Icons.Filled.Storage),
    BACKUP(R.string.backup, Icons.Filled.CloudSync),
    DEVELOPER(R.string.developer, Icons.Filled.DeveloperBoard),
    ABOUT(R.string.about, Icons.Filled.Info),
}

private val settingTools = listOf(Tool.LANGUAGE, Tool.APPEARANCE, Tool.APPLICATION, Tool.ACCESS)
private val engineTools = listOf(Tool.BASIC, Tool.NETWORK, Tool.DNS, Tool.ADVANCED, Tool.ON_DEMAND, Tool.RESOURCES)

@Composable
fun ToolsScreen(vm: AppViewModel) {
    var open by rememberSaveable { mutableStateOf<Tool?>(null) }
    val animate = vm.appSettings.collectAsStateWithLifecycle().value.pageAnimation
    PushHost(open, animate, onBack = { open = null }, label = "tools") { tool ->
        val back = { open = null }
        when (tool) {
            null -> ToolList(vm, onOpen = { open = it })
            Tool.ACTIVITY -> ActivityScreen(vm, back)
            Tool.BASIC -> BasicOptionsScreen(vm, back)
            Tool.NETWORK -> NetworkOptionsScreen(vm, back)
            Tool.DNS -> DnsOptionsScreen(vm, back)
            Tool.ADVANCED -> AdvancedOptionsScreen(vm, back)
            Tool.ON_DEMAND -> OnDemandScreen(vm, back)
            Tool.APPLICATION -> ApplicationScreen(vm, back)
            Tool.APPEARANCE -> AppearanceScreen(vm, back)
            Tool.LANGUAGE -> LanguageScreen(vm, back)
            Tool.BACKUP -> BackupScreen(vm, back)
            Tool.ACCESS -> AccessControlScreen(vm, back)
            Tool.RESOURCES -> ResourcesScreen(vm, back)
            Tool.ABOUT -> AboutScreen(vm, back)
            Tool.DEVELOPER -> DeveloperScreen(vm, back)
        }
    }
}

@Composable
private fun ToolList(vm: AppViewModel, onOpen: (Tool) -> Unit) {
    val engine = vm.engine
    val busy by vm.busy.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val options by vm.options.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val connections by remember(running) {
        if (running) engine.poll { connections().items.size } else flowOf(null)
    }.collectAsStateWithLifecycle(null)
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        uri?.let(vm::exportDiagnostics)
    }
    val values = mapOf(
        Tool.ACTIVITY to connections?.let { pluralStringResource(R.plurals.connection_count, it, it) },
        Tool.DNS to stringResource(if (options.overrideDns) R.string.dns_override else R.string.dns_from_profile),
        Tool.ON_DEMAND to settings.excludedSsids.size.takeIf { it > 0 }?.let { pluralStringResource(R.plurals.wifi_count, it, it) },
        Tool.APPEARANCE to stringResource(
            when (settings.themeMode) {
                ThemeMode.LIGHT -> R.string.theme_light
                ThemeMode.DARK -> R.string.theme_dark
                ThemeMode.SYSTEM -> R.string.follow_system
            },
        ),
        Tool.LANGUAGE to (languageLabel(settings.language) ?: stringResource(R.string.follow_system)),
        Tool.ACCESS to stringResource(settings.accessControl.accessMode.label),
    )
    val tools = @Composable { list: List<Tool> ->
        list.forEach { tool -> NavRow(stringResource(tool.label), values[tool], icon = tool.icon) { onOpen(tool) } }
    }
    val settingSection = @Composable {
        Column {
            SectionHeader(stringResource(R.string.settings_section), top = 8.dp)
            tools(settingTools)
        }
    }
    val engineSection = @Composable {
        Column {
            SectionHeader(stringResource(R.string.network_and_engine))
            tools(engineTools)
        }
    }
    val otherSection = @Composable {
        Column {
            SectionHeader(stringResource(R.string.other))
            tools(listOfNotNull(Tool.ACTIVITY, Tool.BACKUP, Tool.DEVELOPER.takeIf { settings.developerMode }, Tool.ABOUT))
            NavRow(
                stringResource(R.string.export_diagnostics),
                icon = Icons.Filled.BugReport,
                busy = AppViewModel.BUSY_DIAGNOSTICS in busy,
            ) {
                val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                export.launch("po0-clash-diagnostics-$stamp.txt")
            }
        }
    }
    val scroll = rememberScrollState()
    PageScaffold(stringResource(R.string.tools), scroll.canScrollBackward) { padding ->
        if (LocalWindowWidth.current.isExpanded) {
            Row(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding), horizontalArrangement = Arrangement.spacedBy(48.dp)) {
                Column(Modifier.weight(1f)) {
                    settingSection()
                    otherSection()
                }
                Column(Modifier.weight(1f)) { engineSection() }
            }
        } else {
            Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding)) {
                settingSection()
                engineSection()
                otherSection()
            }
        }
    }
}

/** A pushed tools page: back arrow, title, then the caller's segmented rows. */
@Composable
fun ToolPage(
    title: String,
    onBack: () -> Unit,
    actions: List<PageAction> = emptyList(),
    capped: Boolean = true,
    content: LazyListScope.() -> Unit,
) {
    val list = rememberLazyListState()
    PageScaffold(title, list, actions = actions, onBack = onBack, capped = capped) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
            content = content,
        )
    }
}
