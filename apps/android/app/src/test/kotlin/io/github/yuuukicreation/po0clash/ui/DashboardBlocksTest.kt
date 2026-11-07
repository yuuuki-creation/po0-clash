package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.DashboardCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardBlocksTest {
    @Test
    fun untouchedCoreDefaultShowsTheDesignOrderAndPacksWithNoSingleColumnTail() {
        val cards = shownCards(DashboardCard.entries)
        val wide = wideSpanCards(cards)

        assertEquals(DashboardCard.CURRENT_NODE, cards.first())
        assertTrue(DashboardCard.CURRENT_NODE in wide)
        assertTrue(DashboardCard.SPEED in wide)
        assertTrue(DashboardCard.SUBSCRIPTION in wide)
        assertTrue(DashboardCard.WHITELIST in wide)
    }

    @Test
    fun customizedOrderIsKeptAndOddNarrowRunPromotesItsTrailingCard() {
        val cards = listOf(DashboardCard.SPEED, DashboardCard.MEMORY, DashboardCard.MODE, DashboardCard.TRAFFIC)
        val shown = shownCards(cards)
        val wide = wideSpanCards(shown)

        assertEquals(cards, shown)
        assertEquals(setOf(DashboardCard.SPEED, DashboardCard.MEMORY, DashboardCard.MODE, DashboardCard.TRAFFIC), wide)
    }
}

