package io.github.yuuukicreation.po0clash.ui

import android.text.format.Formatter
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext

@Composable
fun DashboardScreen(vm: AppViewModel, onConnect: () -> Unit, onOpen: (Page) -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val snapshot by remember(running) {
        if (running) engine.poll { Snapshot(trafficHistory(), memory(), connections()) } else flowOf(null)
    }.collectAsStateWithLifecycle(null)
    val group = currentGroup(groups, status.currentNode)
    val test = PageAction(
        LineIcons.Bolt,
        stringResource(R.string.test_delay),
        enabled = running && group != null,
        busy = group != null && AppViewModel.busyDelay(group.name) in busy,
    ) { group?.let { vm.testDelay(it.name) } }
    val profile = profiles.firstOrNull { it.selected }?.let { profileName(it.kind, it.name) }
    val subtitle = listOfNotNull(profile, stringResource(R.string.mode_summary, stringResource(modeLabel(status.mode)))).joinToString(" · ")
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val edit = PageAction(LineIcons.Grid, stringResource(R.string.edit_dashboard)) { sheets.show { DashboardEditor(vm) } }

    val grid = rememberLazyGridState()
    PageScaffold(stringResource(R.string.dashboard), grid, actions = listOf(test, edit)) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val columns = ((maxWidth - 20.dp) / 172.dp).toInt().coerceAtLeast(2)
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
                item(span = full) { PageTitle(stringResource(R.string.dashboard), subtitle) }
                settings.dashboardCards.forEach { card ->
                    item(key = card.name, span = if (card in halfCards) null else wide) {
                        Box(itemMotion()) {
                            when (card) {
                                DashboardCard.SPEED -> SpeedCard(snapshot?.history)
                                DashboardCard.MODE -> ModeCard(vm)
                                DashboardCard.CURRENT_NODE -> NodeCard(vm, onClick = { onOpen(Page.PROXIES) })
                                DashboardCard.TAKEOVER -> TakeoverCard(vm, onConnect)
                                DashboardCard.WHITELIST -> WhitelistCard(vm, onClick = { onOpen(Page.WHITELIST) })
                                DashboardCard.TRAFFIC -> TrafficCard(snapshot?.connections)
                                DashboardCard.CONNECTIONS -> ConnectionsCard(snapshot?.connections)
                                DashboardCard.MEMORY -> MemoryCard(snapshot?.memory)
                                DashboardCard.INTRANET_IP -> IntranetIpCard(vm)
                                DashboardCard.SUBSCRIPTION -> SubscriptionCard(vm, onAdd = { onOpen(Page.PROFILES) })
                                DashboardCard.EXIT_IP -> ExitIpCard(vm)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Cards that pair up two to a row on a phone; the rest take the full width. */
private val halfCards = setOf(
    DashboardCard.TAKEOVER,
    DashboardCard.WHITELIST,
    DashboardCard.TRAFFIC,
    DashboardCard.CONNECTIONS,
    DashboardCard.MEMORY,
    DashboardCard.INTRANET_IP,
)

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

/** Shown cards in order with up and down buttons, then the hidden ones to add back. */
@Composable
private fun ColumnScope.DashboardEditor(vm: AppViewModel) {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val shown = settings.dashboardCards
    val hidden = DashboardCard.entries - shown.toSet()
    fun save(cards: List<DashboardCard>) = vm.setAppSettings { it.copy(dashboardCards = cards) }
    SheetTitle(stringResource(R.string.edit_dashboard))
    Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState())) {
        shown.forEachIndexed { index, card ->
            GroupRow(index, shown.size) {
                CheckCircle(true, Modifier.clickable { save(shown - card) })
                Text(stringResource(cardLabel(card)), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                FillButton(LineIcons.ChevronUp, stringResource(R.string.move_up), size = 28.dp, enabled = index > 0) {
                    save(shown.toMutableList().apply { add(index - 1, removeAt(index)) })
                }
                FillButton(LineIcons.ChevronDown, stringResource(R.string.move_down), size = 28.dp, enabled = index < shown.lastIndex) {
                    save(shown.toMutableList().apply { add(index + 1, removeAt(index)) })
                }
            }
        }
        if (hidden.isNotEmpty()) {
            SectionHeader(stringResource(R.string.hidden_cards))
            hidden.forEachIndexed { index, card ->
                GroupRow(index, hidden.size, onClick = { save(shown + card) }) {
                    CheckCircle(false)
                    Text(stringResource(cardLabel(card)), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                }
            }
        }
    }
    TextButton(onClick = { save(DashboardCard.entries) }, modifier = Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.restore_default), color = apple.accent, style = MaterialTheme.typography.bodyLarge)
    }
    SheetDoneButton(onClick = sheets::dismiss)
}

fun modeLabel(mode: Mode) = when (mode) {
    Mode.RULE -> R.string.mode_rule
    Mode.GLOBAL -> R.string.mode_global
    Mode.DIRECT -> R.string.mode_direct
}

private class Snapshot(val history: List<Traffic>, val memory: ULong, val connections: Connections)

/** [Formatter]'s size split into number and unit, so the number can be large and the unit small. */
@Composable
fun byteParts(value: ULong, perSecond: Boolean = false): Pair<String, String> {
    val text = Formatter.formatFileSize(LocalContext.current, value.toLong())
    val split = text.indexOfLast { it.isWhitespace() || it == ' ' }
    val (number, unit) = if (split < 0) text to "" else text.substring(0, split) to text.substring(split + 1)
    return number to if (perSecond) "$unit/s" else unit
}

@Composable
private fun SpeedCard(history: List<Traffic>?) {
    val colors = apple
    val now = history?.lastOrNull()
    InfoCard(stringResource(R.string.network_speed), LineIcons.Chart, note = stringResource(R.string.last_minute), spacing = 8.dp) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            listOf(
                Triple(now?.down ?: 0u, R.string.download, colors.accent),
                Triple(now?.up ?: 0u, R.string.upload, colors.upload),
            ).forEach { (rate, label, color) ->
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    val (number, unit) = byteParts(rate, perSecond = true)
                    BigValue(number, unit, large = true)
                    Legend(color, stringResource(label))
                }
            }
        }
        SpeedChart(history.orEmpty())
    }
}

