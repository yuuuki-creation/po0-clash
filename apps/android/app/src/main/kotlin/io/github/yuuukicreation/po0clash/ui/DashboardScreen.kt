// Layout and styling follow FlClash v0.8.92 (https://github.com/chen08209/FlClash, GPL-3.0), lib/views/dashboard.
package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DataSaverOff
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.NetworkCheck
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.StackedLineChart
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Connections
import io.github.yuuukicreation.po0clash.core.DashboardCard
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.IntranetIp
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Traffic
import io.github.yuuukicreation.po0clash.core.WhitelistOutcome
import kotlin.math.ceil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext

/** FlClash's arrangement; the core's default list has another one, and a list it holds unchanged was never customized. */
private val designOrder = listOf(
    DashboardCard.SPEED,
    DashboardCard.MODE,
    DashboardCard.EXIT_IP,
    DashboardCard.TAKEOVER,
    DashboardCard.INTRANET_IP,
    DashboardCard.MEMORY,
    DashboardCard.TRAFFIC,
    DashboardCard.WHITELIST,
    DashboardCard.CONNECTIONS,
    DashboardCard.CURRENT_NODE,
    DashboardCard.SUBSCRIPTION,
)

private val wideCards = setOf(DashboardCard.SPEED, DashboardCard.MODE, DashboardCard.CURRENT_NODE, DashboardCard.SUBSCRIPTION)
private val tallCards = setOf(DashboardCard.SPEED, DashboardCard.TRAFFIC)

fun shownCards(saved: List<DashboardCard>) = if (saved == DashboardCard.entries) designOrder else saved

/** Where a card sits, in grid columns and in rows of one card line. */
data class CardSlot(val card: DashboardCard, val column: Int, val row: Int, val span: Int, val lines: Int)

/** Each card takes the first free place it fits, reading rows top to bottom, so a tall card leaves no hole beside it. */
fun packDashboard(cards: List<DashboardCard>, columns: Int): List<CardSlot> {
    val taken = HashSet<Pair<Int, Int>>()
    return cards.map { card ->
        val span = if (card in wideCards) minOf(2, columns) else 1
        val lines = if (card in tallCards) 2 else 1
        fun cells(column: Int, row: Int) = (column until column + span).flatMap { x -> (row until row + lines).map { y -> x to y } }
        val (column, row) = generateSequence(0) { it + 1 }
            .flatMap { y -> (0..columns - span).asSequence().map { x -> x to y } }
            .first { (x, y) -> cells(x, y).none(taken::contains) }
        taken += cells(column, row)
        CardSlot(card, column, row, span, lines)
    }
}

private class Snapshot(val history: List<Traffic>, val memory: ULong, val connections: Connections)

private val cardGap = 14.dp

@Composable
fun DashboardScreen(vm: AppViewModel, onConnect: () -> Unit, onOpen: (Page) -> Unit, onOpenGroup: (String?) -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val connectedAt by engine.connectedAt.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val running = status.engine == EngineState.Running
    val snapshot by remember(running) {
        if (running) engine.poll { Snapshot(trafficHistory(), memory(), connections()) } else flowOf(null)
    }.collectAsStateWithLifecycle(null)
    val group = currentGroup(groups, status.currentNode)
    val actions = listOf(
        PageAction(
            LineIcons.Bolt,
            stringResource(R.string.test_delay),
            enabled = running && group != null,
            busy = group != null && AppViewModel.busyDelay(group.name) in busy,
        ) { group?.let { vm.testDelay(it.name) } },
        PageAction(LineIcons.Grid, stringResource(R.string.edit_dashboard)) { sheets.show { DashboardEditor(vm) } },
    )
    val since = connectedAt.takeIf { active }
    val starting = active && since == null
    val fab = if (active || profiles.any { it.selected }) {
        FabAction(
            icon = if (active) Icons.Filled.Pause else Icons.Filled.PlayArrow,
            label = stringResource(if (active) R.string.disconnect else R.string.connect),
            busy = starting,
            text = since?.let { elapsed(it) },
        ) {
            when {
                starting -> Unit
                active -> vm.disconnect()
                else -> onConnect()
            }
        }
    } else {
        null
    }
    val failure = ((status.engine as? EngineState.Failed)?.message ?: vpnError).takeIf { !active }
    val cards = shownCards(settings.dashboardCards)
    val scroll = rememberScrollState()
    PageScaffold(stringResource(R.string.dashboard), scroll.canScrollBackward, actions = actions, fab = fab) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding)) {
            val columns = maxOf(2, ceil(maxWidth / 280.dp).toInt())
            val slots = remember(cards, columns) { packDashboard(cards, columns) }
            Column(verticalArrangement = Arrangement.spacedBy(cardGap)) {
                if (failure != null) FailureCard(failure)
                DashboardGrid(slots, columns) { card ->
                    DashboardCardContent(
                        card = card,
                        vm = vm,
                        snapshot = snapshot,
                        onConnect = onConnect,
                        onOpen = onOpen,
                        onOpenGroup = { onOpenGroup((group ?: groups.firstOrNull())?.name) },
                    )
                }
            }
        }
    }
}

