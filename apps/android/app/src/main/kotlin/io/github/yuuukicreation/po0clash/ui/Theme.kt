package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/** The design spec's color table (docs/development/native-design.md), phone column for dark. */
@Immutable
data class AppleColors(
    val background: Color,
    val card: Color,
    val separator: Color,
    val label: Color,
    val secondaryLabel: Color,
    val accent: Color,
    val accentText: Color,
    val accentFill: Color,
    val accentSoft: Color,
    val green: Color,
    val greenText: Color,
    val orange: Color,
    val red: Color,
    val upload: Color,
    val chevron: Color,
    val fill: Color,
    val glass: Color,
    val glassFallback: Color,
    val glassBorder: Color,
    val selection: Color,
    val track: Color,
    val cell: Color,
    val tabSelection: Color,
    val dark: Boolean,
)

private val Light = AppleColors(
    background = Color(0xFFF2F2F7),
    card = Color.White,
    separator = Color(0x213C3C43),
    label = Color(0xFF1D1D1F),
    secondaryLabel = Color(0xFF6E6E73),
    accent = Color(0xFF007AFF),
    accentText = Color(0xFF0068DA),
    accentFill = Color(0xFF0071E3),
    accentSoft = Color(0x14007AFF),
    green = Color(0xFF34C759),
    greenText = Color(0xFF1E7F35),
    orange = Color(0xFFB25000),
    red = Color(0xFFD70015),
    upload = Color(0xFF8E8E93),
    chevron = Color(0xFFC4C4C7),
    fill = Color(0xFFE9E9EA),
    glass = Color(0x9EFFFFFF),
    glassFallback = Color(0xEDFFFFFF),
    glassBorder = Color(0x0F000000),
    selection = Color.White,
    track = Color(0x1F767680),
    cell = Color(0xFFF2F2F7),
    tabSelection = Color(0x0F000000),
    dark = false,
)

private val Dark = AppleColors(
    background = Color.Black,
    card = Color(0xFF1C1C1E),
    separator = Color(0x99545458),
    label = Color(0xFFF5F5F7),
    secondaryLabel = Color(0xFF98989F),
    accent = Color(0xFF0A84FF),
    accentText = Color(0xFF409CFF),
    accentFill = Color(0xFF0071E3),
    accentSoft = Color(0x2E0A84FF),
    green = Color(0xFF30D158),
    greenText = Color(0xFF30D158),
    orange = Color(0xFFFF9F0A),
    red = Color(0xFFFF6961),
    upload = Color(0xFF8E8E93),
    chevron = Color(0xFF5A5A5F),
    fill = Color(0xFF39393D),
    glass = Color(0x9E252528),
    glassFallback = Color(0xED252528),
    glassBorder = Color(0x1FFFFFFF),
    selection = Color(0xFF636366),
    track = Color(0x3D767680),
    cell = Color(0xFF2C2C2E),
    tabSelection = Color(0x1FFFFFFF),
    dark = true,
)

val LocalAppleColors = staticCompositionLocalOf { Light }

val apple: AppleColors
    @Composable get() = LocalAppleColors.current

private val typography = Typography(
    headlineLarge = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold, lineHeight = 41.sp, letterSpacing = 0.2.sp),
    titleLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold, lineHeight = 25.sp),
    titleMedium = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 21.sp),
    bodyMedium = TextStyle(fontSize = 15.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, lineHeight = 18.sp),
    displaySmall = TextStyle(fontSize = 30.sp, fontWeight = FontWeight.SemiBold, lineHeight = 36.sp, letterSpacing = (-0.5).sp),
    headlineSmall = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.SemiBold, lineHeight = 32.sp, letterSpacing = (-0.4).sp),
    labelMedium = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelSmall = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, lineHeight = 13.sp),
)

/** Fixed-width digits, so rates, timers and delays do not jitter as they change. */
fun TextStyle.tabular() = copy(fontFeatureSettings = "tnum")

@Composable
fun Po0Theme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) Dark else Light
    val scheme = (if (colors.dark) darkColorScheme() else lightColorScheme()).copy(
        primary = colors.accent,
        onPrimary = Color.White,
        background = colors.background,
        onBackground = colors.label,
        surface = colors.card,
        onSurface = colors.label,
        onSurfaceVariant = colors.secondaryLabel,
        surfaceContainerHighest = colors.card,
        outline = colors.separator,
        outlineVariant = colors.separator,
        error = colors.red,
    )
    CompositionLocalProvider(LocalAppleColors provides colors) {
        MaterialTheme(colorScheme = scheme, typography = typography) {
            CompositionLocalProvider(LocalContentColor provides colors.label, content = content)
        }
    }
}
