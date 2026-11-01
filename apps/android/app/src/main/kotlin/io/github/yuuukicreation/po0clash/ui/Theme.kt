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

/** The warm grey tokens from docs/design/native-ui/demo/src/colors.css (`.and.*.pal-b`). */
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
    val warn: Color,
    val bad: Color,
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
    bg = Color(0xFFEFECE8),
    card = Color(0xFFFEFDFC),
    line = Color(0x1C211F1C),
    ink = Color(0xFF211F1C),
    ink2 = Color(0xFF575551),
    ink3 = Color(0xFF888681),
    accent = Color(0xFF24694C),
    onAccent = Color.White,
    track = Color(0xFFE2DFDA),
    scrim = Color(0x52000000),
    warn = Color(0xFF875800),
    bad = Color(0xFFAF2B25),
    cardHi = Color(0xFFE2DFDA),
    outline = Color(0xFF888681),
    sel = Color(0xFFDEDCD7),
    onSel = Color(0xFF211F1C),
    fab = Color(0xFFFEFDFC),
    onFab = Color(0xFF211F1C),
    sheet = Color(0xFFFBFAF8),
    dark = false,
)

private val Dark = Po0Colors(
    bg = Color(0xFF181714),
    card = Color(0xFF252421),
    line = Color(0x20F3F1EE),
    ink = Color(0xFFF3F1EE),
    ink2 = Color(0xFFB9B7B3),
    ink3 = Color(0xFF888682),
    accent = Color(0xFF80CEA8),
    onAccent = Color(0xFF0D1F16),
    track = Color(0xFF32302D),
    scrim = Color(0x80000000),
    warn = Color(0xFFEBC573),
    bad = Color(0xFFFB9890),
    cardHi = Color(0xFF32302D),
    outline = Color(0xFF888682),
    sel = Color(0xFF3E3D3A),
    onSel = Color(0xFFF3F1EE),
    fab = Color(0xFF32302D),
    onFab = Color(0xFFF3F1EE),
    sheet = Color(0xFF282623),
    dark = true,
)

val LocalPo0Colors = staticCompositionLocalOf { Light }

val palette: Po0Colors
    @Composable get() = LocalPo0Colors.current

private val typography = Typography(
    titleLarge = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Medium, lineHeight = 28.sp),
    titleMedium = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 22.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, lineHeight = 20.sp),
    labelMedium = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelSmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
)

/** Fixed-width digits, so rates and delays do not jitter as they change. */
fun TextStyle.tabular() = copy(fontFeatureSettings = "tnum")

private const val DEFAULT_ACCENT = 0xFF24694Cu

private fun contrast(a: Color, b: Color): Float {
    val (hi, lo) = listOf(a.luminance(), b.luminance()).sortedDescending()
    return (hi + 0.05f) / (lo + 0.05f)
}

private val onAccentChoices = listOf(Color.White, Color(0xFF181714))

/**
 * A chosen theme color works as text on the card, so it is pulled towards the ink until it reaches WCAG AA;
 * the default keeps the exact pair the design picked.
 */
fun Po0Colors.withAccent(argb: UInt?, pureBlack: Boolean): Po0Colors {
    val base = if (pureBlack && dark) copy(bg = Color.Black) else this
    if (argb == null || argb == DEFAULT_ACCENT) return base
    val chosen = Color(argb.toInt())
    val steps = generateSequence(0f) { it + 0.05f }.takeWhile { it <= 1f }
    val accent = steps.map { lerp(chosen, ink, it) }.first { contrast(it, card) >= 4.5f }
    return base.copy(accent = accent, onAccent = onAccentChoices.maxBy { contrast(it, accent) })
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
    warn = lerp(a.warn, b.warn, t),
    bad = lerp(a.bad, b.bad, t),
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
        background = colors.bg,
        onBackground = colors.ink,
        surface = colors.card,
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
