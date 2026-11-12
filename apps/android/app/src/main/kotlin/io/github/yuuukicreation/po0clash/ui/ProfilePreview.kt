package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.Node
import io.github.yuuukicreation.po0clash.core.ProxyGroup
import org.yaml.snakeyaml.LoaderOptions
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.constructor.SafeConstructor

data class ProfilePreview(val profileId: String, val proxyCount: Int, val ruleCount: Int, val groups: List<ProxyGroup>)

fun parseProfilePreview(id: String, content: String, linkNodes: List<Node> = emptyList()): ProfilePreview? = runCatching {
    val options = LoaderOptions().apply {
        isAllowDuplicateKeys = false
        maxAliasesForCollections = 50
        codePointLimit = 32 * 1024 * 1024
    }
    val root = Yaml(SafeConstructor(options)).load<Any>(content) as? Map<*, *> ?: return@runCatching null
    fun maps(key: String) = (root[key] as? List<*>)?.filterIsInstance<Map<*, *>>().orEmpty()
    fun groupKind(value: Any?) = when (value) {
        "select" -> "Selector"
        "url-test" -> "URLTest"
        "fallback" -> "Fallback"
        "load-balance" -> "LoadBalance"
        "relay" -> "Relay"
        else -> value?.toString().orEmpty()
    }
    val proxies = maps("proxies")
    val groupData = maps("proxy-groups")
    val types = proxies.mapNotNull { entry ->
        val name = entry["name"] as? String ?: return@mapNotNull null
        val kind = when (val type = entry["type"] as? String) {
            "ss" -> "Shadowsocks"
            "ssr" -> "ShadowsocksR"
            else -> type?.replaceFirstChar { it.uppercase() }.orEmpty()
        }
        name to kind
    }.toMap() + groupData.mapNotNull { entry -> (entry["name"] as? String)?.let { it to groupKind(entry["type"]) } } + mapOf("DIRECT" to "Direct", "REJECT" to "Reject")
    val groups = groupData.mapNotNull { entry ->
        val name = entry["name"] as? String ?: return@mapNotNull null
        val supplied = if ((entry["use"] as? List<*>)?.contains("links") == true) linkNodes else emptyList()
        val nodes = ((entry["proxies"] as? List<*>)?.filterIsInstance<String>().orEmpty().map { Node(it, types[it].orEmpty(), null) } + supplied).distinctBy { it.name }
        ProxyGroup(name, groupKind(entry["type"]), false, null, nodes, entry["icon"] as? String)
    }
    if (groups.map { it.name }.distinct().size != groups.size) return@runCatching null
    ProfilePreview(id, proxies.size + linkNodes.distinctBy { it.name }.size, (root["rules"] as? List<*>)?.size ?: 0, groups)
}.getOrNull()
