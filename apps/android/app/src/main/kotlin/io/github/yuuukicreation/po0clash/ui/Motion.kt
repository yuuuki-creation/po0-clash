package io.github.yuuukicreation.po0clash.ui

import android.provider.Settings
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.SeekableTransitionState
import androidx.compose.animation.core.rememberTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.IndicationNodeFactory
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.node.CompositionLocalConsumerModifierNode
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.currentValueOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

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

/** iOS list and button feedback: a gray wash while held that fades out on release, in place of Material's ripple. */
object ApplePress : IndicationNodeFactory {
    override fun create(interactionSource: InteractionSource): DelegatableNode = ApplePressNode(interactionSource)

    override fun equals(other: Any?) = other === this

    override fun hashCode() = 0x1a5e
}

private class ApplePressNode(private val source: InteractionSource) :
    Modifier.Node(), DrawModifierNode, CompositionLocalConsumerModifierNode {
    private val wash = Animatable(0f)

    override fun onAttach() {
        coroutineScope.launch {
            val held = mutableSetOf<PressInteraction.Press>()
            source.interactions.collect { interaction ->
                when (interaction) {
                    is PressInteraction.Press -> held += interaction
                    is PressInteraction.Release -> held -= interaction.press
                    is PressInteraction.Cancel -> held -= interaction.press
                }
                val target = if (held.isEmpty()) 0f else 1f
                launch { wash.animateTo(target, tween(if (target == 1f) 60 else 280)) }
            }
        }
    }

    override fun ContentDrawScope.draw() {
        drawContent()
        val alpha = wash.value
        if (alpha > 0f) drawRect(currentValueOf(LocalAppleColors).pressed, alpha = alpha)
    }
}

fun <T> AnimatedContentTransitionScope<T?>.push(animate: Boolean): ContentTransform = when {
    !animate -> EnterTransition.None togetherWith ExitTransition.None
    targetState != null -> (slideInHorizontally(pushSpring) { it }) togetherWith
        (slideOutHorizontally(pushSpring) { -it / 3 } + fadeOut(tween(300), 0.7f))
    else -> ((slideInHorizontally(pushSpring) { -it / 3 } + fadeIn(tween(300), 0.7f)) togetherWith
        slideOutHorizontally(pushSpring) { it }).apply { targetContentZIndex = -1f }
}

private val pushSpring = spring(1f, 380f, androidx.compose.ui.unit.IntOffset(1, 1))

/** A stack one page deep; the back gesture drags the page out with the finger, as iOS's edge swipe does. */
@Composable
fun <T : Any> PushHost(target: T?, animate: Boolean, onBack: () -> Unit, label: String, content: @Composable (T?) -> Unit) {
    val motion = animate && !LocalReduceMotion.current
    val state = remember { SeekableTransitionState(target) }
    val sheets = LocalSheets.current
    LaunchedEffect(target, motion) {
        if (state.currentState == target && state.targetState == target) return@LaunchedEffect
        if (motion) state.animateTo(target) else state.snapTo(target)
    }
    PredictiveBackHandler(enabled = target != null && !sheets.open) { events ->
        try {
            events.collect { event -> if (motion) state.seekTo(event.progress, targetState = null) }
            onBack()
        } catch (e: CancellationException) {
            state.animateTo(state.currentState)
            throw e
        }
    }
    rememberTransition(state, label).AnimatedContent(transitionSpec = { push(motion) }) { page ->
        Box(Modifier.fillMaxSize().background(apple.background)) { content(page) }
    }
}

/** SwiftUI's numeric text transition; digits pair up from the right so a number gaining a digit rolls in only that one. */
@Composable
fun RollingText(text: String, style: TextStyle, modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    if (LocalReduceMotion.current) {
        Text(text, style = style, color = color, maxLines = 1, modifier = modifier)
        return
    }
    var shown by remember { mutableStateOf(text) }
    val rising = remember(text) { (text.numeric() ?: 0.0) >= (shown.numeric() ?: 0.0) }
    SideEffect { shown = text }
    Row(modifier) {
        text.forEachIndexed { index, char ->
            key(text.length - index) {
                AnimatedContent(
                    char,
                    transitionSpec = {
                        if (!initialState.isDigit() || !targetState.isDigit()) {
                            fadeIn(tween(150)) togetherWith fadeOut(tween(100))
                        } else {
                            val sign = if (rising) 1 else -1
                            (slideInVertically(digitSpring) { sign * it / 2 } + fadeIn(tween(180))) togetherWith
                                (slideOutVertically(digitSpring) { -sign * it / 2 } + fadeOut(tween(120)))
                        }.using(SizeTransform(clip = false))
                    },
                    label = "digit",
                ) { Text(it.toString(), style = style, color = color, maxLines = 1) }
            }
        }
    }
}

private val digitSpring = spring(0.85f, 500f, androidx.compose.ui.unit.IntOffset(1, 1))

private fun String.numeric() = filter { it.isDigit() || it == '.' }.toDoubleOrNull()

@Composable
fun LazyItemScope.itemMotion(): Modifier =
    if (LocalReduceMotion.current) Modifier else Modifier.animateItem()

@Composable
fun LazyGridItemScope.itemMotion(): Modifier =
    if (LocalReduceMotion.current) Modifier else Modifier.animateItem()
