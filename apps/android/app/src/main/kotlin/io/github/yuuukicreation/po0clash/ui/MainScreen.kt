package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.ProfileKind
import io.github.yuuukicreation.po0clash.core.ProxyGroup
import io.github.yuuukicreation.po0clash.core.Traffic
import kotlinx.coroutines.flow.flowOf

private val connectBarHeight = 68.dp

@Composable
fun MainScreen(vm: AppViewModel, snackbar: SnackbarHostState, onConnect: () -> Unit, onSettings: () -> Unit) {
    val engine = vm.engine
    val groups by engine.groups.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val expanded = remember { mutableStateMapOf<String, Boolean>() }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val modes = listOf(
        Mode.RULE to stringResource(R.string.mode_rule),
        Mode.GLOBAL to stringResource(R.string.mode_global),
        Mode.DIRECT to stringResource(R.string.mode_direct),
    )

    Box(Modifier.fillMaxSize().background(apple.background)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = top + 52.dp,
                bottom = bottom + connectBarHeight + 40.dp,
            ),
        ) {
            statusItems(vm, onConnect)
            if (profiles.isEmpty()) {
                emptyItems(onSettings)
                return@LazyColumn
            }
            item {
                SectionHeader(stringResource(R.string.mode))
                SegmentedPicker(modes, status.mode, enabled = AppViewModel.BUSY_MODE !in busy, onSelect = vm::setMode)
            }
            item { SectionHeader(stringResource(R.string.groups)) }
            if (groups.isEmpty()) {
                item { GroupRow(0, 1) { RowText(stringResource(R.string.groups_unavailable), titleColor = apple.secondaryLabel) } }
            }
            groups.forEach { group ->
                groupItems(
                    group = group,
                    expanded = expanded[group.name] == true,
                    testing = AppViewModel.busyDelay(group.name) in busy,
                    onToggle = { expanded[group.name] = expanded[group.name] != true },
                    onTest = { vm.testDelay(group.name) },
                    onSelect = { vm.selectNode(group.name, it) },
                )
            }
        }
        GlassTopBar(
            title = stringResource(R.string.app_name),
            action = {
                IconButton(onClick = onSettings) {
                    Icon(Icons.Outlined.Settings, contentDescription = stringResource(R.string.settings), tint = apple.accent)
                }
            },
        )
        Box(Modifier.align(Alignment.BottomCenter)) {
            GlassToastHost(snackbar, Modifier.navigationBarsPadding().padding(bottom = connectBarHeight + 24.dp))
            ConnectBar(vm, onConnect)
        }
    }
}

