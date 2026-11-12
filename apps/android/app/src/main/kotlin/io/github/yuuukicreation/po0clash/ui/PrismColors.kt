// Color roles follow FlClash 0.9.3's prism_ui/color.dart (GPL-3.0).
@file:android.annotation.SuppressLint("RestrictedApi")

package io.github.yuuukicreation.po0clash.ui

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import com.google.android.material.color.utilities.DynamicScheme
import com.google.android.material.color.utilities.Hct
import com.google.android.material.color.utilities.SchemeContent
import com.google.android.material.color.utilities.SchemeExpressive
import com.google.android.material.color.utilities.SchemeFruitSalad
import com.google.android.material.color.utilities.SchemeMonochrome
import com.google.android.material.color.utilities.SchemeNeutral
import com.google.android.material.color.utilities.SchemeRainbow
import com.google.android.material.color.utilities.SchemeTonalSpot
import com.google.android.material.color.utilities.SchemeVibrant
import com.google.android.material.color.utilities.TonalPalette
import io.github.yuuukicreation.po0clash.core.SchemeVariant

fun schemeFor(dark: Boolean, seed: UInt, variant: SchemeVariant, pureBlack: Boolean): ColorScheme {
    val argb = if (seed == 0xFF0064E0u) 0xFF007AFFu else seed
    val source = Hct.fromInt(argb.toInt())
    val scheme: DynamicScheme = when (variant) {
        SchemeVariant.TONAL_SPOT -> SchemeTonalSpot(source, dark, 0.0)
        SchemeVariant.MONOCHROME -> SchemeMonochrome(source, dark, 0.0)
        SchemeVariant.NEUTRAL -> SchemeNeutral(source, dark, 0.0)
        SchemeVariant.VIBRANT -> SchemeVibrant(source, dark, 0.0)
        SchemeVariant.EXPRESSIVE -> SchemeExpressive(source, dark, 0.0)
        SchemeVariant.RAINBOW -> SchemeRainbow(source, dark, 0.0)
        SchemeVariant.FRUIT_SALAD -> SchemeFruitSalad(source, dark, 0.0)
        else -> SchemeContent(source, dark, 0.0)
    }
    fun TonalPalette.at(level: Int) = Color(tone(level))
    fun neutral(tone: Int, paper: Boolean = false): Color {
        val cap = if (dark || !paper) 3.0 else 1.5
        val chroma = if (variant == SchemeVariant.CONTENT) (source.chroma / 6).coerceAtMost(10.0) else scheme.neutralPalette.chroma.coerceAtMost(cap)
        return Color(Hct.from(scheme.neutralPalette.hue, chroma, tone.toDouble()).toInt())
    }
    val vivid = variant == SchemeVariant.FIDELITY || variant == SchemeVariant.CONTENT
    val accentTone = if (dark) (source.tone + 3).coerceIn(50.0, 75.0) else source.tone.coerceIn(35.0, 60.0)
    val primary = if (vivid) Color(Hct.from(source.hue, source.chroma, accentTone).toInt()) else scheme.primaryPalette.at(if (dark) 80 else 40)
    val onPrimary = if (vivid && accentTone <= 60) Color.White else scheme.primaryPalette.at(if (dark) 20 else 100)
    val container = TonalPalette.fromHueAndChroma(scheme.primaryPalette.hue, scheme.primaryPalette.chroma.coerceAtMost(48.0))
    val error = TonalPalette.fromInt(0xFFBA1A1A.toInt())
    val p = scheme.primaryPalette
    val s = scheme.secondaryPalette
    val t = scheme.tertiaryPalette
    val nv = scheme.neutralVariantPalette
    val base = if (dark) darkColorScheme() else lightColorScheme()
    val black = dark && pureBlack
    return base.copy(
        primary = primary,
        onPrimary = onPrimary,
        primaryContainer = container.at(if (dark) 30 else 90),
        onPrimaryContainer = container.at(if (dark) 90 else 30),
        secondary = s.at(if (dark) 80 else 40),
        onSecondary = s.at(if (dark) 20 else 100),
        secondaryContainer = s.at(if (dark) 30 else 90),
        onSecondaryContainer = s.at(if (dark) 90 else 10),
        tertiary = t.at(if (dark) 80 else 40),
        onTertiary = t.at(if (dark) 20 else 100),
        tertiaryContainer = t.at(if (dark) 30 else 90),
        onTertiaryContainer = t.at(if (dark) 90 else 10),
        background = neutral(if (dark) if (black) 0 else 6 else 94, paper = true),
        onBackground = neutral(if (dark) 97 else 10),
        surface = neutral(if (dark) if (black) 0 else 6 else 98, paper = true),
        onSurface = neutral(if (dark) 97 else 10),
        surfaceVariant = nv.at(if (dark) 30 else 90),
        onSurfaceVariant = nv.at(if (dark) 80 else 30),
        surfaceTint = primary,
        inverseSurface = neutral(if (dark) 90 else 20),
        inverseOnSurface = neutral(if (dark) 20 else 95),
        inversePrimary = p.at(if (dark) 40 else 80),
        error = error.at(if (dark) 80 else 40),
        onError = error.at(if (dark) 20 else 100),
        errorContainer = error.at(if (dark) 30 else 90),
        onErrorContainer = error.at(if (dark) 90 else 10),
        outline = nv.at(if (dark) 60 else 50),
        outlineVariant = Color(Hct.from(nv.hue, nv.chroma.coerceAtMost(4.0), if (dark) 30.0 else 80.0).toInt()),
        surfaceBright = neutral(if (dark) 24 else 98, paper = true),
        surfaceDim = neutral(if (dark) if (black) 0 else 6 else 87),
        surfaceContainerLowest = neutral(if (dark) if (black) 0 else 4 else 100),
        surfaceContainerLow = neutral(if (dark) if (black) 4 else 10 else 96),
        surfaceContainer = neutral(if (dark) if (black) 6 else 15 else 94),
        surfaceContainerHigh = neutral(if (dark) if (black) 12 else 21 else 92),
        surfaceContainerHighest = neutral(if (dark) if (black) 18 else 27 else 90),
    )
}
