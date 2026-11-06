package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import io.github.yuuukicreation.po0clash.core.AppSettings
import io.github.yuuukicreation.po0clash.core.ThemeMode

/** The Astryx 0.7.9 tokens from docs/design/native-ui/demo/src/colors.css (`.and.*.pal-b`). */
@Immutable
data class Po0Colors(
    val bg: Color,
    val card: Color,
    val line: Color,
    val ink: Color,
    val ink2: Color,
    val ink3: Color,
    val accent: Color,
    val onAccent: Color,
    val track: Color,
    val scrim: Color,
    val good: Color,
    val warn: Color,
    val bad: Color,
    val goodMuted: Color,
    val warnMuted: Color,
    val badMuted: Color,
    val cardHi: Color,
    val outline: Color,
    val sel: Color,
    val onSel: Color,
    val fab: Color,
    val onFab: Color,
    val sheet: Color,
    val dark: Boolean,
)

private val Light = Po0Colors(
    bg = Color(0xFFF8F9FF),
    card = Color(0xFFFFFFFF),
    line = Color(0xFFE0E2EC),
    ink = Color(0xFF191C20),
    ink2 = Color(0xFF43474E),
    ink3 = Color(0xFF73777F),
    accent = Color(0xFF0061A4),
    onAccent = Color.White,
    track = Color(0xFFECEEF4),
    scrim = Color(0x66000000),
    good = Color(0xFF146C2E),
    warn = Color(0xFF835500),
    bad = Color(0xFFBA1A1A),
    goodMuted = Color(0x26146C2E),
    warnMuted = Color(0x26835500),
    badMuted = Color(0x26BA1A1A),
    cardHi = Color(0xFFE6E8EE),
    outline = Color(0xFF73777F),
    sel = Color(0xFFD1E4FF),
    onSel = Color(0xFF001D36),
    fab = Color(0xFF0061A4),
    onFab = Color.White,
    sheet = Color(0xFFF2F3FA),
    dark = false,
)

private val Dark = Po0Colors(
    bg = Color(0xFF111318),
    card = Color(0xFF1D2024),
    line = Color(0xFF2E3137),
    ink = Color(0xFFE2E2E9),
    ink2 = Color(0xFFC3C6CF),
    ink3 = Color(0xFF8D9199),
    accent = Color(0xFF0171E3),
    onAccent = Color.White,
    track = Color(0xFF282A2F),
    scrim = Color(0x99000000),
    good = Color(0xFF6DD58C),
    warn = Color(0xFFFFB951),
    bad = Color(0xFFFFB4AB),
    goodMuted = Color(0x336DD58C),
    warnMuted = Color(0x33FFB951),
    badMuted = Color(0x33FFB4AB),
    cardHi = Color(0xFF33353A),
    outline = Color(0xFF8D9199),
    sel = Color(0xFF00497D),
    onSel = Color(0xFFD1E4FF),
    fab = Color(0xFF0171E3),
    onFab = Color.White,
    sheet = Color(0xFF282A2F),
    dark = true,
)

val LocalPo0Colors = staticCompositionLocalOf { Light }

val palette: Po0Colors
    @Composable get() = LocalPo0Colors.current

private val typography = Typography(
    titleLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold, lineHeight = 26.sp),
    titleMedium = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontSize = 15.sp, lineHeight = 21.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, lineHeight = 20.sp),
    labelMedium = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, lineHeight = 16.sp),
    labelSmall = TextStyle(fontSize = 12.sp, lineHeight = 16.sp),
)

/** Fixed-width digits, so rates and delays do not jitter as they change. */
fun TextStyle.tabular() = copy(fontFeatureSettings = "tnum")

private const val DEFAULT_ACCENT = 0xFF0064E0u
private const val PINE_ACCENT = 0xFF24694Cu

private fun contrast(a: Color, b: Color): Float {
    val (hi, lo) = listOf(a.luminance(), b.luminance()).sortedDescending()
    return (hi + 0.05f) / (lo + 0.05f)
}

private val onAccentChoices = listOf(Color.White, Color(0xFF0A1317))

/**
 * A chosen theme color works as text on the card, so it is pulled towards the ink until it reaches WCAG AA;
 * the default keeps the exact pair the design picked.
 */
