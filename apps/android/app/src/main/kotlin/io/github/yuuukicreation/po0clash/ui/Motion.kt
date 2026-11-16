package io.github.yuuukicreation.po0clash.ui

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.SeekableTransitionState
import androidx.compose.animation.core.rememberTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt
import kotlinx.coroutines.CancellationException

val LocalReduceMotion = staticCompositionLocalOf { false }

val StandardEasing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
val EnterEasing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
val ExitEasing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)
val TabEasing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)
val EaseOutBack = Easing { fraction ->
    val x = fraction - 1f
    1f + 2.70158f * x * x * x + 1.70158f * x * x
}

// prism_ui's bounded spring curves include the remaining displacement at the last frame.
private fun referenceSpring(stiffness: Float, ratio: Float, milliseconds: Int, velocity: Float = 0f): Easing {
    val omega = sqrt(stiffness.toDouble())
    fun position(seconds: Double): Double {
        if (ratio == 1f) return 1 + (-1 + (velocity - omega) * seconds) * exp(-omega * seconds)
        val damped = omega * sqrt(1 - ratio * ratio.toDouble())
        return 1 - exp(-ratio * omega * seconds) * (cos(damped * seconds) + (ratio * omega - velocity) / damped * sin(damped * seconds))
    }
    val seconds = milliseconds / 1000.0
    val residual = 1 - position(seconds)
    return Easing { fraction -> (position(fraction * seconds) + residual * fraction).toFloat() }
}

val AlertEasing = referenceSpring((2 * PI / 0.275).toFloat().let { it * it }, 1f, 404)
val PopupEasing = referenceSpring(400f, 0.754f, 450)
val SheetEasing = referenceSpring(1000f / 3f, 1f, 500)
private val PushEasing = referenceSpring((2 * PI / 0.3).toFloat().let { it * it }, 1f, 450, 9f)

@Composable
fun rememberReduceMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    fun disabled() = Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    var reduce by remember(resolver) { mutableStateOf(disabled()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) { reduce = disabled() }
        }
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return reduce
}

fun tabTransition(animate: Boolean): ContentTransform = ContentTransform(
    targetContentEnter = if (animate) fadeIn(tween(220, easing = TabEasing)) else EnterTransition.None,
    initialContentExit = if (animate) fadeOut(tween(220, easing = TabEasing)) else ExitTransition.None,
    sizeTransform = null,
)

private fun <T> AnimatedContentTransitionScope<T?>.axis(animate: Boolean): ContentTransform {
    if (!animate) return (EnterTransition.None togetherWith ExitTransition.None).using(null)
    val forward = targetState != null
    return (slideInHorizontally(tween(450, easing = PushEasing)) { if (forward) it else -(it * 0.3f).toInt() } togetherWith
        slideOutHorizontally(tween(450, easing = PushEasing)) { if (forward) -(it * 0.3f).toInt() else it })
        .using(null).apply { targetContentZIndex = if (forward) 1f else -1f }
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
    rememberTransition(state, label).AnimatedContent(transitionSpec = { axis(motion) }) { page ->
        Box(Modifier.fillMaxSize().background(palette.bg)) { content(page) }
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
