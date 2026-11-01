package io.github.yuuukicreation.po0clash.ui

import io.github.yuuukicreation.po0clash.core.DashboardCard
import org.junit.Assert.assertEquals
import org.junit.Test

class DashboardBlocksTest {
    @Test
    fun untouchedCoreDefaultShowsTheDesignOrder() {
        val blocks = dashboardBlocks(shownCards(DashboardCard.entries))

        assertEquals(DashboardBlock.Rows(listOf(DashboardCard.CURRENT_NODE), status = true), blocks[0])
        assertEquals(DashboardBlock.ModePicker, blocks[1])
        assertEquals(DashboardBlock.SpeedChart, blocks[2])
        assertEquals(DashboardCard.WHITELIST, (blocks[3] as DashboardBlock.Rows).cards.first())
        assertEquals(DashboardCard.TAKEOVER, (blocks[3] as DashboardBlock.Rows).cards.last())
    }

    @Test
    fun customizedOrderIsKeptAndStatusStaysFirst() {
        val cards = listOf(DashboardCard.SPEED, DashboardCard.MEMORY, DashboardCard.MODE, DashboardCard.TRAFFIC)

        assertEquals(
            listOf(
                DashboardBlock.Rows(emptyList(), status = true),
                DashboardBlock.SpeedChart,
                DashboardBlock.Rows(listOf(DashboardCard.MEMORY)),
                DashboardBlock.ModePicker,
                DashboardBlock.Rows(listOf(DashboardCard.TRAFFIC)),
            ),
            dashboardBlocks(shownCards(cards)),
        )
    }
}
