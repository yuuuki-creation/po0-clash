package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Connections
import io.github.yuuukicreation.po0clash.core.DashboardCard
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.IntranetIp
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Traffic
import io.github.yuuukicreation.po0clash.core.WhitelistOutcome
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext

/** The design's order; the core's default list has another one, and a list it holds unchanged was never customized. */
private val designOrder = listOf(
    DashboardCard.CURRENT_NODE,
    DashboardCard.MODE,
    DashboardCard.SPEED,
    DashboardCard.WHITELIST,
    DashboardCard.SUBSCRIPTION,
    DashboardCard.EXIT_IP,
    DashboardCard.INTRANET_IP,
    DashboardCard.TRAFFIC,
    DashboardCard.CONNECTIONS,
    DashboardCard.MEMORY,
    DashboardCard.TAKEOVER,
)

fun shownCards(saved: List<DashboardCard>) = if (saved == DashboardCard.entries) designOrder else saved

sealed interface DashboardBlock {
    data class Rows(val cards: List<DashboardCard>, val status: Boolean = false) : DashboardBlock
    data object ModePicker : DashboardBlock
    data object SpeedChart : DashboardBlock
}

/** The status row always opens the page; neighbouring plain rows then share one segmented group. */
fun dashboardBlocks(cards: List<DashboardCard>): List<DashboardBlock> {
    val blocks = mutableListOf<DashboardBlock>(DashboardBlock.Rows(emptyList(), status = true))
    cards.forEach { card ->
        val last = blocks.last()
        when {
            card == DashboardCard.MODE -> blocks += DashboardBlock.ModePicker
            card == DashboardCard.SPEED -> blocks += DashboardBlock.SpeedChart
            last is DashboardBlock.Rows -> blocks[blocks.lastIndex] = last.copy(cards = last.cards + card)
            else -> blocks += DashboardBlock.Rows(listOf(card))
        }
    }
    return blocks
}

private class Snapshot(val history: List<Traffic>, val memory: ULong, val connections: Connections)

@Composable
fun DashboardScreen(vm: AppViewModel, onConnect: () -> Unit, onOpen: (Page) -> Unit, onOpenGroup: (String?) -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
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
    val blocks = dashboardBlocks(shownCards(settings.dashboardCards))
    val rows = @Composable { block: DashboardBlock.Rows, columns: Int ->
        val count = block.cards.size + if (block.status) 1 else 0
        SegmentGrid(count, columns) { index ->
            val position = if (block.status) index - 1 else index
            if (position < 0) {
                StatusRow(vm, onConnect, count, columns)
            } else {
                CardRow(
                    block.cards[position],
                    index,
                    count,
                    columns,
                    vm,
                    snapshot,
                    onConnect,
                    onOpen,
                    onOpenGroup = { onOpenGroup(groups.firstOrNull()?.name) },
                )
            }
        }
    }
    val block = @Composable { item: DashboardBlock, columns: Int ->
        when (item) {
            is DashboardBlock.Rows -> rows(item, columns)
            DashboardBlock.ModePicker -> ModeSegments(vm)
            DashboardBlock.SpeedChart -> SpeedGroup(snapshot?.history)
        }
    }
    val scroll = rememberScrollState()
    PageScaffold(stringResource(R.string.dashboard), scroll.canScrollBackward, actions) { padding ->
        Column(
            Modifier.fillMaxSize().verticalScroll(scroll).padding(padding),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (!LocalWindowWidth.current.isExpanded) {
                blocks.forEach { block(it, 1) }
                return@Column
            }
            val lead = blocks.take(1 + blocks.drop(1).takeWhile { it !is DashboardBlock.Rows }.size)
            val side = lead.lastOrNull { it == DashboardBlock.SpeedChart } ?: lead.drop(1).lastOrNull()
            if (side == null) {
                blocks.forEach { block(it, 2) }
                return@Column
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    (lead - side).forEach { block(it, 1) }
                }
                Column(Modifier.weight(1f)) { block(side, 1) }
            }
            blocks.drop(lead.size).forEach { block(it, 2) }
        }
    }
}

