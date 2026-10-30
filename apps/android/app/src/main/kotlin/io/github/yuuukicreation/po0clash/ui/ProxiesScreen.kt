package io.github.yuuukicreation.po0clash.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Node
import io.github.yuuukicreation.po0clash.core.ProxyGroup
import kotlinx.coroutines.launch

private val tileShape = RoundedCornerShape(14.dp)

enum class NodeSort(@param:StringRes val label: Int) {
    DEFAULT(R.string.sort_default),
    DELAY(R.string.sort_delay),
    NAME(R.string.sort_name),
}

private fun List<Node>.sortedBy(sort: NodeSort): List<Node> = when (sort) {
    NodeSort.DEFAULT -> this
    NodeSort.DELAY -> sortedBy { node -> node.delay?.takeIf { it > 0u }?.toLong() ?: Long.MAX_VALUE }
    NodeSort.NAME -> sortedBy { it.name.lowercase() }
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
    val sheets = LocalSheets.current
    val scope = rememberCoroutineScope()
    var expanded by rememberSaveable { mutableStateOf<List<String>?>(null) }
    var sort by rememberSaveable { mutableStateOf(NodeSort.DEFAULT) }
    val open = expanded ?: listOfNotNull(groups.firstOrNull()?.name)
    val direct = status.mode == Mode.DIRECT
    val testing = groups.any { AppViewModel.busyDelay(it.name) in busy }
    val list = rememberLazyListState()
    val sortAnchor = rememberAnchor()
    val sortTitle = stringResource(R.string.sort)
    val sortLabels = NodeSort.entries.map { stringResource(it.label) }
    val shown = !direct && groups.isNotEmpty()

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 56.dp) / 160.dp).toInt().coerceAtLeast(2)
        val headerIndex = buildMap {
            var index = 1
            groups.forEachIndexed { i, group ->
                if (i > 0) index++
                put(group.name, index)
                index += 1 + if (group.name in open) (group.nodes.size + columns - 1) / columns else 0
            }
        }
        val actions = listOf(
            PageAction(LineIcons.Sort, sortTitle, enabled = shown, anchor = sortAnchor) {
                sheets.menu(sortAnchor, sortTitle, NodeSort.entries.map { SheetAction(sortLabels[it.ordinal], checked = it == sort) { sort = it } })
            },
            PageAction(LineIcons.Locate, stringResource(R.string.locate_node), enabled = shown && status.currentNode != null) {
                val group = currentGroup(groups, status.currentNode) ?: return@PageAction
                if (group.name !in open) expanded = open + group.name
                scope.launch { list.animateScrollToItem(headerIndex[group.name] ?: 0) }
            },
            PageAction(LineIcons.Bolt, stringResource(R.string.test_all), enabled = shown, busy = testing) {
                groups.forEach { vm.testDelay(it.name) }
            },
        )
        PageScaffold(stringResource(R.string.proxies), list, actions = actions) { padding ->
            LazyColumn(
                state = list,
                modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
                contentPadding = padding,
            ) {
                item {
                    PageTitle(
                        stringResource(R.string.proxies),
                        pluralStringResource(R.plurals.group_count, groups.size, groups.size).takeIf { shown },
                    )
                }
                when {
                    direct -> item {
                        EmptyCard(stringResource(R.string.direct_mode_title), stringResource(R.string.direct_mode_body))
                    }
                    groups.isEmpty() -> item {
                        EmptyCard(stringResource(R.string.no_groups_title), stringResource(R.string.no_groups_body))
                    }
                    else -> groups.forEachIndexed { index, group ->
                        if (index > 0) item(key = "gap:${group.name}") { Spacer(Modifier.height(12.dp)) }
                        groupItems(
                            group = group,
                            nodes = group.nodes.sortedBy(sort),
                            expanded = group.name in open,
                            testing = AppViewModel.busyDelay(group.name) in busy,
                            columns = columns,
                            onToggle = { expanded = if (group.name in open) open - group.name else open + group.name },
                            onTest = { vm.testDelay(group.name) },
                            onSelect = { vm.selectNode(group.name, it) },
                            nodeTesting = { AppViewModel.busyNodeDelay(it) in busy },
                            onTestNode = vm::testNodeDelay,
                        )
                    }
                }
            }
        }
    }
}

