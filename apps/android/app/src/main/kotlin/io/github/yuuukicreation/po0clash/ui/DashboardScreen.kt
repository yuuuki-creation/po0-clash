// Layout and styling follow FlClash v0.9.3 (https://github.com/chen08209/FlClash, GPL-3.0), lib/views/dashboard.
package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
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
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.res.stringResource
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
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext

private val designOrder = listOf(
    DashboardCard.SPEED,
    DashboardCard.MODE,
    DashboardCard.SUBSCRIPTION,
    DashboardCard.CURRENT_NODE,
    DashboardCard.WHITELIST,
)

fun shownCards(saved: List<DashboardCard>): List<DashboardCard> =
    (if (saved == DashboardCard.entries) designOrder else saved).distinct()

private class Snapshot(val history: List<Traffic>, val memory: ULong, val connections: Connections)

private val cardGap = 8.dp

@Composable
fun DashboardScreen(vm: AppViewModel, onConnect: () -> Unit, editing: Boolean, onEditing: (Boolean) -> Unit, onOpen: (Page) -> Unit, onOpenGroup: (String?) -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val running = status.engine == EngineState.Running
    val snapshot by remember(running) {
        if (running) engine.poll { Snapshot(trafficHistory(), memory(), connections()) } else flowOf(null)
    }.collectAsStateWithLifecycle(null)
    val group = currentGroup(groups, status.currentNode)
    val actions = listOf(
        PageAction(if (editing) LineIcons.Check else LineIcons.Edit, stringResource(if (editing) R.string.done else R.string.edit_dashboard)) { onEditing(!editing) },
    )
    val failure = ((status.engine as? EngineState.Failed)?.message ?: vpnError).takeIf { !active }
    val cards = shownCards(settings.dashboardCards)
    val scroll = rememberScrollState()
    PageScaffold(stringResource(if (editing) R.string.edit_dashboard else R.string.dashboard), scroll.canScrollBackward, actions = actions) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize().verticalScroll(scroll).padding(padding)) {
            val columns = if (!editing && maxWidth >= 840.dp) 2 else 1
            val side = maxOf(0.dp, (maxWidth - if (columns == 1) 560.dp else 1160.dp) / 2)
            Column(Modifier.padding(horizontal = side), verticalArrangement = Arrangement.spacedBy(cardGap)) {
                if (failure != null) FailureCard(failure)
                androidx.compose.runtime.CompositionLocalProvider(LocalDashboardStyle provides true) {
                    Box(Modifier.fillMaxWidth().height(188.dp * LocalDensity.current.fontScale.coerceAtLeast(1f)), propagateMinConstraints = true) {
                        CurrentOutboundCard(vm, onConnect)
                    }
                    cards.chunked(columns).forEach { row ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(cardGap)) {
                            row.forEach { card ->
                                key(card) {
                                    val height = when (card) {
                                        DashboardCard.CURRENT_NODE -> maxOf(132.dp, 60.dp + 52.dp * groups.size.coerceAtMost(4))
                                        DashboardCard.SPEED -> 188.dp
                                        DashboardCard.MODE -> 126.dp
                                        DashboardCard.SUBSCRIPTION -> if (engine.profiles.value.any { it.selected }) 168.dp else 96.dp
                                        DashboardCard.TRAFFIC -> 176.dp
                                        else -> 128.dp
                                    } * LocalDensity.current.fontScale.coerceAtLeast(1f)
                                    var drag by remember(card) { mutableFloatStateOf(0f) }
                                    val title = stringResource(cardLabel(card))
                                    val hideLabel = "${stringResource(R.string.hide_card)}: $title"
                                    Box(Modifier.weight(1f).height(height).graphicsLayer { translationY = drag }
                                        .then(if (editing) Modifier.pointerInput(cards, card) {
                                            detectDragGesturesAfterLongPress(
                                                onDrag = { change, amount -> change.consume(); drag += amount.y },
                                                onDragCancel = { drag = 0f },
                                                onDragEnd = {
                                                    val from = cards.indexOf(card)
                                                    val to = (from + (drag / (size.height + cardGap.toPx())).roundToInt()).coerceIn(cards.indices)
                                                    drag = 0f
                                                    if (from != to) vm.setAppSettings { settings ->
                                                        settings.copy(dashboardCards = cards.toMutableList().apply { add(to, removeAt(from)) })
                                                    }
                                                },
                                            )
                                        } else Modifier), propagateMinConstraints = true) {
                                        DashboardCardContent(card, vm, snapshot, onConnect, onOpen, onOpenGroup)
                                        if (editing) androidx.compose.material3.IconButton(
                                            onClick = { vm.setAppSettings { it.copy(dashboardCards = cards - card) } },
                                            modifier = Modifier.align(Alignment.TopEnd).size(28.dp).semantics { contentDescription = hideLabel }.background(MaterialTheme.colorScheme.errorContainer, CircleShape),
                                        ) {
                                            Text("−", color = MaterialTheme.colorScheme.onErrorContainer, style = MaterialTheme.typography.titleMedium)
                                        }
                                    }
                                }
                            }
                            if (row.size < columns) Spacer(Modifier.weight(1f))
                        }
                    }
                    if (editing) HiddenDashboardCards(vm, cards)
                }
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
internal fun elapsed(since: Long): String {
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
private fun SpeedChart(history: List<Traffic>, upload: Boolean, modifier: Modifier = Modifier) {
    val color = if (upload) palette.accent.copy(alpha = 0.45f) else palette.accent
    val reduce = LocalReduceMotion.current
    val progress = remember(history, reduce) { Animatable(if (reduce || history.size < 2) 1f else 0f) }
    LaunchedEffect(progress) { progress.animateTo(1f, tween(1000, easing = LinearEasing)) }
    Canvas(modifier) {
        val stroke = 2.dp.toPx()
        val bottom = size.height + stroke
        if (history.size < 2) return@Canvas
        fun rate(traffic: Traffic) = if (upload) traffic.up else traffic.down
        val top = maxOf(history.maxOf { rate(it) }.toFloat() * 1.1f, 8192f)
        val step = size.width / (HISTORY - 2)
        val start = size.width - step * (history.size - 1) + step * (1f - progress.value)
        val end = start + step * (history.size - 1)
        val line = Path().apply {
            history.forEachIndexed { index, traffic ->
                val x = start + step * index
                val y = bottom - (bottom - stroke) * (rate(traffic).toFloat() / top)
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
    val icons = listOf(LineIcons.Rules, LineIcons.Globe, LineIcons.Target)
    AppCard {
        CardHeader(stringResource(R.string.outbound_mode), LineIcons.Split)
        Row(Modifier.weight(1f).fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 18.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Mode.entries.forEachIndexed { index, mode ->
                val selected = mode == status.mode
                val shape = RoundedCornerShape(
                    topStart = if (index == 0) 26.dp else 12.dp,
                    bottomStart = if (index == 0) 26.dp else 12.dp,
                    topEnd = if (index == Mode.entries.lastIndex) 26.dp else 12.dp,
                    bottomEnd = if (index == Mode.entries.lastIndex) 26.dp else 12.dp,
                )
                val fill by animateColorAsState(if (selected) palette.accent else palette.block, tween(200), label = "mode")
                Column(
                    Modifier.weight(1f).fillMaxHeight().clip(shape).background(fill)
                        .clickable(enabled = AppViewModel.BUSY_MODE !in busy) { vm.setMode(mode) },
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    val foreground = if (selected) palette.onAccent else palette.ink2
                    Icon(icons[index], contentDescription = null, tint = foreground, modifier = Modifier.size(18.dp))
                    Text(stringResource(modeLabel(mode)), style = MaterialTheme.typography.labelLarge, color = foreground, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun DashboardCardContent(
    card: DashboardCard,
    vm: AppViewModel,
    snapshot: Snapshot?,
    onConnect: () -> Unit,
    onOpen: (Page) -> Unit,
    onOpenGroup: (String?) -> Unit,
) {
    val engine = vm.engine
    val colors = palette
    when (card) {
        DashboardCard.MODE -> ModeCard(vm)
        DashboardCard.SPEED -> AppCard {
            CardHeader(stringResource(R.string.network_speed), LineIcons.Speed)
            Row(Modifier.weight(1f).fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 18.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(true, false).forEach { upload ->
                    val now = snapshot?.history?.lastOrNull()
                    val rate = if (upload) now?.up else now?.down
                    val total = if (upload) snapshot?.connections?.uploadTotal else snapshot?.connections?.downloadTotal
                    val (number, unit) = byteParts(rate ?: 0u, perSecond = true)
                    Box(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(22.dp)).background(colors.block)) {
                        SpeedChart(snapshot?.history.orEmpty(), upload, Modifier.fillMaxWidth().height(70.dp).align(Alignment.BottomCenter))
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Icon(if (upload) LineIcons.ArrowUp else LineIcons.ArrowDown, null, Modifier.size(16.dp), tint = if (upload) colors.ink2 else colors.accent)
                                Text(stringResource(if (upload) R.string.upload else R.string.download), style = MaterialTheme.typography.labelLarge, color = colors.ink2)
                            }
                            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(number, style = MaterialTheme.typography.headlineMedium.tabular(), maxLines = 1)
                                Text(unit, style = MaterialTheme.typography.labelLarge, color = colors.ink2, modifier = Modifier.padding(bottom = 3.dp))
                            }
                            Text(stringResource(R.string.traffic_sum, bytes(total ?: 0u)), style = MaterialTheme.typography.bodySmall.tabular(), color = colors.ink2)
                        }
                    }
                }
            }
        }
        DashboardCard.CURRENT_NODE -> ProxyGroupsCard(vm) { onOpenGroup(it) }
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
    val preview by vm.profilePreview.collectAsStateWithLifecycle()
    val current = profiles.firstOrNull { it.selected }
    val title = current?.let { profileName(it.kind, it.name) }
        ?: stringResource(if (profiles.isEmpty()) R.string.add_subscription else R.string.no_profile)
    val info = preview?.takeIf { it.profileId == current?.id }
    AppCard(onClick = onClick) {
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, top = 12.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(LineIcons.FileText, null, Modifier.size(18.dp), tint = colors.ink2)
            Text(stringResource(R.string.profile_title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            if (current?.kind == io.github.yuuukicreation.po0clash.core.ProfileKind.SUBSCRIPTION) {
                androidx.compose.material3.IconButton(onClick = { vm.updateProfile(current.id) }, modifier = Modifier.size(32.dp)) {
                    Icon(LineIcons.Refresh, stringResource(R.string.update), Modifier.size(20.dp), tint = colors.ink2)
                }
            }
            Icon(LineIcons.ChevronLeft, null, Modifier.size(20.dp).rotate(180f), tint = colors.ink2)
        }
        Column(Modifier.weight(1f).fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 10.dp, bottom = 18.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (current != null) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(current.updatedAt?.let { stringResource(R.string.updated, relativeTime(it)) } ?: "—", style = MaterialTheme.typography.bodySmall, color = colors.ink2)
                    Text(stringResource(if (current.kind == io.github.yuuukicreation.po0clash.core.ProfileKind.SUBSCRIPTION) R.string.profile_remote else R.string.local_file), style = MaterialTheme.typography.bodySmall, color = colors.ink2)
                }
            }
            if (current != null) Row(Modifier.fillMaxWidth()) {
                val counts = listOf(info?.groups?.size to R.string.proxy_group_title, info?.proxyCount to R.string.proxies, info?.ruleCount to R.string.rules)
                counts.forEachIndexed { index, (count, label) ->
                    Column(Modifier.weight(if (index == 0) 2f else 1f)) {
                        Text(count?.toString() ?: "—", style = MaterialTheme.typography.headlineSmall.copy(fontSize = 20.sp, lineHeight = 25.sp).tabular())
                        Text(stringResource(label), style = MaterialTheme.typography.bodySmall, color = colors.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}

private fun cardLabel(card: DashboardCard) = when (card) {
    DashboardCard.CURRENT_NODE -> R.string.proxy_group_title
    DashboardCard.SPEED -> R.string.network_speed
    DashboardCard.MODE -> R.string.outbound_mode
    DashboardCard.TAKEOVER -> R.string.takeover
    DashboardCard.WHITELIST -> R.string.whitelist_enabled
    DashboardCard.TRAFFIC -> R.string.traffic_total
    DashboardCard.CONNECTIONS -> R.string.connections
    DashboardCard.MEMORY -> R.string.memory
    DashboardCard.INTRANET_IP -> R.string.intranet_ip
    DashboardCard.SUBSCRIPTION -> R.string.profile_title
    DashboardCard.EXIT_IP -> R.string.exit_ip
}

@Composable
private fun HiddenDashboardCards(vm: AppViewModel, shown: List<DashboardCard>) {
    val hidden = DashboardCard.entries - shown.toSet()
    if (hidden.isNotEmpty()) {
        SectionHeader(stringResource(R.string.hidden_cards))
        hidden.forEach { card ->
            NavRow(stringResource(cardLabel(card)), icon = LineIcons.Plus) { vm.setAppSettings { it.copy(dashboardCards = shown + card) } }
        }
    }
    TextAction(stringResource(R.string.restore_default)) { vm.setAppSettings { it.copy(dashboardCards = DashboardCard.entries) } }
}
