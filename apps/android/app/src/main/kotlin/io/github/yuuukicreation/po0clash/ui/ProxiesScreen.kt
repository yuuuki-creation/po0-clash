package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
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

private fun ProxiesDensity.rowHeight() = when (this) {
    ProxiesDensity.LOOSE -> 64.dp
    ProxiesDensity.STANDARD -> 56.dp
    ProxiesDensity.TIGHT -> 48.dp
}

/** The group that shows [node] as its choice, the group a user means by "current node". */
fun currentGroup(groups: List<ProxyGroup>, node: String?): ProxyGroup? {
    node ?: return null
    return groups.firstOrNull { it.selectable && it.now == node }
        ?: groups.firstOrNull { it.now == node }
        ?: groups.firstOrNull { group -> group.nodes.any { it.name == node } }
}

/** A group's delay is its current choice's, following nested groups down to a real node. */
private fun ProxyGroup.delay(groups: Map<String, ProxyGroup>, depth: Int = 0): UInt? {
    val choice = now ?: return null
    val nested = groups[choice]
    if (nested != null && depth < 8) return nested.delay(groups, depth + 1)
    return nodes.firstOrNull { it.name == choice }?.delay
}

/** One query covers group names and nodes: a hit on the group's name keeps all its nodes, otherwise only the hits show. */
internal fun ProxyGroup.matches(query: String) =
    query.isEmpty() || name.contains(query, ignoreCase = true) || nodes.any { it.name.contains(query, ignoreCase = true) }

internal fun ProxyGroup.shownNodes(query: String) =
    if (query.isEmpty() || name.contains(query, ignoreCase = true)) nodes else nodes.filter { it.name.contains(query, ignoreCase = true) }

