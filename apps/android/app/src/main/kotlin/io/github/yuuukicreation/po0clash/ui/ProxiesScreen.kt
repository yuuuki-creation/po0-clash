// Layout and styling follow FlClash v0.9.3 (https://github.com/chen08209/FlClash, GPL-3.0), lib/views/proxies.
package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
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
import kotlinx.coroutines.launch

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
    val liveGroups by engine.groups.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val preview by vm.profilePreview.collectAsStateWithLifecycle()
    val groups = liveGroups.ifEmpty { preview?.takeIf { it.profileId == profiles.firstOrNull { profile -> profile.selected }?.id }?.groups.orEmpty() }
    val status by engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    var query by rememberSaveable { mutableStateOf("") }
    var searching by rememberSaveable { mutableStateOf(false) }
    var locating by remember { mutableStateOf(false) }
    var expanded by rememberSaveable { mutableStateOf<List<String>?>(null) }
    val twoLevel = settings.proxiesLayout == ProxiesLayout.TABS
    val running = status.engine == io.github.yuuukicreation.po0clash.core.EngineState.Running
    val shown = status.mode != Mode.DIRECT && groups.isNotEmpty()
    val needle = query.trim()
    val visible = groups.filter { it.matches(needle) }
    val current = groups.firstOrNull { it.name == opened }
    val selected = current?.takeIf { it in visible } ?: visible.firstOrNull() ?: groups.firstOrNull()
    val nested = remember(groups) { groups.associateBy { it.name } }
    val groupList = rememberLazyListState()
    val groupTabs = rememberLazyListState()
    val nodeList = remember(selected?.name) {
        val index = selected?.let { it.nodes.sortedBy(settings.proxiesSort).indexOfFirst { node -> node.name == it.now } } ?: 0
        LazyListState((index - 2).coerceAtLeast(0))
    }
    LaunchedEffect(selected?.name, visible.size) {
        val index = visible.indexOfFirst { it.name == selected?.name }
        if (index >= 0) groupTabs.animateScrollToItem(index)
    }
    val open = expanded ?: emptyList()
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
    val actions = listOfNotNull(
        PageAction(LineIcons.Search, stringResource(R.string.search), enabled = shown) { searching = true },
        (if (twoLevel) PageAction(
            LineIcons.Bolt,
            stringResource(R.string.test_delay),
            enabled = shown && running,
            busy = if (twoLevel && selected != null) AppViewModel.busyDelay(selected.name) in busy else groups.any { AppViewModel.busyDelay(it.name) in busy },
        ) {
            if (selected != null) vm.testDelay(selected.name)
        } else null),
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
        title = stringResource(R.string.proxies),
        scrolled = if (twoLevel) nodeList.canScrollBackward else groupList.canScrollBackward,
        actions = actions,
        search = if (searching) AppBarSearch(query, { query = it }, { searching = false; query = "" }) else null,
        capped = false,
    ) { padding ->
        val nodeRows = @Composable { group: ProxyGroup, contentPadding: PaddingValues, modifier: Modifier ->
            val nodes = group.shownNodes(needle).sortedBy(settings.proxiesSort)
            val testing = AppViewModel.busyDelay(group.name) in busy
            BoxWithConstraints(modifier) {
                val columns = ((maxWidth - 32.dp) / settings.proxiesDensity.tileWidth()).toInt().coerceAtLeast(2)
                val rows = nodes.chunked(columns)
                LaunchedEffect(locating) {
                    if (!locating) return@LaunchedEffect
                    nodes.indexOfFirst { it.name == group.now }.takeIf { it >= 0 }?.let { nodeList.animateScrollToItem(it / columns) }
                    locating = false
                }
                LazyColumn(
                    Modifier.fillMaxSize(),
                    state = nodeList,
                    contentPadding = contentPadding,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (nodes.isEmpty()) item { ValueRow(stringResource(R.string.no_match), "") }
                    itemsIndexed(rows, key = { index, _ -> "tabrow:${group.name}:$index" }) { _, row ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { node ->
                                ProxyCard(
                                    node = node,
                                    style = settings.proxyTileStyle,
                                    selected = node.name == group.now,
                                    enabled = group.selectable,
                                    delay = nested[node.name]?.delay(nested) ?: node.delay,
                                    testing = testing || AppViewModel.busyNodeDelay(node.name) in busy,
                                    onTest = { if (running) vm.testNodeDelay(node.name) },
                                    canTest = running,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    if (group.selectable) vm.selectNode(group.name, node.name)
                                }
                            }
                            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
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
            else -> Column(Modifier.fillMaxSize()) {
                val bottom = padding.calculateBottomPadding()
                GroupTabStrip(
                    groups = visible,
                    selected = selected,
                    iconStyle = settings.groupIconStyle,
                    state = groupTabs,
                    modifier = Modifier.padding(bottom = 8.dp),
                    onSelect = { onOpen(it.name) },
                )
                nodeRows(selected, PaddingValues(start = 16.dp, end = 16.dp, bottom = bottom), Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun GroupTabStrip(
    groups: List<ProxyGroup>,
    selected: ProxyGroup,
    iconStyle: GroupIconStyle,
    state: LazyListState,
    modifier: Modifier = Modifier,
    onSelect: (ProxyGroup) -> Unit,
) {
    val colors = palette
    LazyRow(
        state = state,
        modifier = modifier.fillMaxWidth().padding(vertical = 8.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(groups, key = { it.name }) { group ->
            val active = group.name == selected.name
            val icon = rememberGroupIcon(group.icon.takeIf { iconStyle != GroupIconStyle.HIDDEN })
            Row(
                Modifier.clip(RoundedCornerShape(50))
                    .background(if (active) colors.accent else colors.card)
                    .selectable(selected = active, role = Role.Tab, onClick = { onSelect(group) })
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                icon?.let { Image(it, contentDescription = group.name, modifier = Modifier.size(18.dp).clip(RoundedCornerShape(4.dp))) }
                if (icon == null || iconStyle != GroupIconStyle.ICON_ONLY) {
                    Text(
                        group.name,
                        style = MaterialTheme.typography.titleSmall,
                        color = if (active) colors.onAccent else colors.ink2,
                        maxLines = 1,
                    )
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

/** The group of the list layout: a filled card that folds the nodes beneath it. */
@Composable
private fun GroupHeader(
    group: ProxyGroup,
    expanded: Boolean,
    testing: Boolean,
    iconStyle: GroupIconStyle,
    canTest: Boolean,
    onTest: () -> Unit,
    onToggle: () -> Unit,
    onLocate: (() -> Unit)?,
) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onToggle).padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        GroupAvatar(group, iconStyle)
        Column(Modifier.weight(1f)) {
            Text(group.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(group.now ?: "—", style = MaterialTheme.typography.titleSmall, color = palette.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (expanded) {
            Row(Modifier.clip(RoundedCornerShape(50)).background(palette.block)) {
                androidx.compose.material3.IconButton(onClick = { onLocate?.invoke() }, enabled = onLocate != null, modifier = Modifier.size(32.dp)) {
                    Icon(LineIcons.Target, stringResource(R.string.locate_node), Modifier.size(19.dp), tint = palette.ink2)
                }
                androidx.compose.material3.IconButton(onClick = onTest, enabled = canTest && !testing, modifier = Modifier.size(32.dp)) {
                    if (testing) SmallProgress(14.dp)
                    else Icon(LineIcons.Bolt, stringResource(R.string.test_delay), Modifier.size(19.dp), tint = palette.ink2)
                }
            }
        } else Text(group.kind, style = MaterialTheme.typography.labelLarge, color = palette.ink2)
        androidx.compose.material3.IconButton(onClick = onToggle, modifier = Modifier.size(32.dp).background(palette.block, RoundedCornerShape(50))) {
            Icon(if (expanded) LineIcons.ChevronUp else LineIcons.ChevronDown,
                stringResource(if (expanded) R.string.collapse else R.string.expand), Modifier.size(18.dp), tint = palette.ink2)
        }
    }
}

/** The delay of a node: a bolt until it has been tested; tapping either tests it again. */
@Composable
private fun NodeDelay(delay: UInt?, waiting: Boolean, onTest: () -> Unit, canTest: Boolean = true) {
    Box(
        Modifier.clip(RoundedCornerShape(6.dp)).clickable(enabled = canTest && !waiting, onClick = onTest).height(16.dp),
        contentAlignment = Alignment.Center,
    ) {
        when {
            waiting -> SmallProgress(size = 12.dp)
            delay == null -> Icon(LineIcons.Bolt, contentDescription = stringResource(R.string.test_delay), tint = palette.accent, modifier = Modifier.size(14.dp))
            else -> DelayText(delay)
        }
    }
}

@Composable
fun DelayText(delay: UInt?, style: TextStyle = MaterialTheme.typography.labelSmall) {
    val colors = palette
    when {
        delay == null -> Unit
        delay == 0u -> Text(stringResource(R.string.delay_timeout), style = style.tabular(), color = colors.bad, maxLines = 1)
        else -> Text(
            stringResource(R.string.delay_ms, delay.toInt()),
            style = style.tabular(),
            color = if (delay < 600u) colors.good else colors.warn,
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
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val canTest = status.engine == io.github.yuuukicreation.po0clash.core.EngineState.Running
    val scope = rememberCoroutineScope()
    val busy by vm.busy.collectAsStateWithLifecycle()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 32.dp) / settings.proxiesDensity.tileWidth()).toInt().coerceAtLeast(2)
        val isOpen = { group: ProxyGroup -> group.name in open || query.isNotEmpty() }
        LaunchedEffect(locating) {
            if (!locating) return@LaunchedEffect
            val main = groups.firstOrNull() ?: return@LaunchedEffect
            val row = main.nodes.sortedBy(settings.proxiesSort).indexOfFirst { it.name == main.now }.coerceAtLeast(0) / columns
            list.animateScrollToItem(1 + row)
            onLocated()
        }
        LazyColumn(state = list, modifier = Modifier.fillMaxSize(), contentPadding = padding) {
            if (groups.isEmpty()) item { ValueRow(stringResource(R.string.no_match), "") }
            var cursor = 0
            groups.forEachIndexed { index, group ->
                if (index > 0) {
                    item(key = "gap:${group.name}") { Spacer(Modifier.height(8.dp)) }
                    cursor++
                }
                val groupStart = cursor
                val shownNodes = group.shownNodes(query).sortedBy(settings.proxiesSort)
                val selected = shownNodes.indexOfFirst { it.name == group.now }
                expandableGroup(
                    group,
                    shownNodes,
                    isOpen(group),
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
                    canTest = canTest,
                    onLocate = if (selected < 0) null else { { scope.launch { list.animateScrollToItem(groupStart + 1 + selected / columns) }; Unit } },
                )
                cursor += 1 + if (isOpen(group)) (shownNodes.size + columns - 1) / columns else 0
            }
        }
    }
}

private fun LazyListScope.expandableGroup(
    group: ProxyGroup,
    nodes: List<Node>,
    expanded: Boolean,
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
    canTest: Boolean,
    onLocate: (() -> Unit)?,
) {
    val rows = if (expanded) nodes.chunked(columns) else emptyList()
    item(key = "group:${group.name}") {
        val bottom = if (rows.isEmpty()) 28.dp else 0.dp
        Box(itemMotion().fillMaxWidth().background(palette.card, RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp, bottomStart = bottom, bottomEnd = bottom))) {
            GroupHeader(group, expanded, testing(), iconStyle, canTest, onTest, onToggle, onLocate)
        }
    }
    itemsIndexed(rows, key = { index, _ -> "row:${group.name}:$index" }) { index, row ->
        val bottom = if (index == rows.lastIndex) 28.dp else 0.dp
        Row(itemMotion().fillMaxWidth().background(palette.card, RoundedCornerShape(bottomStart = bottom, bottomEnd = bottom))
            .padding(start = 10.dp, end = 10.dp, bottom = if (index == rows.lastIndex) 10.dp else 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { node ->
                ProxyCard(
                    node,
                    style,
                    selected = node.name == group.now,
                    enabled = group.selectable,
                    delay = nodeDelay(node),
                    testing = testing() || nodeTesting(node.name),
                    onTest = { onTestNode(node.name) },
                    canTest = canTest,
                    modifier = Modifier.weight(1f),
                ) { onSelect(node.name) }
            }
            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

@Composable
private fun ProxyCard(
    node: Node,
    style: ProxyTileStyle,
    selected: Boolean,
    enabled: Boolean,
    delay: UInt?,
    testing: Boolean,
    onTest: () -> Unit,
    canTest: Boolean = true,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val colors = palette
    val nameLines = if (style == ProxyTileStyle.MINIMAL) 1 else 2
    val kind = @Composable { kindModifier: Modifier ->
        Text(
            node.kind,
            style = MaterialTheme.typography.bodySmall,
            color = colors.ink2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = kindModifier,
        )
    }
    AppCard(modifier, filled = true, enabled = enabled, onClick = onClick, corner = 20.dp) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp)) {
            Row(verticalAlignment = Alignment.Top) {
            Text(
                node.name,
                style = MaterialTheme.typography.bodyMedium,
                color = colors.ink,
                minLines = nameLines,
                maxLines = nameLines,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (selected) Box(Modifier.size(22.dp).clip(RoundedCornerShape(50)).background(colors.accent), contentAlignment = Alignment.Center) {
                Icon(LineIcons.Check, null, Modifier.size(15.dp), tint = colors.onAccent)
            }
            }
            Spacer(Modifier.height(8.dp))
            if (style == ProxyTileStyle.DETAILED) {
                kind(Modifier)
                Spacer(Modifier.height(6.dp))
                NodeDelay(delay, testing, onTest, canTest)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    kind(Modifier.weight(1f))
                    NodeDelay(delay, testing, onTest, canTest)
                }
            }
        }
    }
}
