package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.accessMode
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.ThemeMode
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.flowOf

/** Every FlClash tools entry. */
enum class Tool(@param:StringRes val label: Int, val icon: ImageVector) {
    ACTIVITY(R.string.activity, LineIcons.Activity),
    BASIC(R.string.basic_config, LineIcons.FileText),
    NETWORK(R.string.network, LineIcons.Wifi),
    DNS(R.string.dns, LineIcons.Server),
    ADVANCED(R.string.advanced, LineIcons.Wrench),
    ON_DEMAND(R.string.on_demand, LineIcons.WifiOff),
    APPEARANCE(R.string.appearance, LineIcons.Appearance),
    LANGUAGE(R.string.language, LineIcons.Languages),
    APPLICATION(R.string.application, LineIcons.AppWindow),
    ACCESS(R.string.access_control, LineIcons.Smartphone),
    RESOURCES(R.string.resources, LineIcons.Database),
    BACKUP(R.string.backup, LineIcons.CloudUpload),
    DEVELOPER(R.string.developer, LineIcons.Terminal),
    ABOUT(R.string.about, LineIcons.Info),
}

private val config = listOf(Tool.BASIC, Tool.NETWORK, Tool.DNS, Tool.ADVANCED, Tool.ON_DEMAND)
private val application = listOf(Tool.APPEARANCE, Tool.LANGUAGE, Tool.APPLICATION, Tool.ACCESS, Tool.RESOURCES, Tool.BACKUP)

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
    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.tools), list) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.tools)) }
            item { ToolRow(0, 1, Tool.ACTIVITY, values[Tool.ACTIVITY], onOpen) }
            item {
                SectionHeader(stringResource(R.string.config))
                config.forEachIndexed { index, tool -> ToolRow(index, config.size, tool, values[tool], onOpen) }
            }
            item {
                SectionHeader(stringResource(R.string.application))
                application.forEachIndexed { index, tool -> ToolRow(index, application.size, tool, values[tool], onOpen) }
            }
            item {
                val other = listOfNotNull(Tool.DEVELOPER.takeIf { settings.developerMode }, Tool.ABOUT)
                val count = other.size + 1
                SectionHeader(stringResource(R.string.other))
                other.forEachIndexed { index, tool -> ToolRow(index, count, tool, null, onOpen) }
                NavRow(
                    count - 1,
                    count,
                    LineIcons.Download,
                    stringResource(R.string.export_diagnostics),
                    busy = AppViewModel.BUSY_DIAGNOSTICS in busy,
                    chevron = false,
                ) {
                    val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                    export.launch("po0-clash-diagnostics-$stamp.txt")
                }
                SectionFooter(stringResource(R.string.export_diagnostics_hint))
            }
        }
    }
}

@Composable
private fun ToolRow(index: Int, count: Int, tool: Tool, value: String?, onOpen: (Tool) -> Unit) {
    NavRow(index, count, tool.icon, stringResource(tool.label), value) { onOpen(tool) }
}

/** A pushed tools page: back button, large title, then the caller's grouped rows. */
@Composable
fun ToolPage(
    title: String,
    onBack: () -> Unit,
    actions: List<PageAction> = emptyList(),
    subtitle: String? = null,
    content: androidx.compose.foundation.lazy.LazyListScope.() -> Unit,
) {
    val list = rememberLazyListState()
    PageScaffold(title, list, actions = actions, onBack = onBack) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            item { PageTitle(title, subtitle) }
            content()
        }
    }
}