/** Dot, state and the connect button. Failure text and uptime are live status, so they stay under the state. */
@Composable
private fun StatusRow(vm: AppViewModel, onConnect: () -> Unit, count: Int, columns: Int) {
    val engine = vm.engine
    val colors = palette
    val status by engine.status.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val connectedAt by engine.connectedAt.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val failure = (status.engine as? EngineState.Failed)?.message ?: vpnError
    val since = connectedAt
    val starting = active && since == null
    val (dot, title) = when {
        active && since != null -> colors.accent to stringResource(R.string.state_running)
        starting -> colors.warn to stringResource(R.string.state_starting)
        failure != null -> colors.bad to stringResource(R.string.state_failed)
        else -> colors.ink3 to stringResource(R.string.state_stopped)
    }
    GroupRow(0, count, columns = columns, minHeight = 64.dp) {
        StatusDot(dot, pulsing = starting)
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            when {
                since != null && active -> Text(elapsed(since), style = MaterialTheme.typography.bodyMedium.tabular(), color = colors.ink2, maxLines = 1)
                !active && failure != null -> Text(failure, style = MaterialTheme.typography.bodyMedium, color = colors.bad)
            }
        }
        ConnectButton(
            label = stringResource(if (starting) R.string.state_starting else if (active) R.string.disconnect else R.string.connect),
            primary = !active,
            busy = starting,
            enabled = active || profiles.any { it.selected },
            onClick = { if (active) vm.disconnect() else onConnect() },
        )
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

@Composable
private fun ModeSegments(vm: AppViewModel) {
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val modes = Mode.entries.map { it to stringResource(modeLabel(it)) }
    SegmentedPicker(modes, status.mode, enabled = AppViewModel.BUSY_MODE !in busy, onSelect = vm::setMode)
}

fun modeLabel(mode: Mode) = when (mode) {
    Mode.RULE -> R.string.mode_rule
    Mode.GLOBAL -> R.string.mode_global
    Mode.DIRECT -> R.string.mode_direct
}

@Composable
private fun Rate(icon: ImageVector, tint: Color, label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(16.dp))
        Text(value, style = MaterialTheme.typography.bodyMedium.tabular(), color = palette.ink2, maxLines = 1)
    }
}

@Composable
private fun SpeedGroup(history: List<Traffic>?) {
    val colors = palette
    val now = history?.lastOrNull()
    Column {
        GroupRow(0, 2) {
            Text(stringResource(R.string.network_speed), style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = Modifier.weight(1f))
            Rate(LineIcons.ArrowDown, colors.accent, stringResource(R.string.download), "${bytes(now?.down ?: 0u)}/s")
            Rate(LineIcons.ArrowUp, colors.ink2, stringResource(R.string.upload), "${bytes(now?.up ?: 0u)}/s")
        }
        SpeedChart(history.orEmpty(), Modifier.padding(top = 2.dp).clip(segmentShape(1, 2)))
    }
}

private const val HISTORY = 60