fun Po0Colors.withAccent(argb: UInt?, pureBlack: Boolean): Po0Colors {
    val base = if (pureBlack && dark) copy(bg = Color.Black, card = Color(0xFF121316)) else this
    if (argb == null || argb == DEFAULT_ACCENT) return base
    if (argb == PINE_ACCENT) {
        val accent = if (dark) Color(0xFF80CEA8) else Color(0xFF24694C)
        val onAccent = if (dark) Color(0xFF0D1F16) else Color.White
        return base.copy(
            accent = accent,
            onAccent = onAccent,
            sel = accent.copy(alpha = if (dark) 0.22f else 0.14f),
            onSel = accent,
            fab = Color(0xFF24694C),
            onFab = Color.White,
        )
    }
    val chosen = Color(argb.toInt())
    val steps = generateSequence(0f) { it + 0.05f }.takeWhile { it <= 1f }
    val accent = steps.map { lerp(chosen, ink, it) }.first { contrast(it, card) >= 4.5f }
    val onAccent = onAccentChoices.maxBy { contrast(it, accent) }
    return base.copy(
        accent = accent,
        onAccent = onAccent,
        sel = accent.copy(alpha = if (dark) 0.22f else 0.14f),
        onSel = accent,
        fab = accent,
        onFab = onAccent,
    )
}

/** Colors for [dark] with [settings] applied, without the theme fade; separate so it can run off a device. */
fun paletteFor(dark: Boolean, argb: UInt?, pureBlack: Boolean) = (if (dark) Dark else Light).withAccent(argb, pureBlack)

private fun lerp(a: Po0Colors, b: Po0Colors, t: Float) = Po0Colors(
    bg = lerp(a.bg, b.bg, t),
    card = lerp(a.card, b.card, t),
    line = lerp(a.line, b.line, t),
    ink = lerp(a.ink, b.ink, t),
    ink2 = lerp(a.ink2, b.ink2, t),
    ink3 = lerp(a.ink3, b.ink3, t),
    accent = lerp(a.accent, b.accent, t),
    onAccent = lerp(a.onAccent, b.onAccent, t),
    track = lerp(a.track, b.track, t),
    scrim = lerp(a.scrim, b.scrim, t),
    good = lerp(a.good, b.good, t),
    warn = lerp(a.warn, b.warn, t),
    bad = lerp(a.bad, b.bad, t),
    goodMuted = lerp(a.goodMuted, b.goodMuted, t),
    warnMuted = lerp(a.warnMuted, b.warnMuted, t),
    badMuted = lerp(a.badMuted, b.badMuted, t),
    cardHi = lerp(a.cardHi, b.cardHi, t),
    outline = lerp(a.outline, b.outline, t),
    sel = lerp(a.sel, b.sel, t),
    onSel = lerp(a.onSel, b.onSel, t),
    fab = lerp(a.fab, b.fab, t),
    onFab = lerp(a.onFab, b.onFab, t),
    sheet = lerp(a.sheet, b.sheet, t),
    dark = b.dark,
)

@Composable
private fun fadedPalette(target: Po0Colors): Po0Colors {
    var from by remember { mutableStateOf(target) }
    var to by remember { mutableStateOf(target) }
    val progress = remember { Animatable(1f) }
    LaunchedEffect(target) {
        if (target == to) return@LaunchedEffect
        from = lerp(from, to, progress.value)
        to = target
        progress.snapTo(0f)
        progress.animateTo(1f, tween(200))
    }
    return if (progress.value >= 1f) to else lerp(from, to, progress.value)
}

@Composable
fun Po0Theme(settings: AppSettings? = null, content: @Composable () -> Unit) {
    val dark = when (settings?.themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        else -> isSystemInDarkTheme()
    }
    val colors = fadedPalette(paletteFor(dark, settings?.themeColor, settings?.pureBlack == true))
    val scheme = (if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = colors.accent,
        onPrimary = colors.onAccent,
        primaryContainer = colors.sel,
        onPrimaryContainer = colors.onSel,
        secondaryContainer = colors.sel,
        onSecondaryContainer = colors.onSel,
        background = colors.bg,
        onBackground = colors.ink,
        surface = colors.card,
        surfaceContainer = colors.card,
        surfaceContainerLow = colors.card,
        surfaceContainerHigh = colors.sheet,
        onSurface = colors.ink,
        onSurfaceVariant = colors.ink2,
        surfaceContainerHighest = colors.track,
        inverseSurface = colors.ink,
        inverseOnSurface = colors.bg,
        outline = colors.outline,
        outlineVariant = colors.line,
        error = colors.bad,
    )
    val activity = LocalActivity.current
    val view = LocalView.current
    SideEffect {
        val window = activity?.window ?: return@SideEffect
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !dark
            isAppearanceLightNavigationBars = !dark
        }
    }
    val density = LocalDensity.current
    val scale = settings?.textScale?.let { it.toFloat() / 100f } ?: 1f
    CompositionLocalProvider(
        LocalPo0Colors provides colors,
        LocalReduceMotion provides rememberReduceMotion(),
        LocalDensity provides Density(density.density, density.fontScale * scale),
    ) {
        MaterialTheme(colorScheme = scheme, typography = typography) {
            CompositionLocalProvider(LocalContentColor provides colors.ink, content = content)
        }
    }
}
