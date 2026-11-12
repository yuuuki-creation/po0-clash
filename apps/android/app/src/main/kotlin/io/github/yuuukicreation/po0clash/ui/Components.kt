// Layout and styling follow FlClash v0.9.3 (https://github.com/chen08209/FlClash, GPL-3.0), lib/widgets/card.dart.
package io.github.yuuukicreation.po0clash.ui

import android.text.format.DateUtils
import android.text.format.Formatter
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.offset
import androidx.compose.ui.unit.sp
import io.github.yuuukicreation.po0clash.R
import java.text.DateFormat
import java.util.Date

val cardShape = RoundedCornerShape(24.dp)
val LocalDashboardStyle = staticCompositionLocalOf { false }

/** FlClash's card: a low surface inside a hairline, or the selection colors inside a primary one. */
@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    filled: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = palette
    val dashboard = LocalDashboardStyle.current
    val shape = if (dashboard) RoundedCornerShape(34.dp) else cardShape
    val fill by animateColorAsState(
        when {
            selected -> colors.sel
            filled -> MaterialTheme.colorScheme.surfaceContainerHigh
            else -> if (dashboard) MaterialTheme.colorScheme.surfaceContainerLowest else colors.card
        },
        tween(150),
        label = "card",
    )
    val edge by animateColorAsState(
        when {
            filled -> Color.Transparent
            selected -> colors.accent
            else -> colors.line
        },
        tween(150),
        label = "cardEdge",
    )
    Surface(modifier, shape = shape, color = fill, shadowElevation = if (dashboard) 2.dp else 0.dp) {
        Column(
            (if (dashboard) Modifier.fillMaxSize() else Modifier)
                .then(if (!dashboard) Modifier.border(1.dp, edge, shape) else Modifier)
                .then(if (onClick != null) Modifier.clickable(enabled = enabled, onClick = onClick) else Modifier),
            content = content,
        )
    }
}

@Composable
fun CardHeader(title: String, icon: ImageVector, note: String? = null) {
    val colors = palette
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = if (LocalDashboardStyle.current) 18.dp else 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(icon, contentDescription = null, tint = colors.ink2, modifier = Modifier.size(20.dp))
        Text(
            title,
            style = if (LocalDashboardStyle.current) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleSmall,
            color = colors.ink2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (!note.isNullOrEmpty()) {
            Text(
                note,
                style = MaterialTheme.typography.bodySmall.tabular(),
                color = colors.ink2.copy(alpha = 0.8f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 200.dp),
            )
        }
    }
}

@Composable
fun InfoCard(
    title: String,
    icon: ImageVector,
    onClick: (() -> Unit)? = null,
    note: String? = null,
    contentPadding: PaddingValues = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    AppCard(onClick = onClick) {
        CardHeader(title, icon, note)
        Column(
            Modifier.weight(1f).fillMaxWidth().padding(contentPadding),
            verticalArrangement = Arrangement.Bottom,
            content = content,
        )
    }
}

