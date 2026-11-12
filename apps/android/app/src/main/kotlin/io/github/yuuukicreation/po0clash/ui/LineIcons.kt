package io.github.yuuukicreation.po0clash.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

// Glyphs adapted from FlClash 0.9.3 (GPL-3.0), lib/ui/icons/app_glyphs.dart.
object LineIcons {
    val Dashboard = icon("F:" + rect(3.5, 3.5, 7, 8, 2), "F:" + rect(13.5, 3.5, 7, 6, 2), "F:" + rect(3.5, 14.5, 7, 6, 2), "F:" + rect(13.5, 12.5, 7, 8, 2))
    val Profile = icon("F:M7 3h6l6 6v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM12.8 3.2l1.4 1.4v3.2h3.6L19 9.2h-6.2zM8 12h8v1.5H8zM8 16h5v1.5H8z")
    val Tools = icon("F:" + rect(3, 7, 18, 13, 2.8), "M9 7V4.6h6V7", "M3.2 12.6h6.4M14.4 12.6h6.4")
    val Edit = icon("F:M16.5 2.5a2 2 0 0 1 2.8 0l2.2 2.2a2 2 0 0 1 0 2.8L8 21l-6 1 1-6zM15 5l4 4-1.3 1.3-4-4z")
    val Status = icon(rect(3, 5, 18, 14, 3), "M5 12h3l2-4 3 8 2-4h4")
    val Speed = icon("M4.8 18a9 9 0 1 1 14.4 0H4.8zM12 12l4-4")
    val Rules = icon(rect(4, 3, 16, 18, 2), "M7 7h.01M10 7h7M7 12h.01M10 12h7M7 17h.01M10 17h7")
    val Split = icon("M12 21V11M12 11 5 4M12 11l7-7M3 9V3h6M15 3h6v6")
    val Target = icon(circle(12, 12, 9), circle(12, 12, 2), "M12 1v3M12 20v3")
    val Globe = icon("M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18ZM3 12h18M12 3c3 3 3.5 6 3.5 9s-.5 6-3.5 9c-3-3-3.5-6-3.5-9s.5-6 3.5-9Z")
    val Layers = icon("M12 3 3 8l9 5 9-5-9-5ZM3 13l9 5 9-5M3 18l9 5 9-5")
    val ShieldCheck = icon("M12 3l8 3v6c0 4.5-3.2 7.6-8 9-4.8-1.4-8-4.5-8-9V6l8-3ZM8.5 12l2.5 2.5 4.5-5")
    val Sliders = icon("M4 7h9M17 7h3M4 17h3M11 17h9M13 5h4v4h-4zM7 15h4v4H7z")
    val Bolt = icon("M13 3 5 14h6l-1 7 8-11h-6l1-7Z")
    val Sort = icon("m3 8 4-4 4 4", "M7 4v16", "m21 16-4 4-4-4", "M17 20V4")
    val ChevronUp = icon("m18 15-6-6-6 6", stroke = 2.4f)
    val ChevronDown = icon("m6 9 6 6 6-6", stroke = 2.4f)
    val ChevronLeft = icon("M15 5l-7 7 7 7")
    val Check = icon("M5 12.5l4.5 4.5L19 7.5")
    val ArrowDown = icon("M12 5v14M7 14l5 5 5-5")
    val ArrowUp = icon("M12 19V5M7 10l5-5 5 5")
    val Link = icon(
        "M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7",
        "M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7",
    )
    val Unlink = icon(
        "m18.8 13.2 2.2-2.2a5 5 0 0 0-7-7l-2.2 2.2",
        "m5.2 10.8-2.2 2.2a5 5 0 0 0 7 7l2.2-2.2",
        "M8 2v3M2 8h3M16 22v-3M22 16h-3",
    )
    val Activity = icon("M22 12h-4l-3 8.5L9 3.5 6 12H2")
    val FileText = icon(
        "M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z",
        "M14 2.5V8h5.5",
        "M8.5 13h7M8.5 17h5",
    )
    val Info = icon(circle(12, 12, 9.5), "M12 16.5v-5", "M12 7.5h.01")
    val Refresh = icon("M20 11a8 8 0 1 0-2.3 6M20 5v6h-6")
    val Plus = icon("M12 5v14M5 12h14")
    val Trash = icon("M4 7h16M9 7V4h6v3M6.5 7l1 13h9l1-13")
    val Close = icon("M6 6l12 12M18 6 6 18")
    val Search = icon("M11 4a7 7 0 1 0 0 14a7 7 0 0 0 0-14ZM20 20l-4-4")
    val More = icon("M12 5h.01M12 12h.01M12 19h.01", stroke = 3f)
    val Download = icon("M12 3v12", "m7 10 5 5 5-5", "M5 21h14")
    val Grid = icon(rect(3.5, 3.5, 7, 7, 1.8), rect(13.5, 3.5, 7, 7, 1.8), rect(3.5, 13.5, 7, 7, 1.8), rect(13.5, 13.5, 7, 7, 1.8))

    private fun circle(x: Number, y: Number, radius: Number): String {
        val (cx, cy, r) = listOf(x, y, radius).map(Number::toDouble)
        return "M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0z"
    }

    private fun rect(x: Number, y: Number, w: Number, h: Number, r: Number): String {
        val (x0, y0, ww, hh, rr) = listOf(x, y, w, h, r).map(Number::toDouble)
        return "M${x0 + rr} ${y0}h${ww - 2 * rr}a$rr $rr 0 0 1 $rr ${rr}v${hh - 2 * rr}a$rr $rr 0 0 1 ${-rr} ${rr}" +
            "h${-(ww - 2 * rr)}a$rr $rr 0 0 1 ${-rr} ${-rr}v${-(hh - 2 * rr)}a$rr $rr 0 0 1 $rr ${-rr}z"
    }

    private fun icon(vararg paths: String, stroke: Float = 1.6f): ImageVector {
        val builder = ImageVector.Builder(defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f)
        val ink = SolidColor(Color.Black)
        paths.forEach { path ->
            val filled = path.startsWith("F:")
            builder.addPath(
                pathData = addPathNodes(path.removePrefix("F:")),
                pathFillType = androidx.compose.ui.graphics.PathFillType.EvenOdd,
                fill = if (filled) ink else null,
                stroke = if (filled) null else ink,
                strokeLineWidth = stroke,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round,
            )
        }
        return builder.build()
    }
}
