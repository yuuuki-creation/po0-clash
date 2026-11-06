package io.github.yuuukicreation.po0clash.ui

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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
    val colors = palette
    SingleChoiceSegmentedButtonRow(modifier = modifier) {
        options.forEachIndexed { index, (value, label) ->
            val active = value == selected
            SegmentedButton(
                selected = active,
                onClick = { onSelect(value) },
                enabled = enabled,
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                colors = SegmentedButtonDefaults.colors(
                    activeContainerColor = colors.sel,
                    activeContentColor = colors.onSel,
                    activeBorderColor = colors.line,
                    inactiveContainerColor = colors.card,
                    inactiveContentColor = colors.ink2,
                    inactiveBorderColor = colors.line,
                ),
                label = {
                    Text(
                        label,
                        style = MaterialTheme.typography.labelLarge.copy(
                            fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        ),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
            )
        }
    }
}

@Composable
fun Po0Switch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true) {
    val colors = palette
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        enabled = enabled,
        colors = SwitchDefaults.colors(
            checkedThumbColor = colors.onAccent,
            checkedTrackColor = colors.accent,
            checkedBorderColor = colors.accent,
            uncheckedThumbColor = colors.outline,
            uncheckedTrackColor = colors.track,
            uncheckedBorderColor = colors.outline,
        ),
    )
}

@Composable
fun Po0Radio(selected: Boolean) {
    val colors = palette
    RadioButton(
        selected = selected,
        onClick = null,
        colors = RadioButtonDefaults.colors(
            selectedColor = colors.accent,
            unselectedColor = colors.ink3,
        ),
    )
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
            busy && icon == LineIcons.Refresh -> SpinningIcon(icon, colors.ink)
            busy -> SmallProgress(color = colors.ink)
            else -> Icon(icon, contentDescription = label, tint = if (enabled) colors.ink else colors.ink3, modifier = Modifier.size(22.dp))
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

/** The connect button: same width in every state, so the status row does not jump. */
@Composable
fun ConnectButton(label: String, primary: Boolean, busy: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val colors = palette
    val usable = enabled && !busy
    val containerColor = if (primary && !busy) colors.accent else colors.track
    val contentColor = when {
        busy -> colors.ink2
        primary -> colors.onAccent
        else -> colors.ink
    }
    Button(
        onClick = onClick,
        enabled = usable,
        shape = RoundedCornerShape(20.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = containerColor.copy(alpha = if (busy) 1f else 0.5f),
            disabledContentColor = contentColor.copy(alpha = if (busy) 1f else 0.5f),
        ),
        modifier = Modifier.size(128.dp, 40.dp).semantics { contentDescription = label },
    ) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(14.dp).padding(end = 6.dp), color = contentColor, strokeWidth = 2.dp)
        }
        Text(label, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

data class FabAction(val icon: ImageVector, val label: String, val busy: Boolean = false, val onClick: () -> Unit)

@Composable
fun Po0Fab(action: FabAction, modifier: Modifier = Modifier) {
    val colors = palette
    FloatingActionButton(
        onClick = action.onClick,
        modifier = modifier.size(56.dp),
        shape = RoundedCornerShape(16.dp),
        containerColor = colors.fab,
        contentColor = colors.onFab,
        elevation = FloatingActionButtonDefaults.elevation(3.dp, 3.dp, 3.dp, 3.dp),
    ) {
        if (action.busy) {
            SmallProgress(color = colors.onFab)
        } else {
            Icon(action.icon, contentDescription = action.label, modifier = Modifier.size(24.dp))
        }
    }
}
