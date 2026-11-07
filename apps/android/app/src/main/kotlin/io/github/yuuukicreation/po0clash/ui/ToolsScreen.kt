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
    ACTIVITY(R.string.activity, LineIcons.Activity),
    BASIC(R.string.basic_config, LineIcons.Sliders),
    NETWORK(R.string.network, LineIcons.Wifi),
    DNS(R.string.dns, LineIcons.Server),
    ADVANCED(R.string.advanced, LineIcons.Wrench),
    ON_DEMAND(R.string.on_demand, LineIcons.Wifi),
    APPEARANCE(R.string.appearance, LineIcons.Appearance),
    LANGUAGE(R.string.language, LineIcons.Languages),
    APPLICATION(R.string.application, LineIcons.Smartphone),
    ACCESS(R.string.access_control, LineIcons.ShieldCheck),
    RESOURCES(R.string.resources, LineIcons.Database),
    BACKUP(R.string.backup, LineIcons.CloudUpload),
    DEVELOPER(R.string.developer, LineIcons.Terminal),
    ABOUT(R.string.about, LineIcons.Info),
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
        list.forEachIndexed { index, tool ->
            NavRow(index, list.size, stringResource(tool.label), values[tool], icon = tool.icon) { onOpen(tool) }
        }
    }
    val settingSection = @Composable {
        Column {
            SectionHeader(stringResource(R.string.settings_section), top = 0.dp)
            tools(settingTools)
        }
    }
    val otherSection = @Composable {
        val other = listOfNotNull(Tool.ACTIVITY, Tool.BACKUP, Tool.DEVELOPER.takeIf { settings.developerMode }, Tool.ABOUT)
        Column {
            SectionHeader(stringResource(R.string.other), top = 0.dp)
            other.forEachIndexed { index, tool ->
                NavRow(index, other.size + 1, stringResource(tool.label), values[tool], icon = tool.icon) { onOpen(tool) }
            }
            NavRow(
                other.size,
                other.size + 1,
                stringResource(R.string.export_diagnostics),
                icon = LineIcons.FileText,
                busy = AppViewModel.BUSY_DIAGNOSTICS in busy,
                chevron = false,
            ) {
                val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                export.launch("po0-clash-diagnostics-$stamp.txt")
            }
        }
    }
    val engineSection = @Composable {
        Column {
            SectionHeader(stringResource(R.string.network_and_engine), top = 0.dp)
            tools(engineTools)
        }
    }
    val scroll = rememberScrollState()
    PageScaffold(stringResource(R.string.tools), scroll.canScrollBackward) { padding ->
        val spaced = Arrangement.spacedBy(12.dp)
        if (LocalWindowWidth.current.isExpanded) {
            Row(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding), horizontalArrangement = spaced) {
                Column(Modifier.weight(1f), verticalArrangement = spaced) {
                    settingSection()
                    otherSection()
                }
                Column(Modifier.weight(1f)) { engineSection() }
            }
        } else {
            Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding), verticalArrangement = spaced) {
                settingSection()
                otherSection()
                engineSection()
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
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}
