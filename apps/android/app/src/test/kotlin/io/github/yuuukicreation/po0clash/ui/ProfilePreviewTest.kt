package io.github.yuuukicreation.po0clash.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class ProfilePreviewTest {
    @Test
    fun aStoredProfileShowsItsNodesAndCountsBeforeTheVpnStarts() {
        val preview = checkNotNull(parseProfilePreview("profile", """
            proxies:
              - {name: Local, type: socks5, server: 127.0.0.1, port: 1080}
            proxy-groups:
              - {name: Proxy, type: select, proxies: [Local, DIRECT]}
            rules: ['MATCH,Proxy']
        """.trimIndent()))
        assertEquals(1, preview.proxyCount)
        assertEquals(1, preview.ruleCount)
        assertEquals(listOf("Local", "DIRECT"), preview.groups.single().nodes.map { it.name })
        assertEquals("Selector", preview.groups.single().kind)
        assertFalse(preview.groups.single().selectable)
        assertNull(preview.groups.single().now)
    }

    @Test
    fun aProviderGroupDoesNotInventProviderNodesWhileOffline() {
        val preview = checkNotNull(parseProfilePreview("profile", "proxy-groups: [{name: Remote, type: select, use: [airport]}]"))
        assertEquals(emptyList<Any>(), preview.groups.single().nodes)
    }

    @Test
    fun unsupportedDocumentsAndObjectTagsDoNotBecomeAnOfflinePreview() {
        assertNull(parseProfilePreview("profile", "ss://node"))
        assertNull(parseProfilePreview("profile", "!!java.net.URL ['https://example.com']"))
    }
}
