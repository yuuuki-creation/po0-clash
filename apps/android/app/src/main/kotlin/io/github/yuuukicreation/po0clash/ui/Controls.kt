package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun <T> SegmentedPicker(
    options: List<Pair<T, String>>,
    selected: T,
    enabled: Boolean = true,
    modifier: Modifier = Modifier.fillMaxWidth(),
    onSelect: (T) -> Unit,
) {
    SingleChoiceSegmentedButtonRow(modifier = modifier) {
        options.forEachIndexed { index, (value, label) ->
            SegmentedButton(
                selected = value == selected,
                onClick = { onSelect(value) },
                enabled = enabled,
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                label = { Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            )
        }
    }
}

@Composable
fun Po0Switch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true, modifier: Modifier = Modifier) {
    Switch(checked = checked, onCheckedChange = onCheckedChange, modifier = modifier, enabled = enabled)
}

@Composable
fun Po0Radio(selected: Boolean) {
    RadioButton(selected = selected, onClick = null)
}

@Composable
fun StatusDot(color: Color, pulsing: Boolean = false, size: Dp = 10.dp) {
    val tint by animateColorAsState(color, tween(200), label = "dot")
    val fade = if (pulsing && !LocalReduceMotion.current) {
        rememberInfiniteTransition(label = "pulse").animateFloat(
            initialValue = 1f,
            targetValue = 0.3f,
            animationSpec = infiniteRepeatable(tween(800, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "pulse",
        ).value
    } else {
        1f
    }
    Box(Modifier.size(size).alpha(fade).background(tint, CircleShape))
}

@Composable
fun SmallProgress(size: Dp = 20.dp, color: Color = palette.ink2) {
    CircularProgressIndicator(Modifier.size(size), strokeWidth = 2.dp, color = color)
}

@Composable
fun SpinningIcon(icon: ImageVector, tint: Color, modifier: Modifier = Modifier) {
    val angle = if (LocalReduceMotion.current) {
        0f
    } else {
        rememberInfiniteTransition(label = "spin").animateFloat(
            initialValue = 0f,
            targetValue = 360f,
            animationSpec = infiniteRepeatable(tween(800, easing = LinearEasing)),
            label = "spin",
        ).value
    }
    Icon(icon, contentDescription = null, tint = tint, modifier = modifier.size(24.dp).rotate(angle))
}

@Composable
fun AppIconButton(
    icon: ImageVector,
    label: String,
    enabled: Boolean = true,
    busy: Boolean = false,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val colors = palette
    IconButton(onClick = onClick, enabled = enabled && !busy, modifier = modifier.size(44.dp)) {
        when {
            busy && icon == LineIcons.Refresh -> SpinningIcon(icon, colors.ink2)
            busy -> SmallProgress()
            else -> Icon(
                icon,
                contentDescription = label,
                tint = if (enabled) colors.ink2 else colors.ink2.copy(alpha = 0.38f),
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

@Composable
fun TextAction(label: String, enabled: Boolean = true, accent: Boolean = false, onClick: () -> Unit) {
    val colors = palette
    TextButton(
        onClick = onClick,
        enabled = enabled,
        contentPadding = PaddingValues(horizontal = 12.dp),
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelLarge,
            color = if (!enabled) colors.ink3 else if (accent) colors.accent else colors.ink,
        )
    }
}

/** A floating action; with [text] it widens into FlClash's start button, the running time beside the icon. */
data class FabAction(
    val icon: ImageVector,
    val label: String,
    val busy: Boolean = false,
    val text: String? = null,
    val onClick: () -> Unit,
)

@Composable
fun Po0Fab(action: FabAction, modifier: Modifier = Modifier) {
    var lastText by remember { mutableStateOf("") }
    if (action.text != null) lastText = action.text
    FloatingActionButton(onClick = action.onClick, modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(56.dp), contentAlignment = Alignment.Center) {
                if (action.busy) {
                    SmallProgress(color = MaterialTheme.colorScheme.onPrimaryContainer)
                } else {
                    Icon(action.icon, contentDescription = action.label, modifier = Modifier.size(24.dp))
                }
            }
            AnimatedVisibility(action.text != null) {
                Text(
                    lastText,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold).tabular(),
                    maxLines = 1,
                    modifier = Modifier.padding(end = 16.dp),
                )
            }
        }
    }
}
