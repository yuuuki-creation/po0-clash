package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState

@Composable
fun CurrentOutboundCard(vm: AppViewModel, onConnect: () -> Unit, onOpenGroup: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val groups by engine.groups.collectAsStateWithLifecycle()
    val exit by engine.exitIp.collectAsStateWithLifecycle()
    val since by engine.connectedAt.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val starting = active && !running
    val group = currentGroup(groups, status.currentNode) ?: groups.firstOrNull()
    val label = stringResource(if (starting) R.string.state_starting else if (running) R.string.state_running else R.string.state_stopped)
    val control = stringResource(if (active) R.string.disconnect else R.string.connect)
    val colors = palette

    AppCard {
        Row(Modifier.fillMaxSize().padding(20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(LineIcons.Activity, null, Modifier.size(18.dp), tint = colors.ink2)
                    Text(
                        label,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (running) colors.good else colors.ink2,
                        modifier = Modifier.clip(CircleShape).background(if (running) colors.good.copy(alpha = 0.12f) else colors.track)
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                    )
                }
                Column(Modifier.clickable(onClick = engine::refreshExitIp)) {
                    Text(stringResource(R.string.exit_ip), style = MaterialTheme.typography.labelMedium, color = colors.ink2)
                    Text(exit?.ip ?: "—", style = MaterialTheme.typography.headlineSmall.tabular(), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (!exit?.country.isNullOrEmpty()) Text(exit!!.country!!, style = MaterialTheme.typography.bodySmall, color = colors.ink2)
                }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(colors.track.copy(alpha = 0.5f))
                        .clickable(onClick = onOpenGroup).padding(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    Text(group?.name ?: stringResource(R.string.current_node), style = MaterialTheme.typography.labelSmall, color = colors.ink2, maxLines = 1)
                    Text(status.currentNode ?: group?.now ?: stringResource(R.string.connect_first_short), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                FilledIconButton(
                    onClick = { if (active) vm.disconnect() else onConnect() },
                    enabled = !starting && (active || profiles.any { it.selected }),
                    modifier = Modifier.size(76.dp),
                ) {
                    if (starting) CircularProgressIndicator(Modifier.size(28.dp), strokeWidth = 3.dp)
                    else Icon(if (active) Icons.Filled.Stop else Icons.Filled.PlayArrow, control, Modifier.size(32.dp))
                }
                Spacer(Modifier.height(8.dp))
                Text(if (active && since != null) elapsed(since!!) else control, style = MaterialTheme.typography.labelSmall.tabular(), color = colors.ink2)
            }
        }
    }
}
