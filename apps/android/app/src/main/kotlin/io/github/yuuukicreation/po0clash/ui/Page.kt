package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R

/** Space the floating tab bar takes at the bottom of every page, navigation bar included. */
val LocalBottomPadding = compositionLocalOf { 0.dp }

private val navHeight = 52.dp
private val titleHeight = 52.dp
val cardShape = RoundedCornerShape(cardRadius)

@Composable
fun PageScaffold(
    title: String,
    state: LazyListState,
    actions: List<PageAction> = emptyList(),
    extraBottom: Dp = 0.dp,
    onBack: (() -> Unit)? = null,
    content: @Composable (PaddingValues) -> Unit,
) {
    val threshold = with(LocalDensity.current) { (titleHeight * 0.7f).roundToPx() }
    val collapsed by remember(state) {
        derivedStateOf { state.firstVisibleItemIndex > 0 || state.firstVisibleItemScrollOffset > threshold }
    }
    PageScaffold(title, collapsed, state.canScrollBackward, actions, extraBottom, onBack, content)
}

@Composable
fun PageScaffold(
    title: String,
    state: LazyGridState,
    actions: List<PageAction> = emptyList(),
    extraBottom: Dp = 0.dp,
    onBack: (() -> Unit)? = null,
    content: @Composable (PaddingValues) -> Unit,
) {
    val threshold = with(LocalDensity.current) { (titleHeight * 0.7f).roundToPx() }
    val collapsed by remember(state) {
        derivedStateOf { state.firstVisibleItemIndex > 0 || state.firstVisibleItemScrollOffset > threshold }
    }
    PageScaffold(title, collapsed, state.canScrollBackward, actions, extraBottom, onBack, content)
}

/**
 * An iOS page: the list (which puts [PageTitle] first and is the haze source) scrolls under a navigation bar that has
 * no fill of its own. Once content runs under it the scroll edge effect fades in, and once the large title has
 * scrolled away its small centered copy takes over. [actions] sit at the bar's trailing end in one glass capsule, and
 * [onBack] adds the leading back button of a pushed page.
 */
@Composable
private fun PageScaffold(
    title: String,
    collapsed: Boolean,
    scrolled: Boolean,
    actions: List<PageAction>,
    extraBottom: Dp,
    onBack: (() -> Unit)?,
    content: @Composable (PaddingValues) -> Unit,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val padding = PaddingValues(
        start = 16.dp,
        end = 16.dp,
        top = top + navHeight,
        bottom = LocalBottomPadding.current + extraBottom + 16.dp,
    )
    Box(Modifier.fillMaxSize()) {
        content(padding)
        ScrollEdge(scrolled, top + navHeight + 32.dp)
        Box(Modifier.padding(top = top).fillMaxWidth().height(navHeight)) {
            AnimatedVisibility(collapsed, Modifier.align(Alignment.Center), enter = fadeIn(), exit = fadeOut()) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleMedium,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 120.dp),
                )
            }
            if (onBack != null) {
                val back = PageAction(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.back), onClick = onBack)
                GlassButtonGroup(listOf(back), Modifier.align(Alignment.CenterStart).padding(start = 16.dp))
            }
            if (actions.isNotEmpty()) {
                GlassButtonGroup(actions, Modifier.align(Alignment.CenterEnd).padding(end = 16.dp))
            }
        }
    }
}

@Composable
fun PageTitle(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.headlineLarge,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth().height(titleHeight).wrapContentHeight(Alignment.CenterVertically)
            .padding(start = 4.dp),
    )
}

@Composable
fun ContentCard(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().clip(cardShape).background(apple.card)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content,
    )
}

/** A dashboard card: a small monochrome header over its value. */
@Composable
fun InfoCard(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    ContentCard(modifier, onClick) {
        Row(Modifier.fillMaxWidth().height(24.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = apple.secondaryLabel, modifier = Modifier.size(18.dp))
            Text(
                title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                color = apple.secondaryLabel,
                modifier = Modifier.weight(1f).padding(start = 6.dp),
            )
            trailing?.invoke()
        }
        content()
    }
}

@Composable
fun EmptyCard(title: String, detail: String) {
    ContentCard {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(detail, style = MaterialTheme.typography.bodyMedium, color = apple.secondaryLabel)
    }
}