@Composable
private fun ConnectBar(vm: AppViewModel, onConnect: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val profile = profiles.firstOrNull { it.selected }
    val failed = status.engine is EngineState.Failed || vpnError != null
    val (label, color) = when {
        failed -> R.string.state_failed to apple.red
        status.engine == EngineState.Running -> R.string.state_running to apple.green
        active || status.engine == EngineState.Starting -> R.string.state_starting to apple.orange
        else -> R.string.state_stopped to apple.secondaryLabel
    }
    Row(
        Modifier.navigationBarsPadding().padding(start = 16.dp, end = 16.dp, bottom = 12.dp).fillMaxWidth()
            .height(connectBarHeight).glass(RoundedCornerShape(34.dp)).padding(start = 22.dp, end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StatusDot(color)
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(stringResource(label), style = MaterialTheme.typography.titleMedium)
            Text(
                profile?.let { profileName(it.kind, it.name) } ?: stringResource(R.string.no_profile),
                style = MaterialTheme.typography.bodySmall,
                color = apple.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Switch(
            checked = active,
            onCheckedChange = { if (it) onConnect() else vm.disconnect() },
            enabled = active || profile != null,
            colors = appleSwitchColors(),
            thumbContent = {},
        )
    }
}

private fun LazyListScope.statusItems(vm: AppViewModel, onConnect: () -> Unit) {
    item(key = "status") {
        val engine = vm.engine
        val status by engine.status.collectAsStateWithLifecycle()
        val vpnError by engine.vpnError.collectAsStateWithLifecycle()
        val exitIp by engine.exitIp.collectAsStateWithLifecycle()
        val running = status.engine == EngineState.Running
        val traffic by remember(running) { if (running) engine.traffic else flowOf(null) }
            .collectAsStateWithLifecycle(null as Traffic?)
        val failure = (status.engine as? EngineState.Failed)?.message ?: vpnError
        val rows = buildList<@Composable (Int, Int) -> Unit> {
            if (failure != null) {
                add { i, n -> GroupRow(i, n) { RowText(failure, titleColor = apple.red) } }
                add { i, n -> ActionRow(i, n, stringResource(R.string.reconnect), onClick = onConnect) }
            }
            if (running) add { i, n -> ValueRow(i, n, stringResource(R.string.node), status.currentNode ?: "—") }
            add { i, n ->
                val value = exitIp?.let { ip -> listOfNotNull(ip.ip, ip.country).joinToString("  ") } ?: "—"
                ValueRow(i, n, stringResource(R.string.exit_ip), value)
            }
            traffic?.let { t ->
                add { i, n -> ValueRow(i, n, stringResource(R.string.traffic), stringResource(R.string.rate, bytes(t.up), bytes(t.down))) }
            }
        }
        Column(Modifier.padding(top = 16.dp)) {
            rows.forEachIndexed { index, row -> row(index, rows.size) }
        }
    }
}

private fun LazyListScope.emptyItems(onSettings: () -> Unit) {
    item {
        SectionHeader(stringResource(R.string.empty_title))
        GroupRow(0, 2) { RowText(stringResource(R.string.empty_body), titleColor = apple.secondaryLabel) }
        ActionRow(1, 2, stringResource(R.string.empty_action), onClick = onSettings)
    }
}

private fun LazyListScope.groupItems(
    group: ProxyGroup,
    expanded: Boolean,
    testing: Boolean,
    onToggle: () -> Unit,
    onTest: () -> Unit,
    onSelect: (String) -> Unit,
) {
    val count = if (expanded) group.nodes.size + 1 else 1
    item(key = "group:${group.name}") {
        val angle by animateFloatAsState(if (expanded) 90f else 0f, label = "chevron")
        GroupRow(0, count, onClick = onToggle) {
            RowText(group.name, group.now ?: group.kind)
            if (testing) {
                SmallProgress()
            } else {
                TextButton(onClick = onTest) { Text(stringResource(R.string.test_delay), color = apple.accent) }
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = apple.secondaryLabel,
                modifier = Modifier.rotate(angle),
            )
        }
    }
    if (expanded) {
        itemsIndexed(group.nodes, key = { _, node -> "node:${group.name}:${node.name}" }) { index, node ->
            GroupRow(index + 1, count, onClick = if (group.selectable) ({ onSelect(node.name) }) else null) {
                RowText(node.name, node.kind)
                DelayLabel(node.delay)
                Box(Modifier.size(22.dp)) {
                    if (node.name == group.now) Icon(Icons.Filled.Check, contentDescription = null, tint = apple.accent)
                }
            }
        }
    }
    item(key = "gap:${group.name}") { Spacer(Modifier.height(12.dp)) }
}

@Composable
private fun DelayLabel(delay: UInt?) {
    val colors = apple
    val (text, color) = when {
        delay == null -> "" to colors.secondaryLabel
        delay == 0u -> stringResource(R.string.delay_timeout) to colors.red
        delay < 300u -> stringResource(R.string.delay_ms, delay.toInt()) to colors.green
        delay < 800u -> stringResource(R.string.delay_ms, delay.toInt()) to colors.orange
        else -> stringResource(R.string.delay_ms, delay.toInt()) to colors.red
    }
    Text(text, style = MaterialTheme.typography.bodyMedium, color = color)
}

@Composable
fun profileName(kind: ProfileKind, name: String): String =
    if (kind == ProfileKind.LINKS) stringResource(R.string.links_profile) else name
