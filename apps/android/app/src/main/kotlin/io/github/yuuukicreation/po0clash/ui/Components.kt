package io.github.yuuukicreation.po0clash.ui

import android.text.format.DateUtils
import android.text.format.Formatter
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R
import java.text.DateFormat
import java.util.Date

/** Rows are segments: outer corners of the whole group 16, every other corner 4. */
fun segmentShape(index: Int, count: Int, columns: Int = 1): Shape {
    val row = index / columns
    val column = index % columns
    val lastRow = (count - 1) / columns
    fun corner(outer: Boolean) = if (outer) 16.dp else 4.dp
    return RoundedCornerShape(
        topStart = corner(row == 0 && column == 0),
        topEnd = corner(row == 0 && column == columns - 1),
        bottomStart = corner(row == lastRow && column == 0),
        bottomEnd = corner(row == lastRow && column == columns - 1),
    )
}

/** One row of a group; each row is its own lazy item when the list is long, so it carries its own 2 dp gap. */
@Composable
fun GroupRow(
    index: Int,
    count: Int,
    onClick: (() -> Unit)? = null,
    columns: Int = 1,
    minHeight: Dp = 56.dp,
    endPadding: Dp = 16.dp,
    fill: Color = palette.card,
    content: @Composable RowScope.() -> Unit,
) {
    val gapTop = if (index >= columns) 2.dp else 0.dp
    val gapStart = if (index % columns > 0) 2.dp else 0.dp
    Row(
        Modifier.fillMaxWidth().then(if (columns > 1) Modifier.fillMaxHeight() else Modifier)
            .padding(start = gapStart, top = gapTop)
            .clip(segmentShape(index, count, columns))
            .background(fill)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .heightIn(min = minHeight)
            .padding(start = 16.dp, end = endPadding, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

/** Lays [count] rows out in [columns]; columns above one need the same height on each line. */
@Composable
fun SegmentGrid(count: Int, columns: Int, row: @Composable (index: Int) -> Unit) {
    Column {
        (0 until count).chunked(columns).forEach { line ->
            Row(Modifier.height(IntrinsicSize.Min)) {
                line.forEach { index -> Column(Modifier.weight(1f).fillMaxHeight()) { row(index) } }
                repeat(columns - line.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
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
        modifier = Modifier.weight(1f),
    )
}

@Composable
fun Chevron() {
    Icon(LineIcons.ChevronRight, contentDescription = null, tint = palette.ink2, modifier = Modifier.size(16.dp))
}

@Composable
fun ValueRow(index: Int, count: Int, label: String, value: String, columns: Int = 1) {
    GroupRow(index, count, columns = columns) {
        Text(label, style = MaterialTheme.typography.bodyLarge, maxLines = 1)
        RowValue(value)
    }
}

@Composable
fun ActionRow(index: Int, count: Int, label: String, busy: Boolean = false, onClick: () -> Unit) {
    GroupRow(index, count, onClick = if (busy) null else onClick) {
        Text(label, style = MaterialTheme.typography.bodyLarge, color = palette.accent, modifier = Modifier.weight(1f))
        if (busy) SmallProgress()
    }
}

@Composable
fun SectionHeader(text: String, top: Dp = 12.dp) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        color = palette.ink2,
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
        shape = RoundedCornerShape(4.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = colors.accent,
            unfocusedBorderColor = colors.outline,
            cursorColor = colors.accent,
        ),
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
