package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.RestoreScope
import io.github.yuuukicreation.po0clash.core.RestoreStrategy
import io.github.yuuukicreation.po0clash.core.WebDav
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Backup to a file or WebDAV and restore from either; what a restore covers is asked each time, as in FlClash. */
@Composable
fun BackupScreen(vm: AppViewModel, onBack: () -> Unit) {
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val working = AppViewModel.BUSY_BACKUP in busy
    val dav = settings.webdav ?: WebDav("", "", "", "")
    val ready = dav.url.isNotBlank()
    fun setDav(change: (WebDav) -> WebDav) = vm.setAppSettings { it.copy(webdav = change(it.webdav ?: WebDav("", "", "", ""))) }
    fun askScope(restore: (RestoreScope) -> Unit) = sheets.show { RestoreSheet(restore) }
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri -> uri?.let(vm::backupToFile) }
    val open = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { askScope { scope -> vm.restoreFromFile(it, scope) } }
    }
    val strategies = listOf(
        RestoreStrategy.COMPATIBLE to stringResource(R.string.restore_compatible),
        RestoreStrategy.OVERRIDE to stringResource(R.string.restore_override),
    )
    val set = stringResource(R.string.set)
    val missing = stringResource(R.string.webdav_missing)
    ToolPage(stringResource(R.string.backup), onBack) {
        item {
            SectionHeader(stringResource(R.string.local_file))
            NavRow(0, 2, LineIcons.Download, stringResource(R.string.backup_to_file), busy = working, chevron = false) {
                save.launch("po0-clash-backup-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}.zip")
            }
            NavRow(1, 2, LineIcons.FileImport, stringResource(R.string.restore_from_file), busy = working, chevron = false) {
                open.launch(arrayOf("application/zip", "application/octet-stream"))
            }
        }
        item {
            SectionHeader("WebDAV")
            EditRow(0, 4, stringResource(R.string.webdav_url), dav.url, keyboard = KeyboardType.Uri) { v -> setDav { it.copy(url = v) } }
            EditRow(1, 4, stringResource(R.string.webdav_user), dav.user) { v -> setDav { it.copy(user = v) } }
            EditRow(2, 4, stringResource(R.string.webdav_password), if (dav.password.isEmpty()) "" else set, keyboard = KeyboardType.Password, initial = dav.password) { v ->
                setDav { it.copy(password = v) }
            }
            EditRow(3, 4, stringResource(R.string.webdav_file), dav.fileName, "backup.zip") { v -> setDav { it.copy(fileName = v) } }
        }
        item {
            NavRow(0, 3, LineIcons.Refresh, stringResource(R.string.webdav_check), busy = AppViewModel.BUSY_WEBDAV in busy, chevron = false) {
                if (ready) vm.checkWebdav() else vm.toast(missing)
            }
            NavRow(1, 3, LineIcons.CloudUpload, stringResource(R.string.backup_to_webdav), busy = working, chevron = false) {
                if (ready) vm.backupToWebdav() else vm.toast(missing)
            }
            NavRow(2, 3, LineIcons.Download, stringResource(R.string.restore_from_webdav), busy = working, chevron = false) {
                if (ready) askScope(vm::restoreFromWebdav) else vm.toast(missing)
            }
            SectionFooter(stringResource(R.string.webdav_detail))
        }
        item {
            SectionHeader(stringResource(R.string.restore_strategy))
            ChoiceRow(0, 1, stringResource(R.string.restore_strategy), strategies, settings.restoreStrategy) { v ->
                vm.setAppSettings { it.copy(restoreStrategy = v) }
            }
            SectionFooter(stringResource(R.string.restore_strategy_detail))
        }
    }
}

@Composable
private fun RestoreSheet(onRestore: (RestoreScope) -> Unit) {
    val sheets = LocalSheets.current
    SheetTitle(stringResource(R.string.restore_what))
    SheetButtons(stringResource(R.string.restore_all), onCancel = sheets::dismiss) {
        sheets.dismiss()
        onRestore(RestoreScope.ALL)
    }
    TextButton(onClick = {
        sheets.dismiss()
        onRestore(RestoreScope.PROFILES)
    }, modifier = Modifier.fillMaxWidth()) {
        Text(stringResource(R.string.restore_profiles), style = MaterialTheme.typography.bodyLarge, color = apple.accent)
    }
}
