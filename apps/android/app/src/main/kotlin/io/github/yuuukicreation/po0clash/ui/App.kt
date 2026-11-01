package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.LaunchCheck
import io.github.yuuukicreation.po0clash.core.LaunchRecovery

enum class Page(@param:StringRes val label: Int, val icon: ImageVector) {
    DASHBOARD(R.string.dashboard, LineIcons.Dashboard),
    PROXIES(R.string.proxies, LineIcons.Globe),
    PROFILES(R.string.profiles, LineIcons.Layers),
    WHITELIST(R.string.whitelist, LineIcons.ShieldCheck),
    TOOLS(R.string.tools, LineIcons.Sliders),
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var page by rememberSaveable { mutableStateOf(Page.DASHBOARD) }
    var proxyGroup by rememberSaveable { mutableStateOf<String?>(null) }
    val pages = rememberSaveableStateHolder()
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val reduceMotion = LocalReduceMotion.current
    val colors = palette
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
    BackHandler(enabled = page != Page.DASHBOARD) { page = Page.DASHBOARD }
    val fade = settings.pageAnimation && !reduceMotion
    val select: (Page) -> Unit = {
        proxyGroup = null
        page = it
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(colors.bg)) {
        val rail = maxWidth >= 600.dp
        val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        CompositionLocalProvider(
            LocalSheets provides sheets,
            LocalWindowWidth provides maxWidth,
            LocalBottomInset provides if (rail) navigationBottom else 0.dp,
        ) {
            Row(Modifier.fillMaxSize()) {
                if (rail) NavRail(page, settings.showNavLabels, select)
                Column(Modifier.weight(1f).fillMaxHeight().windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.End))) {
                    Box(Modifier.weight(1f).fillMaxWidth().imePadding()) {
                        AnimatedContent(page, transitionSpec = { fadeThrough(fade) }, label = "tabs") { target ->
                            pages.SaveableStateProvider(target) {
                                when (target) {
                                    Page.DASHBOARD -> DashboardScreen(
                                        vm,
                                        onConnect,
                                        onOpen = select,
                                        onOpenGroup = { group ->
                                            proxyGroup = group
                                            page = Page.PROXIES
                                        },
                                    )
                                    Page.PROXIES -> ProxiesScreen(vm, proxyGroup) { proxyGroup = it }
                                    Page.PROFILES -> SubscriptionsScreen(vm)
                                    Page.WHITELIST -> WhitelistScreen(vm)
                                    Page.TOOLS -> ToolsScreen(vm)
                                }
                            }
                        }
                        Toasts(snackbar, Modifier.align(Alignment.BottomCenter))
                    }
                    if (!rail && !WindowInsets.isImeVisible) BottomNav(page, settings.showNavLabels, select)
                }
            }
            SheetHost(sheets)
        }
    }
}

@Composable
private fun Toasts(state: SnackbarHostState, modifier: Modifier) {
    val colors = palette
    SnackbarHost(state, modifier.padding(bottom = LocalBottomInset.current)) { data ->
        Snackbar(data, shape = RoundedCornerShape(4.dp), containerColor = colors.ink, contentColor = colors.bg)
    }
}

@Composable
private fun BottomNav(selected: Page, labels: Boolean, onSelect: (Page) -> Unit) {
    val colors = palette
    val inset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxWidth().background(colors.card)) {
        Spacer(Modifier.fillMaxWidth().height(1.dp).background(colors.line))
        Row(Modifier.fillMaxWidth().selectableGroup().padding(top = 10.dp, bottom = maxOf(14.dp, inset))) {
            Page.entries.forEach { page ->
                NavItem(page, page == selected, labels, Modifier.weight(1f)) { onSelect(page) }
            }
        }
    }
}

@Composable
private fun NavRail(selected: Page, labels: Boolean, onSelect: (Page) -> Unit) {
    val colors = palette
    Row(Modifier.fillMaxHeight().background(colors.card).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Start))) {
        Column(
            Modifier.fillMaxHeight().width(88.dp).selectableGroup(),
            verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        ) {
            Page.entries.forEach { page ->
                NavItem(page, page == selected, labels, Modifier.fillMaxWidth()) { onSelect(page) }
            }
        }
        Spacer(Modifier.fillMaxHeight().width(1.dp).background(colors.line))
    }
}

@Composable
private fun NavItem(page: Page, selected: Boolean, labels: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = palette
    val width by animateFloatAsState(if (selected) 1f else 0.4f, tween(300, easing = StandardEasing), label = "pillWidth")
    val shown by animateFloatAsState(if (selected) 1f else 0f, tween(100), label = "pillAlpha")
    Column(
        modifier.selectable(selected, remember { MutableInteractionSource() }, indication = null, role = Role.Tab, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.size(56.dp, 32.dp), contentAlignment = Alignment.Center) {
            Box(
                Modifier.fillMaxSize().graphicsLayer {
                    scaleX = width
                    alpha = shown
                }.background(colors.sel, RoundedCornerShape(16.dp)),
            )
            Icon(page.icon, stringResource(page.label).takeIf { !labels }, tint = if (selected) colors.onSel else colors.ink, modifier = Modifier.size(22.dp))
        }
        if (labels) {
            Text(
                stringResource(page.label),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 1,
            )
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
        color = palette.ink2,
    )
    SheetDoneButton(onDone)
}
