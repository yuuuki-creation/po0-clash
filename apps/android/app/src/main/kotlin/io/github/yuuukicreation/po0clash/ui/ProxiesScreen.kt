package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Mode
import io.github.yuuukicreation.po0clash.core.Node
import io.github.yuuukicreation.po0clash.core.ProxyGroup

private val nodeShape = RoundedCornerShape(12.dp)

@Composable
fun ProxiesScreen(vm: AppViewModel) {
    val engine = vm.engine
    val groups by engine.groups.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    var expanded by rememberSaveable { mutableStateOf<List<String>?>(null) }
    val open = expanded ?: listOfNotNull(groups.firstOrNull()?.name)
    val direct = status.mode == Mode.DIRECT
    val testing = groups.any { AppViewModel.busyDelay(it.name) in busy }
    val testAll = PageAction(
        Icons.Outlined.Speed,
        stringResource(R.string.test_all),
        enabled = !direct && groups.isNotEmpty(),
        busy = testing,
    ) { groups.forEach { vm.testDelay(it.name) } }

    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.proxies), list, actions = listOf(testAll)) { padding ->
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val columns = ((maxWidth - 56.dp) / 160.dp).toInt().coerceAtLeast(2)
            LazyColumn(
                state = list,
                modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
                contentPadding = padding,
            ) {
                item { PageTitle(stringResource(R.string.proxies)) }
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
                            expanded = group.name in open,
                            testing = AppViewModel.busyDelay(group.name) in busy,
                            columns = columns,
                            onToggle = { expanded = if (group.name in open) open - group.name else open + group.name },
                            onTest = { vm.testDelay(group.name) },
                            onSelect = { vm.selectNode(group.name, it) },
                        )
                    }
                }
            }
        }
    }
}

/** A group card split into lazy items (header, then one item per row of node cells) so long node lists stay lazy. */
private fun LazyListScope.groupItems(
    group: ProxyGroup,
    expanded: Boolean,
    testing: Boolean,
    columns: Int,
    onToggle: () -> Unit,
    onTest: () -> Unit,
    onSelect: (String) -> Unit,
) {
    val rows = if (expanded) group.nodes.chunked(columns) else emptyList()
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
                    NodeCell(
                        node,
                        selected = node.name == group.now,
                        enabled = group.selectable,
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
    val angle by animateFloatAsState(if (expanded) 90f else 0f, label = "chevron")
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onToggle).padding(start = 16.dp, end = 8.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    group.name,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text(
                    group.kind,
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.secondaryLabel,
                    modifier = Modifier.padding(start = 8.dp),
                )
            }
            Text(
                group.now ?: "—",
                style = MaterialTheme.typography.bodyMedium,
                color = colors.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            group.nodes.size.toString(),
            style = MaterialTheme.typography.bodyMedium.tabular(),
            color = colors.secondaryLabel,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
        IconButton(onClick = onTest, enabled = !testing) {
            if (testing) {
                SmallProgress()
            } else {
                Icon(Icons.Outlined.Speed, contentDescription = stringResource(R.string.test_delay), tint = colors.accent)
            }
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = colors.secondaryLabel,
            modifier = Modifier.rotate(angle),
        )
    }
}

@Composable
private fun NodeCell(node: Node, selected: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = apple
    Column(
        modifier.clip(nodeShape)
            .background(if (selected) colors.accent.copy(alpha = 0.12f) else colors.cell)
            .then(if (selected) Modifier.border(1.5.dp, colors.accent, nodeShape) else Modifier)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(node.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                node.kind,
                style = MaterialTheme.typography.labelMedium,
                color = colors.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            DelayText(node.delay, MaterialTheme.typography.labelMedium)
        }
    }
}

/** Under 300 ms green, slower orange, 0 (the core's timeout) red. */
@Composable
fun DelayText(delay: UInt?, style: TextStyle = MaterialTheme.typography.bodyMedium) {
    if (delay == null) return
    val colors = apple
    val (text, color) = when {
        delay == 0u -> stringResource(R.string.delay_timeout) to colors.red
        delay < 300u -> stringResource(R.string.delay_ms, delay.toInt()) to colors.green
        else -> stringResource(R.string.delay_ms, delay.toInt()) to colors.orange
    }
    Text(text, style = style.tabular(), color = color, maxLines = 1)
}
