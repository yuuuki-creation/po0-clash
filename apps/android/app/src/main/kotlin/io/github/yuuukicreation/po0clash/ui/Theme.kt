package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import io.github.yuuukicreation.po0clash.core.AppSettings
import io.github.yuuukicreation.po0clash.core.SchemeVariant
import io.github.yuuukicreation.po0clash.core.ThemeMode

/** The scheme's roles under the names the screens use, plus the status colors Material has no role for. */
@Immutable
data class Po0Colors(
    val bg: Color,
    val card: Color,
    val block: Color,
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
    bg = if (dark) surface else surfaceContainer,
    card = if (dark) surfaceContainer else surfaceBright,
    block = if (dark) surfaceContainerHigh else surfaceContainer,
    line = outlineVariant.copy(alpha = 0.5f),
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
    sel = primaryContainer,
    onSel = onPrimaryContainer,
    sheet = if (dark) surfaceContainerHigh else surfaceBright,
)

val LocalPo0Colors = staticCompositionLocalOf { schemeFor(false, DEFAULT_SEED, SchemeVariant.FIDELITY, false).toPo0Colors(false) }

val palette: Po0Colors
    @Composable get() = LocalPo0Colors.current

/** Fixed-width digits, so rates and delays do not jitter as they change. */
fun TextStyle.tabular() = copy(fontFeatureSettings = "tnum")

private const val DEFAULT_SEED = 0xFF0064E0u

private val appTypography = Typography(
    displayLarge = TextStyle(fontSize = 40.sp, lineHeight = 44.sp, fontWeight = FontWeight.Bold),
    headlineLarge = TextStyle(fontSize = 34.sp, lineHeight = 41.sp, fontWeight = FontWeight.Bold),
    headlineMedium = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold),
    headlineSmall = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold),
    titleLarge = TextStyle(fontSize = 24.sp, lineHeight = 30.sp, fontWeight = FontWeight.Bold),
    titleMedium = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontSize = 17.sp, lineHeight = 22.sp),
    bodyMedium = TextStyle(fontSize = 15.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold),
    labelMedium = TextStyle(fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.SemiBold),
    labelSmall = TextStyle(fontSize = 11.sp, lineHeight = 13.sp),
)

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
        MaterialTheme(colorScheme = scheme, typography = appTypography) {
            CompositionLocalProvider(LocalContentColor provides colors.ink, content = content)
        }
    }
}