@Composable
private fun Legend(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(8.dp).background(color, CircleShape))
        Text(label, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel)
    }
}

/** The last minute: download as the accent line over a faint fill, upload as the gray line, one baseline, no axes. */
@Composable
private fun SpeedChart(history: List<Traffic>) {
    val colors = apple
    Canvas(Modifier.fillMaxWidth().height(56.dp)) {
        drawLine(colors.separator, Offset(0f, size.height), Offset(size.width, size.height), strokeWidth = 1f)
        if (history.size < 2) return@Canvas
        val top = maxOf(history.maxOf { maxOf(it.up, it.down) }.toFloat() * 1.1f, 1024f)
        val step = size.width / (HISTORY - 1)
        val start = size.width - step * (history.size - 1)
        fun line(value: (Traffic) -> ULong) = Path().apply {
            history.forEachIndexed { index, traffic ->
                val x = start + step * index
                val y = (size.height - 1) * (1 - value(traffic).toFloat() / top)
                if (index == 0) moveTo(x, y) else lineTo(x, y)
            }
        }
        val down = line { it.down }
        val area = Path().apply {
            addPath(down)
            lineTo(size.width, size.height)
            lineTo(start, size.height)
            close()
        }
        drawPath(area, colors.accentSoft)
        drawPath(line { it.up }, colors.upload, style = Stroke(1.6.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(down, colors.accent, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

private const val HISTORY = 60

@Composable
private fun ModeCard(vm: AppViewModel) {
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val modes = Mode.entries.map { it to stringResource(modeLabel(it)) }
    val detail = when (status.mode) {
        Mode.RULE -> R.string.mode_rule_detail
        Mode.GLOBAL -> R.string.mode_global_detail
        Mode.DIRECT -> R.string.mode_direct_detail
    }
    InfoCard(stringResource(R.string.outbound_mode), LineIcons.Branch, spacing = 10.dp) {
        SegmentedPicker(modes, status.mode, enabled = AppViewModel.BUSY_MODE !in busy, onSelect = vm::setMode)
        Text(stringResource(detail), style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel)
    }
}

@Composable
private fun NodeCard(vm: AppViewModel, onClick: () -> Unit) {
    val engine = vm.engine
    val colors = apple
    val status by engine.status.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val nodeName = status.currentNode.takeIf { running }
    val group = currentGroup(groups, nodeName)
    val node = nodeName?.let { name -> groups.asSequence().flatMap { it.nodes }.firstOrNull { it.name == name } }
    InfoCard(
        stringResource(R.string.current_node),
        LineIcons.Globe,
        onClick = onClick,
        spacing = 6.dp,
        trailing = {
            Text(
                group?.name.orEmpty(),
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                color = colors.secondaryLabel,
                maxLines = 1,
            )
            Icon(LineIcons.ChevronRight, contentDescription = null, tint = colors.secondaryLabel, modifier = Modifier.size(14.dp))
        },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                nodeName ?: stringResource(if (running) R.string.state_running else R.string.state_stopped),
                style = MaterialTheme.typography.titleLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            node?.delay?.let { DelayText(it, MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold), dot = true) }
        }
        val detail = listOfNotNull(node?.kind, group?.let { pluralStringResource(R.plurals.node_count, it.nodes.size, it.nodes.size) })
        Text(
            detail.joinToString(" · ").ifEmpty { stringResource(R.string.connect_to_see_node) },
            style = MaterialTheme.typography.bodySmall,
            color = colors.secondaryLabel,
        )
    }
}

@Composable
private fun TrafficCard(connections: Connections?) {
    val up = connections?.uploadTotal ?: 0u
    val down = connections?.downloadTotal ?: 0u
    InfoCard(stringResource(R.string.traffic_total), LineIcons.UpDown) {
        val (number, unit) = byteParts(up + down)
        BigValue(number, unit)
        Text("↑ ${bytes(up)} · ↓ ${bytes(down)}", style = MaterialTheme.typography.labelMedium.tabular(), color = apple.secondaryLabel, maxLines = 1)
    }
}

@Composable
private fun ConnectionsCard(connections: Connections?) {
    val items = connections?.items.orEmpty()
    val tcp = items.count { it.network.equals("tcp", ignoreCase = true) }
    InfoCard(stringResource(R.string.connections), LineIcons.Link) {
        BigValue(items.size.toString(), stringResource(R.string.count_unit).ifEmpty { null })
        Text(
            stringResource(R.string.tcp_udp, tcp, items.size - tcp),
            style = MaterialTheme.typography.labelMedium.tabular(),
            color = apple.secondaryLabel,
            maxLines = 1,
        )
    }
}

@Composable
private fun MemoryCard(memory: ULong?) {
    InfoCard(stringResource(R.string.memory), LineIcons.Chip) {
        if (memory != null && memory > 0u) {
            val (number, unit) = byteParts(memory)
            BigValue(number, unit)
        } else {
            BigValue("—")
        }
        Text(stringResource(R.string.engine_memory), style = MaterialTheme.typography.labelMedium, color = apple.secondaryLabel, maxLines = 1)
    }
}

@Composable
private fun ExitIpCard(vm: AppViewModel) {
    val exitIp by vm.engine.exitIp.collectAsStateWithLifecycle()
    InfoCard(
        stringResource(R.string.exit_ip),
        LineIcons.Pin,
        trailing = { FillButton(LineIcons.Refresh, stringResource(R.string.refresh), size = 24.dp, onClick = vm.engine::refreshExitIp) },
    ) {
        Text(
            exitIp?.ip ?: "—",
            style = MaterialTheme.typography.bodyLarge.tabular(),
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.MiddleEllipsis,
            modifier = Modifier.padding(vertical = 5.dp),
        )
        Text(
            exitIp?.country ?: stringResource(R.string.unknown),
            style = MaterialTheme.typography.labelMedium,
            color = apple.secondaryLabel,
            maxLines = 1,
        )
    }
}

@Composable
private fun SubscriptionCard(vm: AppViewModel, onAdd: () -> Unit) {
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val colors = apple
    val current = profiles.firstOrNull { it.selected }
    val switchTitle = stringResource(R.string.switch_subscription)
    val names = profiles.map { profileName(it.kind, it.name) }
    val anchor = rememberAnchor()
    InfoCard(
        stringResource(R.string.subscription),
        LineIcons.Layers,
        note = current?.updatedAt?.let { stringResource(R.string.updated, relativeTime(it)) },
        spacing = 8.dp,
    ) {
        if (profiles.isEmpty()) {
            Text(
                stringResource(R.string.add_subscription),
                style = MaterialTheme.typography.bodyLarge,
                color = colors.accent,
                modifier = Modifier.clip(CircleShape).clickable(onClick = onAdd).padding(vertical = 2.dp),
            )
            return@InfoCard
        }
        val usage = current?.usage?.takeIf { it.total > 0u }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.weight(1f).anchor(anchor).clip(CircleShape)
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
                    LineIcons.ChevronDown,
                    contentDescription = switchTitle,
                    tint = colors.secondaryLabel,
                    modifier = Modifier.padding(start = 4.dp).size(14.dp),
                )
            }
            if (usage != null) {
                val percent = ((usage.upload + usage.download).toDouble() * 100 / usage.total.toDouble()).toInt().coerceIn(0, 100)
                Text("$percent%", style = MaterialTheme.typography.bodySmall.tabular(), color = colors.secondaryLabel)
            }
        }
        current?.let { ProfileUsage(it) }
    }
}

