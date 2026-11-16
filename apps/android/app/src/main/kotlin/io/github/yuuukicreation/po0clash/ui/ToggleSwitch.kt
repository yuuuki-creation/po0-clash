// Follows FlClash 0.9.3's prism_ui/switch.dart (GPL-3.0).
package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import kotlin.math.sin

@Composable
fun Po0Switch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true, modifier: Modifier = Modifier) {
    val colors = palette
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val focused by interaction.collectIsFocusedAsState()
    val current by rememberUpdatedState(checked)
    val change by rememberUpdatedState(onCheckedChange)
    var dragging by remember { mutableStateOf<Float?>(null) }
    val reduced = LocalReduceMotion.current
    val position by animateFloatAsState(
        dragging ?: if (checked) 1f else 0f,
        if (reduced || dragging != null) snap() else tween(300, easing = EaseOutBack),
        label = "switchPosition",
    )
    val lift by animateFloatAsState(if (enabled && (pressed || dragging != null)) 1f else 0f,
        if (reduced) snap() else tween(150, easing = StandardEasing), label = "switchPress")
    Box(
        modifier.size(60.dp, 48.dp)
            .toggleable(checked, interactionSource = interaction, indication = null, enabled = enabled, role = Role.Switch, onValueChange = onCheckedChange)
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectHorizontalDragGestures(
                    onDragStart = { dragging = if (current) 1f else 0f },
                    onDragCancel = { dragging = null },
                    onDragEnd = {
                        val next = (dragging ?: 0f) >= 0.5f
                        dragging = null
                        if (next != current) change(next)
                    },
                    onHorizontalDrag = { event, delta ->
                        event.consume()
                        dragging = ((dragging ?: 0f) + delta / 20.dp.toPx()).coerceIn(0f, 1f)
                    },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.size(52.dp, 32.dp)) {
            if (focused && enabled) {
                val gap = 3.dp.toPx()
                drawRoundRect(colors.accent, Offset(-gap, -gap), Size(size.width + gap * 2, size.height + gap * 2),
                    CornerRadius(size.height / 2 + gap), style = Stroke(2.dp.toPx()))
            }
            val progress = position.coerceIn(0f, 1f)
            val opacity = if (enabled) 1f else 0.38f
            drawRoundRect(lerp(colors.track, colors.accent, progress), cornerRadius = CornerRadius(size.height / 2), alpha = opacity)
            val crossing = sin(progress * Math.PI).toFloat()
            val width = (24 + 10 * crossing + 16 * lift).dp.toPx()
            val height = (24 - 2 * crossing + 16 * lift).dp.toPx()
            val centerX = (16 + 20 * position).dp.toPx()
            drawRoundRect(Color.White, Offset(centerX - width / 2, (size.height - height) / 2), Size(width, height),
                CornerRadius(height / 2), alpha = opacity)
        }
    }
}
