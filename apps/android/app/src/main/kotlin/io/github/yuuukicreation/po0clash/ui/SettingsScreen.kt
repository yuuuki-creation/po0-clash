package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.BuildConfig
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Profile
import io.github.yuuukicreation.po0clash.core.ProfileKind
import io.github.yuuukicreation.po0clash.core.WhitelistEntry
import io.github.yuuukicreation.po0clash.core.WhitelistKind
import io.github.yuuukicreation.po0clash.core.WhitelistOutcome
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun SettingsScreen(vm: AppViewModel, snackbar: SnackbarHostState, onBack: () -> Unit) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        uri?.let(vm::exportDiagnostics)
    }

    Box(Modifier.fillMaxSize().background(apple.background)) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = top + 52.dp, bottom = bottom + 32.dp),
        ) {
            profileItems(vm)
            whitelistItems(vm)
            item {
                val busy by vm.busy.collectAsStateWithLifecycle()
                SectionHeader(stringResource(R.string.diagnostics))
                ActionRow(0, 1, stringResource(R.string.export_diagnostics), busy = AppViewModel.BUSY_DIAGNOSTICS in busy) {
                    val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                    export.launch("po0-clash-diagnostics-$stamp.txt")
                }
                SectionFooter(stringResource(R.string.export_diagnostics_hint))
                SectionHeader(stringResource(R.string.about))
                ValueRow(0, 1, stringResource(R.string.version), "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            }
        }
        GlassTopBar(
            title = stringResource(R.string.settings),
            navigation = {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        contentDescription = stringResource(R.string.back),
                        tint = apple.accent,
                        modifier = Modifier.size(32.dp),
                    )
                }
            },
        )
        GlassToastHost(snackbar, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 16.dp))
    }
}

private fun LazyListScope.profileItems(vm: AppViewModel) {
    item { SectionHeader(stringResource(R.string.subscriptions)) }
    item(key = "profiles") {
        val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
        val busy by vm.busy.collectAsStateWithLifecycle()
        val sheets = LocalSheets.current
        val count = profiles.size + 2
        Column {
            profiles.forEachIndexed { index, profile ->
                ProfileRow(index, count, profile, AppViewModel.busyProfile(profile.id) in busy, vm, sheets)
            }
            val adding = AppViewModel.BUSY_PROFILES in busy
            val addTitle = stringResource(R.string.add_subscription)
            val urlHint = stringResource(R.string.subscription_url)
            val add = stringResource(R.string.add)
            ActionRow(profiles.size, count, addTitle, Icons.Filled.Add, busy = adding) {
                sheets.show { TextSheet(addTitle, urlHint, multiline = false, confirm = add) { text, _ -> vm.addSubscription(text) } }
            }
            val importTitle = stringResource(R.string.import_links)
            val linksHint = stringResource(R.string.share_links)
            ActionRow(profiles.size + 1, count, importTitle, Icons.Outlined.Share) {
                sheets.show { TextSheet(importTitle, linksHint, multiline = true, confirm = add) { text, _ -> vm.importLinks(text) } }
            }
        }
    }
}

@Composable
private fun ProfileRow(index: Int, count: Int, profile: Profile, busy: Boolean, vm: AppViewModel, sheets: Sheets) {
    val name = profileName(profile.kind, profile.name)
    val update = stringResource(R.string.update)
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, name)
    GroupRow(index, count, onClick = { vm.selectProfile(profile.id) }) {
        RowText(name, profileDetails(profile))
        Box(Modifier.size(22.dp)) {
            if (profile.selected) Icon(Icons.Filled.Check, contentDescription = null, tint = apple.accent)
        }
        if (busy) {
            SmallProgress()
        } else {
            IconButton(
                onClick = {
                    sheets.show {
                        ActionSheet(
                            name,
                            listOfNotNull(
                                SheetAction(update) { vm.updateProfile(profile.id) }.takeIf { profile.kind == ProfileKind.SUBSCRIPTION },
                                SheetAction(delete, destructive = true) {
                                    sheets.show { ActionSheet(confirm, listOf(SheetAction(delete, destructive = true) { vm.removeProfile(profile.id) })) }
                                },
                            ),
                        )
                    }
                },
            ) {
                Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.more), tint = apple.secondaryLabel)
            }
        }
    }
}

