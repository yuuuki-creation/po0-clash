package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.DashboardCard
import org.junit.Assert.assertEquals
import org.junit.Test

class DashboardBlocksTest {
    private fun place(slots: List<CardSlot>, card: DashboardCard) = slots.first { it.card == card }.let { it.column to it.row }

    @Test
    fun untouchedCoreDefaultPacksTwoColumnsWithoutGaps() {
        val cards = shownCards(DashboardCard.entries)
        val slots = packDashboard(cards, columns = 2)

        assertEquals(DashboardCard.SPEED, cards.first())
        assertEquals(0 to 0, place(slots, DashboardCard.SPEED))
        assertEquals(0 to 2, place(slots, DashboardCard.MODE))
        assertEquals(0 to 5, place(slots, DashboardCard.TRAFFIC))
        assertEquals(1 to 5, place(slots, DashboardCard.WHITELIST))
        assertEquals(1 to 6, place(slots, DashboardCard.CONNECTIONS))
        assertEquals(0 to 7, place(slots, DashboardCard.CURRENT_NODE))
        val cells = slots.sumOf { it.span * it.lines }
        assertEquals(2 * slots.maxOf { it.row + it.lines }, cells)
    }

    @Test
    fun customizedOrderIsKeptAndATallCardLeavesRoomBesideIt() {
        val cards = listOf(DashboardCard.TRAFFIC, DashboardCard.MEMORY, DashboardCard.MODE, DashboardCard.EXIT_IP)
        val slots = packDashboard(shownCards(cards), columns = 2)

        assertEquals(cards, slots.map { it.card })
        assertEquals(0 to 0, place(slots, DashboardCard.TRAFFIC))
        assertEquals(1 to 0, place(slots, DashboardCard.MEMORY))
        assertEquals(0 to 2, place(slots, DashboardCard.MODE))
        assertEquals(1 to 1, place(slots, DashboardCard.EXIT_IP))
    }

    @Test
    fun wideCardsStayWithinTheGridOnFourColumns() {
        val slots = packDashboard(shownCards(DashboardCard.entries), columns = 4)

        assertEquals(0 to 0, place(slots, DashboardCard.SPEED))
        assertEquals(2 to 0, place(slots, DashboardCard.MODE))
        assert(slots.all { it.column + it.span <= 4 })
    }
}
