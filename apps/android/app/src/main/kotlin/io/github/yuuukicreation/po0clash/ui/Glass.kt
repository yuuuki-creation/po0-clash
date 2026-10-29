package io.github.yuuukicreation.po0clash.ui

import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SwitchColors
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeInput
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.blur.HazeBlurStyle
import dev.chrisbanes.haze.blur.HazeColorEffect
import dev.chrisbanes.haze.blur.hazeBlur
import io.github.yuuukicreation.po0clash.R

val LocalHaze = staticCompositionLocalOf<HazeState?> { null }

/** The floating layer's material: blurred where the platform can, otherwise near-opaque so text beneath stays out. */
@Composable
fun Modifier.glass(shape: Shape, blur: Boolean = true, border: Boolean = true): Modifier {
    val colors = apple
    val haze = LocalHaze.current.takeIf { blur && Build.VERSION.SDK_INT >= 31 }
    val shadow = if (haze != null) {
        Modifier.shadow(20.dp, shape, ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.18f))
    } else {
        Modifier
    }
    val fill = if (haze != null) {
        Modifier.hazeBlur(
            HazeInput.Sources(haze),
            HazeBlurStyle {
                blurRadius(24.dp)
                noiseFactor(0f)
                backgroundColor(colors.background)
                colorEffects(listOf(HazeColorEffect.tint(colors.glass)))
            },
        )
    } else {
        Modifier.background(if (blur) colors.glassFallback else colors.glass)
    }
    return this
        .then(shadow)
        .clip(shape)
        .then(fill)
        .then(if (border) Modifier.border(1.dp, colors.glassBorder, shape) else Modifier)
}

@Composable
fun GlassTopBar(
    title: String,
    modifier: Modifier = Modifier,
    navigation: (@Composable () -> Unit)? = null,
    action: (@Composable () -> Unit)? = null,
) {
    Column(modifier.fillMaxWidth().glass(RoundedCornerShape(0.dp), border = false)) {
        Box(Modifier.windowInsetsPadding(WindowInsets.statusBars).fillMaxWidth().height(52.dp)) {
            navigation?.let { Box(Modifier.align(Alignment.CenterStart).padding(start = 4.dp)) { it() } }
            Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.align(Alignment.Center))
            action?.let { Box(Modifier.align(Alignment.CenterEnd).padding(end = 4.dp)) { it() } }
        }
        HorizontalDivider(thickness = Dp.Hairline, color = apple.separator.copy(alpha = 0.6f))
    }
}

@Composable
fun <T> SegmentedPicker(options: List<Pair<T, String>>, selected: T, enabled: Boolean, onSelect: (T) -> Unit) {
    val colors = apple
    BoxWithConstraints(
        Modifier.fillMaxWidth().height(40.dp).glass(CircleShape, blur = false).background(colors.track).padding(3.dp),
    ) {
        val width = maxWidth / options.size
        val index = options.indexOfFirst { it.first == selected }.coerceAtLeast(0)
        val offset by animateDpAsState(width * index, label = "segment")
        Box(
            Modifier.offset(x = offset).width(width).fillMaxHeight()
                .shadow(3.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.1f), spotColor = Color.Black.copy(alpha = 0.15f))
                .background(colors.selection, CircleShape),
        )
        Row(Modifier.fillMaxSize()) {
            options.forEach { (value, label) ->
                val active = value == selected
                Box(
                    Modifier.weight(1f).fillMaxHeight().clip(CircleShape).clickable(enabled = enabled) { onSelect(value) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (active) colors.label else colors.secondaryLabel,
                    )
                }
            }
        }
    }
}

@Composable
fun appleSwitchColors(): SwitchColors {
    val colors = apple
    return SwitchDefaults.colors(
        checkedThumbColor = Color.White,
        checkedTrackColor = colors.green,
        checkedBorderColor = Color.Transparent,
        uncheckedThumbColor = Color.White,
        uncheckedTrackColor = colors.fill,
        uncheckedBorderColor = Color.Transparent,
    )
}

@Composable
fun GlassToastHost(state: SnackbarHostState, modifier: Modifier = Modifier) {
    SnackbarHost(state, modifier) { data ->
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(
                data.visuals.message,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp).glass(RoundedCornerShape(22.dp))
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            )
        }
    }
}

@Stable
class Sheets {
    var content by mutableStateOf<(@Composable ColumnScope.() -> Unit)?>(null)
        private set

    fun show(sheet: @Composable ColumnScope.() -> Unit) {
        content = sheet
    }

    fun dismiss() {
        content = null
    }
}

val LocalSheets = staticCompositionLocalOf { Sheets() }

@Composable
fun SheetHost(sheets: Sheets) {
    val content = sheets.content
    var last by remember { mutableStateOf(content) }
    if (content != null) last = content
    BackHandler(enabled = content != null) { sheets.dismiss() }
    AnimatedVisibility(content != null, enter = fadeIn(), exit = fadeOut()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f))
                .clickable(remember { MutableInteractionSource() }, indication = null) { sheets.dismiss() },
        )
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
        AnimatedVisibility(
            content != null,
            enter = slideInVertically { it / 2 } + fadeIn(),
            exit = slideOutVertically { it / 2 } + fadeOut(),
        ) {
            Column(
                Modifier.navigationBarsPadding().imePadding().padding(10.dp).fillMaxWidth()
                    .glass(RoundedCornerShape(32.dp))
                    .clickable(remember { MutableInteractionSource() }, indication = null) {}
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                key(last) { last?.invoke(this) }
            }
        }
    }
}

@Composable
fun SheetTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun SheetButtons(confirm: String, enabled: Boolean = true, destructive: Boolean = false, onCancel: () -> Unit, onConfirm: () -> Unit) {
    val colors = apple
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Button(
            onClick = onConfirm,
            enabled = enabled,
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(containerColor = if (destructive) colors.red else colors.accent),
            modifier = Modifier.fillMaxWidth().height(50.dp),
        ) {
            Text(confirm, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
        }
        TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth().height(48.dp)) {
            Text(
                stringResource(R.string.cancel),
                style = MaterialTheme.typography.bodyLarge,
                color = colors.accent,
            )
        }
    }
}

@Composable
fun StatusDot(color: Color) {
    Spacer(Modifier.size(10.dp).background(color, CircleShape))
}
