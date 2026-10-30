package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.AdminPanelSettings
import androidx.compose.material.icons.outlined.Backup
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Contrast
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.DeveloperMode
import androidx.compose.material.icons.outlined.Dns
import androidx.compose.material.icons.outlined.HourglassEmpty
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.Lan
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.BuildConfig
import io.github.yuuukicreation.po0clash.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** The Flutter app's tools entries; those the core cannot back yet open a "coming soon" page instead of hiding. */
enum class Tool(@param:StringRes val label: Int, val icon: ImageVector) {
    LANGUAGE(R.string.language, Icons.Outlined.Translate),
    APPEARANCE(R.string.appearance, Icons.Outlined.Contrast),
    APPLICATION(R.string.application, Icons.Outlined.PhoneAndroid),
    BASIC(R.string.basic_config, Icons.Outlined.Tune),
    NETWORK(R.string.network, Icons.Outlined.Lan),
    DNS(R.string.dns, Icons.Outlined.Dns),
    ADVANCED(R.string.advanced, Icons.Outlined.Build),
    ACCESS(R.string.access_control, Icons.Outlined.AdminPanelSettings),
    RESOURCES(R.string.resources, Icons.Outlined.Inventory2),
    ACTIVITY(R.string.activity, Icons.AutoMirrored.Outlined.ReceiptLong),
    BACKUP(R.string.backup, Icons.Outlined.Backup),
    DEVELOPER(R.string.developer, Icons.Outlined.DeveloperMode),
    ABOUT(R.string.about, Icons.Outlined.Info),
}

private val sections = listOf(
    R.string.settings to listOf(Tool.LANGUAGE, Tool.APPEARANCE, Tool.APPLICATION),
    R.string.network_and_core to listOf(
        Tool.BASIC,
        Tool.NETWORK,
        Tool.DNS,
        Tool.ADVANCED,
        Tool.ACCESS,
        Tool.RESOURCES,
        Tool.ACTIVITY,
    ),
)

@Composable
fun ToolsScreen(vm: AppViewModel) {
    var open by rememberSaveable { mutableStateOf<Tool?>(null) }
    BackHandler(enabled = open != null) { open = null }
    AnimatedContent(
        targetState = open,
        transitionSpec = {
            if (targetState != null) {
                (slideInHorizontally { it } + fadeIn()) togetherWith (slideOutHorizontally { -it / 3 } + fadeOut())
            } else {
                (slideInHorizontally { -it / 3 } + fadeIn()) togetherWith (slideOutHorizontally { it } + fadeOut())
            }
        },
        label = "tools",
    ) { tool ->
        if (tool == null) ToolList(vm, onOpen = { open = it }) else ToolPage(tool, onBack = { open = null })
    }
}

@Composable
private fun ToolList(vm: AppViewModel, onOpen: (Tool) -> Unit) {
    val busy by vm.busy.collectAsStateWithLifecycle()
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        uri?.let(vm::exportDiagnostics)
    }
    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.tools), list) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.tools)) }
            sections.forEach { (header, tools) -> toolSection(header, tools, onOpen) }
            item {
                SectionHeader(stringResource(R.string.other))
                ToolRow(0, 4, Tool.BACKUP, onOpen)
                ActionRow(
                    1,
                    4,
                    stringResource(R.string.export_diagnostics),
                    Icons.Outlined.Description,
                    busy = AppViewModel.BUSY_DIAGNOSTICS in busy,
                ) {
                    val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                    export.launch("po0-clash-diagnostics-$stamp.txt")
                }
                ToolRow(2, 4, Tool.DEVELOPER, onOpen)
                ToolRow(3, 4, Tool.ABOUT, onOpen)
                SectionFooter(stringResource(R.string.export_diagnostics_hint))
            }
        }
    }
}

private fun LazyListScope.toolSection(@StringRes header: Int, tools: List<Tool>, onOpen: (Tool) -> Unit) {
    item(key = header) {
        SectionHeader(stringResource(header))
        tools.forEachIndexed { index, tool -> ToolRow(index, tools.size, tool, onOpen) }
    }
}

@Composable
private fun ToolRow(index: Int, count: Int, tool: Tool, onOpen: (Tool) -> Unit) {
    GroupRow(index, count, onClick = { onOpen(tool) }, inset = 50.dp) {
        Icon(tool.icon, contentDescription = null, tint = apple.accent, modifier = Modifier.size(22.dp))
        Text(stringResource(tool.label), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = apple.secondaryLabel)
    }
}

@Composable
private fun ToolPage(tool: Tool, onBack: () -> Unit) {
    val title = stringResource(tool.label)
    val list = rememberLazyListState()
    var activity by rememberSaveable { mutableStateOf(R.string.requests) }
    PageScaffold(title, list, onBack = onBack) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(title) }
            when (tool) {
                Tool.ABOUT -> item {
                    Column(Modifier.padding(top = 8.dp)) {
                        ValueRow(0, 1, stringResource(R.string.version), "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
                    }
                }
                Tool.ACTIVITY -> item {
                    Column(Modifier.padding(top = 8.dp)) {
                        val tabs = listOf(R.string.requests, R.string.connections, R.string.logs)
                        SegmentedPicker(tabs.map { it to stringResource(it) }, activity, enabled = true) { activity = it }
                        ComingSoon()
                    }
                }
                else -> item { ComingSoon() }
            }
        }
    }
}

@Composable
private fun ComingSoon() {
    Column(
        Modifier.fillMaxWidth().padding(top = 96.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Outlined.HourglassEmpty, contentDescription = null, tint = apple.secondaryLabel, modifier = Modifier.size(44.dp))
        Text(stringResource(R.string.coming_soon), style = MaterialTheme.typography.titleMedium)
        Text(
            stringResource(R.string.coming_soon_body),
            style = MaterialTheme.typography.bodyMedium,
            color = apple.secondaryLabel,
            textAlign = TextAlign.Center,
        )
    }
}
