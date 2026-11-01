package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val fieldShape = RoundedCornerShape(24.dp)

/** Outlined segments of equal width; the selected one fills and grows a check. */
@Composable
fun <T> SegmentedPicker(
    options: List<Pair<T, String>>,
    selected: T,
    enabled: Boolean = true,
    modifier: Modifier = Modifier.fillMaxWidth(),
    onSelect: (T) -> Unit,
) {
    val colors = palette
    Row(
        modifier.height(48.dp).clip(fieldShape).border(1.dp, colors.outline, fieldShape).selectableGroup(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        options.forEachIndexed { index, (value, label) ->
            if (index > 0) Box(Modifier.width(1.dp).fillMaxHeight().background(colors.outline))
            val active = value == selected
            val fill by animateColorAsState(if (active) colors.sel else colors.sel.copy(alpha = 0f), tween(150, easing = StandardEasing), label = "segment")
            val reveal by animateFloatAsState(if (active) 1f else 0f, tween(150, easing = StandardEasing), label = "check")
            Row(
                Modifier.weight(1f).fillMaxHeight().background(fill)
                    .selectable(active, enabled, Role.RadioButton) { onSelect(value) }
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (reveal > 0f) {
                    Box(Modifier.width(24.dp * reveal).height(18.dp).clipToBounds().alpha(reveal)) {
                        Icon(
                            LineIcons.Check,
                            contentDescription = null,
                            tint = colors.onSel,
                            modifier = Modifier.wrapContentWidth(Alignment.Start, unbounded = true).size(18.dp),
                        )
                    }
                }
                Text(
                    label,
                    style = MaterialTheme.typography.bodyLarge.copy(fontSize = 15.sp),
                    color = if (active) colors.onSel else colors.ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Material 3's switch at the design's numbers; Compose's own does not take a 200 ms duration. */
@Composable
fun Po0Switch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true) {
    val colors = palette
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val colorSpec = tween<Color>(200, easing = StandardEasing)
    val dpSpec = tween<Dp>(200, easing = StandardEasing)
    val track by animateColorAsState(if (checked) colors.accent else colors.cardHi, colorSpec, label = "track")
    val edge by animateColorAsState(if (checked) colors.accent else colors.outline, colorSpec, label = "edge")
    val thumb by animateColorAsState(if (checked) colors.onAccent else colors.outline, colorSpec, label = "thumb")
    val size by animateDpAsState(
        when {
            checked && pressed -> 28.dp
            checked || pressed -> 24.dp
            else -> 16.dp
        },
        dpSpec,
        label = "thumbSize",
    )
    val left by animateDpAsState(
        when {
            checked && pressed -> 20.dp
            checked -> 22.dp
            pressed -> 4.dp
            else -> 8.dp
        },
        dpSpec,
        label = "thumbPosition",
    )
    Box(
        Modifier.minimumInteractiveComponentSize()
            .toggleable(checked, interaction, indication = null, enabled = enabled, role = Role.Switch, onValueChange = onCheckedChange)
            .alpha(if (enabled) 1f else 0.38f)
            .size(52.dp, 32.dp)
            .background(track, CircleShape)
            .border(2.dp, edge, CircleShape),
    ) {
        Box(Modifier.align(Alignment.CenterStart).offset(x = left).size(size).background(thumb, CircleShape))
    }
}

@Composable
fun Po0Radio(selected: Boolean) {
    val colors = palette
    val edge by animateColorAsState(if (selected) colors.accent else colors.ink2, tween(150, easing = StandardEasing), label = "radio")
    val dot by animateFloatAsState(if (selected) 1f else 0f, tween(150, easing = StandardEasing), label = "radioDot")
    Box(Modifier.size(20.dp).border(2.dp, edge, CircleShape), contentAlignment = Alignment.Center) {
        Box(
            Modifier.size(10.dp).graphicsLayer {
                scaleX = dot
                scaleY = dot
            }.background(colors.accent, CircleShape),
        )
    }
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
    IconButton(onClick = onClick, enabled = enabled && !busy, modifier = modifier.size(48.dp)) {
        when {
            busy && icon == LineIcons.Refresh -> SpinningIcon(icon, colors.ink)
            busy -> SmallProgress(color = colors.ink)
            else -> Icon(icon, contentDescription = label, tint = if (enabled) colors.ink else colors.ink3, modifier = Modifier.size(24.dp))
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
    val spec = tween<Color>(200, easing = StandardEasing)
    val usable = enabled && !busy
    val fill by animateColorAsState(if (primary && !busy) colors.accent else colors.sel, spec, label = "connectFill")
    val ink by animateColorAsState(
        when {
            busy -> colors.ink2
            primary -> colors.onAccent
            else -> colors.onSel
        },
        spec,
        label = "connectInk",
    )
    Row(
        Modifier.size(128.dp, 40.dp).alpha(if (enabled || busy) 1f else 0.5f).clip(CircleShape).background(fill)
            .clickable(enabled = usable, role = Role.Button, onClick = onClick)
            .padding(horizontal = 8.dp)
            .semantics { contentDescription = label },
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(14.dp), color = ink, strokeWidth = 2.dp)
        Text(label, style = MaterialTheme.typography.labelLarge, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
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
