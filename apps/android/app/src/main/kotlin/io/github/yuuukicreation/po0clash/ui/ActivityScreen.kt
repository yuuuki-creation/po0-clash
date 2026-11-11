package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Connection
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.LogEntry
import io.github.yuuukicreation.po0clash.core.LogLevel
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.flowOf

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
    val captureLogs = vm.appSettings.collectAsStateWithLifecycle().value.captureLogs
    val tabs = if (captureLogs) ActivityTab.entries else ActivityTab.entries - ActivityTab.LOGS
    var picked by rememberSaveable { mutableStateOf(ActivityTab.REQUESTS) }
    val tab = picked.takeIf { it in tabs } ?: ActivityTab.REQUESTS
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
    var level by rememberSaveable { mutableStateOf<LogLevel?>(null) }
    val sheets = LocalSheets.current
    val levelAnchor = rememberAnchor()
    val levelTitle = stringResource(R.string.log_level)
    val allLevels = stringResource(R.string.all)
    val exportLogs = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        uri?.let { vm.exportText(it, logs.asReversed().joinToString("\n") { e -> "${Date(e.at * 1000)} ${e.level} ${e.message}" }) }
    }
    val actions = when (tab) {
        ActivityTab.REQUESTS -> listOf(PageAction(LineIcons.Trash, stringResource(R.string.clear), enabled = requests.isNotEmpty(), onClick = vm::clearRequests))
        ActivityTab.CONNECTIONS -> listOf(
            PageAction(
                LineIcons.Unlink,
                stringResource(R.string.close_all),
                enabled = connections.isNotEmpty(),
                busy = AppViewModel.BUSY_CONNECTIONS in busy,
                onClick = vm::closeAllConnections,
            ),
        )
        ActivityTab.LOGS -> listOf(
            PageAction(LineIcons.Sliders, levelTitle, anchor = levelAnchor) {
                val choices = listOf(null to allLevels) + LEVELS.map { it to levelLabel(it) }
                sheets.menu(levelAnchor, choices.map { (value, label) -> SheetAction(label, checked = value == level) { level = value } })
            },
            PageAction(LineIcons.Download, stringResource(R.string.export), enabled = logs.isNotEmpty()) {
                exportLogs.launch("po0-clash-logs-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}.txt")
            },
            PageAction(LineIcons.Trash, stringResource(R.string.clear), enabled = logs.isNotEmpty(), onClick = vm::clearLogs),
        )
    }
    val showDetail = { connection: Connection, live: Boolean ->
        sheets.show { ConnectionDetail(connection, if (live) ({ vm.closeConnection(connection.id) }) else null) }
    }

    val title = stringResource(R.string.activity)
    val list = rememberLazyListState()
    PageScaffold(title, list, actions = actions, onBack = onBack, capped = false) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            item(key = "controls") {
                Column(Modifier.padding(bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SegmentedPicker(tabs.map { it to stringResource(it.label) }, tab, enabled = true) { picked = it }
                    SearchField(query) { query = it }
                }
            }
            when (tab) {
                ActivityTab.REQUESTS -> {
                    val shown = requests.filter { it.matches(needle) }
                    if (shown.isEmpty()) item { EmptyState(stringResource(R.string.no_requests), LineIcons.Activity) }
                    items(shown) { request ->
                        ConnectionRow(request, onClick = { showDetail(request, false) }, trailing = { TimeLabel(request.start) })
                    }
                }
                ActivityTab.CONNECTIONS -> {
                    val shown = connections.filter { it.matches(needle) }
                    if (shown.isEmpty()) {
                        item {
                            EmptyState(stringResource(R.string.no_connections), LineIcons.Link)
                        }
                    }
                    items(shown, key = { it -> it.id }) { connection ->
                        Box(itemMotion()) {
                            ConnectionRow(connection, onClick = { showDetail(connection, true) }) {
                                Column(horizontalAlignment = Alignment.End) {
                                    Text("↑ ${bytes(connection.upload)}", style = MaterialTheme.typography.bodyMedium.tabular(), color = palette.ink2, maxLines = 1)
                                    Text("↓ ${bytes(connection.download)}", style = MaterialTheme.typography.bodyMedium.tabular(), color = palette.ink2, maxLines = 1)
                                }
                                AppIconButton(
                                    LineIcons.Close,
                                    stringResource(R.string.close),
                                    enabled = "connection:${connection.id}" !in busy,
                                ) { vm.closeConnection(connection.id) }
                            }
                        }
                    }
                }
                ActivityTab.LOGS -> {
                    val minimum = level?.ordinal ?: 0
                    val shown = logs.filter { it.level.ordinal >= minimum && (needle.isEmpty() || it.message.contains(needle, ignoreCase = true)) }
                    if (shown.isEmpty()) item { EmptyState(stringResource(R.string.no_logs), LineIcons.FileText) }
                    items(shown) { entry -> LogRow(entry) }
                }
            }
        }
    }
}

