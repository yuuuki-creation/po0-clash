package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.DashboardCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class DashboardBlocksTest {
    @Test
    fun defaultCardsFollowTheInstalledFlClashMobileLayout() {
        assertEquals(
            listOf(DashboardCard.SPEED, DashboardCard.MODE, DashboardCard.SUBSCRIPTION, DashboardCard.CURRENT_NODE, DashboardCard.WHITELIST),
            shownCards(DashboardCard.entries),
        )
    }

    @Test
    fun customizedCardsKeepTheirOrderAndNoDuplicateIsRendered() {
        assertEquals(listOf(DashboardCard.MEMORY, DashboardCard.MODE), shownCards(listOf(DashboardCard.MEMORY, DashboardCard.MODE, DashboardCard.MEMORY)))
    }

    @Test
    fun allOptionalCardsMayBeHidden() {
        assertEquals(emptyList<DashboardCard>(), shownCards(emptyList()))
    }
}
