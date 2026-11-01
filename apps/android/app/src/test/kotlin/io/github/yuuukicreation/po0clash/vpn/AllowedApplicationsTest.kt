package io.github.yuuukicreation.po0clash.vpn

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AllowedApplicationsTest {
    @Test
    fun emptyOrUnavailableSelectionCannotStart() {
        assertFalse(addAvailableApplications(emptyList()) { true })
        assertFalse(addAvailableApplications(listOf("removed", "invalid")) { false })
    }

    @Test
    fun availableSelectionCanStartEvenWhenAnotherPackageIsMissing() {
        val added = mutableListOf<String>()
        assertTrue(addAvailableApplications(listOf("removed", "installed")) {
            if (it == "installed") added.add(it) else false
        })
        assertTrue("installed" in added)
    }
}
