package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.R

/** A list row that opens something: accent icon, label, gray value, chevron. */
@Composable
fun NavRow(
    index: Int,
    count: Int,
    icon: ImageVector?,
    label: String,
    value: String? = null,
    busy: Boolean = false,
    chevron: Boolean = true,
    onClick: () -> Unit,
) {
    val colors = apple
    GroupRow(index, count, onClick = if (busy) null else onClick, inset = if (icon != null) 50.dp else 16.dp) {
        if (icon != null) Icon(icon, contentDescription = null, tint = colors.accent, modifier = Modifier.size(22.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge, maxLines = 1, modifier = if (value == null) Modifier.weight(1f) else Modifier)
        if (value != null) {
            Text(
                value,
                style = MaterialTheme.typography.bodyLarge,
                color = colors.secondaryLabel,
                textAlign = TextAlign.End,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
        }
        if (busy) {
            SmallProgress()
        } else if (chevron) {
            Icon(LineIcons.ChevronRight, contentDescription = null, tint = colors.chevron, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
fun SwitchRow(
    index: Int,
    count: Int,
    label: String,
    checked: Boolean,
    detail: String? = null,
    enabled: Boolean = true,
    onChange: (Boolean) -> Unit,
) {
    GroupRow(index, count) {
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            if (detail != null) Text(detail, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel)
        }
        AppleSwitch(checked, onChange, enabled = enabled)
    }
}

/** A value row that edits its text in a sheet; [placeholder] shows when the value is empty. */
@Composable
fun EditRow(
    index: Int,
    count: Int,
    label: String,
    value: String,
    placeholder: String = stringResource(R.string.not_set),
    keyboard: KeyboardType = KeyboardType.Text,
    validate: (String) -> Boolean = { true },
    initial: String = value,
    onSave: (String) -> Unit,
) {
    val sheets = LocalSheets.current
    NavRow(index, count, null, label, value.ifEmpty { placeholder }) {
        sheets.show { ValueSheet(label, initial, multiline = false, keyboard = keyboard, validate = validate, onSave = onSave) }
    }
}

/** A row for a list of strings, edited one per line; shows how many there are. */
@Composable
fun ListRow(
    index: Int,
    count: Int,
    label: String,
    values: List<String>,
    hint: String? = null,
    code: Boolean = false,
    onSave: (List<String>) -> Unit,
) {
    val sheets = LocalSheets.current
    val summary = if (values.isEmpty()) stringResource(R.string.not_set) else values.singleOrNull() ?: stringResource(R.string.item_count, values.size)
    NavRow(index, count, null, label, summary) {
        sheets.show {
            ValueSheet(label, values.joinToString("\n"), multiline = true, hint = hint, code = code) { text ->
                onSave(text.lines().map(String::trim).filter(String::isNotEmpty))
            }
        }
    }
}

/** A row for a string map, edited one `key = value` pair per line. */
@Composable
fun MapRow(index: Int, count: Int, label: String, values: Map<String, String>, onSave: (Map<String, String>) -> Unit) {
    val text = values.entries.joinToString("\n") { "${it.key} = ${it.value}" }
    ListRow(index, count, label, text.lines().filter(String::isNotEmpty), hint = stringResource(R.string.map_hint)) { lines ->
        onSave(
            lines.mapNotNull { line ->
                val split = line.indexOf('=').takeIf { it > 0 } ?: line.indexOf(':').takeIf { it > 0 } ?: return@mapNotNull null
                line.substring(0, split).trim() to line.substring(split + 1).trim()
            }.toMap(),
        )
    }
}

/** A row whose value is one of [options], picked from a menu that grows out of the row. */
@Composable
fun <T> ChoiceRow(index: Int, count: Int, label: String, options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit) {
    val sheets = LocalSheets.current
    val anchor = rememberAnchor()
    Column(Modifier.anchor(anchor)) {
        NavRow(index, count, null, label, options.firstOrNull { it.first == selected }?.second) {
            sheets.menu(anchor, label, options.map { (value, text) -> SheetAction(text, checked = value == selected) { onSelect(value) } })
        }
    }
}

@Composable
fun ValueSheet(
    title: String,
    initial: String,
    multiline: Boolean,
    keyboard: KeyboardType = KeyboardType.Text,
    validate: (String) -> Boolean = { true },
    hint: String? = null,
    code: Boolean = false,
    onSave: (String) -> Unit,
) {
    val sheets = LocalSheets.current
    var text by rememberSaveable { mutableStateOf(initial) }
    SheetTitle(title)
    SheetField(text, { text = it }, hint ?: title, multiline, keyboard, code)
    if (hint != null) Text(hint, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel)
    SheetButtons(stringResource(R.string.save), enabled = validate(text.trim()), onCancel = sheets::dismiss) {
        sheets.dismiss()
        onSave(text.trim())
    }
}

fun isPort(text: String) = text.toIntOrNull()?.let { it in 0..65535 } == true