@Composable
private fun DashboardGrid(slots: List<CardSlot>, columns: Int, card: @Composable (DashboardCard) -> Unit) {
    val line = 80.dp * LocalDensity.current.fontScale.coerceAtLeast(1f)
    Layout(
        content = {
            slots.forEach { slot ->
                key(slot.card) { Box(propagateMinConstraints = true) { card(slot.card) } }
            }
        },
        modifier = Modifier.fillMaxWidth(),
    ) { measurables, constraints ->
        val gap = cardGap.roundToPx()
        val lineHeight = line.roundToPx()
        val cell = (constraints.maxWidth - gap * (columns - 1)) / columns
        val placeables = measurables.mapIndexed { index, measurable ->
            val slot = slots[index]
            measurable.measure(
                Constraints.fixed(cell * slot.span + gap * (slot.span - 1), lineHeight * slot.lines + gap * (slot.lines - 1)),
            )
        }
        val rows = slots.maxOfOrNull { it.row + it.lines } ?: 0
        layout(constraints.maxWidth, (rows * (lineHeight + gap) - gap).coerceAtLeast(0)) {
            placeables.forEachIndexed { index, placeable ->
                val slot = slots[index]
                placeable.place(slot.column * (cell + gap), slot.row * (lineHeight + gap))
            }
        }
    }
}

