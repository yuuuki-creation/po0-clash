// Follows FlClash 0.9.3's prism_ui/switch.dart (GPL-3.0).
package io.github.yuuukicreation.po0clash.ui

import android.graphics.BlurMaskFilter
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import kotlin.math.sin
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun Po0Switch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true, modifier: Modifier = Modifier) {
    val colors = palette
    val surface = MaterialTheme.colorScheme.surface
    val blur = with(LocalDensity.current) { 6.dp.toPx() }
    val shadow = remember(blur) { Paint().apply { asFrameworkPaint().maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL) } }
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val focused by interaction.collectIsFocusedAsState()
    val current by rememberUpdatedState(checked)
    val change by rememberUpdatedState(onCheckedChange)
    var dragging by remember { mutableStateOf<Float?>(null) }
    var releasedFrom by remember { mutableStateOf<Float?>(null) }
    var linear by remember { mutableStateOf(false) }
    var advancing by remember { mutableStateOf(checked) }
    val progress = remember { Animatable(if (checked) 1f else 0f) }
    val scope = rememberCoroutineScope()
    var held by remember { mutableStateOf(false) }
    var holdJob by remember { mutableStateOf<Job?>(null) }
    val reduced = LocalReduceMotion.current
    fun holdAcross() {
        holdJob?.cancel()
        if (reduced || !enabled) { held = false; return }
        held = true
        holdJob = scope.launch { delay(200); held = false }
    }
    LaunchedEffect(reduced, enabled) {
        if (reduced || !enabled) { holdJob?.cancel(); held = false }
    }
    LaunchedEffect(checked, dragging != null, reduced, enabled) {
        if (dragging != null) { progress.stop(); return@LaunchedEffect }
        val start = releasedFrom
        releasedFrom = null
        if (start != null) progress.snapTo(start)
        else if (progress.value == 0f || progress.value == 1f) { advancing = checked; linear = false }
        val end = if (checked) 1f else 0f
        if (abs(end - progress.value) > 0.5f) holdAcross()
        if (reduced) progress.snapTo(end)
        else progress.animateTo(end, tween((300 * abs(end - progress.value)).roundToInt(), easing = LinearEasing))
    }
    val raw = dragging ?: progress.value
    val position = if (linear || dragging != null) raw else if (advancing) EaseOutBack.transform(raw) else 1f - EaseOutBack.transform(1f - raw)
    val lift = reversibleProgress(enabled && (pressed || dragging != null || held), 150, EaseOutCubic, EaseOutCubic)
    val visualPosition by rememberUpdatedState(position)
    Box(
        modifier.size(60.dp, 48.dp)
            .toggleable(checked, interactionSource = interaction, indication = null, enabled = enabled, role = Role.Switch, onValueChange = { holdAcross(); onCheckedChange(it) })
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectHorizontalDragGestures(
                    onDragStart = { holdJob?.cancel(); held = false; linear = true; dragging = visualPosition.coerceIn(0f, 1f) },
                    onDragCancel = { releasedFrom = dragging; dragging = null },
                    onDragEnd = {
                        val next = (dragging ?: 0f) >= 0.5f
                        releasedFrom = dragging
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
            val amount = raw.coerceIn(0f, 1f)
            val track = if (enabled) lerp(colors.track, colors.accent, amount) else lerp(colors.track.copy(alpha = 0.12f), colors.ink.copy(alpha = 0.12f), amount)
            val thumb = if (enabled) lerp(colors.ink3, colors.onAccent, amount) else lerp(colors.ink.copy(alpha = 0.38f), surface, amount)
            drawRoundRect(track, cornerRadius = CornerRadius(size.height / 2))
            val crossing = sin(amount * Math.PI).toFloat()
            val width = (24 + 10 * crossing + 16 * lift).dp.toPx()
            val height = (24 - 2 * crossing + 16 * lift).dp.toPx()
            val centerX = (16 + 20 * position).dp.toPx()
            val left = centerX - width / 2
            val top = (size.height - height) / 2
            if (lift > 0f) drawIntoCanvas { canvas ->
                shadow.color = Color.Black.copy(alpha = 0.2f * lift)
                val offset = 2.dp.toPx()
                canvas.drawRoundRect(left, top + offset, left + width, top + height + offset, height / 2, height / 2, shadow)
            }
            drawRoundRect(lerp(thumb, Color.White, lift), Offset(left, top), Size(width, height), CornerRadius(height / 2))
        }
    }
}
