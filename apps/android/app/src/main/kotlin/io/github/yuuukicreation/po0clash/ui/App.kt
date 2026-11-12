package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.filled.Construction
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.SpaceDashboard
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.LaunchCheck
import io.github.yuuukicreation.po0clash.core.LaunchRecovery

enum class Page(@param:StringRes val label: Int, val icon: ImageVector) {
    DASHBOARD(R.string.dashboard, LineIcons.Dashboard),
    PROXIES(R.string.proxies, LineIcons.Globe),
    PROFILES(R.string.profiles, LineIcons.Profile),
    WHITELIST(R.string.whitelist, Icons.Filled.VerifiedUser),
    TOOLS(R.string.tools, LineIcons.Tools),
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var page by rememberSaveable { mutableStateOf(Page.DASHBOARD) }
    var dashboardEditing by rememberSaveable { mutableStateOf(false) }
    var proxyGroup by rememberSaveable { mutableStateOf<String?>(null) }
    val pages = rememberSaveableStateHolder()
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val destinations = if (dashboardEditing) listOf(Page.DASHBOARD, Page.TOOLS) else Page.entries.filter { it != Page.PROXIES || profiles.isNotEmpty() }
    val reduceMotion = LocalReduceMotion.current
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    val notice by vm.engine.launchNotice.collectAsStateWithLifecycle()
    LaunchedEffect(notice) {
        val check = notice ?: return@LaunchedEffect
        vm.engine.dismissLaunchNotice()
        sheets.show { LaunchNotice(check, sheets::dismiss) }
    }
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
    BackHandler(enabled = dashboardEditing) { dashboardEditing = false }
    val fade = settings.pageAnimation && !reduceMotion
    val select: (Page) -> Unit = {
        dashboardEditing = false
        proxyGroup = null
        page = it
    }

    BoxWithConstraints(Modifier.fillMaxSize().background(palette.bg)) {
        val rail = maxWidth >= 600.dp
        val navigationBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        CompositionLocalProvider(
            LocalSheets provides sheets,
            LocalWindowWidth provides maxWidth,
            LocalBottomInset provides if (rail) navigationBottom else 62.dp + maxOf(21.dp, navigationBottom),
        ) {
            Row(Modifier.fillMaxSize()) {
                if (rail) NavRail(destinations, page, settings.showNavLabels, select)
                Box(Modifier.weight(1f).fillMaxHeight().windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.End))) {
                    Box(Modifier.fillMaxSize().imePadding()) {
                        AnimatedContent(page, transitionSpec = { fadeThrough(fade) }, label = "tabs") { target ->
                            pages.SaveableStateProvider(target) {
                                when (target) {
                                    Page.DASHBOARD -> DashboardScreen(
                                        vm,
                                        onConnect,
                                        editing = dashboardEditing,
                                        onEditing = { dashboardEditing = it },
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
                    if (!rail && !WindowInsets.isImeVisible) {
                        BottomNav(destinations, page, settings.showNavLabels, Modifier.align(Alignment.BottomCenter).padding(bottom = maxOf(21.dp, navigationBottom)), select)
                    }
                }
            }
            SheetHost(sheets)
        }
    }
}

@Composable
private fun Toasts(state: SnackbarHostState, modifier: Modifier) {
    SnackbarHost(state, modifier.padding(bottom = LocalBottomInset.current))
}

@Composable
private fun NavIcon(page: Page, title: String, labels: Boolean) {
    Icon(page.icon, contentDescription = title.takeIf { !labels })
}

@Composable
private fun BottomNav(items: List<Page>, selected: Page, labels: Boolean, modifier: Modifier, onSelect: (Page) -> Unit) {
    val colors = palette
    val select by rememberUpdatedState(onSelect)
    val reduceMotion = LocalReduceMotion.current
    BoxWithConstraints(modifier.fillMaxWidth().padding(horizontal = 21.dp), contentAlignment = Alignment.Center) {
        val width = minOf(maxWidth, 86.dp * items.size + 8.dp)
        val itemWidth = (width - 8.dp) / items.size
        val index = items.indexOf(selected).coerceAtLeast(0)
        val position by animateDpAsState(
            itemWidth * index,
            if (reduceMotion) snap() else spring(dampingRatio = 0.85f, stiffness = 650f),
            label = "navigation",
        )
        Surface(
            Modifier.widthIn(max = width).height(62.dp),
            shape = CircleShape,
            color = colors.card,
            shadowElevation = 12.dp,
        ) {
            BoxWithConstraints(Modifier.fillMaxSize().padding(4.dp).pointerInput(items) {
                var dragX = 0f
                var last = -1
                detectHorizontalDragGestures(
                    onDragStart = { dragX = it.x; last = -1 },
                    onHorizontalDrag = { change, amount ->
                        change.consume()
                        dragX += amount
                        val next = (dragX / (size.width.toFloat() / items.size)).toInt().coerceIn(items.indices)
                        if (next != last) { last = next; select(items[next]) }
                    },
                )
            }) {
                Box(Modifier.offset(x = position).widthIn(min = itemWidth, max = itemWidth).fillMaxHeight().background(colors.block, CircleShape))
                Row(Modifier.fillMaxSize()) {
                    items.forEach { page ->
                        val title = stringResource(page.label)
                        val active = page == selected
                        Column(
                            Modifier.weight(1f).fillMaxHeight().clip(CircleShape).selectable(active, role = Role.Tab, onClick = { onSelect(page) }),
                            verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(page.icon, if (labels) null else title, Modifier.size(28.dp), tint = if (active) colors.accent else colors.ink2)
                            if (labels) {
                                Text(title, color = if (active) colors.accent else colors.ink2, fontSize = 10.sp,
                                    lineHeight = 14.5.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NavRail(items: List<Page>, selected: Page, labels: Boolean, onSelect: (Page) -> Unit) {
    NavigationRail(containerColor = MaterialTheme.colorScheme.surfaceContainer) {
        Spacer(Modifier.height(8.dp))
        items.forEach { page ->
            val title = stringResource(page.label)
            NavigationRailItem(
                selected = page == selected,
                onClick = { onSelect(page) },
                icon = { NavIcon(page, title, labels) },
                label = if (labels) {
                    { Text(title, maxLines = 1) }
                } else {
                    null
                },
                alwaysShowLabel = labels,
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
