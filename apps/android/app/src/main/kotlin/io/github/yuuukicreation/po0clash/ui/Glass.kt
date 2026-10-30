package io.github.yuuukicreation.po0clash.ui

import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeInput
import dev.chrisbanes.haze.HazeProgressive
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.blur.HazeBlurStyle
import dev.chrisbanes.haze.blur.HazeColorEffect
import dev.chrisbanes.haze.blur.hazeBlur
import io.github.yuuukicreation.po0clash.R

val LocalHaze = staticCompositionLocalOf<HazeState?> { null }

private val blurs = Build.VERSION.SDK_INT >= 31

/**
 * Liquid Glass for the floating layer only: blurred content under a thin tint and a hairline highlight. Without blur
 * (before API 31) it falls back to a near-opaque fill, like iOS with Reduce Transparency. [tint] makes it the
 * prominent, accent-colored glass.
 */
@Composable
fun Modifier.glass(shape: Shape, tint: Color? = null, shadow: Boolean = true): Modifier {
    val colors = apple
    val haze = LocalHaze.current.takeIf { blurs }
    val lift = if (shadow) {
        Modifier.shadow(16.dp, shape, ambientColor = Color.Black.copy(alpha = 0.06f), spotColor = Color.Black.copy(alpha = 0.16f))
    } else {
        Modifier
    }
    val fill = when {
        haze == null -> Modifier.background(tint ?: colors.glassFallback)
        else -> Modifier.hazeBlur(
            HazeInput.Sources(haze),
            HazeBlurStyle {
                blurRadius(20.dp)
                noiseFactor(0f)
                backgroundColor(colors.background)
                colorEffects(listOf(HazeColorEffect.tint(tint?.copy(alpha = 0.86f) ?: colors.glass)))
            },
        )
    }
    return this
        .then(lift)
        .clip(shape)
        .then(fill)
        .border(Dp.Hairline, if (tint != null) Color.White.copy(alpha = 0.3f) else colors.glassBorder, shape)
}

/** iOS 26's scroll edge effect: a progressive blur that fades out, shown only once content runs under the bar. */
@Composable
fun ScrollEdge(visible: Boolean, height: Dp, modifier: Modifier = Modifier) {
    val colors = apple
    val alpha by animateFloatAsState(if (visible) 1f else 0f, label = "edge")
    if (alpha == 0f) return
    val haze = LocalHaze.current.takeIf { blurs }
    val fade = Brush.verticalGradient(0f to Color.Black, 0.7f to Color.Black, 1f to Color.Transparent)
    val effect = if (haze != null) {
        Modifier.hazeBlur(
            HazeInput.Sources(haze),
            HazeBlurStyle {
                blurRadius(20.dp)
                noiseFactor(0f)
                backgroundColor(colors.background)
                colorEffects(listOf(HazeColorEffect.tint(colors.background.copy(alpha = 0.8f))))
                progressive(HazeProgressive.verticalGradient(startIntensity = 1f, endIntensity = 0f))
                mask(fade)
                alpha(alpha)
            },
        )
    } else {
        Modifier.background(
            Brush.verticalGradient(
                0f to colors.background.copy(alpha = 0.93f * alpha),
                0.7f to colors.background.copy(alpha = 0.9f * alpha),
                1f to Color.Transparent,
            ),
        )
    }
    Box(modifier.fillMaxWidth().height(height).then(effect))
}

data class PageAction(
    val icon: ImageVector,
    val label: String,
    val enabled: Boolean = true,
    val busy: Boolean = false,
    val anchor: Anchor? = null,
    val onClick: () -> Unit,
)

