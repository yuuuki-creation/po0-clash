package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.WhitelistEntry
import io.github.yuuukicreation.po0clash.core.WhitelistKind
import io.github.yuuukicreation.po0clash.core.WhitelistOutcome
import io.github.yuuukicreation.po0clash.core.WhitelistState

@Composable
fun WhitelistScreen(vm: AppViewModel) {
    val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val addTitle = stringResource(R.string.whitelist_add)
    val hint = stringResource(R.string.whitelist_text)
    val nameHint = stringResource(R.string.whitelist_name)
    val add = stringResource(R.string.add)
    val actions = listOf(
        PageAction(
            Icons.Outlined.Refresh,
            stringResource(R.string.whitelist_now),
            enabled = whitelist.entries.isNotEmpty(),
            busy = AppViewModel.BUSY_WHITELIST_NOW in busy,
            onClick = vm::whitelistNow,
        ),
        PageAction(Icons.Filled.Add, addTitle, busy = AppViewModel.BUSY_WHITELIST in busy) {
            sheets.show {
                TextSheet(addTitle, hint, multiline = true, confirm = add, namePlaceholder = nameHint) { text, name ->
                    vm.addWhitelist(text, name)
                }
            }
        },
    )

    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.whitelist), list, actions) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.whitelist)) }
            item(key = "switch") {
                Column(Modifier.padding(top = 8.dp)) {
                    GroupRow(0, 1) {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(R.string.whitelist_enabled), style = MaterialTheme.typography.bodyLarge)
                            Text(whitelistSummary(whitelist), style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel)
                        }
                        AppleSwitch(whitelist.enabled, vm::setWhitelistEnabled, enabled = AppViewModel.BUSY_WHITELIST !in busy)
                    }
                    SectionFooter(stringResource(R.string.whitelist_hint))
                }
            }
            item { SectionHeader(stringResource(R.string.whitelist_entries)) }
            if (whitelist.entries.isEmpty()) {
                item { EmptyCard(stringResource(R.string.whitelist_none), stringResource(R.string.whitelist_empty_body)) }
            }
            itemsIndexed(whitelist.entries, key = { _, entry -> entry.id }) { index, entry ->
                EntryRow(index, whitelist.entries.size, entry, vm)
            }
        }
    }
}

@Composable
private fun EntryRow(index: Int, count: Int, entry: WhitelistEntry, vm: AppViewModel) {
    val colors = apple
    val sheets = LocalSheets.current
    val anchor = rememberAnchor()
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, entry.name.ifBlank { entry.label })
    val result = entry.result
    val outcome = result?.outcome
    val resultColor = when (outcome) {
        WhitelistOutcome.APPLIED -> colors.green
        WhitelistOutcome.REJECTED, WhitelistOutcome.ERROR -> colors.red
        else -> colors.secondaryLabel
    }
    val resultText = if (result == null || outcome == null) {
        stringResource(R.string.whitelist_pending)
    } else {
        listOfNotNull(stringResource(outcomeLabel(outcome)), result.ip, relativeTime(result.at)).joinToString(" · ") +
            (result.message?.let { "\n$it" } ?: "")
    }
    val kind = if (entry.kind == WhitelistKind.PO0) "po0" else "ggy"
    GroupRow(index, count) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                entry.name.ifBlank { entry.label },
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text("$kind · ${entry.label}", style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
            Text(resultText, style = MaterialTheme.typography.bodySmall, color = resultColor)
        }
        IconButton(
            onClick = { sheets.menu(anchor, confirm, listOf(SheetAction(delete, destructive = true) { vm.removeWhitelist(entry.id) })) },
            modifier = Modifier.anchor(anchor),
        ) {
            Icon(Icons.Outlined.Delete, contentDescription = delete, tint = colors.secondaryLabel)
        }
    }
}

@Composable
fun whitelistSummary(whitelist: WhitelistState): String {
    val entries = whitelist.entries
    if (entries.isEmpty()) return stringResource(R.string.whitelist_none)
    val applied = entries.count { it.result?.outcome == WhitelistOutcome.APPLIED }
    return pluralStringResource(R.plurals.whitelist_summary, entries.size, applied, entries.size)
}

private fun outcomeLabel(outcome: WhitelistOutcome) = when (outcome) {
    WhitelistOutcome.APPLIED -> R.string.outcome_applied
    WhitelistOutcome.NOT_APPLIED -> R.string.outcome_not_applied
    WhitelistOutcome.DISABLED -> R.string.outcome_disabled
    WhitelistOutcome.REJECTED -> R.string.outcome_rejected
    WhitelistOutcome.ERROR -> R.string.outcome_error
}