private fun Connection.matches(needle: String) = needle.isEmpty() ||
    listOfNotNull(host, destination, process, rule, rulePayload).any { it.contains(needle, ignoreCase = true) } ||
    chains.any { it.contains(needle, ignoreCase = true) }

@Composable
private fun ConnectionRow(connection: Connection, onClick: () -> Unit, trailing: @Composable () -> Unit) {
    val colors = palette
    GroupRow(onClick = onClick) {
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
                listOfNotNull(connection.network.uppercase(), connection.process, rule).filter(String::isNotBlank).joinToString(" · "),
                style = MaterialTheme.typography.bodyMedium,
                color = colors.ink2,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (connection.chains.isNotEmpty()) {
                Text(
                    connection.chains.asReversed().joinToString(" → "),
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        trailing()
    }
}

private val LEVELS = listOf(LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARNING, LogLevel.ERROR)

private fun levelLabel(level: LogLevel) = when (level) {
    LogLevel.ERROR -> "ERROR"
    LogLevel.WARNING -> "WARN"
    LogLevel.DEBUG -> "DEBUG"
    else -> "INFO"
}

@Composable
private fun ColumnScope.ConnectionDetail(connection: Connection, onClose: (() -> Unit)?) {
    val sheets = LocalSheets.current
    val rows = listOfNotNull(
        stringResource(R.string.destination) to connection.destination,
        stringResource(R.string.source) to connection.source,
        stringResource(R.string.network) to "${connection.network.uppercase()} · ${connection.inbound}",
        connection.process?.let { stringResource(R.string.process) to (connection.processPath ?: it) },
        stringResource(R.string.rule) to listOf(connection.rule, connection.rulePayload).filter(String::isNotBlank).joinToString(" "),
        stringResource(R.string.chain) to connection.chains.asReversed().joinToString(" → "),
        stringResource(R.string.traffic_total) to "↑ ${bytes(connection.upload)} · ↓ ${bytes(connection.download)}",
        stringResource(R.string.started) to DateFormat.getDateTimeInstance().format(Date(connection.start * 1000)),
    ).filter { it.second.isNotBlank() }
    SheetTitle(connection.host.ifBlank { connection.destination })
    SheetBody {
        rows.forEach { (label, value) ->
            GroupRow {
                Text(label, style = MaterialTheme.typography.bodyMedium, color = palette.ink2)
                Text(value, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.End, modifier = Modifier.weight(1f))
            }
        }
    }
    if (onClose != null) {
        SheetButtons(stringResource(R.string.close), onCancel = sheets::dismiss) {
            sheets.dismiss()
            onClose()
        }
    } else {
        SheetDoneButton(sheets::dismiss)
    }
}

@Composable
private fun LogRow(entry: LogEntry) {
    val colors = palette
    val label = levelLabel(entry.level)
    val color = when (entry.level) {
        LogLevel.ERROR -> colors.bad
        LogLevel.WARNING -> colors.warn
        LogLevel.DEBUG -> colors.ink2
        else -> colors.accent
    }
    GroupRow {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = color)
                TimeLabel(entry.at)
            }
            Text(entry.message, style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace))
        }
    }
}

@Composable
private fun TimeLabel(epochSeconds: Long) {
    val time = remember(epochSeconds) { DateFormat.getTimeInstance(DateFormat.MEDIUM).format(Date(epochSeconds * 1000)) }
    Text(time, style = MaterialTheme.typography.bodyMedium.tabular(), color = palette.ink2)
}
