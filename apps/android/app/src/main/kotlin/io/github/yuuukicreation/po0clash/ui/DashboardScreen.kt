package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridItemSpanScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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

private val fullSpanCards = setOf(
    DashboardCard.CURRENT_NODE,
    DashboardCard.MODE,
    DashboardCard.SPEED,
    DashboardCard.SUBSCRIPTION,
)

private fun wideSpanCards(cards: List<DashboardCard>): Set<DashboardCard> {
    val result = fullSpanCards.toMutableSet()
    val narrowRun = mutableListOf<DashboardCard>()
    fun flush() {
        if (narrowRun.size % 2 == 1) result += narrowRun.last()
        narrowRun.clear()
    }
    cards.forEach { card ->
        if (card in fullSpanCards) flush() else narrowRun += card
    }
    flush()
    return result
}

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
    val profiles by engine.profiles.collectAsStateWithLifecycle()
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
    val profileTitle = profiles.firstOrNull { it.selected }?.let { profileName(it.kind, it.name) }
    val subtitle = listOfNotNull(profileTitle, stringResource(modeLabel(status.mode))).joinToString(" · ")
    val cards = shownCards(settings.dashboardCards)
    val wideCards = remember(cards) { wideSpanCards(cards) }
    val grid = rememberLazyGridState()
    PageScaffold(stringResource(R.string.dashboard), grid, actions = actions, subtitle = subtitle) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val columns = if (maxWidth >= 840.dp) 4 else 2
            val wide: LazyGridItemSpanScope.() -> GridItemSpan = { GridItemSpan(minOf(2, maxLineSpan)) }
            val full: LazyGridItemSpanScope.() -> GridItemSpan = { GridItemSpan(maxLineSpan) }
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = grid,
                modifier = Modifier.fillMaxSize(),
                contentPadding = padding,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "hero_status", span = full) {
                    StatusHeroCard(vm, onConnect)
                }
                cards.forEach { card ->
                    item(key = card.name, span = if (card in wideCards) wide else null) {
                        Box(itemMotion()) {
                            DashboardMetricCard(
                                card = card,
                                vm = vm,
                                snapshot = snapshot,
                                onConnect = onConnect,
                                onOpen = onOpen,
                                onOpenGroup = { onOpenGroup(groups.firstOrNull()?.name) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusHeroCard(vm: AppViewModel, onConnect: () -> Unit) {
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
    val connected = active && since != null
    val title = when {
        connected -> stringResource(R.string.state_running)
        starting -> stringResource(R.string.state_starting)
        failure != null -> stringResource(R.string.state_failed)
        else -> stringResource(R.string.state_stopped)
    }
    val heroShape = RoundedCornerShape(24.dp)
    val containerColor = if (connected) colors.sel else colors.card
    val borderColor = if (connected) colors.accent.copy(alpha = 0.35f) else colors.line.copy(alpha = 0.7f)
    val badgeBg = when {
        connected -> colors.accent
        starting -> colors.warnMuted
        failure != null -> colors.badMuted
        else -> colors.track
    }
    val badgeTint = when {
        connected -> colors.onAccent
        starting -> colors.warn
        failure != null -> colors.bad
        else -> colors.ink2
    }
    Row(
        Modifier.fillMaxWidth()
            .clip(heroShape)
            .background(containerColor)
            .border(1.dp, borderColor, heroShape)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(44.dp).background(badgeBg, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (connected) LineIcons.ShieldCheck else LineIcons.Shield,
                contentDescription = null,
                tint = badgeTint,
                modifier = Modifier.size(22.dp),
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium.copy(fontSize = 18.sp, fontWeight = FontWeight.Bold),
                color = if (connected) colors.onSel else colors.ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            when {
                since != null && active -> {
                    val sub = listOfNotNull(elapsed(since), status.currentNode).joinToString(" · ")
                    Text(sub, style = MaterialTheme.typography.bodySmall.tabular(), color = if (connected) colors.onSel.copy(alpha = 0.8f) else colors.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                !active && failure != null -> {
                    Text(failure, style = MaterialTheme.typography.bodySmall, color = colors.bad, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                else -> {
                    val selectedProfile = profiles.firstOrNull { it.selected }?.let { profileName(it.kind, it.name) } ?: stringResource(R.string.no_profile)
                    Text(selectedProfile, style = MaterialTheme.typography.bodySmall, color = colors.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
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

fun modeLabel(mode: Mode) = when (mode) {
    Mode.RULE -> R.string.mode_rule
    Mode.GLOBAL -> R.string.mode_global
    Mode.DIRECT -> R.string.mode_direct
}

private const val HISTORY = 60

@Composable
private fun SpeedChart(history: List<Traffic>, modifier: Modifier = Modifier) {
    val colors = palette
    val reduce = LocalReduceMotion.current
    val progress = remember(history, reduce) { Animatable(if (reduce || history.size < 2) 1f else 0f) }
    LaunchedEffect(progress) { progress.animateTo(1f, tween(1000, easing = LinearEasing)) }
    Canvas(modifier.fillMaxWidth().height(68.dp)) {
        val bottom = size.height - 2.dp.toPx()
        val span = bottom - 4.dp.toPx()
        val top = maxOf(history.maxOfOrNull { maxOf(it.up, it.down) }?.toFloat()?.times(1.1f) ?: 0f, 1024f)
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
        drawLine(colors.line, Offset(0f, bottom), Offset(size.width, bottom), 1.dp.toPx())
        if (history.size < 2) return@Canvas
        val downPath = line { it.down }
        val areaPath = Path().apply {
            addPath(downPath)
            lineTo(size.width, bottom)
            lineTo(start.coerceAtLeast(0f), bottom)
            close()
        }
        drawPath(areaPath, colors.accent.copy(alpha = 0.12f))
        drawPath(line { it.up }, colors.ink3, style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(downPath, colors.accent, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

@Composable
private fun DashboardMetricCard(
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
        DashboardCard.MODE -> {
            val status by engine.status.collectAsStateWithLifecycle()
            val busy by vm.busy.collectAsStateWithLifecycle()
            val modes = Mode.entries.map { it to stringResource(modeLabel(it)) }
            InfoCard(stringResource(R.string.outbound_mode), LineIcons.Branch, spacing = 10.dp) {
                SegmentedPicker(modes, status.mode, enabled = AppViewModel.BUSY_MODE !in busy, onSelect = vm::setMode)
            }
        }
        DashboardCard.SPEED -> {
            val now = snapshot?.history?.lastOrNull()
            InfoCard(stringResource(R.string.network_speed), LineIcons.Chart, spacing = 10.dp) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    listOf(
                        Triple(now?.down ?: 0u, R.string.download, colors.accent),
                        Triple(now?.up ?: 0u, R.string.upload, colors.ink3),
                    ).forEach { (rate, label, dotColor) ->
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            val (num, unit) = byteParts(rate, perSecond = true)
                            BigValue(num, unit, large = true)
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Box(Modifier.size(8.dp).background(dotColor, CircleShape))
                                Text(stringResource(label), style = MaterialTheme.typography.labelMedium, color = colors.ink2)
                            }
                        }
                    }
                }
                SpeedChart(snapshot?.history.orEmpty())
            }
        }
        DashboardCard.CURRENT_NODE -> {
            val status by engine.status.collectAsStateWithLifecycle()
            val groups by engine.groups.collectAsStateWithLifecycle()
            val running = status.engine == EngineState.Running
            val nodeName = status.currentNode.takeIf { running }
            val group = currentGroup(groups, nodeName) ?: groups.firstOrNull()
            val node = nodeName?.let { name -> groups.asSequence().flatMap { it.nodes }.firstOrNull { it.name == name } }
            InfoCard(
                stringResource(R.string.current_node),
                LineIcons.Globe,
                onClick = onOpenGroup,
                trailing = {
                    if (group != null) {
                        Text(group.name, style = MaterialTheme.typography.labelMedium, color = colors.ink2, maxLines = 1)
                    }
                    Chevron()
                },
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        nodeName ?: group?.now ?: "—",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    if (node?.delay != null) {
                        DelayText(node.delay, MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold))
                    }
                }
                val meta = listOfNotNull(node?.kind, group?.let { "${it.nodes.size} ${stringResource(R.string.nodes)}" }).joinToString(" · ")
                Text(
                    meta.ifEmpty { stringResource(R.string.connect_first_short) },
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.ink2,
                    maxLines = 1,
                )
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
                LineIcons.ShieldCheck,
                onClick = { onOpen(Page.WHITELIST) },
                trailing = {
                    Po0Switch(whitelist.enabled, vm::setWhitelistEnabled, enabled = AppViewModel.BUSY_WHITELIST !in busy)
                },
            ) {
                BigValue(whitelist.entries.size.toString())
                Text(summary, style = MaterialTheme.typography.labelMedium, color = colors.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        DashboardCard.SUBSCRIPTION -> {
            val profiles by engine.profiles.collectAsStateWithLifecycle()
            val current = profiles.firstOrNull { it.selected }
            val usage = current?.usage?.takeIf { it.total > 0u }
            val title = current?.let { profileName(it.kind, it.name) }
                ?: stringResource(if (profiles.isEmpty()) R.string.add_subscription else R.string.no_profile)
            InfoCard(
                stringResource(R.string.subscription),
                LineIcons.Layers,
                onClick = { onOpen(Page.PROFILES) },
                note = current?.updatedAt?.let { stringResource(R.string.updated, relativeTime(it)) },
                trailing = { Chevron() },
                spacing = 8.dp,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        title,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (profiles.isEmpty()) colors.accent else colors.ink,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    if (usage != null) {
                        val pct = ((usage.upload + usage.download).toDouble() * 100 / usage.total.toDouble()).toInt().coerceIn(0, 100)
                        Text("$pct%", style = MaterialTheme.typography.labelLarge.tabular(), color = colors.accent, fontWeight = FontWeight.SemiBold)
                    }
                }
                if (usage != null) {
                    val fraction = ((usage.upload + usage.download).toDouble() / usage.total.toDouble()).toFloat().coerceIn(0f, 1f)
                    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(colors.track)) {
                        Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().clip(CircleShape).background(colors.accent))
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(
                            "${bytes(usage.upload + usage.download)} / ${bytes(usage.total)}",
                            style = MaterialTheme.typography.labelMedium.tabular(),
                            color = colors.ink2,
                        )
                        usage.expire?.let { Text(date(it), style = MaterialTheme.typography.labelMedium.tabular(), color = colors.ink2) }
                    }
                }
            }
        }
        DashboardCard.EXIT_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            InfoCard(
                stringResource(R.string.exit_ip),
                LineIcons.Pin,
                onClick = engine::refreshExitIp,
                trailing = { Icon(LineIcons.Refresh, contentDescription = null, tint = colors.ink2, modifier = Modifier.size(15.dp)) },
            ) {
                Text(
                    exitIp?.ip ?: "—",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold).tabular(),
                    maxLines = 1,
                    overflow = TextOverflow.MiddleEllipsis,
                )
                Text(
                    exitIp?.country ?: stringResource(R.string.connect_first_short),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.ink2,
                    maxLines = 1,
                )
            }
        }
        DashboardCard.INTRANET_IP -> {
            val exitIp by engine.exitIp.collectAsStateWithLifecycle()
            val ip by produceState<IntranetIp?>(null, exitIp) { value = withContext(Dispatchers.IO) { engine.core.intranetIp() } }
            InfoCard(stringResource(R.string.intranet_ip), LineIcons.Lan) {
                Text(
                    ip?.ip ?: "—",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold).tabular(),
                    maxLines = 1,
                    overflow = TextOverflow.MiddleEllipsis,
                )
                Text(
                    ip?.`interface`?.takeIf(String::isNotBlank) ?: "LAN",
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.ink2,
                    maxLines = 1,
                )
            }
        }
        DashboardCard.TRAFFIC -> {
            val up = snapshot?.connections?.uploadTotal ?: 0u
            val down = snapshot?.connections?.downloadTotal ?: 0u
            val (num, unit) = byteParts(up + down)
            InfoCard(stringResource(R.string.traffic_total), LineIcons.UpDown) {
                BigValue(num, unit)
                Text(
                    "↑ ${bytes(up)} · ↓ ${bytes(down)}",
                    style = MaterialTheme.typography.labelMedium.tabular(),
                    color = colors.ink2,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        DashboardCard.CONNECTIONS -> {
            val items = snapshot?.connections?.items.orEmpty()
            val tcp = items.count { it.network.equals("tcp", ignoreCase = true) }
            InfoCard(stringResource(R.string.connections), LineIcons.Link) {
                BigValue(items.size.toString())
                Text(
                    "TCP $tcp · UDP ${items.size - tcp}",
                    style = MaterialTheme.typography.labelMedium.tabular(),
                    color = colors.ink2,
                    maxLines = 1,
                )
            }
        }
        DashboardCard.MEMORY -> {
            val mem = snapshot?.memory
            InfoCard(stringResource(R.string.memory), LineIcons.Chip) {
                if (mem != null && mem > 0u) {
                    val (num, unit) = byteParts(mem)
                    BigValue(num, unit)
                } else {
                    BigValue("—")
                }
                Text("mihomo", style = MaterialTheme.typography.labelMedium, color = colors.ink2, maxLines = 1)
            }
        }
        DashboardCard.TAKEOVER -> {
            val active by engine.vpnActive.collectAsStateWithLifecycle()
            val profiles by engine.profiles.collectAsStateWithLifecycle()
            InfoCard(
                stringResource(R.string.takeover),
                LineIcons.Shield,
                trailing = {
                    Po0Switch(active, { on -> if (on) onConnect() else vm.disconnect() }, enabled = active || profiles.any { it.selected })
                },
            ) {
                BigValue(stringResource(R.string.vpn))
                Text(
                    stringResource(if (active) R.string.state_running else R.string.state_stopped),
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.ink2,
                    maxLines = 1,
                )
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
