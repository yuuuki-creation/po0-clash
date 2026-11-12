package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R

@Composable
fun ProxyGroupsCard(vm: AppViewModel, onOpen: (String) -> Unit) {
    val liveGroups by vm.engine.groups.collectAsStateWithLifecycle()
    val preview by vm.profilePreview.collectAsStateWithLifecycle()
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val groups = liveGroups.ifEmpty { preview?.takeIf { it.profileId == profiles.firstOrNull { profile -> profile.selected }?.id }?.groups.orEmpty() }
    AppCard {
        CardHeader(stringResource(R.string.proxy_group_title), LineIcons.Layers)
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (groups.isEmpty()) {
                Text(stringResource(R.string.no_groups_title), style = MaterialTheme.typography.bodyMedium, color = palette.ink2)
            } else groups.take(4).forEach { group ->
                Row(Modifier.fillMaxWidth().clickable { onOpen(group.name) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    GroupAvatar(group, vm.appSettings.value.groupIconStyle)
                    Column(Modifier.weight(1f)) {
                        Text(group.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(group.now ?: "—", style = MaterialTheme.typography.bodySmall, color = palette.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}
