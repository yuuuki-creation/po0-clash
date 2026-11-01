package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R
import kotlin.math.roundToInt
import kotlinx.coroutines.launch

@Stable
class Anchor {
    var bounds by mutableStateOf(Rect.Zero)
}

@Composable
fun rememberAnchor() = remember { Anchor() }

fun Modifier.anchor(anchor: Anchor) = onGloballyPositioned { anchor.bounds = it.boundsInRoot() }

data class SheetAction(
    val label: String,
    val destructive: Boolean = false,
    val checked: Boolean = false,
    val value: String? = null,
    val dividerBefore: Boolean = false,
    val onClick: () -> Unit,
)

internal class Menu(val anchor: Rect, val actions: List<SheetAction>)

internal class Confirm(val title: String, val body: String?, val confirm: String, val onConfirm: () -> Unit)

@Stable
class Sheets {
    var content by mutableStateOf<(@Composable ColumnScope.() -> Unit)?>(null)
        private set
    internal var menu by mutableStateOf<Menu?>(null)
        private set
    internal var dialog by mutableStateOf<Confirm?>(null)
        private set

    fun show(sheet: @Composable ColumnScope.() -> Unit) {
        dismiss()
        content = sheet
    }

    fun menu(anchor: Anchor, actions: List<SheetAction>) {
        dismiss()
        menu = Menu(anchor.bounds, actions)
    }

    fun confirm(title: String, confirm: String, body: String? = null, onConfirm: () -> Unit) {
        dismiss()
        dialog = Confirm(title, body, confirm, onConfirm)
    }

    fun dismiss() {
        content = null
        menu = null
        dialog = null
    }

    val open: Boolean get() = content != null || menu != null || dialog != null
}

val LocalSheets = staticCompositionLocalOf { Sheets() }

@Composable
fun SheetHost(sheets: Sheets) {
    val colors = palette
    val content = sheets.content
    val menu = sheets.menu
    val dialog = sheets.dialog
    var lastContent by remember { mutableStateOf(content) }
    var lastMenu by remember { mutableStateOf(menu) }
    var lastDialog by remember { mutableStateOf(dialog) }
    if (content != null) lastContent = content
    if (menu != null) lastMenu = menu
    if (dialog != null) lastDialog = dialog
    BackHandler(enabled = sheets.open) { sheets.dismiss() }
    val tapOutside = Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, indication = null) { sheets.dismiss() }
    if (menu != null) Box(tapOutside)
    AnimatedVisibility(content != null || dialog != null, enter = fadeIn(tween(300, easing = LinearEasing)), exit = fadeOut(tween(200, easing = LinearEasing))) {
        Box(tapOutside.background(colors.scrim))
    }
    Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.BottomCenter) {
        AnimatedVisibility(
            content != null,
            enter = slideInVertically(tween(400, easing = EnterEasing)) { it },
            exit = slideOutVertically(tween(200, easing = ExitEasing)) { it },
        ) {
            BottomSheet(sheets::dismiss) { key(lastContent) { lastContent?.invoke(this) } }
        }
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        AnimatedVisibility(
            dialog != null,
            enter = fadeIn(tween(300, easing = EnterEasing)) + scaleIn(tween(300, easing = EnterEasing), initialScale = 0.85f),
            exit = fadeOut(tween(150, easing = ExitEasing)),
        ) {
            lastDialog?.let { ConfirmDialog(it, sheets::dismiss) }
        }
    }
    lastMenu?.let { MenuPopup(it, visible = menu != null, onDismiss = sheets::dismiss) }
}