@Composable
private fun profileDetails(profile: Profile): String? {
    val lines = mutableListOf<String>()
    profile.usage?.let { usage ->
        val used = bytes(usage.upload + usage.download)
        lines += if (usage.total > 0u) stringResource(R.string.usage, used, bytes(usage.total)) else used
        usage.expire?.takeIf { it > 0 }?.let { lines += stringResource(R.string.expires, date(it)) }
    }
    profile.updatedAt?.let { lines += stringResource(R.string.updated, relativeTime(it)) }
    return lines.takeIf { it.isNotEmpty() }?.joinToString("\n")
}

private fun LazyListScope.whitelistItems(vm: AppViewModel) {
    item { SectionHeader(stringResource(R.string.whitelist)) }
    item(key = "whitelist-switch") {
        val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
        val busy by vm.busy.collectAsStateWithLifecycle()
        GroupRow(0, whitelist.entries.size + 3) {
            RowText(stringResource(R.string.whitelist_enabled))
            Switch(
                checked = whitelist.enabled,
                onCheckedChange = vm::setWhitelistEnabled,
                enabled = AppViewModel.BUSY_WHITELIST !in busy,
                colors = appleSwitchColors(),
                thumbContent = {},
            )
        }
    }
    item(key = "whitelist-entries") {
        val whitelist by vm.engine.whitelist.collectAsStateWithLifecycle()
        val busy by vm.busy.collectAsStateWithLifecycle()
        val sheets = LocalSheets.current
        val count = whitelist.entries.size + 3
        val delete = stringResource(R.string.delete)
        Column {
            whitelist.entries.forEachIndexed { index, entry ->
                val confirm = stringResource(R.string.delete_title, entry.name.ifBlank { entry.label })
                WhitelistRow(index + 1, count, entry) {
                    sheets.show { ActionSheet(confirm, listOf(SheetAction(delete, destructive = true) { vm.removeWhitelist(entry.id) })) }
                }
            }
            val addTitle = stringResource(R.string.whitelist_add)
            val hint = stringResource(R.string.whitelist_text)
            val nameHint = stringResource(R.string.whitelist_name)
            val add = stringResource(R.string.add)
            ActionRow(count - 2, count, addTitle, Icons.Filled.Add, busy = AppViewModel.BUSY_WHITELIST in busy) {
                sheets.show {
                    TextSheet(addTitle, hint, multiline = true, confirm = add, namePlaceholder = nameHint) { text, name ->
                        vm.addWhitelist(text, name)
                    }
                }
            }
            ActionRow(
                count - 1,
                count,
                stringResource(R.string.whitelist_now),
                Icons.Outlined.Refresh,
                busy = AppViewModel.BUSY_WHITELIST_NOW in busy,
                onClick = vm::whitelistNow,
            )
        }
        SectionFooter(stringResource(R.string.whitelist_hint))
    }
}

@Composable
private fun WhitelistRow(index: Int, count: Int, entry: WhitelistEntry, onDelete: () -> Unit) {
    val colors = apple
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
        Column(Modifier.weight(1f)) {
            Text(entry.name.ifBlank { entry.label }, style = MaterialTheme.typography.bodyLarge)
            Text("$kind · ${entry.label}", style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
            Text(resultText, style = MaterialTheme.typography.bodySmall, color = resultColor)
        }
        IconButton(onClick = onDelete) {
            Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.delete), tint = colors.secondaryLabel)
        }
    }
}

private fun outcomeLabel(outcome: WhitelistOutcome) = when (outcome) {
    WhitelistOutcome.APPLIED -> R.string.outcome_applied
    WhitelistOutcome.NOT_APPLIED -> R.string.outcome_not_applied
    WhitelistOutcome.DISABLED -> R.string.outcome_disabled
    WhitelistOutcome.REJECTED -> R.string.outcome_rejected
    WhitelistOutcome.ERROR -> R.string.outcome_error
}
