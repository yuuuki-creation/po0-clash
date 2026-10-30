package io.github.yuuukicreation.po0clash.ui

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Hub
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SpaceDashboard
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.chrisbanes.haze.rememberHazeState
import io.github.yuuukicreation.po0clash.R

enum class Page(@param:StringRes val label: Int, val icon: ImageVector) {
    DASHBOARD(R.string.dashboard, Icons.Filled.SpaceDashboard),
    PROXIES(R.string.proxies, Icons.Filled.Hub),
    SUBSCRIPTIONS(R.string.subscriptions, Icons.Filled.Inbox),
    WHITELIST(R.string.whitelist, Icons.Filled.VerifiedUser),
    SETTINGS(R.string.settings, Icons.Filled.Settings),
}

private val tabBarHeight = 62.dp
private val tabBarMargin = 18.dp

@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var page by rememberSaveable { mutableStateOf(Page.DASHBOARD) }
    val pages = rememberSaveableStateHolder()
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val haze = rememberHazeState()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + tabBarMargin + tabBarHeight
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    BackHandler(enabled = page != Page.DASHBOARD) { page = Page.DASHBOARD }

    CompositionLocalProvider(LocalHaze provides haze, LocalSheets provides sheets, LocalBottomPadding provides bottom) {
        Box(Modifier.fillMaxSize().background(apple.background)) {
            pages.SaveableStateProvider(page) {
                when (page) {
                    Page.DASHBOARD -> DashboardScreen(vm, onConnect, onOpen = { page = it })
                    Page.PROXIES -> ProxiesScreen(vm)
                    Page.SUBSCRIPTIONS -> SubscriptionsScreen(vm)
                    Page.WHITELIST -> WhitelistScreen(vm)
                    Page.SETTINGS -> SettingsScreen(vm)
                }
            }
            Column(Modifier.align(Alignment.BottomCenter)) {
                GlassToastHost(snackbar, Modifier.padding(bottom = 76.dp))
                TabBar(page, onSelect = { page = it })
            }
            SheetHost(sheets)
        }
    }
}

/** iOS 26's floating tab bar: one glass capsule inset from the edges, the selected tab on a brighter sliding capsule. */
@Composable
private fun TabBar(selected: Page, onSelect: (Page) -> Unit) {
    val colors = apple
    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(bottom = tabBarMargin), contentAlignment = Alignment.Center) {
        BoxWithConstraints(
            Modifier.padding(horizontal = tabBarMargin).widthIn(max = 480.dp).fillMaxWidth().height(tabBarHeight)
                .glass(CircleShape).padding(4.dp),
        ) {
            val width = maxWidth / Page.entries.size
            val offset by animateDpAsState(width * selected.ordinal, label = "tab")
            Box(Modifier.offset(x = offset).width(width).fillMaxHeight().background(colors.tabSelection, CircleShape))
            Row(Modifier.fillMaxSize().selectableGroup()) {
                Page.entries.forEach { page ->
                    val active = page == selected
                    val tint = if (active) colors.accent else colors.label
                    Column(
                        Modifier.weight(1f).fillMaxHeight().clip(CircleShape)
                            .semantics { this.selected = active }
                            .clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Tab) {
                                onSelect(page)
                            },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Icon(
                            page.icon,
                            contentDescription = null,
                            tint = tint,
                            modifier = Modifier.size(24.dp),
                        )
                        Text(
                            stringResource(page.label),
                            style = MaterialTheme.typography.labelSmall,
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
