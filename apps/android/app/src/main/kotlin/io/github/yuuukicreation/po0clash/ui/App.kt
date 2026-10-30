package io.github.yuuukicreation.po0clash.ui

import android.os.Build
import android.os.SystemClock
import androidx.activity.compose.BackHandler
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.util.lerp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.colorControls
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.highlight.Highlight
import com.kyant.backdrop.shadow.Shadow
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.LaunchCheck
import io.github.yuuukicreation.po0clash.core.LaunchRecovery
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sign
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class Page(@param:StringRes val label: Int, val icon: ImageVector) {
    DASHBOARD(R.string.dashboard, LineIcons.Gauge),
    PROXIES(R.string.proxies, LineIcons.Globe),
    PROFILES(R.string.profiles, LineIcons.Layers),
    WHITELIST(R.string.whitelist, LineIcons.ShieldCheck),
    TOOLS(R.string.tools, LineIcons.Sliders),
}

private val tabBarHeight = 62.dp
private val statusBarHeight = 54.dp
private val barGap = 8.dp
private val barSide = 20.dp
private val barMaxWidth = 480.dp

@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var page by rememberSaveable { mutableStateOf(Page.DASHBOARD) }
    var minimized by rememberSaveable { mutableStateOf(false) }
    val pages = rememberSaveableStateHolder()
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val reduceMotion = rememberReduceMotion()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val pagesBackdrop = rememberPageBackdrop()
    val rootBackdrop = rememberPageBackdrop()
    val scrollWatch = remember { MinimizeOnScroll { minimized = it } }
    val tabBarBottom = maxOf(30.dp, WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + barGap)
    val bottom = tabBarBottom + tabBarHeight + barGap + statusBarHeight
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    val notice by vm.engine.launchNotice.collectAsStateWithLifecycle()
    LaunchedEffect(notice) {
        val check = notice ?: return@LaunchedEffect
        vm.engine.dismissLaunchNotice()
        sheets.show { LaunchNotice(check, sheets::dismiss) }
    }
    LaunchedEffect(vm) { if (vm.appSettings.value.autoCheckUpdate) vm.checkUpdate(userInitiated = false) }
    val release by vm.release.collectAsStateWithLifecycle()
    LaunchedEffect(release) {
        val (found, automatic) = release ?: return@LaunchedEffect
        vm.dismissRelease()
        sheets.show {
            ReleaseSheet(found, automatic, onDone = sheets::dismiss) {
                sheets.dismiss()
                vm.setAppSettings { it.copy(autoCheckUpdate = false) }
            }
        }
    }
    LaunchedEffect(page) { minimized = false }
    BackHandler(enabled = page != Page.DASHBOARD) { page = Page.DASHBOARD }
    val fade = settings.pageAnimation && !reduceMotion

    CompositionLocalProvider(
        LocalSheets provides sheets,
        LocalBottomPadding provides bottom,
        LocalReduceMotion provides reduceMotion,
        LocalIndication provides ApplePress,
    ) {
        Box(Modifier.fillMaxSize().background(apple.background)) {
            Box(Modifier.fillMaxSize().layerBackdrop(rootBackdrop)) {
                Box(Modifier.fillMaxSize().layerBackdrop(pagesBackdrop).nestedScroll(scrollWatch)) {
                    AnimatedContent(
                        page,
                        transitionSpec = {
                            if (fade) fadeIn(tween(200, delayMillis = 40)) togetherWith fadeOut(tween(120))
                            else EnterTransition.None togetherWith ExitTransition.None
                        },
                        label = "tabs",
                    ) { target ->
                        pages.SaveableStateProvider(target) {
                            when (target) {
                                Page.DASHBOARD -> DashboardScreen(vm, onConnect, onOpen = { page = it })
                                Page.PROXIES -> ProxiesScreen(vm)
                                Page.PROFILES -> SubscriptionsScreen(vm)
                                Page.WHITELIST -> WhitelistScreen(vm)
                                Page.TOOLS -> ToolsScreen(vm)
                            }
                        }
                    }
                }
                CompositionLocalProvider(LocalBackdrop provides pagesBackdrop) {
                    BottomBars(
                        minimized = minimized,
                        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarBottom),
                        toast = { GlassToastHost(snackbar) },
                        status = { StatusBar(vm, onConnect, it) },
                        tabs = { mini, modifier ->
                            TabBar(page, settings.showNavLabels, mini, modifier, onExpand = { minimized = false }) { page = it }
                        },
                    )
                }
            }
            CompositionLocalProvider(LocalBackdrop provides rootBackdrop) { SheetHost(sheets) }
        }
    }
}

