package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.chrisbanes.haze.rememberHazeState

@Composable
fun App(onConnect: () -> Unit, vm: AppViewModel = viewModel()) {
    var settings by rememberSaveable { mutableStateOf(false) }
    val snackbar = remember { SnackbarHostState() }
    val sheets = remember { Sheets() }
    val haze = rememberHazeState()
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    BackHandler(enabled = settings) { settings = false }

    CompositionLocalProvider(LocalHaze provides haze, LocalSheets provides sheets) {
        Box(Modifier.fillMaxSize().background(apple.background)) {
            AnimatedContent(
                targetState = settings,
                transitionSpec = {
                    val direction = if (targetState) 1 else -1
                    (slideInHorizontally { it / 3 * direction } + fadeIn()) togetherWith
                        (slideOutHorizontally { -it / 3 * direction } + fadeOut())
                },
                label = "screen",
            ) { showSettings ->
                if (showSettings) {
                    SettingsScreen(vm, snackbar, onBack = { settings = false })
                } else {
                    MainScreen(vm, snackbar, onConnect, onSettings = { settings = true })
                }
            }
            SheetHost(sheets)
        }
    }
}
