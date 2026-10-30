package io.github.yuuukicreation.po0clash.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kyant.backdrop.backdrops.layerBackdrop
import io.github.yuuukicreation.po0clash.R

/** Space the floating status bar and tab bar take at the bottom of every page, navigation bar included. */
val LocalBottomPadding = compositionLocalOf { 0.dp }

private val navHeight = 44.dp
private val titleHeight = 41.dp
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
 * An iOS page: the list (which puts [PageTitle] first and is recorded for the glass) scrolls under a navigation bar that has
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
    val backdrop = rememberPageBackdrop()
    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().layerBackdrop(backdrop)) { content(padding) }
        CompositionLocalProvider(LocalBackdrop provides backdrop) { NavigationBar(title, top, collapsed, scrolled, actions, onBack) }
    }
}

@Composable
private fun NavigationBar(title: String, top: Dp, collapsed: Boolean, scrolled: Boolean, actions: List<PageAction>, onBack: (() -> Unit)?) {
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
            val back = PageAction(LineIcons.ChevronLeft, stringResource(R.string.back), onClick = onBack)
            GlassButtonGroup(listOf(back), Modifier.align(Alignment.CenterStart).padding(start = 16.dp))
        }
        if (actions.isNotEmpty()) {
            GlassButtonGroup(actions, Modifier.align(Alignment.CenterEnd).padding(end = 16.dp))
        }
    }
}

/** The large title, with an optional 15 pt summary line under it. */
@Composable
fun PageTitle(title: String, subtitle: String? = null) {
    Column(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 2.dp, bottom = 14.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.headlineLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.height(titleHeight).wrapContentHeight(Alignment.CenterVertically),
        )
        if (subtitle != null) {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = apple.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
fun ContentCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    spacing: Dp = 8.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val sink by animateFloatAsState(if (pressed && !LocalReduceMotion.current) 0.97f else 1f, spring(0.6f, 600f), label = "card")
    Column(
        modifier.fillMaxWidth().graphicsLayer {
            scaleX = sink
            scaleY = sink
        }.clip(cardShape).background(apple.card)
            .then(if (onClick != null) Modifier.clickable(interaction, LocalIndication.current, onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(spacing),
        content = content,
    )
}

/** A dashboard card: a small gray title with its monochrome icon, an optional note or button at the end, then the value. */
@Composable
fun InfoCard(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    note: String? = null,
    spacing: Dp = 4.dp,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = apple
    ContentCard(modifier, onClick, spacing) {
        Row(Modifier.fillMaxWidth().heightIn(min = 20.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, tint = colors.secondaryLabel, modifier = Modifier.size(15.dp))
            Text(
                title,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                color = colors.secondaryLabel,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(start = 6.dp),
            )
            if (note != null) {
                Text(note, style = MaterialTheme.typography.bodySmall.tabular(), fontWeight = FontWeight.Medium, color = colors.secondaryLabel, maxLines = 1)
            }
            trailing?.invoke()
        }
        content()
    }
}

/** A large semibold number with its small gray unit, as the spec sets values apart from their labels. */
@Composable
fun BigValue(value: String, unit: String? = null, large: Boolean = false) {
    val colors = apple
    Row(verticalAlignment = Alignment.Bottom) {
        RollingText(
            value,
            (if (large) MaterialTheme.typography.displaySmall else MaterialTheme.typography.headlineSmall).tabular(),
            Modifier.alignByBaseline(),
        )
        if (unit != null) {
            Text(
                unit,
                style = if (large) MaterialTheme.typography.bodyMedium else MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = colors.secondaryLabel,
                maxLines = 1,
                modifier = Modifier.alignByBaseline().padding(start = 3.dp),
            )
        }
    }
}

/** iOS's content-unavailable view: a large gray symbol, a title and a short note, centered on the page rather than carded. */
@Composable
fun EmptyCard(title: String, detail: String, icon: ImageVector = LineIcons.Info) {
    Column(
        Modifier.fillMaxWidth().padding(top = 56.dp, bottom = 24.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, contentDescription = null, tint = apple.secondaryLabel, modifier = Modifier.padding(bottom = 6.dp).size(44.dp))
        Text(title, style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp), fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        Text(detail, style = MaterialTheme.typography.bodyMedium, color = apple.secondaryLabel, textAlign = TextAlign.Center)
    }
}
