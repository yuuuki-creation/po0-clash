package io.github.yuuukicreation.po0clash.ui

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asAndroidBitmap
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

    private fun screenshot(name: String) {
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir(null), "motion-shots")
        directory.mkdirs()
        File(directory, "$name.png").outputStream().use {
            ui.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}
