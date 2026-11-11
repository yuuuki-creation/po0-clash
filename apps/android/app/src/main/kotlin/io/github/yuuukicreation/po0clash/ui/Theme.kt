package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Density
import androidx.core.view.WindowCompat
import io.github.yuuukicreation.po0clash.core.AppSettings
import io.github.yuuukicreation.po0clash.core.SchemeVariant
import io.github.yuuukicreation.po0clash.core.ThemeMode
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.pow
import kotlin.math.sin

/** The scheme's roles under the names the screens use, plus the status colors Material has no role for. */
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
    val sel: Color,
    val onSel: Color,
    val sheet: Color,
)

private fun ColorScheme.toPo0Colors(dark: Boolean) = Po0Colors(
    bg = surface,
    card = surfaceContainerLow,
    line = surfaceContainerHighest,
    ink = onSurface,
    ink2 = onSurfaceVariant,
    ink3 = outline,
    accent = primary,
    onAccent = onPrimary,
    track = surfaceContainerHighest,
    scrim = Color.Black.copy(alpha = if (dark) 0.6f else 0.4f),
    good = if (dark) Color(0xFF6DD58C) else Color(0xFF146C2E),
    warn = if (dark) Color(0xFFFFB951) else Color(0xFF835500),
    bad = error,
    sel = secondaryContainer,
    onSel = onSecondaryContainer,
    sheet = surfaceContainer,
)

val LocalPo0Colors = staticCompositionLocalOf { schemeFor(false, DEFAULT_SEED, SchemeVariant.FIDELITY, false).toPo0Colors(false) }

val palette: Po0Colors
    @Composable get() = LocalPo0Colors.current

/** Fixed-width digits, so rates and delays do not jitter as they change. */
fun TextStyle.tabular() = copy(fontFeatureSettings = "tnum")

private const val DEFAULT_SEED = 0xFF0064E0u

private fun linear(channel: Float): Double {
    val c = channel.toDouble()
    return if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
}

private fun encoded(channel: Double): Float {
    val c = channel.coerceIn(0.0, 1.0)
    return (if (c <= 0.0031308) c * 12.92 else 1.055 * c.pow(1 / 2.4) - 0.055).toFloat()
}

private class LinearRgb(val r: Double, val g: Double, val b: Double) {
    val inGamut get() = minOf(r, g, b) >= -1e-4 && maxOf(r, g, b) <= 1 + 1e-4
    val luminance get() = 0.2126 * r + 0.7152 * g + 0.0722 * b
    fun toColor() = Color(encoded(r), encoded(g), encoded(b))
}

private fun oklch(lightness: Double, chroma: Double, hue: Double): LinearRgb {
    val a = chroma * cos(hue)
    val b = chroma * sin(hue)
    val l = (lightness + 0.3963377774 * a + 0.2158037573 * b).pow(3)
    val m = (lightness - 0.1055613458 * a - 0.0638541728 * b).pow(3)
    val s = (lightness - 0.0894841775 * a - 1.2914855480 * b).pow(3)
    return LinearRgb(
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )
}

/** The OKLCH hue (radians) and chroma of [color]. */
private fun hueAndChroma(color: Color): Pair<Double, Double> {
    val r = linear(color.red)
    val g = linear(color.green)
    val b = linear(color.blue)
    val l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    val m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    val s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    val a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    val bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return atan2(bb, a) to hypot(a, bb)
}

/**
 * One hue at a fixed chroma, read by Material tone (CIE L*). OKLCH keeps a hue steady across tones where
 * CIELAB turns blue to purple; chroma gives way wherever sRGB cannot show it.
 */
private class TonalPalette(private val hue: Double, private val chroma: Double) {
    private fun atLightness(lightness: Double): LinearRgb {
        var low = 0.0
        var high = chroma
        if (oklch(lightness, high, hue).inGamut) return oklch(lightness, high, hue)
        repeat(14) {
            val mid = (low + high) / 2
            if (oklch(lightness, mid, hue).inGamut) low = mid else high = mid
        }
        return oklch(lightness, low, hue)
    }

    fun tone(tone: Int): Color {
        val target = if (tone > 8) ((tone + 16) / 116.0).pow(3) else tone / 903.3
        var low = 0.0
        var high = 1.0
        repeat(24) {
            val mid = (low + high) / 2
            if (atLightness(mid).luminance < target) low = mid else high = mid
        }
        return atLightness((low + high) / 2).toColor()
    }
}

/** Material's baseline error tones; they do not follow the seed. */
private val errorLight = listOf(Color(0xFFBA1A1A), Color.White, Color(0xFFFFDAD6), Color(0xFF410002))
private val errorDark = listOf(Color(0xFFFFB4AB), Color(0xFF690005), Color(0xFF93000A), Color(0xFFFFDAD6))