/** iOS 26's tab bar minimize behavior: scrolling content down folds the bar away, scrolling back up brings it back. */
private class MinimizeOnScroll(private val onChange: (Boolean) -> Unit) : NestedScrollConnection {
    private var travel = 0f

    override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
        val dy = consumed.y
        if (dy != 0f) {
            travel = if (sign(travel) == sign(dy)) travel + dy else dy
            if (abs(travel) > 48f) onChange(travel < 0f)
        }
        return Offset.Zero
    }
}

/** Minimized, the tab bar shrinks to a circle and the status bar slides down beside it, as iOS 26 tucks a bottom accessory inline. */
@Composable
private fun BottomBars(
    minimized: Boolean,
    modifier: Modifier,
    toast: @Composable () -> Unit,
    status: @Composable (Modifier) -> Unit,
    tabs: @Composable (mini: Float, Modifier) -> Unit,
) {
    val motion = if (LocalReduceMotion.current) snap() else spring(0.82f, 340f, 0.001f)
    val mini by animateFloatAsState(if (minimized) 1f else 0f, motion, label = "minimize")
    Layout(
        content = {
            Box { toast() }
            status(Modifier)
            tabs(mini, Modifier)
        },
        modifier = modifier.fillMaxWidth(),
    ) { (toastPart, statusPart, tabsPart), constraints ->
        val side = barSide.roundToPx()
        val gap = barGap.roundToPx()
        val tabHeight = tabBarHeight.roundToPx()
        val statusHeight = statusBarHeight.roundToPx()
        val width = minOf(constraints.maxWidth - 2 * side, barMaxWidth.roundToPx())
        val left = (constraints.maxWidth - width) / 2
        val tabWidth = lerp(width.toFloat(), tabHeight.toFloat(), mini).roundToInt()
        val inset = ((tabHeight + gap) * mini).roundToInt()
        val toastPlaced = toastPart.measure(constraints.copy(minHeight = 0))
        val statusPlaced = statusPart.measure(Constraints.fixed(width - inset, statusHeight))
        val tabsPlaced = tabsPart.measure(Constraints.fixed(tabWidth, tabHeight))
        val height = toastPlaced.height + (if (toastPlaced.height > 0) gap else 0) + statusHeight + gap + tabHeight
        layout(constraints.maxWidth, height) {
            val tabY = height - tabHeight
            val statusY = lerp((tabY - gap - statusHeight).toFloat(), (tabY + (tabHeight - statusHeight) / 2).toFloat(), mini).roundToInt()
            tabsPlaced.place(left, tabY)
            statusPlaced.place(left + inset, statusY)
            toastPlaced.place(0, statusY - gap - toastPlaced.height)
        }
    }
}

