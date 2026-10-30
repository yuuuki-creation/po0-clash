package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.GroupIconStyle
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Node
import io.github.yuuukicreation.po0clash.core.ProxiesDensity
import io.github.yuuukicreation.po0clash.core.ProxiesLayout
import io.github.yuuukicreation.po0clash.core.ProxiesSort
import io.github.yuuukicreation.po0clash.core.ProxyGroup
import io.github.yuuukicreation.po0clash.core.ProxyTileStyle
import kotlinx.coroutines.launch

private val tileShape = RoundedCornerShape(14.dp)

private fun List<Node>.sortedBy(sort: ProxiesSort): List<Node> = when (sort) {
    ProxiesSort.PROFILE -> this
    ProxiesSort.DELAY -> sortedBy { node -> node.delay?.takeIf { it > 0u }?.toLong() ?: Long.MAX_VALUE }
    ProxiesSort.NAME -> sortedBy { it.name.lowercase() }
}

private fun ProxiesDensity.tileWidth() = when (this) {
    ProxiesDensity.LOOSE -> 180.dp
    ProxiesDensity.STANDARD -> 150.dp
    ProxiesDensity.TIGHT -> 110.dp
}

/** The group that shows [node] as its choice, the group a user means by "current node". */
fun currentGroup(groups: List<ProxyGroup>, node: String?): ProxyGroup? {
    node ?: return null
    return groups.firstOrNull { it.selectable && it.now == node }
        ?: groups.firstOrNull { it.now == node }
        ?: groups.firstOrNull { group -> group.nodes.any { it.name == node } }
}

@Composable
fun ProxiesScreen(vm: AppViewModel) {
    val engine = vm.engine
    val groups by engine.groups.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val scope = rememberCoroutineScope()
    var expanded by rememberSaveable { mutableStateOf<List<String>?>(null) }
    var tab by rememberSaveable { mutableStateOf<String?>(null) }
    val open = expanded ?: listOfNotNull(groups.firstOrNull()?.name)
    val tabs = settings.proxiesLayout == ProxiesLayout.TABS
    val selected = groups.firstOrNull { it.name == tab } ?: groups.firstOrNull()
    val direct = status.mode == Mode.DIRECT
    val testing = groups.any { AppViewModel.busyDelay(it.name) in busy }
    val list = rememberLazyListState()
    val shown = !direct && groups.isNotEmpty()

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 56.dp) / settings.proxiesDensity.tileWidth()).toInt().coerceAtLeast(1)
        val itemIndex = { group: ProxyGroup, node: String ->
            val row = group.nodes.sortedBy(settings.proxiesSort).indexOfFirst { it.name == node }.coerceAtLeast(0) / columns
            if (tabs) {
                3 + row
            } else {
                var index = 1
                for ((i, g) in groups.withIndex()) {
                    if (i > 0) index++
                    if (g.name == group.name) break
                    index += 1 + if (g.name in open) (g.nodes.size + columns - 1) / columns else 0
                }
                index + 1 + row
            }
        }
        val actions = listOf(
            PageAction(LineIcons.Sort, stringResource(R.string.display), enabled = shown) { sheets.show { ProxiesDisplay(vm) } },
            PageAction(LineIcons.Locate, stringResource(R.string.locate_node), enabled = shown && status.currentNode != null) {
                val node = status.currentNode ?: return@PageAction
                val group = currentGroup(groups, node) ?: return@PageAction
                if (tabs) tab = group.name else if (group.name !in open) expanded = open + group.name
                scope.launch { list.animateScrollToItem(itemIndex(group, node)) }
            },
            PageAction(LineIcons.Bolt, stringResource(R.string.test_all), enabled = shown, busy = testing) {
                groups.forEach { vm.testDelay(it.name) }
            },
        )
        PageScaffold(stringResource(R.string.proxies), list, actions = actions) { padding ->
            LazyColumn(
                state = list,
                modifier = Modifier.fillMaxSize(),
                contentPadding = padding,
            ) {
                item {
                    PageTitle(
                        stringResource(R.string.proxies),
                        pluralStringResource(R.plurals.group_count, groups.size, groups.size).takeIf { shown },
                    )
                }
                val groupItems = { group: ProxyGroup, open: Boolean, onToggle: (() -> Unit)? ->
                    groupItems(
                        group = group,
                        nodes = group.nodes.sortedBy(settings.proxiesSort),
                        expanded = open,
                        testing = AppViewModel.busyDelay(group.name) in busy,
                        columns = columns,
                        style = settings.proxyTileStyle,
                        showIcon = settings.groupIconStyle != GroupIconStyle.HIDDEN,
                        onToggle = onToggle,
                        onTest = { vm.testDelay(group.name) },
                        onSelect = { vm.selectNode(group.name, it) },
                        nodeTesting = { AppViewModel.busyNodeDelay(it) in busy },
                        onTestNode = vm::testNodeDelay,
                    )
                }
                when {
                    direct -> item {
                        EmptyCard(stringResource(R.string.direct_mode_title), stringResource(R.string.direct_mode_body), LineIcons.Unlink)
                    }
                    groups.isEmpty() || selected == null -> item {
                        EmptyCard(stringResource(R.string.no_groups_title), stringResource(R.string.no_groups_body), LineIcons.Globe)
                    }
                    tabs -> {
                        item(key = "tabs") { GroupTabs(groups, selected.name, settings.groupIconStyle) { tab = it } }
                        groupItems(selected, true, null)
                    }
                    else -> groups.forEachIndexed { index, group ->
                        if (index > 0) item(key = "gap:${group.name}") { Spacer(Modifier.height(12.dp)) }
                        groupItems(group, group.name in open) {
                            expanded = if (group.name in open) open - group.name else open + group.name
                        }
                    }
                }
            }
        }
    }
}

