package io.github.yuuukicreation.po0clash.ui

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class MotionTest {
    @get:Rule val ui = createComposeRule()

    @Test fun navigationCommitsOnReleaseAndCancelsWithoutSwitching() {
        val selected = mutableStateOf(Page.DASHBOARD)
        val changes = mutableListOf<Page>()
        ui.setContent {
            MaterialTheme {
                BottomNav(Page.entries, selected.value, false, Modifier.testTag("dock")) {
                    selected.value = it
                    changes += it
                }
            }
        }
        val dock = ui.onNodeWithTag("dock")
        dock.performTouchInput {
            down(Offset(width * 0.15f, height / 2f))
            moveTo(Offset(width * 0.85f, height / 2f), 200)
        }
        ui.runOnIdle { assertEquals(emptyList<Page>(), changes) }
        dock.performTouchInput { cancel() }
        ui.runOnIdle { assertEquals(Page.DASHBOARD, selected.value) }
        dock.performTouchInput {
            down(Offset(width * 0.15f, height / 2f))
            moveTo(Offset(width * 0.85f, height / 2f), 200)
            up()
        }
        ui.runOnIdle { assertEquals(listOf(Page.TOOLS), changes) }
        screenshot("navigation")
    }

    @Test fun switchSupportsTapDragAndDisabledSemantics() {
        val checked = mutableStateOf(false)
        val enabled = mutableStateOf(true)
        ui.setContent { MaterialTheme { Po0Switch(checked.value, { checked.value = it }, enabled.value, Modifier.testTag("switch")) } }
        val toggle = ui.onNodeWithTag("switch")
        toggle.assertIsOff().performClick().assertIsOn()
        toggle.performTouchInput { swipeLeft() }
        toggle.assertIsOff()
        ui.runOnIdle { enabled.value = false }
        toggle.assertIsNotEnabled().performTouchInput { click() }
        toggle.assertIsOff()
        screenshot("switch-disabled")
    }

    @Test fun tabCrossfadeKeepsBothPagesUntilTransitionCompletes() {
        val page = mutableStateOf("first")
        ui.mainClock.autoAdvance = false
        ui.setContent {
            MaterialTheme {
                Box(Modifier.size(240.dp)) {
                    AnimatedContent(page.value, transitionSpec = { tabTransition(true) }, label = "testTabs") { Text(it) }
                }
            }
        }
        ui.runOnIdle { page.value = "second" }
        ui.mainClock.advanceTimeBy(100)
        ui.onNodeWithText("first").assertExists()
        ui.onNodeWithText("second").assertExists()
        screenshot("tab-midpoint")
        ui.mainClock.advanceTimeBy(160)
        ui.onNodeWithText("first").assertDoesNotExist()
        ui.onNodeWithText("second").assertExists()
    }

    @Test fun reducedMotionFinishesImmediatelyAndBusyControlCanBeCancelled() {
        val page = mutableStateOf("first")
        var clicks = 0
        ui.mainClock.autoAdvance = false
        ui.setContent {
            MaterialTheme {
                CompositionLocalProvider(LocalReduceMotion provides true) {
                    AnimatedContent(page.value, transitionSpec = { tabTransition(false) }, label = "reducedTabs") {
                        if (it == "first") Text(it)
                        else ConnectionToggle(true, true, "Stop", 0f) { clicks++ }
                    }
                }
            }
        }
        ui.runOnIdle { page.value = "second" }
        ui.mainClock.advanceTimeByFrame()
        ui.mainClock.advanceTimeByFrame()
        ui.onNodeWithText("first").assertDoesNotExist()
        ui.onNodeWithContentDescription("Stop")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ProgressBarRangeInfo, ProgressBarRangeInfo.Indeterminate))
            .performClick()
        ui.runOnIdle { assertEquals(1, clicks) }
        screenshot("reduced-motion")
    }

    @Test fun secondaryPageSlidesOverItsParentAndCanReverseMidflight() {
        val page = mutableStateOf<String?>(null)
        ui.mainClock.autoAdvance = false
        ui.setContent {
            MaterialTheme {
                PushHost(page.value, true, { page.value = null }, "push") { Text(it ?: "parent") }
            }
        }
        ui.runOnIdle { page.value = "detail" }
        ui.mainClock.advanceTimeBy(100)
        assertTrue(ui.onNodeWithText("detail").getUnclippedBoundsInRoot().left > 0.dp)
        assertTrue(ui.onNodeWithText("parent").getUnclippedBoundsInRoot().left < 0.dp)
        screenshot("push-midpoint")
        ui.runOnIdle { page.value = null }
        ui.mainClock.advanceTimeBy(600)
        ui.onNodeWithText("detail").assertDoesNotExist()
        ui.onNodeWithText("parent").assertLeftPositionInRootIsEqualTo(0.dp)
    }

    @Test fun popupRetainsContentDuringExitAndReopensWithNewActions() {
        val sheets = Sheets()
        val anchor = Anchor()
        ui.mainClock.autoAdvance = false
        ui.setContent { MaterialTheme { SheetHost(sheets) } }
        ui.runOnIdle { sheets.menu(anchor, listOf(SheetAction("first action") {})) }
        ui.mainClock.advanceTimeBy(500)
        ui.onNodeWithText("first action").assertExists()
        ui.runOnIdle { sheets.dismiss() }
        ui.mainClock.advanceTimeBy(100)
        ui.onNodeWithText("first action").assertExists()
        ui.mainClock.advanceTimeBy(150)
        ui.onNodeWithText("first action").assertDoesNotExist()
        ui.runOnIdle { sheets.menu(anchor, listOf(SheetAction("second action") {})) }
        ui.mainClock.advanceTimeBy(500)
        ui.onNodeWithText("first action").assertDoesNotExist()
        ui.onNodeWithText("second action").assertExists()
        screenshot("popup")
    }

    @Test fun switchTapKeepsTheThumbLiftedAfterRelease() {
        val checked = mutableStateOf(false)
        ui.mainClock.autoAdvance = false
        ui.setContent { MaterialTheme { Po0Switch(checked.value, { checked.value = it }, modifier = Modifier.testTag("switch").background(Color.Black)) } }
        val toggle = ui.onNodeWithTag("switch")
        toggle.performTouchInput { click() }
        ui.mainClock.advanceTimeBy(128)
        assertTrue("tap must lift the thumb beyond its track", thumbBounds()[3] - thumbBounds()[1] > 32f)
        screenshot("switch-tap-held")
        ui.mainClock.advanceTimeBy(300)
        assertTrue("tap lift must settle", thumbBounds()[3] - thumbBounds()[1] < 25f)
        toggle.assertIsOn()
    }

    @Test fun switchReversalUsesTheRemainingTravelAndKeepsTheLatestValue() {
        val checked = mutableStateOf(false)
        ui.mainClock.autoAdvance = false
        ui.setContent { MaterialTheme { Po0Switch(checked.value, { checked.value = it }, modifier = Modifier.testTag("switch").background(Color.Black)) } }
        ui.runOnIdle { checked.value = true }
        ui.mainClock.advanceTimeBy(80)
        ui.runOnIdle { checked.value = false }
        ui.mainClock.advanceTimeBy(128)
        val bounds = thumbBounds()
        assertEquals(20f, (bounds[0] + bounds[2]) / 2, 0.6f)
        ui.runOnIdle { checked.value = true }
        ui.mainClock.advanceTimeBy(500)
        ui.onNodeWithTag("switch").assertIsOn()
        assertEquals(40f, (thumbBounds()[0] + thumbBounds()[2]) / 2, 0.6f)
    }

    @Test fun retiringMenuCannotRepeatAnActionOrDismissItsReplacement() {
        val sheets = Sheets()
        var actions = 0
        ui.mainClock.autoAdvance = false
        ui.setContent { MaterialTheme { SheetHost(sheets) } }
        ui.runOnIdle {
            sheets.menu(Anchor(), listOf(SheetAction("open form") {
                actions++
                sheets.show { Text("replacement form") }
            }))
        }
        ui.mainClock.advanceTimeBy(500)
        ui.onNodeWithText("open form").performTouchInput { click(); advanceEventTime(1); click() }
        ui.mainClock.advanceTimeBy(32)
        ui.onNodeWithText("open form").assertIsNotEnabled().performTouchInput { click() }
        ui.mainClock.advanceTimeBy(600)
        ui.runOnIdle { assertEquals(1, actions); assertTrue(sheets.open) }
        ui.onNodeWithText("replacement form").assertExists()
        ui.runOnIdle { sheets.dismiss() }
        ui.mainClock.advanceTimeBy(32)
        ui.onNodeWithText("replacement form").assertDoesNotExist()
    }

    @Test fun reopeningADragDismissedSheetDoesNotKeepItsOldOffset() {
        val sheets = Sheets()
        ui.mainClock.autoAdvance = false
        ui.setContent { MaterialTheme { SheetHost(sheets) } }
        ui.runOnIdle { sheets.show { Box(Modifier.size(240.dp)) { Text("first form") } } }
        ui.mainClock.advanceTimeBy(600)
        val top = ui.onNodeWithText("first form").getUnclippedBoundsInRoot().top
        val scale = ui.density.density
        ui.onRoot().performTouchInput {
            down(Offset(width / 2f, (top.value - 24f) * scale))
            moveBy(Offset(0f, 120f * scale), 200)
            up()
        }
        ui.mainClock.advanceTimeBy(32)
        ui.runOnIdle { sheets.show { Box(Modifier.size(240.dp)) { Text("second form") } } }
        ui.mainClock.advanceTimeBy(600)
        ui.onNodeWithText("second form").assertTopPositionInRootIsEqualTo(top)
    }

    @Test fun runningAnimationReversesInPlaceAndReducedMotionStopsIt() {
        val running = mutableStateOf(false)
        val reduced = mutableStateOf(false)
        ui.mainClock.autoAdvance = false
        ui.setContent {
            CompositionLocalProvider(LocalReduceMotion provides reduced.value) {
                val progress = reversibleProgress(running.value, 450, EaseOutBack, EaseInCubic)
                Box(Modifier.fillMaxSize()) { Text("marker", Modifier.offset(x = 100.dp * progress)) }
            }
        }
        ui.runOnIdle { running.value = true }
        ui.mainClock.advanceTimeBy(96)
        assertTrue(ui.onNodeWithText("marker").getUnclippedBoundsInRoot().left > 50.dp)
        ui.runOnIdle { running.value = false }
        ui.mainClock.advanceTimeBy(144)
        ui.onNodeWithText("marker").assertLeftPositionInRootIsEqualTo(0.dp)
        ui.runOnIdle { running.value = true }
        ui.mainClock.advanceTimeBy(500)
        ui.runOnIdle { running.value = false }
        ui.mainClock.advanceTimeBy(128)
        assertTrue(ui.onNodeWithText("marker").getUnclippedBoundsInRoot().left < 60.dp)
        ui.runOnIdle { reduced.value = true }
        ui.mainClock.advanceTimeByFrame()
        ui.mainClock.advanceTimeByFrame()
        ui.onNodeWithText("marker").assertLeftPositionInRootIsEqualTo(0.dp)
    }

    private fun thumbBounds(): FloatArray {
        val image = ui.onNodeWithTag("switch").captureToImage()
        val pixels = image.toPixelMap()
        var left = image.width
        var top = image.height
        var right = 0
        var bottom = 0
        for (y in 0 until image.height) for (x in 0 until image.width) {
            val color = pixels[x, y]
            if (color.red > 0.97f && color.green > 0.97f && color.blue > 0.97f && color.alpha > 0.9f) {
                left = minOf(left, x); top = minOf(top, y); right = maxOf(right, x); bottom = maxOf(bottom, y)
            }
        }
        val density = image.width / 60f
        return floatArrayOf(left / density, top / density, (right + 1) / density, (bottom + 1) / density)
    }

    private fun screenshot(name: String) {
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir(null), "motion-shots")
        directory.mkdirs()
        File(directory, "$name.png").outputStream().use {
            ui.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}