@Composable
private fun FailureCard(message: String) {
    val scheme = MaterialTheme.colorScheme
    Column(
        Modifier.fillMaxWidth().clip(cardShape).background(scheme.errorContainer).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(stringResource(R.string.state_failed), style = MaterialTheme.typography.titleSmall, color = scheme.onErrorContainer)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = scheme.onErrorContainer, maxLines = 4, overflow = TextOverflow.Ellipsis)
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

fun modeLabel(mode: Mode) = when (mode) {
    Mode.RULE -> R.string.mode_rule
    Mode.GLOBAL -> R.string.mode_global
    Mode.DIRECT -> R.string.mode_direct
}

private const val HISTORY = 60

/** The total rate over the last minute, sliding left as each sample arrives. */
@Composable
private fun SpeedChart(history: List<Traffic>, modifier: Modifier = Modifier) {
    val color = palette.accent
    val reduce = LocalReduceMotion.current
    val progress = remember(history, reduce) { Animatable(if (reduce || history.size < 2) 1f else 0f) }
    LaunchedEffect(progress) { progress.animateTo(1f, tween(1000, easing = LinearEasing)) }
    Canvas(modifier) {
        val stroke = 2.dp.toPx()
        val bottom = size.height - stroke
        if (history.size < 2) {
            drawLine(color, Offset(0f, bottom), Offset(size.width, bottom), stroke)
            return@Canvas
        }
        val top = maxOf(history.maxOf { it.up + it.down }.toFloat() * 1.1f, 1024f)
        val step = size.width / (HISTORY - 2)
        val start = size.width - step * (history.size - 1) + step * (1f - progress.value)
        val end = start + step * (history.size - 1)
        val line = Path().apply {
            history.forEachIndexed { index, traffic ->
                val x = start + step * index
                val y = bottom - (bottom - stroke) * ((traffic.up + traffic.down).toFloat() / top)
                if (index == 0) moveTo(x, y) else lineTo(x, y)
            }
        }
        val area = Path().apply {
            addPath(line)
            lineTo(end, size.height)
            lineTo(start, size.height)
            close()
        }
        drawPath(area, Brush.verticalGradient(listOf(color.copy(alpha = 0.3f), Color.Transparent)))
        drawPath(line, color, style = Stroke(stroke, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

@Composable
private fun TrafficDonut(up: ULong, down: ULong, upColor: Color, downColor: Color, modifier: Modifier) {
    val track = palette.track
    Canvas(modifier) {
        val stroke = size.minDimension * 0.2f
        val inset = Offset(stroke / 2, stroke / 2)
        val ring = Size(size.width - stroke, size.height - stroke)
        val total = (up + down).toFloat()
        if (total <= 0f) {
            drawArc(track, 0f, 360f, useCenter = false, topLeft = inset, size = ring, style = Stroke(stroke))
            return@Canvas
        }
        val upSweep = 360f * up.toFloat() / total
        drawArc(upColor, -90f, upSweep, useCenter = false, topLeft = inset, size = ring, style = Stroke(stroke))
        drawArc(downColor, -90f + upSweep, 360f - upSweep, useCenter = false, topLeft = inset, size = ring, style = Stroke(stroke))
    }
}

@Composable
private fun TrafficLine(icon: ImageVector, color: Color, value: ULong) {
    val (number, unit) = byteParts(value)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(14.dp))
        Text(number, style = MaterialTheme.typography.bodySmall.tabular(), maxLines = 1, modifier = Modifier.weight(1f))
        Text(unit, style = MaterialTheme.typography.bodySmall, color = palette.ink2, maxLines = 1)
    }
}

@Composable
private fun TrafficLegend(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(20.dp, 8.dp).background(color, RoundedCornerShape(3.dp)))
        Text(label, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

private val switchCardPadding = PaddingValues(start = 16.dp, end = 8.dp, bottom = 8.dp)

@Composable
private fun SwitchCardBody(text: String, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text,
            style = MaterialTheme.typography.titleSmall.copy(fontSize = 12.sp),
            color = palette.ink2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Po0Switch(checked, onChange, enabled = enabled, modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun ModeCard(vm: AppViewModel) {
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val scheme = MaterialTheme.colorScheme
    val (thumb, onThumb) = when (status.mode) {
        Mode.RULE -> scheme.secondaryContainer to scheme.onSecondaryContainer
        Mode.GLOBAL -> scheme.primaryContainer to scheme.onPrimaryContainer
        Mode.DIRECT -> scheme.tertiaryContainer to scheme.onTertiaryContainer
    }
    val fill by animateColorAsState(thumb, tween(200), label = "mode")
    AppCard {
        Row(Modifier.weight(1f).fillMaxWidth().padding(12.dp)) {
            Mode.entries.forEach { mode ->
                val selected = mode == status.mode
                Box(
                    Modifier.weight(1f).fillMaxHeight()
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (selected) fill else Color.Transparent)
                        .clickable(enabled = AppViewModel.BUSY_MODE !in busy) { vm.setMode(mode) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(modeLabel(mode)),
                        style = MaterialTheme.typography.titleSmall.copy(fontSize = 15.sp),
                        color = if (selected) onThumb else palette.ink2,
                        maxLines = 1,
                    )
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(8.dp).background(fill.copy(alpha = 0.5f)))
    }
}

@Composable
private fun DashboardCardContent(
    card: DashboardCard,
    vm: AppViewModel,
    snapshot: Snapshot?,
    onConnect: () -> Unit,
    onOpen: (Page) -> Unit,
    onOpenGroup: () -> Unit,
) {
    val engine = vm.engine
    val colors = palette
    when (card) {
        DashboardCard.MODE -> ModeCard(vm)
        DashboardCard.SPEED -> {
            val now = snapshot?.history?.lastOrNull()
            val (up, upUnit) = byteParts(now?.up ?: 0u, perSecond = true)
            val (down, downUnit) = byteParts(now?.down ?: 0u, perSecond = true)
            AppCard {
                CardHeader(stringResource(R.string.network_speed), Icons.Filled.Speed, "↑ $up $upUnit  ↓ $down $downUnit")
                SpeedChart(snapshot?.history.orEmpty(), Modifier.weight(1f).fillMaxWidth().padding(top = 16.dp))
            }
        }
        DashboardCard.CURRENT_NODE -> {
            val status by engine.status.collectAsStateWithLifecycle()
            val groups by engine.groups.collectAsStateWithLifecycle()
            val running = status.engine == EngineState.Running
            val nodeName = status.currentNode.takeIf { running }
            val group = currentGroup(groups, nodeName) ?: groups.firstOrNull()
            val node = nodeName?.let { name -> groups.asSequence().flatMap { it.nodes }.firstOrNull { it.name == name } }
            InfoCard(stringResource(R.string.current_node), Icons.Filled.Public, onClick = onOpenGroup, note = group?.name) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CardValue(nodeName ?: group?.now ?: stringResource(R.string.connect_first_short), Modifier.weight(1f))
                    DelayText(node?.delay)
                }
            }
        }
        DashboardCard.WHITELIST -> {
            val whitelist by engine.whitelist.collectAsStateWithLifecycle()
            val busy by vm.busy.collectAsStateWithLifecycle()
            val applied = whitelist.entries.count { it.result?.outcome == WhitelistOutcome.APPLIED }
            val summary = when {
                !whitelist.enabled -> stringResource(R.string.off)
                whitelist.entries.isEmpty() -> stringResource(R.string.whitelist_none)
                else -> pluralStringResource(R.plurals.whitelist_summary, whitelist.entries.size, applied, whitelist.entries.size)
            }
            InfoCard(
                stringResource(R.string.whitelist),
                Icons.Filled.VerifiedUser,
                onClick = { onOpen(Page.WHITELIST) },
                contentPadding = switchCardPadding,
            ) {
                SwitchCardBody(summary, whitelist.enabled, AppViewModel.BUSY_WHITELIST !in busy, vm::setWhitelistEnabled)
            }
        }
        DashboardCard.SUBSCRIPTION -> SubscriptionCard(vm) { onOpen(Page.PROFILES) }
        DashboardCard.EXIT_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            InfoCard(stringResource(R.string.exit_ip), Icons.Filled.NetworkCheck, onClick = engine::refreshExitIp, note = exitIp?.country) {
                CardValue(exitIp?.ip ?: "—")
            }
        }
        DashboardCard.INTRANET_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            val ip by produceState<IntranetIp?>(null, exitIp) { value = withContext(Dispatchers.IO) { engine.core.intranetIp() } }
            InfoCard(stringResource(R.string.intranet_ip), Icons.Filled.Devices, note = ip?.`interface`) {
                CardValue(ip?.ip ?: "—")
            }
        }
        DashboardCard.TRAFFIC -> {
            val up = snapshot?.connections?.uploadTotal ?: 0u
            val down = snapshot?.connections?.downloadTotal ?: 0u
            val downColor = colors.ink3
            InfoCard(stringResource(R.string.traffic_total), Icons.Filled.DataSaverOff) {
                Row(
                    Modifier.weight(1f).fillMaxWidth().padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TrafficDonut(up, down, colors.accent, downColor, Modifier.fillMaxHeight().aspectRatio(1f))
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        TrafficLegend(colors.accent, stringResource(R.string.upload))
                        TrafficLegend(downColor, stringResource(R.string.download))
                    }
                }
                TrafficLine(LineIcons.ArrowUp, colors.accent, up)
                Spacer(Modifier.height(8.dp))
                TrafficLine(LineIcons.ArrowDown, downColor, down)
            }
        }
        DashboardCard.CONNECTIONS -> {
            val items = snapshot?.connections?.items.orEmpty()
            val tcp = items.count { it.network.equals("tcp", ignoreCase = true) }
            InfoCard(stringResource(R.string.connections), Icons.Filled.Link, note = "TCP $tcp · UDP ${items.size - tcp}") {
                CardValue(items.size.toString())
            }
        }
        DashboardCard.MEMORY -> {
            val memory = snapshot?.memory?.takeIf { it > 0u }
            InfoCard(stringResource(R.string.memory), Icons.Filled.Memory) {
                CardValue(memory?.let { bytes(it) } ?: "—")
            }
        }
        DashboardCard.TAKEOVER -> {
            val active by engine.vpnActive.collectAsStateWithLifecycle()
            val profiles by engine.profiles.collectAsStateWithLifecycle()
            InfoCard(stringResource(R.string.vpn), Icons.Filled.StackedLineChart, contentPadding = switchCardPadding) {
                SwitchCardBody(
                    stringResource(if (active) R.string.state_running else R.string.state_stopped),
                    active,
                    enabled = active || profiles.any { it.selected },
                ) { on -> if (on) onConnect() else vm.disconnect() }
            }
        }
    }
}

/** The selected profile, with its usage as a bar along the card's bottom edge. */
@Composable
private fun SubscriptionCard(vm: AppViewModel, onClick: () -> Unit) {
    val colors = palette
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val current = profiles.firstOrNull { it.selected }
    val usage = current?.usage?.takeIf { it.total > 0u }
    val title = current?.let { profileName(it.kind, it.name) }
        ?: stringResource(if (profiles.isEmpty()) R.string.add_subscription else R.string.no_profile)
    val note = usage?.expire?.takeIf { it > 0 }?.let { date(it) }
        ?: current?.updatedAt?.let { stringResource(R.string.updated, relativeTime(it)) }
    AppCard(onClick = onClick) {
        CardHeader(stringResource(R.string.subscription), Icons.Filled.Folder, note)
        Row(
            Modifier.weight(1f).fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = if (usage != null) 10.dp else 16.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CardValue(title, Modifier.weight(1f), color = if (profiles.isEmpty()) colors.accent else colors.ink)
            if (usage != null) {
                Text(
                    "${bytes(usage.upload + usage.download)} / ${bytes(usage.total)}",
                    style = MaterialTheme.typography.bodySmall.tabular(),
                    color = colors.ink2,
                    maxLines = 1,
                )
            }
        }
        if (usage != null) {
            val fraction = ((usage.upload + usage.download).toDouble() / usage.total.toDouble()).toFloat().coerceIn(0f, 1f)
            Box(Modifier.fillMaxWidth().height(6.dp).background(colors.track)) {
                Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(colors.accent))
            }
        }
    }
}

private fun cardLabel(card: DashboardCard) = when (card) {
    DashboardCard.CURRENT_NODE -> R.string.current_node
    DashboardCard.SPEED -> R.string.network_speed
    DashboardCard.MODE -> R.string.outbound_mode
    DashboardCard.TAKEOVER -> R.string.takeover
    DashboardCard.WHITELIST -> R.string.whitelist_enabled
    DashboardCard.TRAFFIC -> R.string.traffic_total
    DashboardCard.CONNECTIONS -> R.string.connections
    DashboardCard.MEMORY -> R.string.memory
    DashboardCard.INTRANET_IP -> R.string.intranet_ip
    DashboardCard.SUBSCRIPTION -> R.string.subscription
    DashboardCard.EXIT_IP -> R.string.exit_ip
}

@Composable
private fun ColumnScope.DashboardEditor(vm: AppViewModel) {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val shown = shownCards(settings.dashboardCards)
    val hidden = DashboardCard.entries - shown.toSet()
    fun save(cards: List<DashboardCard>) = vm.setAppSettings { it.copy(dashboardCards = cards) }
    SheetTitle(stringResource(R.string.edit_dashboard))
    SheetBody {
        shown.forEachIndexed { index, card ->
            GroupRow(endPadding = 4.dp) {
                Checkbox(true, { save(shown - card) }, modifier = Modifier.size(24.dp))
                Text(stringResource(cardLabel(card)), style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = Modifier.weight(1f))
                AppIconButton(LineIcons.ChevronUp, stringResource(R.string.move_up), enabled = index > 0) {
                    save(shown.toMutableList().apply { add(index - 1, removeAt(index)) })
                }
                AppIconButton(LineIcons.ChevronDown, stringResource(R.string.move_down), enabled = index < shown.lastIndex) {
                    save(shown.toMutableList().apply { add(index + 1, removeAt(index)) })
                }
            }
        }
        if (hidden.isNotEmpty()) {
            SectionHeader(stringResource(R.string.hidden_cards))
            hidden.forEach { card ->
                GroupRow(onClick = { save(shown + card) }) {
                    Checkbox(false, { save(shown + card) }, modifier = Modifier.size(24.dp))
                    Text(stringResource(cardLabel(card)), style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = Modifier.weight(1f))
                }
            }
        }
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.End)) {
        TextAction(stringResource(R.string.restore_default)) { save(DashboardCard.entries) }
        TextAction(stringResource(R.string.done), accent = true, onClick = sheets::dismiss)
    }
}
