// Layout follows FlClash 0.9.3's dashboard/widgets/current_outbound.dart (GPL-3.0).
package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.IpQuality
import io.github.yuuukicreation.po0clash.core.IpType
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal fun cookiePath(center: Offset, radius: Float, lobes: Int, amount: Float = 1f): Path = Path().apply {
    repeat(241) { index ->
        val angle = index * 2 * PI / 240
        val r = radius * (1 - amount * 0.05f + amount * 0.05f * cos(lobes * angle)).toFloat()
        val x = center.x + r * cos(angle).toFloat()
        val y = center.y + r * sin(angle).toFloat()
        if (index == 0) moveTo(x, y) else lineTo(x, y)
    }
    close()
}

@Composable
fun CurrentOutboundCard(vm: AppViewModel, onConnect: () -> Unit) {
    val engine = vm.engine
    val status by engine.status.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val exit by engine.exitIp.collectAsStateWithLifecycle()
    val since by engine.connectedAt.collectAsStateWithLifecycle()
    val quality by produceState<IpQuality?>(null, exit?.ip) {
        value = null
        exit?.ip?.let { ip -> value = withContext(Dispatchers.IO) { runCatching { engine.core.ipQuality(ip, false) }.getOrNull() } }
    }
    val running = status.engine == EngineState.Running
    val starting = active && !running
    val colors = palette
    val enabled = active || profiles.any { it.selected }
    val label = stringResource(if (starting) R.string.state_starting else if (running) R.string.status_running else R.string.status_stopped)
    val control = stringResource(if (active) R.string.disconnect else R.string.connect)
    val morph by animateFloatAsState(if (running) 1f else 0f, if (LocalReduceMotion.current) snap() else tween(450), label = "connectionShape")
    val kind = quality?.kind?.let { value ->
        stringResource(when (value) {
            IpType.RESIDENTIAL -> R.string.ip_residential
            IpType.MOBILE -> R.string.ip_mobile
            IpType.BUSINESS -> R.string.ip_business
            IpType.HOSTING -> R.string.ip_hosting
        })
    }
    AppCard {
        Box(Modifier.fillMaxSize()) {
            Canvas(Modifier.fillMaxSize()) {
                drawPath(cookiePath(Offset(size.width - 60.dp.toPx(), 54.dp.toPx()), 120.dp.toPx(), 12), colors.block)
            }
            Column(Modifier.fillMaxSize().padding(start = 20.dp, end = 16.dp, top = 18.dp, bottom = 18.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(LineIcons.Status, null, Modifier.size(18.dp), tint = colors.ink2)
                    Text(stringResource(R.string.status_title), style = MaterialTheme.typography.titleMedium)
                    Text(label, style = MaterialTheme.typography.labelMedium, maxLines = 1,
                        color = if (running) colors.good else colors.ink2,
                        modifier = Modifier.clip(CircleShape).background(if (running) colors.good.copy(alpha = 0.12f) else colors.block)
                            .padding(horizontal = 10.dp, vertical = 4.dp))
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(Modifier.weight(1f).clickable(onClick = engine::refreshExitIp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                            Canvas(Modifier.fillMaxSize()) {
                                val d = size.minDimension * 0.2f
                                val r = size.minDimension * 0.3f
                                for (x in listOf(-d, d)) for (y in listOf(-d, d)) drawCircle(colors.block, r, center + Offset(x, y))
                            }
                            Text(exit?.country?.takeIf { it.isNotBlank() } ?: "—", style = MaterialTheme.typography.titleSmall, color = colors.ink2)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(exit?.ip ?: "—", style = MaterialTheme.typography.headlineSmall.tabular(), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(kind ?: "—", style = MaterialTheme.typography.labelMedium, color = colors.ink2,
                                modifier = Modifier.clip(CircleShape).background(colors.block).padding(horizontal = 12.dp, vertical = 4.dp))
                        }
                    }
                    Box(
                        Modifier.size(88.dp).clip(CircleShape).semantics { contentDescription = control }.clickable(enabled = enabled, role = Role.Button) {
                            if (active) vm.disconnect() else onConnect()
                        },
                        contentAlignment = Alignment.Center,
                    ) {
                        Canvas(Modifier.fillMaxSize()) { drawPath(cookiePath(center, size.minDimension / 2, 9, morph), if (enabled) colors.accent else colors.track) }
                        if (starting) CircularProgressIndicator(Modifier.size(28.dp), color = colors.onAccent, strokeWidth = 3.dp)
                        else Icon(if (running) Icons.Filled.Pause else Icons.Filled.PlayArrow, control, Modifier.size(30.dp), tint = if (enabled) colors.onAccent else colors.ink2)
                    }
                }
                Row(Modifier.fillMaxWidth().padding(end = 98.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    Column {
                        Text(stringResource(R.string.run_time), style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp, lineHeight = 16.sp), color = colors.ink2)
                        Text(since?.takeIf { running }?.let { elapsed(it) } ?: "—", style = MaterialTheme.typography.titleSmall.tabular())
                    }
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.ip_organization), style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp, lineHeight = 16.sp), color = colors.ink2)
                        Text(quality?.organization ?: quality?.asn?.let { "AS$it" } ?: "—", style = MaterialTheme.typography.titleSmall,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}
