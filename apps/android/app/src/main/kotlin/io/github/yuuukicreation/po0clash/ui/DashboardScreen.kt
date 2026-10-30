package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridItemSpanScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.outlined.AltRoute
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.outlined.Cable
import androidx.compose.material.icons.outlined.Hub
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Memory
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Connections
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Traffic
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf

private val connectButtonHeight = 56.dp

@Composable
fun DashboardScreen(vm: AppViewModel, onConnect: () -> Unit, onOpen: (Page) -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val failure = (status.engine as? EngineState.Failed)?.message ?: vpnError
    val running = status.engine == EngineState.Running
    val snapshot by remember(running) {
        if (running) engine.poll { Snapshot(trafficHistory(), memory(), connections()) } else flowOf(null)
    }.collectAsStateWithLifecycle(null)

    val grid = rememberLazyGridState()
    PageScaffold(stringResource(R.string.dashboard), grid, extraBottom = connectButtonHeight + 12.dp) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val columns = ((maxWidth - 20.dp) / 172.dp).toInt().coerceAtLeast(2)
            val wide: LazyGridItemSpanScope.() -> GridItemSpan = { GridItemSpan(minOf(2, maxLineSpan)) }
            val full: LazyGridItemSpanScope.() -> GridItemSpan = { GridItemSpan(maxLineSpan) }
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = grid,
                modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
                contentPadding = padding,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = full) { PageTitle(stringResource(R.string.dashboard)) }
                if (failure != null) item(span = full) { FailureCard(failure, onConnect) }
                item(span = wide) { SpeedCard(snapshot?.history) }
                item { TrafficCard(snapshot?.connections) }
                item { ConnectionsCard(snapshot?.connections) }
                item { ExitIpCard(vm) }
                item { MemoryCard(snapshot?.memory) }
                item(span = wide) { NodeCard(vm, onClick = { onOpen(Page.PROXIES) }) }
                item(span = wide) { ModeCard(vm) }
                item(span = wide) { SubscriptionCard(vm, onAdd = { onOpen(Page.PROFILES) }) }
                item(span = wide) { WhitelistCard(vm, onClick = { onOpen(Page.WHITELIST) }) }
            }
        }
        Box(Modifier.fillMaxSize().padding(end = 16.dp, bottom = LocalBottomPadding.current + 12.dp), Alignment.BottomEnd) {
            ConnectButton(vm, onConnect)
        }
    }
}

@Composable
private fun FailureCard(message: String, onReconnect: () -> Unit) {
    ContentCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.WarningAmber, contentDescription = null, tint = apple.red, modifier = Modifier.size(22.dp))
            Text(
                stringResource(R.string.state_failed),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.weight(1f).padding(start = 8.dp),
            )
            TextButton(onClick = onReconnect, shape = CircleShape) {
                Text(stringResource(R.string.reconnect), style = MaterialTheme.typography.bodyLarge, color = apple.accent)
            }
        }
        Text(message, style = MaterialTheme.typography.bodyMedium, color = apple.secondaryLabel, maxLines = 6, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * FlClash's start button, the app's one tinted action: prominent blue glass while off, plain glass showing the
 * connection's age once it is up; a tap while on disconnects.
 */
@Composable
private fun ConnectButton(vm: AppViewModel, onConnect: () -> Unit) {
    val engine = vm.engine
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val connectedAt by engine.connectedAt.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val colors = apple
    val enabled = active || profiles.any { it.selected }
    val shape = CircleShape
    val surface = when {
        active -> Modifier.glass(shape)
        enabled -> Modifier.glass(shape, tint = colors.accent)
        else -> Modifier.glass(shape, tint = colors.accent).alpha(0.5f)
    }
    val tint = if (active) colors.label else Color.White
    Row(
        Modifier.height(connectButtonHeight).then(surface).clip(shape)
            .clickable(enabled = enabled) { if (active) vm.disconnect() else onConnect() }
            .padding(start = 18.dp, end = 22.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val since = connectedAt
        when {
            !active -> Icon(Icons.Filled.PlayArrow, contentDescription = null, tint = tint)
            since == null -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = colors.secondaryLabel)
            else -> Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.disconnect), tint = tint)
        }
        val label = when {
            !active -> stringResource(R.string.connect)
            since == null -> stringResource(R.string.state_starting)
            else -> elapsed(since)
        }
        Text(label, style = MaterialTheme.typography.titleMedium.tabular(), color = tint)
    }
}