@Composable
private fun IntranetIpCard(vm: AppViewModel) {
    val exitIp by vm.engine.exitIp.collectAsStateWithLifecycle()
    val ip by produceState<IntranetIp?>(null, exitIp) { value = withContext(Dispatchers.IO) { vm.engine.core.intranetIp() } }
    InfoCard(stringResource(R.string.intranet_ip), LineIcons.Lan) {
        Text(
            ip?.ip ?: "—",
            style = MaterialTheme.typography.bodyLarge.tabular(),
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.MiddleEllipsis,
            modifier = Modifier.padding(vertical = 5.dp),
        )
        Text(
            ip?.`interface`?.takeIf(String::isNotBlank) ?: stringResource(R.string.unknown),
            style = MaterialTheme.typography.labelMedium,
            color = apple.secondaryLabel,
            maxLines = 1,
        )
    }
}

/** Android's takeover is the VPN itself, so the switch connects and disconnects. */
@Composable
private fun TakeoverCard(vm: AppViewModel, onConnect: () -> Unit) {
    val active by vm.engine.vpnActive.collectAsStateWithLifecycle()
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    InfoCard(stringResource(R.string.takeover), LineIcons.Shield) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("VPN", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    stringResource(if (active) R.string.takeover_on else R.string.takeover_off),
                    style = MaterialTheme.typography.labelMedium,
                    color = apple.secondaryLabel,
                )
            }
            AppleSwitch(active, { on -> if (on) onConnect() else vm.disconnect() }, enabled = active || profiles.any { it.selected })
        }
    }
}

@Composable
private fun WhitelistCard(vm: AppViewModel, onClick: () -> Unit) {
    val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    InfoCard(stringResource(R.string.whitelist), LineIcons.ShieldCheck, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(if (whitelist.enabled) R.string.on else R.string.off),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(whitelistSummary(whitelist), style = MaterialTheme.typography.labelMedium, color = apple.secondaryLabel, maxLines = 1)
            }
            AppleSwitch(whitelist.enabled, vm::setWhitelistEnabled, enabled = AppViewModel.BUSY_WHITELIST !in busy)
        }
    }
}