/** A new sample starts one step past the right edge and slides in over the next second, so the line never jumps. */
@Composable
private fun SpeedChart(history: List<Traffic>, modifier: Modifier) {
    val colors = palette
    val reduce = LocalReduceMotion.current
    // Made in the composition that brings the sample: an effect only starts after that frame has drawn it at the old offset.
    val progress = remember(history, reduce) { Animatable(if (reduce || history.size < 2) 1f else 0f) }
    LaunchedEffect(progress) { progress.animateTo(1f, tween(1000, easing = LinearEasing)) }
    Canvas(modifier.fillMaxWidth().height(96.dp).background(colors.card)) {
        val bottom = size.height - 4.dp.toPx()
        val span = bottom - 6.dp.toPx()
        val top = maxOf(history.maxOfOrNull { maxOf(it.up, it.down) }?.toFloat()?.times(1.1f) ?: 0f, 1024f)
        // The core keeps 60 samples, so one of them always waits past an edge and the line's left end never pops in.
        val step = size.width / (HISTORY - 2)
        val slide = step * (1f - progress.value)
        val start = size.width - step * (history.size - 1) + slide
        fun line(value: (Traffic) -> ULong) = Path().apply {
            history.forEachIndexed { index, traffic ->
                val x = start + step * index
                val y = bottom - span * (value(traffic).toFloat() / top)
                if (index == 0) moveTo(x, y) else lineTo(x, y)
            }
        }
        if (history.size < 2) {
            drawLine(colors.accent, Offset(0f, bottom), Offset(size.width, bottom), 1.5.dp.toPx())
            return@Canvas
        }
        drawPath(line { it.up }, colors.ink2, style = Stroke(1.25.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(line { it.down }, colors.accent, style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

@Composable
private fun CardRow(
    card: DashboardCard,
    index: Int,
    count: Int,
    columns: Int,
    vm: AppViewModel,
    snapshot: Snapshot?,
    onConnect: () -> Unit,
    onOpen: (Page) -> Unit,
    onOpenGroup: () -> Unit,
) {
    val engine = vm.engine
    when (card) {
        DashboardCard.CURRENT_NODE -> NodeRow(vm, index, count, columns, onOpenGroup)
        DashboardCard.WHITELIST -> {
            val whitelist by engine.whitelist.collectAsStateWithLifecycle()
            val applied = whitelist.entries.count { it.result?.outcome == WhitelistOutcome.APPLIED }
            val value = when {
                !whitelist.enabled -> stringResource(R.string.off)
                whitelist.entries.isEmpty() -> stringResource(R.string.whitelist_none)
                else -> pluralStringResource(R.plurals.whitelist_summary, whitelist.entries.size, applied, whitelist.entries.size)
            }
            LinkRow(index, count, columns, stringResource(R.string.whitelist), value) { onOpen(Page.WHITELIST) }
        }
        DashboardCard.SUBSCRIPTION -> {
            val profiles by engine.profiles.collectAsStateWithLifecycle()
            val current = profiles.firstOrNull { it.selected }
            val usage = current?.usage?.takeIf { it.total > 0u }
            LinkRow(
                index,
                count,
                columns,
                current?.let { profileName(it.kind, it.name) } ?: stringResource(if (profiles.isEmpty()) R.string.add_subscription else R.string.no_profile),
                usage?.let { "${bytes(it.upload + it.download)} / ${bytes(it.total)}" },
            ) { onOpen(Page.PROFILES) }
        }
        DashboardCard.EXIT_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            GroupRow(index, count, columns = columns, onClick = engine::refreshExitIp) {
                Text(stringResource(R.string.exit_ip), style = MaterialTheme.typography.bodyLarge, maxLines = 1)
                RowValue(exitIp?.let { listOfNotNull(it.country, it.ip).joinToString(" · ") } ?: "—", TextOverflow.MiddleEllipsis)
            }
        }
        DashboardCard.INTRANET_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            val ip by produceState<IntranetIp?>(null, exitIp) { value = withContext(Dispatchers.IO) { engine.core.intranetIp() } }
            ValueRow(index, count, stringResource(R.string.intranet_ip), ip?.ip ?: "—", columns)
        }
        DashboardCard.TRAFFIC -> {
            val colors = palette
            GroupRow(index, count, columns = columns) {
                Text(stringResource(R.string.traffic_total), style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = Modifier.weight(1f))
                Rate(LineIcons.ArrowDown, colors.accent, stringResource(R.string.download), bytes(snapshot?.connections?.downloadTotal ?: 0u))
                Rate(LineIcons.ArrowUp, colors.ink2, stringResource(R.string.upload), bytes(snapshot?.connections?.uploadTotal ?: 0u))
            }
        }
        DashboardCard.CONNECTIONS -> ValueRow(index, count, stringResource(R.string.connections), (snapshot?.connections?.items?.size ?: 0).toString(), columns)
        DashboardCard.MEMORY -> ValueRow(
            index,
            count,
            stringResource(R.string.memory),
            snapshot?.memory?.takeIf { it > 0u }?.let { bytes(it) } ?: "—",
            columns,
        )
        DashboardCard.TAKEOVER -> {
            val active by engine.vpnActive.collectAsStateWithLifecycle()
            val profiles by engine.profiles.collectAsStateWithLifecycle()
            GroupRow(index, count, columns = columns) {
                Text(stringResource(R.string.takeover), style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = Modifier.weight(1f))
                Po0Switch(active, { on -> if (on) onConnect() else vm.disconnect() }, enabled = active || profiles.any { it.selected })
            }
        }
        DashboardCard.SPEED, DashboardCard.MODE -> Unit
    }
}

@Composable
private fun LinkRow(index: Int, count: Int, columns: Int, label: String, value: String?, onClick: () -> Unit) {
    GroupRow(index, count, columns = columns, onClick = onClick) {
        Text(label, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = if (value == null) Modifier.weight(1f) else Modifier)
        value?.let { RowValue(it) }
        Chevron()
    }
}

@Composable
private fun NodeRow(vm: AppViewModel, index: Int, count: Int, columns: Int, onClick: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val name = status.currentNode.takeIf { status.engine == EngineState.Running }
    val node = name?.let { groups.asSequence().flatMap { group -> group.nodes }.firstOrNull { it.name == name } }
    GroupRow(index, count, columns = columns, onClick = onClick) {
        Text(stringResource(R.string.current_node), style = MaterialTheme.typography.bodyLarge, maxLines = 1)
        Text(
            name ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            color = palette.ink2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
        )
        if (name != null) DelayText(node?.delay)
        Chevron()
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
    val colors = palette
    val shown = shownCards(settings.dashboardCards)
    val hidden = DashboardCard.entries - shown.toSet()
    val ticks = CheckboxDefaults.colors(checkedColor = colors.accent, uncheckedColor = colors.ink2, checkmarkColor = colors.onAccent)
    fun save(cards: List<DashboardCard>) = vm.setAppSettings { it.copy(dashboardCards = cards) }
    SheetTitle(stringResource(R.string.edit_dashboard))
    SheetBody {
        shown.forEachIndexed { index, card ->
            GroupRow(index, shown.size, endPadding = 4.dp, fill = colors.card) {
                Checkbox(true, { save(shown - card) }, colors = ticks, modifier = Modifier.size(24.dp))
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
            hidden.forEachIndexed { index, card ->
                GroupRow(index, hidden.size, onClick = { save(shown + card) }) {
                    Checkbox(false, { save(shown + card) }, colors = ticks, modifier = Modifier.size(24.dp))
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
