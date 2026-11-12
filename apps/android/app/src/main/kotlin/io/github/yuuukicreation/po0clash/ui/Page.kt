package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R

/** The real window width, which picks the navigation (600) and the column count (840). */
val LocalWindowWidth = compositionLocalOf { 0.dp }

/** Bottom space a page must leave itself: the system bar when a rail has no bottom bar to cover it. */
val LocalBottomInset = compositionLocalOf { 0.dp }

val Dp.isExpanded: Boolean get() = this >= 840.dp

private val maxContentWidth = 1100.dp

data class PageAction(
    val icon: ImageVector,
    val label: String,
    val enabled: Boolean = true,
    val busy: Boolean = false,
    val anchor: Anchor? = null,
    val onClick: () -> Unit,
)

class AppBarSearch(val query: String, val onQuery: (String) -> Unit, val onClose: () -> Unit)

@Composable
fun PageScaffold(
    title: String,
    state: LazyListState,
    actions: List<PageAction> = emptyList(),
    onBack: (() -> Unit)? = null,
    capped: Boolean = true,
    fab: FabAction? = null,
    content: @Composable (PaddingValues) -> Unit,
) = PageScaffold(title, state.canScrollBackward, actions, onBack, null, capped, fab, content)

@Composable
fun PageScaffold(
    title: String,
    state: LazyGridState,
    actions: List<PageAction> = emptyList(),
    onBack: (() -> Unit)? = null,
    capped: Boolean = true,
    fab: FabAction? = null,
    content: @Composable (PaddingValues) -> Unit,
) = PageScaffold(title, state.canScrollBackward, actions, onBack, null, capped, fab, content)

@Composable
fun PageScaffold(
    title: String,
    scrolled: Boolean,
    actions: List<PageAction> = emptyList(),
    onBack: (() -> Unit)? = null,
    search: AppBarSearch? = null,
    capped: Boolean = true,
    fab: FabAction? = null,
    content: @Composable (PaddingValues) -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        AppBar(title, scrolled, actions, onBack, search)
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val side = if (capped) maxOf(16.dp, (maxWidth - maxContentWidth) / 2) else 16.dp
            val bottom = LocalBottomInset.current
            content(
                PaddingValues(
                    start = side,
                    end = side,
                    top = 20.dp,
                    bottom = bottom + if (fab != null) 88.dp else 16.dp,
                ),
            )
            if (fab != null) {
                Po0Fab(fab, Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = bottom + 16.dp))
            }
        }
    }
}

@Composable
private fun AppBar(
    title: String,
    scrolled: Boolean,
    actions: List<PageAction>,
    onBack: (() -> Unit)?,
    search: AppBarSearch?,
) {
    val colors = palette
    val fill by animateColorAsState(if (scrolled) colors.sheet else colors.bg, tween(200), label = "appBar")
    Box(Modifier.fillMaxWidth().background(fill).windowInsetsPadding(WindowInsets.statusBars)) {
        Row(
            Modifier.fillMaxWidth().height(64.dp).padding(start = 16.dp, end = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (search != null) {
                AppBarSearchField(search, Modifier.weight(1f).padding(end = 12.dp))
                return@Row
            }
            if (onBack != null) AppIconButton(LineIcons.ChevronLeft, stringResource(R.string.back), onClick = onBack)
            Crossfade(title, Modifier.weight(1f), animationSpec = tween(150), label = "appBarTitle") {
                Text(it, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            actions.forEach { action ->
                AppIconButton(
                    action.icon,
                    action.label,
                    action.enabled,
                    action.busy,
                    action.anchor?.let { Modifier.anchor(it) } ?: Modifier,
                    action.onClick,
                )
            }
        }
    }
}

@Composable
private fun AppBarSearchField(search: AppBarSearch, modifier: Modifier) {
    val colors = palette
    val focus = remember { FocusRequester() }
    val appear = remember { Animatable(0f) }
    val shape = CircleShape
    LaunchedEffect(Unit) {
        focus.requestFocus()
        appear.animateTo(1f, tween(200, easing = StandardEasing))
    }
    Row(
        modifier.height(44.dp)
            .graphicsLayer {
                alpha = appear.value
                scaleX = 0.9f + 0.1f * appear.value
                transformOrigin = TransformOrigin(1f, 0.5f)
            }
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, shape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppIconButton(LineIcons.ChevronLeft, stringResource(R.string.back), onClick = search.onClose)
        Box(Modifier.weight(1f).padding(start = 4.dp, end = 16.dp)) {
            if (search.query.isEmpty()) {
                Text(stringResource(R.string.search), style = MaterialTheme.typography.bodyLarge, color = colors.ink2)
            }
            BasicTextField(
                search.query,
                search.onQuery,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                modifier = Modifier.fillMaxWidth().focusRequester(focus),
            )
        }
    }
}

/** The in-page search field of Activity, Access control and Licenses; filtering is instant. */
@Composable
fun SearchField(query: String, onChange: (String) -> Unit) {
    val colors = palette
    Row(
        Modifier.fillMaxWidth().height(48.dp).background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(LineIcons.Search, contentDescription = null, tint = colors.ink2, modifier = Modifier.padding(end = 10.dp))
        Box(Modifier.weight(1f)) {
            if (query.isEmpty()) Text(stringResource(R.string.search), style = MaterialTheme.typography.bodyLarge, color = colors.ink2)
            BasicTextField(
                query,
                onChange,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