@Composable
fun CardValue(text: String, modifier: Modifier = Modifier, color: Color = palette.ink) {
    Text(
        text,
        style = MaterialTheme.typography.bodyMedium.copy(fontSize = 15.sp, fontWeight = FontWeight.Light).tabular(),
        color = color,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}

@Composable
fun byteParts(value: ULong, perSecond: Boolean = false): Pair<String, String> {
    val text = Formatter.formatFileSize(LocalContext.current, value.toLong())
    val split = text.indexOfLast { it.isWhitespace() || it == '\u00A0' }
    val (number, unit) = if (split < 0) text to "" else text.substring(0, split) to text.substring(split + 1)
    return number to if (perSecond) "$unit/s" else unit
}

/** Lets a row's ripple reach the screen edges from inside the page's side padding. */
private fun Modifier.bleed(side: Dp) = layout { measurable, constraints ->
    val extra = side.roundToPx() * 2
    val placeable = measurable.measure(constraints.offset(horizontal = extra))
    layout(placeable.width - extra, placeable.height) { placeable.place(-extra / 2, 0) }
}

@Composable
fun GroupRow(
    onClick: (() -> Unit)? = null,
    minHeight: Dp = 56.dp,
    endPadding: Dp = 16.dp,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        Modifier.bleed(16.dp).fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .heightIn(min = minHeight)
            .padding(start = 16.dp, end = endPadding, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        content = content,
    )
}

@Composable
fun RowScope.RowText(title: String, subtitle: String? = null, titleColor: Color = palette.ink) {
    Column(Modifier.weight(1f)) {
        Text(title, style = MaterialTheme.typography.bodyLarge, color = titleColor, maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (!subtitle.isNullOrEmpty()) {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = palette.ink2)
        }
    }
}

@Composable
fun RowScope.RowValue(value: String, overflow: TextOverflow = TextOverflow.Ellipsis) {
    Text(
        value,
        style = MaterialTheme.typography.bodyLarge.tabular(),
        color = palette.ink2,
        textAlign = TextAlign.End,
        maxLines = 1,
        overflow = overflow,
        modifier = Modifier.widthIn(max = 220.dp),
    )
}

@Composable
fun ValueRow(label: String, value: String) {
    GroupRow {
        Text(label, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        RowValue(value)
    }
}

@Composable
fun ActionRow(label: String, busy: Boolean = false, onClick: () -> Unit) {
    GroupRow(onClick = if (busy) null else onClick) {
        Text(label, style = MaterialTheme.typography.bodyLarge, color = palette.accent, modifier = Modifier.weight(1f))
        if (busy) SmallProgress()
    }
}

@Composable
fun SectionHeader(text: String, top: Dp = 16.dp) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.SemiBold,
        color = palette.ink2.copy(alpha = 0.8f),
        modifier = Modifier.padding(top = top, bottom = 8.dp),
    )
}

@Composable
fun EmptyState(title: String, icon: ImageVector = LineIcons.Info) {
    Column(
        Modifier.fillMaxWidth().padding(top = 56.dp, bottom = 24.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = palette.ink3, modifier = Modifier.size(40.dp))
        Text(title, style = MaterialTheme.typography.bodyLarge, color = palette.ink2, textAlign = TextAlign.Center)
    }
}

@Composable
fun FullEmptyState(title: String, icon: ImageVector, padding: PaddingValues) {
    Column(Modifier.fillMaxSize().padding(padding)) { EmptyState(title, icon) }
}

@Composable
fun bytes(value: ULong): String = Formatter.formatFileSize(LocalContext.current, value.toLong())

@Composable
fun relativeTime(epochSeconds: Long): String {
    val now = System.currentTimeMillis()
    if (now - epochSeconds * 1000 < DateUtils.MINUTE_IN_MILLIS) return stringResource(R.string.just_now)
    return DateUtils.getRelativeTimeSpanString(epochSeconds * 1000, now, DateUtils.MINUTE_IN_MILLIS).toString()
}

fun date(epochSeconds: Long): String = DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(epochSeconds * 1000))

@Composable
fun SheetField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    multiline: Boolean,
    keyboardType: KeyboardType = if (multiline) KeyboardType.Text else KeyboardType.Uri,
    code: Boolean = false,
) {
    val colors = palette
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = colors.ink2, style = MaterialTheme.typography.bodyLarge) },
        singleLine = !multiline,
        minLines = if (code) 10 else if (multiline) 4 else 1,
        maxLines = if (code) 16 else if (multiline) 8 else 1,
        textStyle = if (code) MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace) else LocalTextStyle.current,
        keyboardOptions = KeyboardOptions(
            keyboardType = keyboardType,
            autoCorrectEnabled = !code,
            capitalization = KeyboardCapitalization.None,
        ),
        visualTransformation = if (keyboardType == KeyboardType.Password) PasswordVisualTransformation() else VisualTransformation.None,
                modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun TextSheet(
    title: String,
    placeholder: String,
    multiline: Boolean,
    confirm: String,
    namePlaceholder: String? = null,
    onConfirm: (text: String, name: String) -> Unit,
) {
    val sheets = LocalSheets.current
    var text by rememberSaveable { mutableStateOf("") }
    var name by rememberSaveable { mutableStateOf("") }
    SheetTitle(title)
    SheetField(text, { text = it }, placeholder, multiline)
    if (namePlaceholder != null) SheetField(name, { name = it }, namePlaceholder, multiline = false, keyboardType = KeyboardType.Text)
    SheetButtons(confirm, enabled = text.isNotBlank(), onCancel = sheets::dismiss) {
        sheets.dismiss()
        onConfirm(text, name)
    }
}
