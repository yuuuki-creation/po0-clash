package io.github.yuuukicreation.po0clash.ui

import android.text.format.DateUtils
import android.text.format.Formatter
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R
import java.text.DateFormat
import java.util.Date

val cardRadius = 22.dp

/**
 * One row of an inset grouped list; rows are separate lazy items so long lists stay lazy. The separator starts where
 * the row's text does, so pass [inset] when the row leads with an icon.
 */
@Composable
fun GroupRow(
    index: Int,
    count: Int,
    onClick: (() -> Unit)? = null,
    inset: Dp = 16.dp,
    content: @Composable RowScope.() -> Unit,
) {
    val top = if (index == 0) cardRadius else 0.dp
    val bottom = if (index == count - 1) cardRadius else 0.dp
    Column(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(top, top, bottom, bottom))
            .background(apple.card)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        if (index > 0) Hairline(Modifier.padding(start = inset))
        Row(
            Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(start = 16.dp, end = 14.dp, top = 10.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

@Composable
fun RowScope.RowText(title: String, subtitle: String? = null, titleColor: Color = apple.label, subtitleColor: Color = apple.secondaryLabel) {
    Column(Modifier.weight(1f)) {
        Text(title, style = MaterialTheme.typography.bodyLarge, color = titleColor, maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (!subtitle.isNullOrEmpty()) {
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = subtitleColor)
        }
    }
}

@Composable
fun ValueRow(index: Int, count: Int, label: String, value: String) {
    GroupRow(index, count) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = apple.secondaryLabel,
            textAlign = TextAlign.End,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
fun ActionRow(index: Int, count: Int, label: String, icon: ImageVector? = null, busy: Boolean = false, onClick: () -> Unit) {
    GroupRow(index, count, onClick = if (busy) null else onClick, inset = if (icon != null) 50.dp else 16.dp) {
        if (icon != null) Icon(icon, contentDescription = null, tint = apple.accent, modifier = Modifier.size(22.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge, color = apple.accent, modifier = Modifier.weight(1f))
        if (busy) SmallProgress()
    }
}

@Composable
fun SectionHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        fontWeight = FontWeight.SemiBold,
        color = apple.secondaryLabel,
        modifier = modifier.padding(start = 16.dp, top = 20.dp, bottom = 6.dp),
    )
}

@Composable
fun SectionFooter(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = apple.secondaryLabel,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp),
    )
}

@Composable
fun SmallProgress(size: Dp = 18.dp) {
    CircularProgressIndicator(Modifier.size(size), strokeWidth = 2.dp, color = apple.secondaryLabel)
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
) {
    val colors = apple
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = colors.secondaryLabel) },
        singleLine = !multiline,
        minLines = if (multiline) 4 else 1,
        maxLines = if (multiline) 8 else 1,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(12.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = colors.card,
            unfocusedContainerColor = colors.card,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
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
    if (namePlaceholder != null) SheetField(name, { name = it }, namePlaceholder, multiline = false)
    SheetField(text, { text = it }, placeholder, multiline)
    SheetButtons(confirm, enabled = text.isNotBlank(), onCancel = sheets::dismiss) {
        sheets.dismiss()
        onConfirm(text, name)
    }
}
