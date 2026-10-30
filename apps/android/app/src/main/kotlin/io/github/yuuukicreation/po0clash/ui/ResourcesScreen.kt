package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.EngineState
import io.github.yuuukicreation.po0clash.core.GeodataLoader
import io.github.yuuukicreation.po0clash.core.Provider
import io.github.yuuukicreation.po0clash.core.ProviderKind
import kotlinx.coroutines.flow.flowOf

/** Geo databases, their download settings, and the profile's proxy and rule providers. */
@Composable
fun ResourcesScreen(vm: AppViewModel, onBack: () -> Unit) {
    val engine = vm.engine
    val o by vm.options.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val running = status.engine == EngineState.Running
    val geo by remember { engine.poll { geoFiles() } }.collectAsStateWithLifecycle(emptyList())
    val providers by remember(running) {
        if (running) engine.poll { runCatching { providers() }.getOrDefault(emptyList()) } else flowOf(emptyList())
    }.collectAsStateWithLifecycle(emptyList())
    val loaders = listOf(GeodataLoader.STANDARD to stringResource(R.string.loader_standard), GeodataLoader.MEMCONSERVATIVE to stringResource(R.string.loader_memconservative))
    val update = PageAction(LineIcons.Refresh, stringResource(R.string.update_geo), busy = AppViewModel.BUSY_GEO in busy, onClick = vm::updateGeo)
    ToolPage(stringResource(R.string.resources), onBack, actions = listOf(update)) {
        item {
            SectionHeader(stringResource(R.string.geo_files))
            geo.forEachIndexed { index, file ->
                GroupRow(index, geo.size) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(file.name, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            file.modified?.let { stringResource(R.string.updated, relativeTime(it)) } ?: stringResource(R.string.not_downloaded),
                            style = MaterialTheme.typography.bodySmall,
                            color = apple.secondaryLabel,
                        )
                    }
                    file.size?.let { Text(bytes(it), style = MaterialTheme.typography.bodyMedium.tabular(), color = apple.secondaryLabel) }
                }
            }
            SectionFooter(stringResource(R.string.geo_files_detail))
        }
        item {
            SectionHeader(stringResource(R.string.geo_settings))
            ChoiceRow(0, 3, stringResource(R.string.geodata_loader), loaders, o.geodataLoader) { v -> vm.setOptions { it.copy(geodataLoader = v) } }
            SwitchRow(1, 3, stringResource(R.string.auto_update), o.geoAutoUpdate) { v -> vm.setOptions { it.copy(geoAutoUpdate = v) } }
            EditRow(
                2,
                3,
                stringResource(R.string.update_interval),
                o.geoUpdateInterval.toString(),
                keyboard = KeyboardType.Number,
                validate = { (it.toUIntOrNull() ?: 0u) > 0u },
            ) { v -> vm.setOptions { it.copy(geoUpdateInterval = v.toUInt()) } }
        }
        item {
            val urls = o.geoxUrl
            SectionHeader(stringResource(R.string.geo_urls))
            EditRow(0, 4, "GeoIP", urls.geoip, keyboard = KeyboardType.Uri) { v -> vm.setOptions { it.copy(geoxUrl = it.geoxUrl.copy(geoip = v)) } }
            EditRow(1, 4, "GeoSite", urls.geosite, keyboard = KeyboardType.Uri) { v -> vm.setOptions { it.copy(geoxUrl = it.geoxUrl.copy(geosite = v)) } }
            EditRow(2, 4, "MMDB", urls.mmdb, keyboard = KeyboardType.Uri) { v -> vm.setOptions { it.copy(geoxUrl = it.geoxUrl.copy(mmdb = v)) } }
            EditRow(3, 4, "ASN", urls.asn, keyboard = KeyboardType.Uri) { v -> vm.setOptions { it.copy(geoxUrl = it.geoxUrl.copy(asn = v)) } }
        }
        listOf(ProviderKind.PROXY to R.string.proxy_providers, ProviderKind.RULE to R.string.rule_providers).forEach { (kind, title) ->
            val items = providers.filter { it.kind == kind }
            item(key = "providers:$kind") {
                SectionHeader(stringResource(title))
                if (items.isEmpty()) {
                    ValueRow(0, 1, stringResource(if (running) R.string.none else R.string.connect_first_short), "")
                }
                items.forEachIndexed { index, provider ->
                    ProviderRow(index, items.size, provider, busy = AppViewModel.busyProvider(provider.name) in busy) {
                        vm.updateProvider(provider.kind, provider.name)
                    }
                }
            }
        }
    }
}

@Composable
private fun ProviderRow(index: Int, count: Int, provider: Provider, busy: Boolean, onUpdate: () -> Unit) {
    val colors = apple
    GroupRow(index, count) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(provider.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            val detail = listOfNotNull(
                provider.vehicle,
                provider.behavior,
                stringResource(R.string.item_count, provider.count.toInt()),
                provider.updatedAt?.let { relativeTime(it) },
            )
            Text(detail.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
            provider.usage?.takeIf { it.total > 0u }?.let { usage ->
                Text(
                    stringResource(R.string.usage, bytes(usage.upload + usage.download), bytes(usage.total)),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.secondaryLabel,
                )
            }
        }
        if (provider.vehicle.equals("HTTP", ignoreCase = true)) {
            FillButton(LineIcons.Refresh, stringResource(R.string.update), busy = busy, onClick = onUpdate)
        }
    }
}
