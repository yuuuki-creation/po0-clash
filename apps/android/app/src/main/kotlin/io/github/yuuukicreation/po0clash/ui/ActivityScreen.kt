package io.github.yuuukicreation.po0clash.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.LinkOff
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Connection
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.LogEntry
import io.github.yuuukicreation.po0clash.core.LogLevel
import kotlinx.coroutines.flow.flowOf
import java.text.DateFormat
import java.util.Date

private enum class ActivityTab(@param:StringRes val label: Int) {
    REQUESTS(R.string.requests),
    CONNECTIONS(R.string.connections),
    LOGS(R.string.logs),
}

/** FlClash's requests, connections and logs, newest first; reached from Tools on phones. */
@Composable
fun ActivityScreen(vm: AppViewModel, onBack: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val busy by vm.busy.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(ActivityTab.REQUESTS) }
    var query by rememberSaveable { mutableStateOf("") }
    val requests by remember(tab) {
        if (tab == ActivityTab.REQUESTS) engine.poll { requests().asReversed() } else flowOf(emptyList())
    }.collectAsStateWithLifecycle(emptyList())
    val connections by remember(tab, running) {
        if (tab == ActivityTab.CONNECTIONS && running) engine.poll { connections().items } else flowOf(emptyList())
    }.collectAsStateWithLifecycle(emptyList())
    val logs by remember(tab) {
        if (tab == ActivityTab.LOGS) engine.poll { logs().asReversed() } else flowOf(emptyList())
    }.collectAsStateWithLifecycle(emptyList())
    val needle = query.trim()
    val action = when (tab) {
        ActivityTab.REQUESTS -> PageAction(Icons.Outlined.Delete, stringResource(R.string.clear), enabled = requests.isNotEmpty(), onClick = vm::clearRequests)
        ActivityTab.CONNECTIONS -> PageAction(
            Icons.Outlined.LinkOff,
            stringResource(R.string.close_all),
            enabled = connections.isNotEmpty(),
            busy = AppViewModel.BUSY_CONNECTIONS in busy,
            onClick = vm::closeAllConnections,
        )
        ActivityTab.LOGS -> PageAction(Icons.Outlined.Delete, stringResource(R.string.clear), enabled = logs.isNotEmpty(), onClick = vm::clearLogs)
    }

    val title = stringResource(R.string.activity)
    val list = rememberLazyListState()
    PageScaffold(title, list, actions = listOf(action), onBack = onBack) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(title) }
            item(key = "controls") {
                Column(Modifier.padding(top = 8.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SegmentedPicker(ActivityTab.entries.map { it to stringResource(it.label) }, tab, enabled = true) { tab = it }
                    SearchField(query) { query = it }
                }
            }
            when (tab) {
                ActivityTab.REQUESTS -> {
                    val shown = requests.filter { it.matches(needle) }
                    if (shown.isEmpty()) item { EmptyCard(stringResource(R.string.no_requests), stringResource(R.string.no_requests_body)) }
                    itemsIndexed(shown) { index, request ->
                        ConnectionRow(index, shown.size, request, trailing = { TimeLabel(request.start) })
                    }
                }
                ActivityTab.CONNECTIONS -> {
                    val shown = connections.filter { it.matches(needle) }
                    if (shown.isEmpty()) {
                        item {
                            EmptyCard(
                                stringResource(R.string.no_connections),
                                stringResource(if (running) R.string.no_connections_body else R.string.connect_first),
                            )
                        }
                    }
                    itemsIndexed(shown, key = { _, it -> it.id }) { index, connection ->
                        ConnectionRow(index, shown.size, connection) {
                            Column(horizontalAlignment = Alignment.End) {
                                Text("↑ ${bytes(connection.upload)}", style = MaterialTheme.typography.labelMedium.tabular(), color = apple.secondaryLabel)
                                Text("↓ ${bytes(connection.download)}", style = MaterialTheme.typography.labelMedium.tabular(), color = apple.secondaryLabel)
                            }
                            IconButton(
                                onClick = { vm.closeConnection(connection.id) },
                                enabled = "connection:${connection.id}" !in busy,
                                modifier = Modifier.size(36.dp),
                            ) {
                                Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.close), tint = apple.secondaryLabel)
                            }
                        }
                    }
                }
                ActivityTab.LOGS -> {
                    val shown = logs.filter { needle.isEmpty() || it.message.contains(needle, ignoreCase = true) }
                    if (shown.isEmpty()) item { EmptyCard(stringResource(R.string.no_logs), stringResource(R.string.no_logs_body)) }
                    itemsIndexed(shown) { index, entry -> LogRow(index, shown.size, entry) }
                }
            }
        }
    }
}

private fun Connection.matches(needle: String) = needle.isEmpty() ||
    listOfNotNull(host, destination, process, rule, rulePayload).any { it.contains(needle, ignoreCase = true) } ||
    chains.any { it.contains(needle, ignoreCase = true) }

@Composable
private fun SearchField(query: String, onChange: (String) -> Unit) {
    val colors = apple
    Row(
        Modifier.fillMaxWidth().height(40.dp).background(colors.track, CircleShape).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.Search, contentDescription = null, tint = colors.secondaryLabel, modifier = Modifier.size(20.dp))
        Box(Modifier.weight(1f).padding(start = 8.dp)) {
            if (query.isEmpty()) Text(stringResource(R.string.search), style = MaterialTheme.typography.bodyLarge, color = colors.secondaryLabel)
            BasicTextField(
                query,
                onChange,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = colors.label),
                cursorBrush = SolidColor(colors.accent),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun ConnectionRow(index: Int, count: Int, connection: Connection, trailing: @Composable () -> Unit) {
    val colors = apple
    GroupRow(index, count) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                connection.host.ifBlank { connection.destination },
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.MiddleEllipsis,
            )
            val rule = if (connection.rulePayload.isBlank()) connection.rule else "${connection.rule}(${connection.rulePayload})"
            Text(
                listOfNotNull(connection.network.uppercase(), connection.process, rule).joinToString(" · "),
                style = MaterialTheme.typography.bodySmall,
                color = colors.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (connection.chains.isNotEmpty()) {
                Text(
                    connection.chains.asReversed().joinToString(" → "),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        trailing()
    }
}

@Composable
private fun LogRow(index: Int, count: Int, entry: LogEntry) {
    val colors = apple
    val (label, color) = when (entry.level) {
        LogLevel.ERROR -> "ERROR" to colors.red
        LogLevel.WARNING -> "WARN" to colors.orange
        LogLevel.DEBUG -> "DEBUG" to colors.secondaryLabel
        else -> "INFO" to colors.accent
    }
    GroupRow(index, count) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = color)
                TimeLabel(entry.at)
            }
            Text(entry.message, style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace))
        }
    }
}

@Composable
private fun TimeLabel(epochSeconds: Long) {
    val time = remember(epochSeconds) { DateFormat.getTimeInstance(DateFormat.MEDIUM).format(Date(epochSeconds * 1000)) }
    Text(time, style = MaterialTheme.typography.labelMedium.tabular(), color = apple.secondaryLabel)
}