/** A group card split into lazy items (header, then one item per row of node tiles) so long node lists stay lazy. */
private fun LazyListScope.groupItems(
    group: ProxyGroup,
    nodes: List<Node>,
    expanded: Boolean,
    testing: Boolean,
    columns: Int,
    onToggle: () -> Unit,
    onTest: () -> Unit,
    onSelect: (String) -> Unit,
    nodeTesting: (String) -> Boolean,
    onTestNode: (String) -> Unit,
) {
    val rows = if (expanded) nodes.chunked(columns) else emptyList()
    item(key = "group:${group.name}") {
        CardSlice(top = true, bottom = rows.isEmpty()) {
            GroupHeader(group, expanded, testing, onToggle, onTest)
        }
    }
    items(rows.withIndex().toList(), key = { (index, _) -> "row:${group.name}:$index" }) { (index, row) ->
        val last = index == rows.lastIndex
        CardSlice(top = false, bottom = last) {
            Row(
                Modifier.padding(start = 12.dp, end = 12.dp, bottom = if (last) 12.dp else 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                row.forEach { node ->
                    NodeTile(
                        node,
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
private fun GroupHeader(group: ProxyGroup, expanded: Boolean, testing: Boolean, onToggle: () -> Unit, onTest: () -> Unit) {
    val colors = apple
    val now = group.nodes.firstOrNull { it.name == group.now }
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onToggle).padding(start = 16.dp, end = 12.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
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
        FillButton(if (expanded) LineIcons.ChevronUp else LineIcons.ChevronDown, stringResource(if (expanded) R.string.collapse else R.string.expand), onClick = onToggle)
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
    selected: Boolean,
    enabled: Boolean,
    testing: Boolean,
    onTest: () -> Unit,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val colors = apple
    Column(
        modifier.clip(tileShape)
            .background(if (selected) colors.accentSoft else colors.cell)
            .then(if (selected) Modifier.border(1.5.dp, colors.accent, tileShape) else Modifier)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                node.name,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (selected) Icon(LineIcons.Check, contentDescription = stringResource(R.string.selected), tint = colors.accent, modifier = Modifier.size(14.dp))
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            val small = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, lineHeight = 16.sp)
            Text(
                node.kind,
                style = small,
                color = colors.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Box(
                Modifier.heightIn(min = 18.dp).clip(CircleShape).clickable(enabled = !testing, onClick = onTest).padding(horizontal = 2.dp),
                contentAlignment = Alignment.Center,
            ) {
                when {
                    testing -> CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 1.5.dp, color = colors.secondaryLabel)
                    node.delay == null -> Icon(
                        LineIcons.Bolt,
                        contentDescription = stringResource(R.string.test_delay),
                        tint = colors.secondaryLabel,
                        modifier = Modifier.size(14.dp),
                    )
                    else -> DelayText(node.delay, small.copy(fontWeight = FontWeight.Medium))
                }
            }
        }
    }
}

/** Under 120 ms green, slower orange, 0 (the core's timeout) red; [dot] adds the status dot in front. */
@Composable
fun DelayText(delay: UInt?, style: TextStyle = MaterialTheme.typography.bodyMedium, dot: Boolean = false) {
    if (delay == null) return
    val colors = apple
    val (text, color, dotColor) = when {
        delay == 0u -> Triple(stringResource(R.string.delay_timeout), colors.red, colors.red)
        delay < 120u -> Triple(stringResource(R.string.delay_ms, delay.toInt()), colors.greenText, colors.green)
        else -> Triple(stringResource(R.string.delay_ms, delay.toInt()), colors.orange, colors.orange)
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        if (dot) Box(Modifier.size(7.dp).background(dotColor, CircleShape))
        Text(text, style = style.tabular(), color = color, maxLines = 1)
    }
}
