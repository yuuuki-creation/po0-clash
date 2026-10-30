package io.github.yuuukicreation.po0clash.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.util.Base64
import android.util.LruCache
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import com.caverock.androidsvg.SVG
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.security.MessageDigest

/** A profile's group `icon` (image URL, inline SVG or base64 data), decoded once; downloads are also kept on disk. */
object GroupIcons {
    private const val SIZE = 96
    private const val MAX_BYTES = 1 shl 20
    private val memory = LruCache<String, ImageBitmap>(64)
    private val failed = mutableSetOf<String>()

    fun cached(icon: String): ImageBitmap? = memory.get(icon)

    suspend fun load(context: Context, icon: String): ImageBitmap? = withContext(Dispatchers.IO) {
        memory.get(icon)?.let { return@withContext it }
        if (synchronized(failed) { icon in failed }) return@withContext null
        val bitmap = runCatching { source(context, icon.trim())?.let(::decode) }.getOrNull()
        if (bitmap == null) {
            synchronized(failed) { failed += icon }
        } else {
            memory.put(icon, bitmap)
        }
        bitmap
    }

    private fun source(context: Context, icon: String): ByteArray? = when {
        icon.startsWith("<") -> icon.encodeToByteArray()
        icon.startsWith("data:") -> {
            val (meta, data) = icon.substringAfter(':') to icon.substringAfter(',')
            if (meta.substringBefore(',').endsWith(";base64")) {
                Base64.decode(data, Base64.DEFAULT)
            } else {
                URLDecoder.decode(data, "UTF-8").encodeToByteArray()
            }
        }
        icon.startsWith("http://") || icon.startsWith("https://") -> download(context, icon)
        else -> Base64.decode(icon, Base64.DEFAULT)
    }

    private fun download(context: Context, url: String): ByteArray? {
        val name = MessageDigest.getInstance("SHA-256").digest(url.encodeToByteArray()).joinToString("") { "%02x".format(it) }
        val file = File(context.cacheDir, "group-icons/$name")
        if (file.isFile) return file.readBytes()
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        return try {
            if (connection.responseCode !in 200..299) return null
            val bytes = connection.inputStream.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (out.size() <= MAX_BYTES) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                }
                out.toByteArray()
            }
            if (bytes.size > MAX_BYTES) return null
            file.parentFile?.mkdirs()
            file.writeBytes(bytes)
            bytes
        } finally {
            connection.disconnect()
        }
    }

    private fun decode(bytes: ByteArray): ImageBitmap? {
        val head = bytes.copyOf(minOf(bytes.size, 512)).decodeToString()
        if ("<svg" in head || head.trimStart().startsWith("<?xml")) {
            val svg = SVG.getFromString(bytes.decodeToString())
            if (svg.documentViewBox == null && svg.documentWidth > 0 && svg.documentHeight > 0) {
                svg.setDocumentViewBox(0f, 0f, svg.documentWidth, svg.documentHeight)
            }
            val bitmap = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
            Canvas(bitmap).drawPicture(svg.renderToPicture(SIZE, SIZE))
            return bitmap.asImageBitmap()
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
    }
}

/** The decoded icon, or null while it loads, when there is none, and when it cannot be read. */
@Composable
fun rememberGroupIcon(icon: String?): ImageBitmap? {
    val context = LocalContext.current.applicationContext
    val bitmap by produceState(icon?.let(GroupIcons::cached), icon) {
        if (value == null && !icon.isNullOrBlank()) value = GroupIcons.load(context, icon)
    }
    return bitmap
}
