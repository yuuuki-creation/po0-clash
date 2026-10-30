package io.github.yuuukicreation.po0clash.ui

import android.os.SystemClock
import androidx.activity.compose.BackHandler
import androidx.annotation.StringRes
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.chrisbanes.haze.rememberHazeState
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import kotlinx.coroutines.delay

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

@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var page by rememberSaveable { mutableStateOf(Page.DASHBOARD) }
    val pages = rememberSaveableStateHolder()
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val haze = rememberHazeState()
    val tabBarBottom = maxOf(30.dp, WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + barGap)
    val bottom = tabBarBottom + tabBarHeight + barGap + statusBarHeight
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    BackHandler(enabled = page != Page.DASHBOARD) { page = Page.DASHBOARD }

    CompositionLocalProvider(LocalHaze provides haze, LocalSheets provides sheets, LocalBottomPadding provides bottom) {
        Box(Modifier.fillMaxSize().background(apple.background)) {
            pages.SaveableStateProvider(page) {
                when (page) {
                    Page.DASHBOARD -> DashboardScreen(vm, onConnect, onOpen = { page = it })
                    Page.PROXIES -> ProxiesScreen(vm)
                    Page.PROFILES -> SubscriptionsScreen(vm)
                    Page.WHITELIST -> WhitelistScreen(vm)
                    Page.TOOLS -> ToolsScreen(vm)
                }
            }
            Column(
                Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarBottom),
                verticalArrangement = Arrangement.spacedBy(barGap),
            ) {
                GlassToastHost(snackbar)
                StatusBar(vm, onConnect)
                TabBar(page, vm.appSettings.collectAsStateWithLifecycle().value.showNavLabels, onSelect = { page = it })
            }
            SheetHost(sheets)
        }
    }
}

/** The spec's bottom status bar: state dot, state and "uptime · node", and the one solid start/stop button. */
@Composable
private fun StatusBar(vm: AppViewModel, onConnect: () -> Unit) {
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
        active && since != null -> listOfNotNull(elapsed(since), status.currentNode).joinToString(" · ")
        active -> ""
        failure != null -> failure
        enabled -> stringResource(R.string.tap_to_connect)
        else -> stringResource(R.string.add_profile_first)
    }
    Row(
        Modifier.padding(horizontal = barSide).widthIn(max = 480.dp).fillMaxWidth().height(statusBarHeight)
            .glass(CircleShape).padding(start = 18.dp, end = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(8.dp).background(dot, CircleShape))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
            if (detail.isNotEmpty()) {
                Text(
                    detail,
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, lineHeight = 15.sp).tabular(),
                    color = colors.secondaryLabel,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
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
            when {
                active && since == null -> CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = Color.White)
                active -> Icon(LineIcons.Stop, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                else -> Icon(LineIcons.Play, contentDescription = null, tint = Color.White, modifier = Modifier.size(15.dp))
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

/** iOS 26's floating tab bar: one glass capsule, the selected tab in the accent color on a faint sliding capsule. */
@Composable
private fun TabBar(selected: Page, labels: Boolean, onSelect: (Page) -> Unit) {
    val colors = apple
    BoxWithConstraints(
        Modifier.padding(horizontal = barSide).widthIn(max = 480.dp).fillMaxWidth().height(tabBarHeight)
            .glass(CircleShape).padding(4.dp),
    ) {
        val width = maxWidth / Page.entries.size
        val offset by animateDpAsState(width * selected.ordinal, label = "tab")
        Box(Modifier.offset(x = offset).width(width).fillMaxHeight().background(colors.tabSelection, CircleShape))
        Row(Modifier.fillMaxSize().selectableGroup()) {
            Page.entries.forEach { page ->
                val active = page == selected
                val tint = if (active) colors.accentText else colors.label
                Column(
                    Modifier.weight(1f).fillMaxHeight().clip(CircleShape)
                        .semantics { this.selected = active }
                        .clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Tab) {
                            onSelect(page)
                        },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
                ) {
                    Icon(page.icon, contentDescription = stringResource(page.label).takeIf { !labels }, tint = tint, modifier = Modifier.size(if (labels) 22.dp else 26.dp))
                    if (labels) Text(
                        stringResource(page.label),
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
