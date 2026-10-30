package io.github.yuuukicreation.po0clash.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Description
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.BuildConfig
import io.github.yuuukicreation.po0clash.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun SettingsScreen(vm: AppViewModel) {
    val busy by vm.busy.collectAsStateWithLifecycle()
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        uri?.let(vm::exportDiagnostics)
    }

    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.settings), list) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.settings)) }
            item {
                SectionHeader(stringResource(R.string.diagnostics))
                ActionRow(
                    0,
                    1,
                    stringResource(R.string.export_diagnostics),
                    Icons.Outlined.Description,
                    busy = AppViewModel.BUSY_DIAGNOSTICS in busy,
                ) {
                    val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
                    export.launch("po0-clash-diagnostics-$stamp.txt")
                }
                SectionFooter(stringResource(R.string.export_diagnostics_hint))
                SectionHeader(stringResource(R.string.about))
                ValueRow(0, 1, stringResource(R.string.version), "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            }
        }
    }
}
