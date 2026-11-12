package io.github.yuuukicreation.po0clash.ui

import android.icu.text.BreakIterator
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.core.GroupIconStyle
import io.github.yuuukicreation.po0clash.core.ProxyGroup

@Composable
fun GroupAvatar(group: ProxyGroup, style: GroupIconStyle) {
    if (style == GroupIconStyle.HIDDEN) return
    val icon = rememberGroupIcon(group.icon)
    val initial = remember(group.name) {
        val boundary = BreakIterator.getCharacterInstance().apply { setText(group.name) }.next()
        if (boundary == BreakIterator.DONE) "?" else group.name.substring(0, boundary).uppercase()
    }
    Box(Modifier.size(36.dp).clip(RoundedCornerShape(12.dp)).background(palette.block), contentAlignment = Alignment.Center) {
        if (icon != null) Image(icon, group.name, Modifier.size(28.dp))
        else Text(initial, style = MaterialTheme.typography.titleSmall, color = palette.ink2)
    }
}