/** FlClash's tabbed layout: one capsule per group, the chosen one lifted like a segmented control's thumb. */
@Composable
private fun GroupTabs(groups: List<ProxyGroup>, selected: String, iconStyle: GroupIconStyle, onSelect: (String) -> Unit) {
    val colors = apple
    LazyRow(
        Modifier.fillMaxWidth().padding(bottom = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(groups, key = { it.name }) { group ->
            val active = group.name == selected
            val icon = rememberGroupIcon(group.icon.takeIf { iconStyle != GroupIconStyle.HIDDEN })
            Row(
                Modifier.height(34.dp).clip(CircleShape)
                    .background(if (active) colors.card else colors.track)
                    .clickable(role = Role.Tab, onClickLabel = group.name) { onSelect(group.name) }
                    .padding(horizontal = if (icon != null && iconStyle == GroupIconStyle.ICON_ONLY) 8.dp else 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                icon?.let { Image(it, contentDescription = group.name.takeIf { iconStyle == GroupIconStyle.ICON_ONLY }, modifier = Modifier.size(20.dp).clip(RoundedCornerShape(5.dp))) }
                if (icon == null || iconStyle != GroupIconStyle.ICON_ONLY) {
                    Text(
                        group.name,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (active) colors.accentText else colors.label,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

/** How the proxies page lays groups and nodes out, all kept in the core's app settings. */
@Composable
private fun ColumnScope.ProxiesDisplay(vm: AppViewModel) {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    SheetTitle(stringResource(R.string.display))
    DisplayPicker(
        stringResource(R.string.layout),
        listOf(ProxiesLayout.TABS to stringResource(R.string.layout_tabs), ProxiesLayout.LIST to stringResource(R.string.layout_list)),
        settings.proxiesLayout,
    ) { v -> vm.setAppSettings { it.copy(proxiesLayout = v) } }
    DisplayPicker(
        stringResource(R.string.sort),
        listOf(
            ProxiesSort.PROFILE to stringResource(R.string.sort_default),
            ProxiesSort.DELAY to stringResource(R.string.sort_delay),
            ProxiesSort.NAME to stringResource(R.string.sort_name),
        ),
        settings.proxiesSort,
    ) { v -> vm.setAppSettings { it.copy(proxiesSort = v) } }
    DisplayPicker(
        stringResource(R.string.density),
        listOf(
            ProxiesDensity.LOOSE to stringResource(R.string.density_loose),
            ProxiesDensity.STANDARD to stringResource(R.string.density_standard),
            ProxiesDensity.TIGHT to stringResource(R.string.density_tight),
        ),
        settings.proxiesDensity,
    ) { v -> vm.setAppSettings { it.copy(proxiesDensity = v) } }
    DisplayPicker(
        stringResource(R.string.tile_style),
        listOf(
            ProxyTileStyle.DETAILED to stringResource(R.string.tile_detailed),
            ProxyTileStyle.COMPACT to stringResource(R.string.tile_compact),
            ProxyTileStyle.MINIMAL to stringResource(R.string.tile_minimal),
        ),
        settings.proxyTileStyle,
    ) { v -> vm.setAppSettings { it.copy(proxyTileStyle = v) } }
    DisplayPicker(
        stringResource(R.string.group_icons),
        listOf(
            GroupIconStyle.STANDARD to stringResource(R.string.icon_standard),
            GroupIconStyle.ICON_ONLY to stringResource(R.string.icon_only),
            GroupIconStyle.HIDDEN to stringResource(R.string.icon_hidden),
        ),
        settings.groupIconStyle,
    ) { v -> vm.setAppSettings { it.copy(groupIconStyle = v) } }
    SheetDoneButton(onClick = sheets::dismiss)
}

@Composable
private fun <T> DisplayPicker(label: String, options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = apple.secondaryLabel, modifier = Modifier.padding(start = 4.dp))
        SegmentedPicker(options, selected, enabled = true, onSelect = onSelect)
    }
}

/** A group card split into lazy items (header, then one item per row of node tiles) so long node lists stay lazy. */
private fun LazyListScope.groupItems(
    group: ProxyGroup,
    nodes: List<Node>,
    expanded: Boolean,
    testing: Boolean,
    columns: Int,
    style: ProxyTileStyle,
    showIcon: Boolean,
    onToggle: (() -> Unit)?,
    onTest: () -> Unit,
    onSelect: (String) -> Unit,
    nodeTesting: (String) -> Boolean,
    onTestNode: (String) -> Unit,
) {
    val rows = if (expanded) nodes.chunked(columns) else emptyList()
    item(key = "group:${group.name}") {
        Box(itemMotion()) {
            CardSlice(top = true, bottom = rows.isEmpty()) {
                GroupHeader(group, expanded, testing, showIcon, onToggle, onTest)
            }
        }
    }
    items(rows.withIndex().toList(), key = { (index, _) -> "row:${group.name}:$index" }) { (index, row) ->
        Box(itemMotion()) {
            val last = index == rows.lastIndex
            CardSlice(top = false, bottom = last) {
                Row(
                    Modifier.padding(start = 12.dp, end = 12.dp, bottom = if (last) 12.dp else 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    row.forEach { node ->
                        NodeTile(
                            node,
                            style,
                            selected = node.name == group.now,
                            enabled = group.selectable,
                            testing = nodeTesting(node.name),
                            onTest = { onTestNode(node.name) },
                            modifier = Modifier.weight(1f),
                        ) { onSelect(node.name) }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
private fun CardSlice(top: Boolean, bottom: Boolean, content: @Composable () -> Unit) {
    val topRadius: Dp = if (top) cardRadius else 0.dp
    val bottomRadius: Dp = if (bottom) cardRadius else 0.dp
    Column(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(topRadius, topRadius, bottomRadius, bottomRadius))
            .background(apple.card),
    ) {
        content()
    }
}

@Composable
private fun GroupHeader(group: ProxyGroup, expanded: Boolean, testing: Boolean, showIcon: Boolean, onToggle: (() -> Unit)?, onTest: () -> Unit) {
    val colors = apple
    val icon = rememberGroupIcon(group.icon.takeIf { showIcon })
    val now = group.nodes.firstOrNull { it.name == group.now }
    Row(
        Modifier.fillMaxWidth().then(if (onToggle != null) Modifier.clickable(onClick = onToggle) else Modifier)
            .padding(start = 16.dp, end = 12.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        icon?.let { Image(it, contentDescription = null, modifier = Modifier.padding(end = 4.dp).size(36.dp).clip(RoundedCornerShape(9.dp))) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    group.name,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Chip(group.kind)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    listOfNotNull(group.now, pluralStringResource(R.plurals.node_count, group.nodes.size, group.nodes.size).takeIf { expanded })
                        .joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.secondaryLabel,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (!expanded) {
                    now?.delay?.let {
                        Text(" · ", style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
                        DelayText(it, MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        FillButton(LineIcons.Bolt, stringResource(R.string.test_delay), busy = testing, onClick = onTest)
        if (onToggle != null) {
            FillButton(if (expanded) LineIcons.ChevronUp else LineIcons.ChevronDown, stringResource(if (expanded) R.string.collapse else R.string.expand), onClick = onToggle)
        }
    }
}

@Composable
fun Chip(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, lineHeight = 16.sp),
        fontWeight = FontWeight.Medium,
        color = apple.secondaryLabel,
        maxLines = 1,
        modifier = Modifier.background(apple.track, RoundedCornerShape(6.dp)).padding(horizontal = 7.dp, vertical = 1.dp),
    )
}

@Composable
private fun NodeTile(
    node: Node,
    style: ProxyTileStyle,
    selected: Boolean,
    enabled: Boolean,
    testing: Boolean,
    onTest: () -> Unit,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val colors = apple
    val small = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, lineHeight = 16.sp)
    val delay = @Composable {
        Box(
            Modifier.heightIn(min = 18.dp).clip(CircleShape).clickable(enabled = !testing, onClick = onTest).padding(horizontal = 2.dp),
            contentAlignment = Alignment.Center,
        ) {
            AnimatedContent(
                if (testing) 0 else if (node.delay == null) 1 else 2,
                transitionSpec = { (fadeIn(tween(180)) + scaleIn(initialScale = 0.8f)) togetherWith fadeOut(tween(100)) },
                contentAlignment = Alignment.Center,
                label = "delay",
            ) { state ->
                when (state) {
                    0 -> CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 1.5.dp, color = colors.secondaryLabel)
                    1 -> Icon(LineIcons.Bolt, contentDescription = stringResource(R.string.test_delay), tint = colors.secondaryLabel, modifier = Modifier.size(14.dp))
                    else -> DelayText(node.delay, small.copy(fontWeight = FontWeight.Medium))
                }
            }
        }
    }
    val fill by animateColorAsState(if (selected) colors.accentSoft else colors.cell, label = "tile")
    val edge by animateColorAsState(if (selected) colors.accent else colors.accent.copy(alpha = 0f), label = "edge")
    Column(
        modifier.clip(tileShape)
            .background(fill)
            .border(1.5.dp, edge, tileShape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = if (style == ProxyTileStyle.DETAILED) 10.dp else 8.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                node.name,
                style = if (style == ProxyTileStyle.MINIMAL) small.copy(fontWeight = FontWeight.SemiBold) else MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (style == ProxyTileStyle.COMPACT) {
                delay()
            } else {
                AnimatedVisibility(selected, enter = scaleIn(spring(0.55f, 500f)) + fadeIn(), exit = scaleOut() + fadeOut()) {
                    Icon(LineIcons.Check, contentDescription = stringResource(R.string.selected), tint = colors.accent, modifier = Modifier.size(14.dp))
                }
            }
        }
        if (style == ProxyTileStyle.DETAILED) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(node.kind, style = small, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                delay()
            }
        }
    }
}

/** Under 600 ms green, slower orange, 0 (the core's timeout) red; [dot] adds the status dot in front. */
@Composable
fun DelayText(delay: UInt?, style: TextStyle = MaterialTheme.typography.bodyMedium, dot: Boolean = false) {
    if (delay == null) return
    val colors = apple
    val (text, color, dotColor) = when {
        delay == 0u -> Triple(stringResource(R.string.delay_timeout), colors.red, colors.red)
        delay < 600u -> Triple(stringResource(R.string.delay_ms, delay.toInt()), colors.greenText, colors.green)
        else -> Triple(stringResource(R.string.delay_ms, delay.toInt()), colors.orange, colors.orange)
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        val tint by animateColorAsState(color, label = "delay")
        if (dot) Box(Modifier.size(7.dp).background(dotColor, CircleShape))
        RollingText(text, style.tabular(), color = tint)
    }
}
