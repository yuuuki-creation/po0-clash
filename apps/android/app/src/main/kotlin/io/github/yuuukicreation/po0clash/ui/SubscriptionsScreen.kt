package io.github.yuuukicreation.po0clash.ui

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Profile
import io.github.yuuukicreation.po0clash.core.ProfileKind

@Composable
fun SubscriptionsScreen(vm: AppViewModel) {
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val add = stringResource(R.string.add)
    val importTitle = stringResource(R.string.import_links)
    val linksHint = stringResource(R.string.share_links)
    val addTitle = stringResource(R.string.add_subscription)
    val urlHint = stringResource(R.string.subscription_url)
    val adding = AppViewModel.BUSY_PROFILES in busy
    val actions = listOf(
        PageAction(Icons.Outlined.Link, importTitle, enabled = !adding) {
            sheets.show { TextSheet(importTitle, linksHint, multiline = true, confirm = add) { text, _ -> vm.importLinks(text) } }
        },
        PageAction(Icons.Filled.Add, addTitle, busy = adding) {
            sheets.show { TextSheet(addTitle, urlHint, multiline = false, confirm = add) { text, _ -> vm.addSubscription(text) } }
        },
    )

    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.subscriptions), list, actions) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.subscriptions)) }
            if (profiles.isEmpty()) {
                item { EmptyCard(stringResource(R.string.empty_title), stringResource(R.string.empty_body)) }
            }
            itemsIndexed(profiles, key = { _, profile -> profile.id }) { index, profile ->
                ProfileRow(index, profiles.size, profile, AppViewModel.busyProfile(profile.id) in busy, vm)
            }
        }
    }
}

@Composable
private fun ProfileRow(index: Int, count: Int, profile: Profile, busy: Boolean, vm: AppViewModel) {
    val sheets = LocalSheets.current
    val anchor = rememberAnchor()
    val name = profileName(profile.kind, profile.name)
    val update = stringResource(R.string.update)
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, name)
    GroupRow(index, count, onClick = { vm.selectProfile(profile.id) }) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Column {
                Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                profile.url?.let { Uri.parse(it).host }?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel, maxLines = 1)
                }
            }
            ProfileUsage(profile, showUpdated = true)
        }
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            if (profile.selected) {
                Icon(Icons.Filled.Check, contentDescription = stringResource(R.string.selected), tint = apple.accent, modifier = Modifier.size(22.dp))
            }
        }
        Box(Modifier.size(36.dp).anchor(anchor), contentAlignment = Alignment.Center) {
            if (busy) {
                SmallProgress()
            } else {
                IconButton(
                    onClick = {
                        sheets.menu(
                            anchor,
                            name,
                            listOfNotNull(
                                SheetAction(update) { vm.updateProfile(profile.id) }.takeIf { profile.kind == ProfileKind.SUBSCRIPTION },
                                SheetAction(delete, destructive = true) {
                                    sheets.menu(anchor, confirm, listOf(SheetAction(delete, destructive = true) { vm.removeProfile(profile.id) }))
                                },
                            ),
                        )
                    },
                ) {
                    Icon(Icons.Filled.MoreHoriz, contentDescription = stringResource(R.string.more), tint = apple.accent)
                }
            }
        }
    }
}

/** The usage bar with used / total and expiry, then optionally when the profile was last updated. */
@Composable
fun ProfileUsage(profile: Profile, showUpdated: Boolean = false) {
    val colors = apple
    val usage = profile.usage
    if (usage != null && usage.total > 0u) {
        val used = usage.upload + usage.download
        val fraction = (used.toDouble() / usage.total.toDouble()).coerceIn(0.0, 1.0).toFloat()
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.fillMaxWidth().height(6.dp).background(colors.track, CircleShape)) {
                Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(colors.accent, CircleShape))
            }
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    stringResource(R.string.usage, bytes(used), bytes(usage.total)),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.secondaryLabel,
                    modifier = Modifier.padding(end = 12.dp),
                )
                usage.expire?.takeIf { it > 0 }?.let {
                    Text(stringResource(R.string.expires, date(it)), style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
                }
            }
        }
    }
    if (showUpdated) {
        profile.updatedAt?.let {
            Text(stringResource(R.string.updated, relativeTime(it)), style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
        }
    }
}

@Composable
fun profileName(kind: ProfileKind, name: String): String =
    if (kind == ProfileKind.LINKS) stringResource(R.string.links_profile) else name
