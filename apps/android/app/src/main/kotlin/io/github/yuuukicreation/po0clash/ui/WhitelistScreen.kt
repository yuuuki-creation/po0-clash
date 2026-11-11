package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.WhitelistEntry
import io.github.yuuukicreation.po0clash.core.WhitelistKind
import io.github.yuuukicreation.po0clash.core.WhitelistOutcome

@Composable
fun WhitelistScreen(vm: AppViewModel) {
    val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val addTitle = stringResource(R.string.whitelist_add)
    val hint = stringResource(R.string.whitelist_text)
    val nameHint = stringResource(R.string.whitelist_name)
    val add = stringResource(R.string.add)
    val checking = AppViewModel.BUSY_WHITELIST_NOW in busy
    val actions = listOf(
        PageAction(
            LineIcons.Refresh,
            stringResource(R.string.whitelist_now),
            enabled = whitelist.enabled && whitelist.entries.isNotEmpty(),
            busy = checking,
            onClick = vm::whitelistNow,
        ),
    )
    val fab = FabAction(LineIcons.Plus, addTitle, busy = AppViewModel.BUSY_WHITELIST in busy) {
        sheets.show {
            TextSheet(addTitle, hint, multiline = true, confirm = add, namePlaceholder = nameHint) { text, name ->
                vm.addWhitelist(text, name)
            }
        }
    }
    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.whitelist), list, actions, fab = fab) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            item(key = "switch") {
                GroupRow {
                    Text(stringResource(R.string.whitelist_enabled), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    Po0Switch(whitelist.enabled, vm::setWhitelistEnabled, enabled = AppViewModel.BUSY_WHITELIST !in busy)
                }
            }
            item(key = "title") { SectionHeader(stringResource(R.string.whitelist_entries)) }
            if (whitelist.entries.isEmpty()) {
                item(key = "empty") { EmptyState(stringResource(R.string.whitelist_none), LineIcons.ShieldCheck) }
            }
            items(whitelist.entries, key = { entry -> entry.id }) { entry ->
                Box(itemMotion()) {
                    EntryRow(entry, whitelist.enabled, checking, vm)
                }
            }
        }
    }
}

private fun WhitelistEntry.kindLabel() = if (kind == WhitelistKind.PO0) "po0" else "ggy"

@Composable
private fun EntryRow(entry: WhitelistEntry, enabled: Boolean, checking: Boolean, vm: AppViewModel) {
    val colors = palette
    val sheets = LocalSheets.current
    val delete = stringResource(R.string.delete)
    val name = entry.name.ifBlank { entry.label }
    val confirm = stringResource(R.string.delete_title, name)
    val outcome = entry.result?.outcome
    val failed = outcome == WhitelistOutcome.REJECTED || outcome == WhitelistOutcome.ERROR
    val (dot, text) = when {
        !enabled -> colors.ink3 to stringResource(R.string.outcome_disabled)
        checking -> colors.warn to stringResource(R.string.whitelist_checking)
        outcome == null -> colors.ink3 to stringResource(R.string.whitelist_pending)
        else -> dotColor(outcome, colors) to stringResource(outcomeLabel(outcome))
    }
    GroupRow(endPadding = 4.dp, onClick = { sheets.show { EntryDetail(entry, name) } }) {
        Text(entry.kindLabel(), style = MaterialTheme.typography.bodyMedium, color = colors.ink2, modifier = Modifier.width(34.dp))
        Column(Modifier.weight(1f)) {
            Text(name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (failed && enabled) {
                entry.result?.message?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = colors.bad, maxLines = 2, overflow = TextOverflow.Ellipsis) }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatusDot(dot, pulsing = checking && enabled, size = 8.dp)
            Text(text, style = MaterialTheme.typography.bodyMedium, color = colors.ink2, maxLines = 1)
        }
        AppIconButton(LineIcons.Trash, delete) {
            sheets.confirm(confirm, delete) { vm.removeWhitelist(entry.id) }
        }
    }
}

@Composable
private fun EntryDetail(entry: WhitelistEntry, name: String) {
    val sheets = LocalSheets.current
    val colors = palette
    val result = entry.result
    val outcome = result?.outcome
    SheetTitle(name)
    Text("${entry.kindLabel()} · ${entry.label}", style = MaterialTheme.typography.bodyLarge)
    Text(
        if (result == null || outcome == null) {
            stringResource(R.string.whitelist_pending)
        } else {
            listOfNotNull(stringResource(outcomeLabel(outcome)), result.ip, relativeTime(result.at)).joinToString(" · ")
        },
        style = MaterialTheme.typography.bodyMedium,
        color = colors.ink2,
    )
    result?.message?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = if (outcome == WhitelistOutcome.APPLIED) colors.ink2 else colors.bad) }
    SheetDoneButton(sheets::dismiss)
}

private fun dotColor(outcome: WhitelistOutcome, colors: Po0Colors): Color = when (outcome) {
    WhitelistOutcome.APPLIED -> colors.accent
    WhitelistOutcome.REJECTED, WhitelistOutcome.ERROR -> colors.bad
    else -> colors.ink3
}

private fun outcomeLabel(outcome: WhitelistOutcome) = when (outcome) {
    WhitelistOutcome.APPLIED -> R.string.outcome_applied
    WhitelistOutcome.NOT_APPLIED -> R.string.outcome_not_applied
    WhitelistOutcome.DISABLED -> R.string.outcome_disabled
    WhitelistOutcome.REJECTED -> R.string.outcome_rejected
    WhitelistOutcome.ERROR -> R.string.outcome_error
}