/** Toolbar buttons that share one 44-high glass capsule; icons only, as iOS groups them. */
@Composable
fun GlassButtonGroup(actions: List<PageAction>, modifier: Modifier = Modifier) {
    val colors = apple
    Row(
        modifier.height(44.dp).glass(CircleShape).padding(horizontal = if (actions.size == 1) 0.dp else 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        actions.forEach { action ->
            val enabled = action.enabled && !action.busy
            Box(
                Modifier.size(44.dp, if (actions.size == 1) 44.dp else 40.dp)
                    .then(action.anchor?.let { Modifier.anchor(it) } ?: Modifier)
                    .clip(CircleShape)
                    .clickable(enabled = enabled, role = Role.Button, onClickLabel = action.label, onClick = action.onClick),
                contentAlignment = Alignment.Center,
            ) {
                if (action.busy) {
                    SmallProgress()
                } else {
                    Icon(
                        action.icon,
                        contentDescription = action.label,
                        tint = if (enabled) colors.label else colors.secondaryLabel,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
    }
}

/** The spec's secondary button: a filled circle holding a small monochrome icon. */
@Composable
fun FillButton(icon: ImageVector, label: String, size: Dp = 32.dp, busy: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val colors = apple
    Box(
        Modifier.size(size).clip(CircleShape).background(colors.track)
            .clickable(enabled = enabled && !busy, role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) {
            SmallProgress(14.dp)
        } else {
            Icon(icon, contentDescription = label, tint = if (enabled) colors.label else colors.secondaryLabel, modifier = Modifier.size(size * 0.47f))
        }
    }
}

@Composable
fun <T> SegmentedPicker(options: List<Pair<T, String>>, selected: T, enabled: Boolean, onSelect: (T) -> Unit) {
    val colors = apple
    BoxWithConstraints(
        Modifier.fillMaxWidth().height(36.dp).background(colors.track, CircleShape).padding(2.dp),
    ) {
        val width = maxWidth / options.size
        val index = options.indexOfFirst { it.first == selected }.coerceAtLeast(0)
        val offset by animateDpAsState(width * index, label = "segment")
        Box(
            Modifier.offset(x = offset).width(width).fillMaxHeight()
                .shadow(2.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.12f))
                .background(colors.selection, CircleShape),
        )
        Row(Modifier.fillMaxSize()) {
            options.forEach { (value, label) ->
                val active = value == selected
                Box(
                    Modifier.weight(1f).fillMaxHeight().clip(CircleShape)
                        .clickable(enabled = enabled, role = Role.Tab) { onSelect(value) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = colors.label,
                    )
                }
            }
        }
    }
}

/** The iOS switch: system green when on; while pressed the knob stretches and turns to glass. */
@Composable
fun AppleSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true) {
    val colors = apple
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val progress by animateFloatAsState(if (checked) 1f else 0f, label = "switch")
    val knobWidth by animateDpAsState(if (pressed) 35.dp else 27.dp, label = "knob")
    val track = lerp(colors.fill, colors.green, progress)
    Box(
        Modifier.size(51.dp, 31.dp)
            .background(if (enabled) track else track.copy(alpha = track.alpha * 0.5f), CircleShape)
            .toggleable(checked, interaction, indication = null, enabled = enabled, role = Role.Switch, onValueChange = onCheckedChange)
            .padding(2.dp),
    ) {
        val knob = if (pressed) {
            Modifier.background(Color.White.copy(alpha = 0.55f), CircleShape).border(Dp.Hairline, Color.White, CircleShape)
        } else {
            Modifier.background(Color.White, CircleShape)
        }
        Box(
            Modifier.offset(x = (47.dp - knobWidth) * progress).size(knobWidth, 27.dp)
                .shadow(3.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.12f), spotColor = Color.Black.copy(alpha = 0.2f))
                .then(knob),
        )
    }
}

@Composable
fun GlassToastHost(state: SnackbarHostState, modifier: Modifier = Modifier) {
    SnackbarHost(state, modifier) { data ->
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(
                data.visuals.message,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp).glass(CircleShape)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            )
        }
    }
}

/** Where a menu came from, so it can grow out of the button that opened it. */
@Stable
class Anchor {
    var bounds by mutableStateOf(Rect.Zero)
}

@Composable
fun rememberAnchor() = remember { Anchor() }

fun Modifier.anchor(anchor: Anchor) = onGloballyPositioned { anchor.bounds = it.boundsInRoot() }

data class SheetAction(val label: String, val destructive: Boolean = false, val checked: Boolean = false, val onClick: () -> Unit)

internal class Menu(val anchor: Rect, val title: String?, val actions: List<SheetAction>)

@Stable
class Sheets {
    var content by mutableStateOf<(@Composable ColumnScope.() -> Unit)?>(null)
        private set
    internal var menu by mutableStateOf<Menu?>(null)
        private set

