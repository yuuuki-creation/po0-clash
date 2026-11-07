package io.github.yuuukicreation.po0clash.ui

import android.provider.Settings
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.SeekableTransitionState
import androidx.compose.animation.core.rememberTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.CancellationException

val LocalReduceMotion = staticCompositionLocalOf { false }

val StandardEasing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
val EnterEasing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
val ExitEasing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)

@Composable
fun rememberReduceMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    var reduce by remember { mutableStateOf(false) }
    LifecycleResumeEffect(resolver) {
        reduce = Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        onPauseOrDispose {}
    }
    return reduce
}

fun fadeThrough(animate: Boolean): ContentTransform =
    if (!animate) {
        EnterTransition.None togetherWith ExitTransition.None
    } else {
        (fadeIn(tween(300, easing = StandardEasing)) + scaleIn(tween(300, easing = StandardEasing), initialScale = 0.96f)) togetherWith
            fadeOut(tween(90, easing = LinearEasing))
    }

private fun <T> AnimatedContentTransitionScope<T?>.axis(animate: Boolean, shift: Int): ContentTransform {
    if (!animate) return EnterTransition.None togetherWith ExitTransition.None
    val sign = if (targetState != null) 1 else -1
    return (
        slideInHorizontally(tween(300, easing = StandardEasing)) { sign * shift } + fadeIn(tween(210, 90, LinearEasing))
        ) togetherWith (
        slideOutHorizontally(tween(300, easing = StandardEasing)) { -sign * shift } + fadeOut(tween(90, easing = LinearEasing))
        )
}

/** A stack one page deep, moving along the x axis both ways; the system back gesture seeks the transition. */
@Composable
fun <T : Any> PushHost(
    target: T?,
    animate: Boolean,
    onBack: () -> Unit,
    label: String,
    backEnabled: Boolean = true,
    content: @Composable (T?) -> Unit,
) {
    val motion = animate && !LocalReduceMotion.current
    val state = remember { SeekableTransitionState(target) }
    val sheets = LocalSheets.current
    val shift = with(LocalDensity.current) { 30.dp.roundToPx() }
    LaunchedEffect(target, motion) {
        if (state.currentState == target && state.targetState == target) return@LaunchedEffect
        if (motion) state.animateTo(target) else state.snapTo(target)
    }
    PredictiveBackHandler(enabled = backEnabled && target != null && !sheets.open) { events ->
        try {
            events.collect { event -> if (motion) state.seekTo(event.progress, targetState = null) }
            onBack()
        } catch (e: CancellationException) {
            state.animateTo(state.currentState)
            throw e
        }
    }
    rememberTransition(state, label).AnimatedContent(transitionSpec = { axis(motion, shift) }) { page ->
        Box(Modifier.fillMaxSize()) { content(page) }
    }
}

@Composable
fun LazyItemScope.itemMotion(): Modifier =
    if (LocalReduceMotion.current) {
        Modifier
    } else {
        Modifier.animateItem(
            fadeInSpec = tween(250, easing = EnterEasing),
            placementSpec = tween(250, easing = StandardEasing),
            fadeOutSpec = tween(200, easing = ExitEasing),
        )
    }

@Composable
fun LazyGridItemScope.itemMotion(): Modifier =
    if (LocalReduceMotion.current) {
        Modifier
    } else {
        Modifier.animateItem(
            fadeInSpec = tween(250, easing = EnterEasing),
            placementSpec = tween(250, easing = StandardEasing),
            fadeOutSpec = tween(200, easing = ExitEasing),
        )
    }
