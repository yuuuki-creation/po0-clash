package io.github.yuuukicreation.po0clash.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/** The design spec's thin line icons (24-unit SVG paths, round caps); a leading `F:` marks a filled shape. */
object LineIcons {
    val Gauge = icon("M12 14l4-4", "M3.34 19a10 10 0 1 1 17.32 0")
    val Globe = icon(circle(12, 12, 9.5), "M2.5 12h19", "M12 2.5a14.5 14.5 0 0 1 0 19a14.5 14.5 0 0 1 0-19z")
    val Layers = icon("M12 2.5 2.5 7.5l9.5 5 9.5-5z", "m2.5 16.5 9.5 5 9.5-5", "m2.5 12 9.5 5 9.5-5")
    val ShieldCheck = icon("M12 21.5s8-3.8 8-9.8V5.2l-8-2.9-8 2.9v6.5c0 6 8 9.8 8 9.8z", "m8.8 12 2.2 2.2 4.2-4.4")
    val Sliders = icon(
        "M20 5h-7", "M9 5H4", "M20 12h-9", "M7 12H4", "M20 19h-5", "M11 19H4", "M13 3v4", "M7 10v4", "M15 17v4",
    )
    val Bolt = icon("M13 2.5 4 13.5h7.5l-1 8 9-11H12z")
    val Sort = icon("m3 8 4-4 4 4", "M7 4v16", "m21 16-4 4-4-4", "M17 20V4")
    val Locate = icon(circle(12, 12, 7), circle(12, 12, 2), "M12 2v3M12 19v3M2 12h3M19 12h3")
    val ChevronUp = icon("m18 15-6-6-6 6", stroke = 2.4f)
    val ChevronDown = icon("m6 9 6 6 6-6", stroke = 2.4f)
    val ChevronRight = icon("m9 18 6-6-6-6", stroke = 2.4f)
    val ChevronLeft = icon("m15 18-6-6 6-6", stroke = 2.4f)
    val Check = icon("M20 6 9 17l-5-5", stroke = 3f)
    val Chart = icon("m7 15 3-3 3 3 5-6", "M3 3v18h18")
    val Branch = icon(circle(6, 18, 2.5), circle(18, 6, 2.5), "M6 3v12.5", "M18 8.5a9.5 9.5 0 0 1-9.5 9.5")
    val UpDown = icon("M7 20V4", "m3 8 4-4 4 4", "M17 4v16", "m21 16-4 4-4-4")
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
    val FileImport = icon(
        "M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z",
        "M14 2.5V8h5.5",
        "M12 18v-6",
        "m9 15 3 3 3-3",
    )
    val Wifi = icon("M5 12.5a10 10 0 0 1 14 0", "M2 9a14.5 14.5 0 0 1 20 0", "M8.5 16a5 5 0 0 1 7 0", "M12 19.5h.01")
    val WifiOff = icon(
        "M3 3l18 18", "M8.5 16a5 5 0 0 1 7 0", "M5 12.5a10 10 0 0 1 4.5-2.6", "M2 9a14.5 14.5 0 0 1 4.5-2.9",
        "M22 9a14.5 14.5 0 0 0-11-3.9", "M19 12.5a10 10 0 0 0-2-1.4", "M12 19.5h.01",
    )
    val Server = icon(rect(3, 3.5, 18, 7, 2), rect(3, 13.5, 18, 7, 2), "M7 7h.01M7 17h.01")
    val Wrench = icon(
        "M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.8-3.8a6 6 0 0 1-7.9 7.9l-6.9 6.9a2.1 2.1 0 0 1-3-3l6.9-6.9a6 6 0 0 1 7.9-7.9z",
    )
    val Appearance = icon(circle(12, 12, 9), "F:M12 3a9 9 0 0 0 0 18z")
    val Languages = icon("m5 8 6 6", "m4 14 6-6 2-3", "M2 5h12", "M7 2h1", "m22 22-5-10-5 10", "M14 18h6")
    val AppWindow = icon(rect(3, 4, 18, 16, 2.5), "M3 9h18", "M6.5 6.5h.01M9 6.5h.01")
    val Smartphone = icon(rect(6, 2.5, 12, 19, 2.5), "M11 18h2")
    val Database = icon(
        "M4 5.5a8 3 0 1 0 16 0a8 3 0 1 0-16 0z",
        "M4 5.5v13c0 1.7 3.6 3 8 3s8-1.3 8-3v-13",
        "M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3",
    )
    val CloudUpload = icon("M12 13v8", "m8 17 4-4 4 4", "M20 16.6A5 5 0 0 0 18 7h-1.3A8 8 0 1 0 4 15.3")
    val Terminal = icon("m4 17 6-6-6-6", "M12 19h8")
    val Info = icon(circle(12, 12, 9.5), "M12 16.5v-5", "M12 7.5h.01")
    val Chip = icon(rect(6, 6, 12, 12, 2), "M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4")
    val Pin = icon("M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0z", circle(12, 10, 3))
    val Refresh = icon("M3 12a9 9 0 0 1 15-6.7L21 8", "M21 3v5h-5", "M21 12a9 9 0 0 1-15 6.7L3 16", "M3 21v-5h5")
    val Plus = icon("M12 5v14M5 12h14", stroke = 2f)
    val Trash = icon("M3 6h18", "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2")
    val Close = icon("M18 6 6 18", "m6 6 12 12", stroke = 2f)
    val Search = icon(circle(11, 11, 7.5), "m21 21-4.3-4.3")
    val More = icon("F:" + circle(5, 12, 1.7), "F:" + circle(12, 12, 1.7), "F:" + circle(19, 12, 1.7))
    val Warning = icon(
        "M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z",
        "M12 9v4",
        "M12 17h.01",
    )
    val Hourglass = icon(
        "M5 22h14", "M5 2h14", "M17 22v-4.2a2 2 0 0 0-.6-1.4L12 12l-4.4 4.4a2 2 0 0 0-.6 1.4V22",
        "M7 2v4.2a2 2 0 0 0 .6 1.4L12 12l4.4-4.4a2 2 0 0 0 .6-1.4V2",
    )
    val Package = icon("M21 8 12 3 3 8v8l9 5 9-5z", "M3 8l9 5 9-5", "M12 13v8")
    val Rules = icon("M8 6h13M8 12h13M8 18h13", "M3 6h.01M3 12h.01M3 18h.01")
    val Download = icon("M12 3v12", "m7 10 5 5 5-5", "M5 21h14")
    val Battery = icon(rect(2, 7, 16, 10, 2), "M22 11v2")
    val Grid = icon(rect(3.5, 3.5, 7, 7, 1.8), rect(13.5, 3.5, 7, 7, 1.8), rect(3.5, 13.5, 7, 7, 1.8), rect(13.5, 13.5, 7, 7, 1.8))
    val Lan = icon(rect(9, 2.5, 6, 5, 1), rect(2.5, 16.5, 6, 5, 1), rect(15.5, 16.5, 6, 5, 1), "M12 7.5v4.5M5.5 16.5V12h13v4.5")
    val Shield = icon("M12 21.5s8-3.8 8-9.8V5.2l-8-2.9-8 2.9v6.5c0 6 8 9.8 8 9.8z")
    val Palette = icon(circle(12, 12, 9.5), "F:" + circle(7.5, 11, 1.4), "F:" + circle(10.5, 7, 1.4), "F:" + circle(15, 7.5, 1.4))
    val Play = icon("F:M7 3.5v17l14-8.5z")
    val Stop = icon("F:" + rect(4, 4, 16, 16, 3.5))

    private fun circle(x: Number, y: Number, radius: Number): String {
        val (cx, cy, r) = listOf(x, y, radius).map(Number::toDouble)
        return "M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0z"
    }

    private fun rect(x: Number, y: Number, w: Number, h: Number, r: Number): String {
        val (x0, y0, ww, hh, rr) = listOf(x, y, w, h, r).map(Number::toDouble)
        return "M${x0 + rr} ${y0}h${ww - 2 * rr}a$rr $rr 0 0 1 $rr ${rr}v${hh - 2 * rr}a$rr $rr 0 0 1 ${-rr} ${rr}" +
            "h${-(ww - 2 * rr)}a$rr $rr 0 0 1 ${-rr} ${-rr}v${-(hh - 2 * rr)}a$rr $rr 0 0 1 $rr ${-rr}z"
    }

    private fun icon(vararg paths: String, stroke: Float = 1.8f): ImageVector {
        val builder = ImageVector.Builder(defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f)
        val ink = SolidColor(Color.Black)
        paths.forEach { path ->
            val filled = path.startsWith("F:")
            builder.addPath(
                pathData = addPathNodes(path.removePrefix("F:")),
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