@Composable
private fun BottomSheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val colors = palette
    val scope = rememberCoroutineScope()
    val drag = remember { Animatable(0f) }
    val threshold = with(LocalDensity.current) { 96.dp.toPx() }
    Column(
        Modifier.offset { IntOffset(0, drag.value.roundToInt()) }
            .widthIn(max = 640.dp).fillMaxWidth()
            .background(colors.sheet, RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
            .clickable(remember { MutableInteractionSource() }, indication = null) {}
            .windowInsetsPadding(WindowInsets.ime.union(WindowInsets.navigationBars))
            .padding(start = 24.dp, end = 24.dp, bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(
            Modifier.fillMaxWidth().padding(top = 12.dp)
                .draggable(
                    rememberDraggableState { delta -> scope.launch { drag.snapTo((drag.value + delta).coerceAtLeast(0f)) } },
                    Orientation.Vertical,
                    onDragStopped = { velocity ->
                        if (drag.value > threshold || velocity > 1000f) onDismiss() else drag.animateTo(0f, tween(200, easing = StandardEasing))
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(32.dp, 4.dp).background(colors.outline, RoundedCornerShape(2.dp)))
        }
        content()
    }
}

@Composable
private fun ConfirmDialog(dialog: Confirm, onDismiss: () -> Unit) {
    val colors = palette
    BoxWithConstraints {
        Column(
            Modifier.width(minOf(360.dp, maxWidth - 48.dp))
                .background(colors.sheet, RoundedCornerShape(28.dp))
                .clickable(remember { MutableInteractionSource() }, indication = null) {}
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(dialog.title, style = MaterialTheme.typography.titleLarge)
            dialog.body?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = colors.ink2) }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.End)) {
                TextAction(stringResource(R.string.cancel), onClick = onDismiss)
                TextAction(dialog.confirm, accent = true) {
                    onDismiss()
                    dialog.onConfirm()
                }
            }
        }
    }
}

/** Grows out of the anchor's corner, below it when there is room and above it otherwise. */
@Composable
private fun MenuPopup(menu: Menu, visible: Boolean, onDismiss: () -> Unit) {
    val density = LocalDensity.current
    val margin = with(density) { 16.dp.roundToPx() }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val below = menu.anchor.center.y < constraints.maxHeight * 0.6f
        val origin = TransformOrigin(1f, if (below) 0f else 1f)
        Layout(
            content = {
                AnimatedVisibility(
                    visible,
                    enter = scaleIn(tween(150, easing = StandardEasing), initialScale = 0.8f, transformOrigin = origin) +
                        fadeIn(tween(150, easing = StandardEasing)),
                    exit = fadeOut(tween(100, easing = LinearEasing)),
                ) {
                    MenuCard(menu, onDismiss)
                }
            },
        ) { measurables, constraints ->
            val placeable = measurables.firstOrNull()?.measure(
                Constraints(maxWidth = constraints.maxWidth - 2 * margin, maxHeight = constraints.maxHeight - 2 * margin),
            )
            layout(constraints.maxWidth, constraints.maxHeight) {
                placeable ?: return@layout
                val anchor = menu.anchor
                val x = (anchor.right.toInt() - placeable.width).coerceIn(margin, constraints.maxWidth - margin - placeable.width)
                val y = if (below) anchor.bottom.toInt() else anchor.top.toInt() - placeable.height
                placeable.place(x, y.coerceIn(margin, constraints.maxHeight - margin - placeable.height))
            }
        }
    }
}

@Composable
private fun MenuCard(menu: Menu, onDismiss: () -> Unit) {
    val colors = palette
    Surface(shape = RoundedCornerShape(4.dp), color = colors.sheet, shadowElevation = 4.dp) {
        Column(
            Modifier.widthIn(min = 160.dp, max = 300.dp).width(IntrinsicSize.Max)
                .verticalScroll(rememberScrollState()).padding(vertical = 8.dp),
        ) {
            menu.actions.forEach { action ->
                if (action.dividerBefore) HorizontalDivider(Modifier.padding(vertical = 8.dp), 1.dp, colors.line)
                Row(
                    Modifier.fillMaxWidth().height(48.dp)
                        .background(if (action.checked) colors.sel else colors.sheet)
                        .clickable {
                            onDismiss()
                            action.onClick()
                        }
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Text(
                        action.label,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (action.destructive) colors.bad else colors.ink,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    action.value?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = colors.ink2, maxLines = 1) }
                    if (action.checked) Icon(LineIcons.Check, contentDescription = null, tint = colors.onSel, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

@Composable
fun SheetTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleLarge, modifier = Modifier.fillMaxWidth())
}

@Composable
fun SheetButtons(confirm: String, enabled: Boolean = true, onCancel: () -> Unit, onConfirm: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.End)) {
        TextAction(stringResource(R.string.cancel), onClick = onCancel)
        TextAction(confirm, enabled = enabled, accent = true, onClick = onConfirm)
    }
}

@Composable
fun SheetDoneButton(onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        TextAction(stringResource(R.string.done), accent = true, onClick = onClick)
    }
}

/** Long content in a sheet: scrolls within the sheet instead of pushing the buttons off screen. */
@Composable
fun ColumnScope.SheetBody(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()), content = content)
}
