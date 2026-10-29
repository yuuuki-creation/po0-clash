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

@Immutable
data class AppleColors(
    val background: Color,
    val card: Color,
    val separator: Color,
    val label: Color,
    val secondaryLabel: Color,
    val accent: Color,
    val green: Color,
    val orange: Color,
    val red: Color,
    val fill: Color,
    val glass: Color,
    val glassFallback: Color,
    val glassBorder: Color,
    val selection: Color,
    val track: Color,
    val dark: Boolean,
)

private val Light = AppleColors(
    background = Color(0xFFF2F2F7),
    card = Color.White,
    separator = Color(0xFFC6C6C8),
    label = Color.Black,
    secondaryLabel = Color(0xFF8A8A8E),
    accent = Color(0xFF007AFF),
    green = Color(0xFF34C759),
    orange = Color(0xFFFF9500),
    red = Color(0xFFFF3B30),
    fill = Color(0xFFE9E9EA),
    glass = Color.White.copy(alpha = 0.66f),
    glassFallback = Color.White.copy(alpha = 0.93f),
    glassBorder = Color.White.copy(alpha = 0.8f),
    selection = Color.White,
    track = Color(0x1F767680),
    dark = false,
)

private val Dark = AppleColors(
    background = Color.Black,
    card = Color(0xFF1C1C1E),
    separator = Color(0xFF38383A),
    label = Color.White,
    secondaryLabel = Color(0xFF98989F),
    accent = Color(0xFF0A84FF),
    green = Color(0xFF30D158),
    orange = Color(0xFFFF9F0A),
    red = Color(0xFFFF453A),
    fill = Color(0xFF39393D),
    glass = Color(0xFF282828).copy(alpha = 0.6f),
    glassFallback = Color(0xFF282828).copy(alpha = 0.94f),
    glassBorder = Color.White.copy(alpha = 0.14f),
    selection = Color(0xFF636366),
    track = Color.Transparent,
    dark = true,
)

val LocalAppleColors = staticCompositionLocalOf { Light }

val apple: AppleColors
    @Composable get() = LocalAppleColors.current

private val typography = Typography(
    titleMedium = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, lineHeight = 22.sp),
    bodyLarge = TextStyle(fontSize = 17.sp, lineHeight = 22.sp),
    bodyMedium = TextStyle(fontSize = 15.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium, lineHeight = 20.sp),
    labelMedium = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
)

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