@Composable
private fun elapsed(since: Long): String {
    val now by produceState(SystemClock.elapsedRealtime(), since) {
        while (true) {
            value = SystemClock.elapsedRealtime()
            delay(1000 - (value - since) % 1000)
        }
    }
    val seconds = ((now - since) / 1000).coerceAtLeast(0)
    return "%02d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60)
}

private class Snapshot(val history: List<Traffic>, val memory: ULong, val connections: Connections)

@Composable
private fun SpeedCard(history: List<Traffic>?) {
    val now = history?.lastOrNull()
    val peak = history?.maxOfOrNull { maxOf(it.up, it.down) }
    InfoCard(
        stringResource(R.string.traffic),
        Icons.Outlined.Speed,
        trailing = {
            peak?.let {
                Text(stringResource(R.string.peak, bytes(it)), style = MaterialTheme.typography.labelMedium.tabular(), color = apple.secondaryLabel)
            }
        },
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            RateLine(Icons.Filled.ArrowUpward, now?.up?.let { stringResource(R.string.per_second, bytes(it)) })
            RateLine(Icons.Filled.ArrowDownward, now?.down?.let { stringResource(R.string.per_second, bytes(it)) })
        }
        SpeedChart(history.orEmpty())
    }
}

/** The last minute of rates: download as the solid line, upload as the faint one, scaled to the busier of the two. */
@Composable
private fun SpeedChart(history: List<Traffic>) {
    val colors = apple
    Canvas(Modifier.fillMaxWidth().height(56.dp)) {
        drawLine(colors.separator, Offset(0f, size.height), Offset(size.width, size.height), strokeWidth = 1f)
        if (history.size < 2) return@Canvas
        val top = maxOf(history.maxOf { maxOf(it.up, it.down) }.toFloat(), 1024f)
        val step = size.width / (HISTORY - 1)
        val start = size.width - step * (history.size - 1)
        fun line(value: (Traffic) -> ULong) = Path().apply {
            history.forEachIndexed { index, traffic ->
                val x = start + step * index
                val y = size.height * (1 - value(traffic).toFloat() / top)
                if (index == 0) moveTo(x, y) else lineTo(x, y)
            }
        }
        val stroke = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
        drawPath(line { it.up }, colors.accent.copy(alpha = 0.4f), style = stroke)
        drawPath(line { it.down }, colors.accent, style = stroke)
    }
}

private const val HISTORY = 60

@Composable
private fun TrafficCard(connections: Connections?) {
    InfoCard(stringResource(R.string.traffic_total), Icons.Outlined.SwapVert, Modifier.heightIn(min = 112.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            RateLine(Icons.Filled.ArrowUpward, connections?.uploadTotal?.let { bytes(it) })
            RateLine(Icons.Filled.ArrowDownward, connections?.downloadTotal?.let { bytes(it) })
        }
    }
}

@Composable
private fun ConnectionsCard(connections: Connections?) {
    InfoCard(stringResource(R.string.connections), Icons.Outlined.Cable, Modifier.heightIn(min = 112.dp)) {
        BigValue(connections?.items?.size?.toString())
    }
}

@Composable
private fun MemoryCard(memory: ULong?) {
    InfoCard(stringResource(R.string.memory), Icons.Outlined.Memory, Modifier.heightIn(min = 112.dp)) {
        BigValue(memory?.takeIf { it > 0u }?.let { bytes(it) })
    }
}

@Composable
private fun BigValue(value: String?) {
    Text(value ?: "—", style = MaterialTheme.typography.titleLarge.tabular(), maxLines = 1)
}

@Composable
private fun RateLine(icon: ImageVector, value: String?) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = apple.secondaryLabel, modifier = Modifier.size(16.dp))
        Text(
            value ?: "—",
            style = MaterialTheme.typography.bodyLarge.tabular(),
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            modifier = Modifier.padding(start = 6.dp),
        )
    }
}