    fun show(sheet: @Composable ColumnScope.() -> Unit) {
        menu = null
        content = sheet
    }

    fun menu(anchor: Anchor, title: String?, actions: List<SheetAction>) {
        content = null
        menu = Menu(anchor.bounds, title, actions)
    }

    fun dismiss() {
        content = null
        menu = null
    }
}

val LocalSheets = staticCompositionLocalOf { Sheets() }

@Composable
fun SheetHost(sheets: Sheets) {
    val content = sheets.content
    val menu = sheets.menu
    var last by remember { mutableStateOf(content) }
    var lastMenu by remember { mutableStateOf(menu) }
    if (content != null) last = content
    if (menu != null) lastMenu = menu
    BackHandler(enabled = content != null || menu != null) { sheets.dismiss() }
    AnimatedVisibility(content != null || menu != null, enter = fadeIn(), exit = fadeOut()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = if (content != null) 0.2f else 0.08f))
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
                Modifier.navigationBarsPadding().imePadding().padding(8.dp).fillMaxWidth()
                    .glass(RoundedCornerShape(34.dp))
                    .clickable(remember { MutableInteractionSource() }, indication = null) {}
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                key(last) { last?.invoke(this) }
            }
        }
    }
    lastMenu?.let { MenuPopup(it, visible = menu != null, onDismiss = sheets::dismiss) }
}

/** A glass menu that grows out of its anchor, below it when there is room and above it otherwise. */
@Composable
private fun MenuPopup(menu: Menu, visible: Boolean, onDismiss: () -> Unit) {
    val colors = apple
    val density = LocalDensity.current
    val gap = with(density) { 8.dp.roundToPx() }
    val margin = with(density) { 16.dp.roundToPx() }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val below = menu.anchor.center.y < constraints.maxHeight * 0.6f
        val origin = TransformOrigin(1f, if (below) 0f else 1f)
        Layout(
            content = {
                AnimatedVisibility(
                    visible,
                    enter = scaleIn(initialScale = 0.6f, transformOrigin = origin) + fadeIn(),
                    exit = scaleOut(targetScale = 0.6f, transformOrigin = origin) + fadeOut(),
                ) {
                    Column(Modifier.widthIn(min = 220.dp, max = 280.dp).glass(RoundedCornerShape(26.dp)).padding(vertical = 6.dp)) {
                        menu.title?.let {
                            Text(
                                it,
                                style = MaterialTheme.typography.labelMedium,
                                color = colors.secondaryLabel,
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                            )
                        }
                        menu.actions.forEach { action ->
                            Row(
                                Modifier.fillMaxWidth().clickable {
                                    onDismiss()
                                    action.onClick()
                                }.padding(horizontal = 20.dp, vertical = 13.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    action.label,
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = if (action.destructive) colors.red else colors.label,
                                    modifier = Modifier.weight(1f),
                                )
                                if (action.checked) Icon(LineIcons.Check, contentDescription = null, tint = colors.accent, modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                }
            },
        ) { measurables, constraints ->
            val placeable = measurables.firstOrNull()?.measure(Constraints(maxWidth = constraints.maxWidth - 2 * margin))
            layout(constraints.maxWidth, constraints.maxHeight) {
                placeable ?: return@layout
                val anchor = menu.anchor
                val x = (anchor.right.toInt() - placeable.width).coerceIn(margin, constraints.maxWidth - margin - placeable.width)
                val y = if (below) anchor.bottom.toInt() + gap else anchor.top.toInt() - gap - placeable.height
                placeable.place(x, y.coerceAtLeast(margin))
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
fun SheetButtons(confirm: String, enabled: Boolean = true, onCancel: () -> Unit, onConfirm: () -> Unit) {
    val colors = apple
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Button(
            onClick = onConfirm,
            enabled = enabled,
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(containerColor = colors.accent),
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
fun SheetDoneButton(onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = apple.accent),
        modifier = Modifier.fillMaxWidth().height(50.dp),
    ) {
        Text(stringResource(R.string.done), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun Hairline(modifier: Modifier = Modifier) {
    HorizontalDivider(modifier, Dp.Hairline, apple.separator)
}