@Composable
fun ProxiesScreen(vm: AppViewModel, opened: String?, onOpen: (String?) -> Unit) {
    val engine = vm.engine
    val groups by engine.groups.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    var query by rememberSaveable { mutableStateOf("") }
    var searching by rememberSaveable { mutableStateOf(false) }
    var locating by remember { mutableStateOf(false) }
    var expanded by rememberSaveable { mutableStateOf<List<String>?>(null) }
    val wide = LocalWindowWidth.current.isExpanded
    val twoLevel = settings.proxiesLayout == ProxiesLayout.TABS
    val shown = status.mode != Mode.DIRECT && groups.isNotEmpty()
    val needle = query.trim()
    val visible = groups.filter { it.matches(needle) }
    val current = groups.firstOrNull { it.name == opened }
    val selected = current?.takeIf { it in visible } ?: visible.firstOrNull() ?: groups.firstOrNull()
    val nested = remember(groups) { groups.associateBy { it.name } }
    val onSecondLevel = twoLevel && current != null
    val groupList = rememberLazyListState()
    var listedGroup by remember { mutableStateOf(selected?.name) }
    if (wide || current != null) listedGroup = selected?.name
    val nodeList = remember(listedGroup) {
        val index = selected?.let { it.nodes.sortedBy(settings.proxiesSort).indexOfFirst { node -> node.name == it.now } } ?: 0
        LazyListState((index - 2).coerceAtLeast(0))
    }
    val open = expanded ?: listOfNotNull(groups.firstOrNull()?.name)
    val anchor = rememberAnchor()
    val viewMenu = proxyViewMenu(vm, anchor)
    val sortMenu = listOf(
        ProxiesSort.PROFILE to stringResource(R.string.sort_default),
        ProxiesSort.DELAY to stringResource(R.string.sort_delay),
        ProxiesSort.NAME to stringResource(R.string.sort_name),
    ).map { (sort, label) ->
        SheetAction(label, checked = settings.proxiesSort == sort) { vm.setAppSettings { it.copy(proxiesSort = sort) } }
    }
    val locateLabel = stringResource(R.string.locate_node)
    val actions = listOf(
        PageAction(LineIcons.Search, stringResource(R.string.search), enabled = shown) { searching = true },
        PageAction(
            LineIcons.Bolt,
            stringResource(R.string.test_delay),
            enabled = shown,
            busy = if (onSecondLevel) AppViewModel.busyDelay(current.name) in busy else groups.any { AppViewModel.busyDelay(it.name) in busy },
        ) {
            if (onSecondLevel) vm.testDelay(current.name) else groups.forEach { vm.testDelay(it.name) }
        },
        PageAction(LineIcons.More, stringResource(R.string.more), enabled = shown, anchor = anchor) {
            val main = groups.firstOrNull()
            val locate = SheetAction(locateLabel) {
                query = ""
                searching = false
                onOpen(main?.name)
                if (!twoLevel && main != null && main.name !in open) expanded = open + main.name
                locating = true
            }
            sheets.menu(anchor, listOf(locate) + sortMenu.mapIndexed { i, it -> it.copy(dividerBefore = i == 0) } + viewMenu)
        },
    )
    BackHandler(enabled = searching) {
        searching = false
        query = ""
    }
    PageScaffold(
        title = if (onSecondLevel) current.name else stringResource(R.string.proxies),
        scrolled = if (onSecondLevel || wide) nodeList.canScrollBackward || groupList.canScrollBackward else groupList.canScrollBackward,
        actions = actions,
        onBack = if (onSecondLevel && !wide) ({ onOpen(null) }) else null,
        search = if (searching) AppBarSearch(query, { query = it }, { searching = false; query = "" }) else null,
        capped = false,
    ) { padding ->
        val groupRows = @Composable { list: LazyListState, chevron: Boolean, contentPadding: PaddingValues, modifier: Modifier ->
            LazyColumn(modifier, state = list, contentPadding = contentPadding) {
                if (visible.isEmpty()) item { ValueRow(0, 1, stringResource(R.string.no_match), "") }
                itemsIndexed(visible, key = { _, it -> it.name }) { index, group ->
                    ProxyGroupRow(group, index, visible.size, group.delay(nested), active = wide && group == selected, chevron, settings.groupIconStyle) {
                        onOpen(group.name)
                    }
                }
            }
        }
        val nodeRows = @Composable { group: ProxyGroup, contentPadding: PaddingValues, modifier: Modifier ->
            val nodes = group.shownNodes(needle).sortedBy(settings.proxiesSort)
            val testing = AppViewModel.busyDelay(group.name) in busy
            val showKind = LocalWindowWidth.current >= 600.dp
            LaunchedEffect(locating) {
                if (!locating) return@LaunchedEffect
                nodes.indexOfFirst { it.name == group.now }.takeIf { it >= 0 }?.let { nodeList.animateScrollToItem(it) }
                locating = false
            }
            LazyColumn(modifier, state = nodeList, contentPadding = contentPadding) {
                if (nodes.isEmpty()) item { ValueRow(0, 1, stringResource(R.string.no_match), "") }
                itemsIndexed(nodes, key = { _, it -> it.name }) { index, node ->
                    GroupRow(
                        index,
                        nodes.size,
                        onClick = if (group.selectable) ({ vm.selectNode(group.name, node.name) }) else null,
                        minHeight = settings.proxiesDensity.rowHeight(),
                    ) {
                        Po0Radio(node.name == group.now)
                        Text(node.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                        if (settings.proxyTileStyle == ProxyTileStyle.DETAILED && showKind) {
                            Text(node.kind, style = MaterialTheme.typography.bodyMedium, color = palette.ink2, maxLines = 1)
                        }
                        if (settings.proxyTileStyle != ProxyTileStyle.MINIMAL) {
                            NodeDelay(nested[node.name]?.delay(nested) ?: node.delay, testing || AppViewModel.busyNodeDelay(node.name) in busy) {
                                vm.testNodeDelay(node.name)
                            }
                        }
                    }
                }
            }
        }
        when {
            status.mode == Mode.DIRECT -> FullEmptyState(stringResource(R.string.direct_mode_title), LineIcons.Unlink, padding)
            groups.isEmpty() || selected == null -> FullEmptyState(stringResource(R.string.no_groups_title), LineIcons.Globe, padding)
            !twoLevel -> ExpandableGroups(
                vm,
                groupList,
                visible,
                needle,
                nested,
                open,
                onToggle = { name -> expanded = if (name in open) open - name else open + name },
                locating = locating,
                onLocated = { locating = false },
                padding = padding,
            )
            wide -> Row(Modifier.fillMaxSize()) {
                val top = padding.calculateTopPadding()
                val bottom = padding.calculateBottomPadding()
                groupRows(groupList, false, PaddingValues(start = 16.dp, top = top, bottom = bottom), Modifier.width(340.dp + 16.dp))
                nodeRows(selected, PaddingValues(start = 12.dp, end = 16.dp, top = top, bottom = bottom), Modifier.weight(1f))
            }
            else -> PushHost(
                target = current?.name,
                animate = settings.pageAnimation,
                onBack = { onOpen(null) },
                label = "proxyLevels",
                backEnabled = !searching,
            ) { name ->
                val group = name?.let { nested[it] }
                if (group == null) {
                    groupRows(groupList, true, padding, Modifier.fillMaxSize())
                } else {
                    nodeRows(group, padding, Modifier.fillMaxSize())
                }
            }
        }
    }
}

@Composable
private fun proxyViewMenu(vm: AppViewModel, anchor: Anchor): List<SheetAction> {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    fun <T> entry(label: String, options: List<Pair<T, String>>, selected: T, divider: Boolean = false, apply: (T) -> Unit) = SheetAction(
        label,
        value = options.firstOrNull { it.first == selected }?.second,
        dividerBefore = divider,
    ) {
        sheets.menu(anchor, options.map { (value, text) -> SheetAction(text, checked = value == selected) { apply(value) } })
    }
    return listOf(
        entry(
            stringResource(R.string.layout),
            listOf(ProxiesLayout.TABS to stringResource(R.string.layout_tabs), ProxiesLayout.LIST to stringResource(R.string.layout_list)),
            settings.proxiesLayout,
            divider = true,
        ) { v -> vm.setAppSettings { it.copy(proxiesLayout = v) } },
        entry(
            stringResource(R.string.density),
            listOf(
                ProxiesDensity.LOOSE to stringResource(R.string.density_loose),
                ProxiesDensity.STANDARD to stringResource(R.string.density_standard),
                ProxiesDensity.TIGHT to stringResource(R.string.density_tight),
            ),
            settings.proxiesDensity,
        ) { v -> vm.setAppSettings { it.copy(proxiesDensity = v) } },
        entry(
            stringResource(R.string.tile_style),
            listOf(
                ProxyTileStyle.DETAILED to stringResource(R.string.tile_detailed),
                ProxyTileStyle.COMPACT to stringResource(R.string.tile_compact),
                ProxyTileStyle.MINIMAL to stringResource(R.string.tile_minimal),
            ),
            settings.proxyTileStyle,
        ) { v -> vm.setAppSettings { it.copy(proxyTileStyle = v) } },
        entry(
            stringResource(R.string.group_icons),
            listOf(
                GroupIconStyle.STANDARD to stringResource(R.string.icon_standard),
                GroupIconStyle.ICON_ONLY to stringResource(R.string.icon_only),
                GroupIconStyle.HIDDEN to stringResource(R.string.icon_hidden),
            ),
            settings.groupIconStyle,
        ) { v -> vm.setAppSettings { it.copy(groupIconStyle = v) } },
    )
}

@Composable
private fun ProxyGroupRow(
    group: ProxyGroup,
    index: Int,
    count: Int,
    delay: UInt?,
    active: Boolean,
    chevron: Boolean,
    iconStyle: GroupIconStyle,
    trailing: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    val icon = rememberGroupIcon(group.icon.takeIf { iconStyle != GroupIconStyle.HIDDEN })
    GroupRow(index, count, onClick = onClick, minHeight = 72.dp, fill = if (active) palette.sel else palette.card) {
        icon?.let { Image(it, contentDescription = group.name, modifier = Modifier.size(36.dp).clip(RoundedCornerShape(8.dp))) }
        Column(Modifier.weight(1f)) {
            if (icon == null || iconStyle != GroupIconStyle.ICON_ONLY) {
                Text(group.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            group.now?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = palette.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
        DelayText(delay, placeholder = true)
        trailing?.invoke()
        if (chevron) Chevron()
    }
}

@Composable
private fun NodeDelay(delay: UInt?, waiting: Boolean, onTest: () -> Unit) {
    val shown by animateFloatAsState(if (waiting) 0.4f else 1f, tween(150), label = "delayWait")
    Box(
        Modifier.alpha(shown).clip(CircleShape).clickable(enabled = !waiting, onClick = onTest).padding(horizontal = 4.dp, vertical = 8.dp),
    ) {
        DelayText(delay, placeholder = true)
    }
}

/** Data, so it changes at once: secondary text, warning from 600 ms, error for the core's 0 (timed out). */
@Composable
fun DelayText(delay: UInt?, style: TextStyle = MaterialTheme.typography.bodyMedium, placeholder: Boolean = false) {
    val colors = palette
    when {
        delay == null -> if (placeholder) Text("—", style = style.tabular(), color = colors.ink2, maxLines = 1)
        delay == 0u -> Text(stringResource(R.string.delay_timeout), style = style.tabular(), color = colors.bad, maxLines = 1)
        else -> Text(
            stringResource(R.string.delay_ms, delay.toInt()),
            style = style.tabular(),
            color = if (delay < 600u) colors.ink2 else colors.warn,
            maxLines = 1,
        )
    }
}

/** The `list` layout: every group on one page, expanding into a grid of node tiles. */
@Composable
private fun ExpandableGroups(
    vm: AppViewModel,
    list: LazyListState,
    groups: List<ProxyGroup>,
    query: String,
    nested: Map<String, ProxyGroup>,
    open: List<String>,
    onToggle: (String) -> Unit,
    locating: Boolean,
    onLocated: () -> Unit,
    padding: PaddingValues,
) {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 56.dp) / settings.proxiesDensity.tileWidth()).toInt().coerceAtLeast(1)
        val isOpen = { group: ProxyGroup -> group.name in open || query.isNotEmpty() }
        LaunchedEffect(locating) {
            if (!locating) return@LaunchedEffect
            val main = groups.firstOrNull() ?: return@LaunchedEffect
            val row = main.nodes.sortedBy(settings.proxiesSort).indexOfFirst { it.name == main.now }.coerceAtLeast(0) / columns
            list.animateScrollToItem(1 + row)
            onLocated()
        }
        LazyColumn(state = list, modifier = Modifier.fillMaxSize(), contentPadding = padding) {
            if (groups.isEmpty()) item { ValueRow(0, 1, stringResource(R.string.no_match), "") }
            groups.forEachIndexed { index, group ->
                if (index > 0) item(key = "gap:${group.name}") { Spacer(Modifier.height(12.dp)) }
                expandableGroup(
                    group,
                    group.shownNodes(query).sortedBy(settings.proxiesSort),
                    isOpen(group),
                    delay = group.delay(nested),
                    testing = { AppViewModel.busyDelay(group.name) in busy },
                    columns = columns,
                    style = settings.proxyTileStyle,
                    iconStyle = settings.groupIconStyle,
                    onToggle = { onToggle(group.name) },
                    onTest = { vm.testDelay(group.name) },
                    onSelect = { vm.selectNode(group.name, it) },
                    nodeDelay = { node -> nested[node.name]?.delay(nested) ?: node.delay },
                    nodeTesting = { AppViewModel.busyNodeDelay(it) in busy },
                    onTestNode = vm::testNodeDelay,
                )
            }
        }
    }
}

private fun LazyListScope.expandableGroup(
    group: ProxyGroup,
    nodes: List<Node>,
    expanded: Boolean,
    delay: UInt?,
    testing: () -> Boolean,
    columns: Int,
    style: ProxyTileStyle,
    iconStyle: GroupIconStyle,
    onToggle: () -> Unit,
    onTest: () -> Unit,
    onSelect: (String) -> Unit,
    nodeDelay: (Node) -> UInt?,
    nodeTesting: (String) -> Boolean,
    onTestNode: (String) -> Unit,
) {
    val rows = if (expanded) nodes.chunked(columns) else emptyList()
    item(key = "group:${group.name}") {
        Box(itemMotion()) {
            ProxyGroupRow(
                group,
                0,
                if (rows.isEmpty()) 1 else 2,
                delay,
                active = false,
                chevron = false,
                iconStyle = iconStyle,
                trailing = {
                    AppIconButton(LineIcons.Bolt, stringResource(R.string.test_delay), busy = testing(), onClick = onTest)
                    AppIconButton(
                        if (expanded) LineIcons.ChevronUp else LineIcons.ChevronDown,
                        stringResource(if (expanded) R.string.collapse else R.string.expand),
                        onClick = onToggle,
                    )
                },
                onClick = onToggle,
            )
        }
    }
    itemsIndexed(rows, key = { index, _ -> "row:${group.name}:$index" }) { index, row ->
        val last = index == rows.lastIndex
        Row(
            itemMotion().padding(top = if (index == 0) 2.dp else 0.dp)
                .clip(RoundedCornerShape(topStart = cornerOf(index == 0), topEnd = cornerOf(index == 0), bottomStart = if (last) 16.dp else 0.dp, bottomEnd = if (last) 16.dp else 0.dp))
                .background(palette.card)
                .padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = if (last) 12.dp else 0.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            row.forEach { node ->
                NodeTile(
                    node,
                    style,
                    selected = node.name == group.now,
                    enabled = group.selectable,
                    delay = nodeDelay(node),
                    testing = testing() || nodeTesting(node.name),
                    onTest = { onTestNode(node.name) },
                    modifier = Modifier.weight(1f),
                ) { onSelect(node.name) }
            }
            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

private fun cornerOf(first: Boolean): Dp = if (first) 4.dp else 0.dp

@Composable
private fun NodeTile(
    node: Node,
    style: ProxyTileStyle,
    selected: Boolean,
    enabled: Boolean,
    delay: UInt?,
    testing: Boolean,
    onTest: () -> Unit,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val colors = palette
    val fill by animateColorAsState(if (selected) colors.sel else colors.bg, tween(150, easing = StandardEasing), label = "tile")
    Column(
        modifier.clip(RoundedCornerShape(12.dp)).background(fill).clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = if (style == ProxyTileStyle.DETAILED) 10.dp else 8.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Po0Radio(selected)
            Text(node.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            if (style == ProxyTileStyle.COMPACT) NodeDelay(delay, testing, onTest)
        }
        if (style == ProxyTileStyle.DETAILED) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(node.kind, style = MaterialTheme.typography.bodyMedium, color = colors.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                NodeDelay(delay, testing, onTest)
            }
        }
    }
}
