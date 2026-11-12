package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.DashboardCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class DashboardBlocksTest {
    @Test
    fun defaultDashboardStartsWithTheConnectionControlAndCombinesTheExitIp() {
        val cards = shownCards(DashboardCard.entries)
        assertEquals(DashboardCard.CURRENT_NODE, cards.first())
        assertEquals(DashboardCard.SPEED, cards[1])
        assertFalse(DashboardCard.EXIT_IP in cards)
        assertEquals(cards.size, cards.distinct().size)
    }

    @Test
    fun customizedDashboardRetainsItsOrderAndHasOneConnectionControl() {
        val chosen = listOf(DashboardCard.MEMORY, DashboardCard.CURRENT_NODE, DashboardCard.MODE)
        assertEquals(listOf(DashboardCard.CURRENT_NODE, DashboardCard.MEMORY, DashboardCard.MODE), shownCards(chosen))
    }

    @Test
    fun hidingAllOptionalCardsKeepsTheAppConnectable() {
        assertEquals(listOf(DashboardCard.CURRENT_NODE), shownCards(emptyList()))
    }
}