/** A Material 3 scheme grown from [seed]; separate from the composable so it can run off a device. */
fun schemeFor(dark: Boolean, seed: UInt, variant: SchemeVariant, pureBlack: Boolean): ColorScheme {
    val (hue, seedChroma) = hueAndChroma(Color(seed.toInt()))
    val third = Math.PI / 3
    val chroma = when (variant) {
        SchemeVariant.MONOCHROME -> listOf(0.0, 0.0, 0.0, 0.0, 0.0)
        SchemeVariant.NEUTRAL -> listOf(0.034, 0.022, 0.045, 0.006, 0.006)
        SchemeVariant.TONAL_SPOT -> listOf(0.10, 0.045, 0.068, 0.017, 0.022)
        else -> listOf(
            maxOf(seedChroma, 0.10),
            (seedChroma * 0.5).coerceIn(0.045, 0.08),
            maxOf(seedChroma - 0.09, 0.068),
            minOf(seedChroma / 8, 0.012),
            minOf(seedChroma / 8 + 0.011, 0.022),
        )
    }
    val p = TonalPalette(hue, chroma[0])
    val s = TonalPalette(hue, chroma[1])
    val t = TonalPalette(hue + third, chroma[2])
    val n = TonalPalette(hue, chroma[3])
    val nv = TonalPalette(hue, chroma[4])
    if (!dark) {
        return lightColorScheme(
            primary = p.tone(40),
            onPrimary = p.tone(100),
            primaryContainer = p.tone(90),
            onPrimaryContainer = p.tone(10),
            inversePrimary = p.tone(80),
            secondary = s.tone(40),
            onSecondary = s.tone(100),
            secondaryContainer = s.tone(90),
            onSecondaryContainer = s.tone(10),
            tertiary = t.tone(40),
            onTertiary = t.tone(100),
            tertiaryContainer = t.tone(90),
            onTertiaryContainer = t.tone(10),
            background = n.tone(98),
            onBackground = n.tone(10),
            surface = n.tone(98),
            onSurface = n.tone(10),
            surfaceVariant = nv.tone(90),
            onSurfaceVariant = nv.tone(30),
            surfaceTint = p.tone(40),
            inverseSurface = n.tone(20),
            inverseOnSurface = n.tone(95),
            error = errorLight[0],
            onError = errorLight[1],
            errorContainer = errorLight[2],
            onErrorContainer = errorLight[3],
            outline = nv.tone(50),
            outlineVariant = nv.tone(80),
            surfaceBright = n.tone(98),
            surfaceDim = n.tone(87),
            surfaceContainerLowest = n.tone(100),
            surfaceContainerLow = n.tone(96),
            surfaceContainer = n.tone(94),
            surfaceContainerHigh = n.tone(92),
            surfaceContainerHighest = n.tone(90),
        )
    }
    val surfaces = if (pureBlack) listOf(0, 0, 5, 8, 12, 17) else listOf(6, 4, 10, 12, 17, 22)
    return darkColorScheme(
        primary = p.tone(80),
        onPrimary = p.tone(20),
        primaryContainer = p.tone(30),
        onPrimaryContainer = p.tone(90),
        inversePrimary = p.tone(40),
        secondary = s.tone(80),
        onSecondary = s.tone(20),
        secondaryContainer = s.tone(30),
        onSecondaryContainer = s.tone(90),
        tertiary = t.tone(80),
        onTertiary = t.tone(20),
        tertiaryContainer = t.tone(30),
        onTertiaryContainer = t.tone(90),
        background = n.tone(surfaces[0]),
        onBackground = n.tone(90),
        surface = n.tone(surfaces[0]),
        onSurface = n.tone(90),
        surfaceVariant = nv.tone(30),
        onSurfaceVariant = nv.tone(80),
        surfaceTint = p.tone(80),
        inverseSurface = n.tone(90),
        inverseOnSurface = n.tone(20),
        error = errorDark[0],
        onError = errorDark[1],
        errorContainer = errorDark[2],
        onErrorContainer = errorDark[3],
        outline = nv.tone(60),
        outlineVariant = nv.tone(30),
        surfaceBright = n.tone(24),
        surfaceDim = n.tone(surfaces[0]),
        surfaceContainerLowest = n.tone(surfaces[1]),
        surfaceContainerLow = n.tone(surfaces[2]),
        surfaceContainer = n.tone(surfaces[3]),
        surfaceContainerHigh = n.tone(surfaces[4]),
        surfaceContainerHighest = n.tone(surfaces[5]),
    )
}

@Composable
fun Po0Theme(settings: AppSettings? = null, content: @Composable () -> Unit) {
    val dark = when (settings?.themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        else -> isSystemInDarkTheme()
    }
    val seed = settings?.themeColor ?: DEFAULT_SEED
    val variant = settings?.schemeVariant ?: SchemeVariant.FIDELITY
    val pureBlack = settings?.pureBlack == true
    val scheme = remember(dark, seed, variant, pureBlack) { schemeFor(dark, seed, variant, pureBlack) }
    val colors = remember(scheme) { scheme.toPo0Colors(dark) }
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
        MaterialTheme(colorScheme = scheme) {
            CompositionLocalProvider(LocalContentColor provides colors.ink, content = content)
        }
    }
}