@Composable
private fun ExitIpCard(vm: AppViewModel) {
    val exitIp by vm.engine.exitIp.collectAsStateWithLifecycle()
    InfoCard(
        stringResource(R.string.exit_ip),
        Icons.Outlined.Language,
        Modifier.heightIn(min = 112.dp),
        trailing = {
            IconButton(onClick = vm.engine::refreshExitIp, modifier = Modifier.size(28.dp)) {
                Icon(
                    Icons.Outlined.Refresh,
                    contentDescription = stringResource(R.string.refresh),
                    tint = apple.accent,
                    modifier = Modifier.size(18.dp),
                )
            }
        },
    ) {
        Column {
            Text(
                exitIp?.ip ?: "—",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.MiddleEllipsis,
            )
            exitIp?.country?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel) }
        }
    }
}

@Composable
private fun NodeCard(vm: AppViewModel, onClick: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val node = status.currentNode.takeIf { status.engine == EngineState.Running }
    val delay = node?.let { name -> groups.asSequence().flatMap { it.nodes }.firstOrNull { it.name == name && it.delay != null }?.delay }
    InfoCard(
        stringResource(R.string.current_node),
        Icons.Outlined.Hub,
        onClick = onClick,
        trailing = {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = apple.secondaryLabel)
        },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                node ?: "—",
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            DelayText(delay)
        }
    }
}

@Composable
private fun ModeCard(vm: AppViewModel) {
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val modes = listOf(
        Mode.RULE to stringResource(R.string.mode_rule),
        Mode.GLOBAL to stringResource(R.string.mode_global),
        Mode.DIRECT to stringResource(R.string.mode_direct),
    )
    InfoCard(stringResource(R.string.mode), Icons.AutoMirrored.Outlined.AltRoute) {
        SegmentedPicker(modes, status.mode, enabled = AppViewModel.BUSY_MODE !in busy, onSelect = vm::setMode)
    }
}

@Composable
private fun SubscriptionCard(vm: AppViewModel, onAdd: () -> Unit) {
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val current = profiles.firstOrNull { it.selected }
    val switchTitle = stringResource(R.string.switch_subscription)
    val names = profiles.map { profileName(it.kind, it.name) }
    val anchor = rememberAnchor()
    InfoCard(stringResource(R.string.subscription), Icons.Outlined.Inbox) {
        if (profiles.isEmpty()) {
            Text(
                stringResource(R.string.add_subscription),
                style = MaterialTheme.typography.bodyLarge,
                color = apple.accent,
                modifier = Modifier.clip(CircleShape).clickable(onClick = onAdd).padding(vertical = 2.dp),
            )
            return@InfoCard
        }
        Row(
            Modifier.anchor(anchor).clip(CircleShape)
                .clickable(enabled = AppViewModel.BUSY_PROFILES !in busy) {
                    sheets.menu(anchor, switchTitle, profiles.mapIndexed { i, profile -> SheetAction(names[i]) { vm.selectProfile(profile.id) } })
                },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                current?.let { profileName(it.kind, it.name) } ?: stringResource(R.string.no_profile),
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Icon(
                Icons.Filled.UnfoldMore,
                contentDescription = switchTitle,
                tint = apple.secondaryLabel,
                modifier = Modifier.padding(start = 4.dp).size(20.dp),
            )
        }
        current?.let { ProfileUsage(it) }
    }
}

@Composable
private fun WhitelistCard(vm: AppViewModel, onClick: () -> Unit) {
    val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    InfoCard(stringResource(R.string.whitelist_enabled), Icons.Outlined.VerifiedUser, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                whitelistSummary(whitelist),
                style = MaterialTheme.typography.bodyLarge,
                color = apple.secondaryLabel,
                modifier = Modifier.weight(1f),
            )
            AppleSwitch(whitelist.enabled, vm::setWhitelistEnabled, enabled = AppViewModel.BUSY_WHITELIST !in busy)
        }
    }
}