/** Why this launch did not connect by itself, in Flutter's words. */
@Composable
private fun LaunchNotice(check: LaunchCheck, onDone: () -> Unit) {
    val cleared = check.recovery == LaunchRecovery.CLEAR_PROFILE
    SheetTitle(stringResource(if (cleared) R.string.crash_detected else R.string.launch_interrupted))
    Text(
        if (cleared) stringResource(R.string.crash_detected_body, check.profileName.orEmpty()) else stringResource(R.string.launch_interrupted_body),
        style = MaterialTheme.typography.bodyMedium,
        color = apple.secondaryLabel,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
    SheetDoneButton(onDone)
}

/** The spec's bottom status bar: state dot, state and "uptime · node", and the one solid start/stop button. */
@Composable
private fun StatusBar(vm: AppViewModel, onConnect: () -> Unit, modifier: Modifier) {
    val engine = vm.engine
    val colors = apple
    val status by engine.status.collectAsStateWithLifecycle()
    val active by engine.vpnActive.collectAsStateWithLifecycle()
    val vpnError by engine.vpnError.collectAsStateWithLifecycle()
    val connectedAt by engine.connectedAt.collectAsStateWithLifecycle()
    val profiles by engine.profiles.collectAsStateWithLifecycle()
    val failure = (status.engine as? EngineState.Failed)?.message ?: vpnError
    val since = connectedAt
    val enabled = active || profiles.any { it.selected }
    val (dot, title) = when {
        active && since != null -> colors.green to stringResource(R.string.state_running)
        active -> colors.orange to stringResource(R.string.state_starting)
        failure != null -> colors.red to stringResource(R.string.state_failed)
        else -> colors.secondaryLabel to stringResource(R.string.state_stopped)
    }
    val detail = when {
        active && since != null -> null
        active -> ""
        failure != null -> failure
        enabled -> stringResource(R.string.tap_to_connect)
        else -> stringResource(R.string.add_profile_first)
    }
    val dotColor by animateColorAsState(dot, label = "dot")
    val detailStyle = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, lineHeight = 15.sp).tabular()
    val press = rememberGlassPress()
    Row(
        modifier.then(press?.gesture ?: Modifier).glass(CircleShape, press = press).padding(start = 18.dp, end = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(8.dp).background(dotColor, CircleShape))
        Column(Modifier.weight(1f)) {
            AnimatedContent(title, transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(120)) }, label = "state") {
                Text(it, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
            }
            if (detail == null && since != null) {
                Row {
                    RollingText(elapsed(since), detailStyle, color = colors.secondaryLabel)
                    status.currentNode?.let {
                        Text(" · $it", style = detailStyle, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            } else if (!detail.isNullOrEmpty()) {
                Text(detail, style = detailStyle, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        val label = stringResource(if (active) R.string.disconnect else R.string.connect)
        Box(
            Modifier.size(40.dp).alpha(if (enabled) 1f else 0.4f)
                .shadow(1.dp, CircleShape)
                .background(colors.accentFill, CircleShape).clip(CircleShape)
                .clickable(enabled = enabled, role = Role.Button, onClickLabel = label) {
                    if (active) vm.disconnect() else onConnect()
                }
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            val state = when {
                active && since == null -> 0
                active -> 1
                else -> 2
            }
            AnimatedContent(
                state,
                transitionSpec = { (scaleIn(spring(0.6f, 500f), 0.5f) + fadeIn()) togetherWith (scaleOut(targetScale = 0.5f) + fadeOut()) },
                label = "button",
            ) {
                when (it) {
                    0 -> CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = Color.White)
                    1 -> Icon(LineIcons.Stop, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                    else -> Icon(LineIcons.Play, contentDescription = null, tint = Color.White, modifier = Modifier.size(15.dp))
                }
            }
        }
    }
}

@Composable
private fun elapsed(since: Long): String {
    val now by produceState(SystemClock.elapsedRealtime(), since) {
        while (true) {
            value = SystemClock.elapsedRealtime()
            delay(1000 - (value - since) % 1000)
        }
    }
    val seconds = ((now - since) / 1000).coerceAtLeast(0)
    return "%02d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60)
}

/** iOS 26's tab bar: the selection is a lens that swells under the finger and follows it, settling on the nearest tab. */
@Composable
private fun TabBar(selected: Page, labels: Boolean, mini: Float, modifier: Modifier, onExpand: () -> Unit, onSelect: (Page) -> Unit) {
    val colors = apple
    val reduce = LocalReduceMotion.current
    val backdrop = LocalBackdrop.current
    val scope = rememberCoroutineScope()
    val count = Page.entries.size
    val position = remember { Animatable(selected.ordinal.toFloat(), 0.001f) }
    val press = remember { Animatable(0f, 0.001f) }
    var held by remember { mutableStateOf(false) }
    LaunchedEffect(selected, reduce) {
        if (held) return@LaunchedEffect
        if (reduce) position.snapTo(selected.ordinal.toFloat()) else position.animateTo(selected.ordinal.toFloat(), slide)
    }
    val lit = if (held) position.value.roundToInt() else selected.ordinal
    Box(modifier.glass(CircleShape)) {
        if (mini > 0f) {
            Icon(
                selected.icon,
                contentDescription = stringResource(selected.label),
                tint = colors.accentText,
                modifier = Modifier.align(Alignment.Center).size(26.dp).alpha(((mini - 0.5f) * 2f).coerceIn(0f, 1f)),
            )
        }
        if (mini >= 1f) {
            Box(Modifier.fillMaxSize().clip(CircleShape).clickable(role = Role.Button, onClick = onExpand))
            return@Box
        }
        BoxWithConstraints(
            Modifier.fillMaxSize().padding(4.dp).alpha((1f - mini * 2f).coerceIn(0f, 1f))
                .pointerInput(count, reduce) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        val tab = size.width.toFloat() / count
                        held = true
                        if (!reduce) scope.launch { press.animateTo(1f, swell) }
                        var dragged = false
                        var last = down.position
                        var target = position.value
                        while (true) {
                            val change = awaitPointerEvent().changes.firstOrNull { it.id == down.id } ?: break
                            change.consume()
                            if (!change.pressed) break
                            last = change.position
                            if (!dragged && abs(last.x - down.position.x) > viewConfiguration.touchSlop) dragged = true
                            if (dragged) {
                                target = (last.x / tab - 0.5f).coerceIn(0f, count - 1f)
                                val to = target
                                scope.launch { if (reduce) position.snapTo(to) else position.animateTo(to, follow) }
                            }
                        }
                        val index = if (dragged) target.roundToInt() else (last.x / tab).toInt()
                        val page = Page.entries[index.coerceIn(0, count - 1)]
                        onSelect(page)
                        scope.launch {
                            if (reduce) position.snapTo(page.ordinal.toFloat()) else position.animateTo(page.ordinal.toFloat(), slide)
                            held = false
                        }
                        scope.launch { press.animateTo(0f, swell) }
                    }
                },
        ) {
            val width = maxWidth / count
            val lens = Modifier.offset { IntOffset((position.value * width.toPx()).roundToInt(), 0) }.width(width).fillMaxHeight()
            Box(
                if (backdrop == null || Build.VERSION.SDK_INT < 31) {
                    lens.background(colors.tabSelection, CircleShape)
                } else {
                    lens.drawBackdrop(
                        backdrop = backdrop,
                        shape = { CircleShape },
                        effects = {
                            val p = press.value
                            colorControls(saturation = 1.8f)
                            blur(12.dp.toPx() * if (refracts) 1f - p else 1f)
                            lens(8.dp.toPx() * p, 12.dp.toPx() * p)
                        },
                        highlight = { Highlight.Default.copy(alpha = press.value) },
                        shadow = { Shadow(radius = 10.dp, color = Color.Black.copy(alpha = 0.12f), alpha = press.value) },
                        layerBlock = {
                            val grow = 1f + 0.22f * press.value
                            scaleX = grow
                            scaleY = grow
                        },
                        onDrawSurface = {
                            drawRect(colors.glass, alpha = 1f - press.value)
                            drawRect(colors.tabSelection, alpha = 1f - press.value)
                            drawRect(Color.White.copy(alpha = if (colors.dark) 0.08f else 0.3f), alpha = press.value)
                        },
                    )
                },
            )
            Row(Modifier.fillMaxSize().selectableGroup()) {
                Page.entries.forEach { page ->
                    val active = page.ordinal == lit
                    val tint by animateColorAsState(if (active) colors.accentText else colors.label, label = "tab")
                    val name = stringResource(page.label)
                    Column(
                        Modifier.weight(1f).fillMaxHeight()
                            .graphicsLayer {
                                val grow = if (active) 1f + 0.12f * press.value else 1f
                                scaleX = grow
                                scaleY = grow
                            }
                            .semantics {
                                role = Role.Tab
                                this.selected = page == selected
                                contentDescription = name
                                onClick {
                                    onSelect(page)
                                    true
                                }
                            },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
                    ) {
                        Icon(page.icon, contentDescription = null, tint = tint, modifier = Modifier.size(if (labels) 22.dp else 26.dp))
                        if (labels) {
                            Text(
                                name,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, lineHeight = 12.sp),
                                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                                color = tint,
                                maxLines = 1,
                            )
                        }
                    }
                }
            }
        }
    }
}

private val refracts = Build.VERSION.SDK_INT >= 33
private val slide = spring(0.78f, 420f, 0.001f)
private val follow = spring(1f, 900f, 0.001f)
private val swell = spring(0.55f, 380f, 0.001f)
