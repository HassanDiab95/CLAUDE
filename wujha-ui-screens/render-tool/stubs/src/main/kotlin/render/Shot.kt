package render

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.ImageComposeScene
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.firestore.FakeStore
import kotlinx.coroutines.delay
import org.jetbrains.skia.EncodedImageFormat
import java.io.File
import java.util.Base64

object Shot {
    var outDir = File("out")
    const val W = 360
    const val H = 800
    const val D = 3f

    /** A phone-like status bar, so each PNG reads as a device screen. */
    @Composable
    fun StatusBar(bg: Color) {
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(
                Modifier.fillMaxWidth().height(28.dp).background(bg).padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("9:41", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF1B1B1B))
                Box(Modifier.weight(1f))
                Text("▂▄▆█  ◢  ▮▮▮", fontSize = 10.sp, color = Color(0xFF1B1B1B))
            }
        }
    }

    suspend fun shot(name: String, statusBg: Color = Color(0xFFF7F3EA), settleMs: Int = 1600, content: @Composable () -> Unit) {
        outDir.mkdirs()
        val scene = ImageComposeScene(width = (W * D).toInt(), height = (H * D).toInt(), density = Density(D)) {
            Column(Modifier.fillMaxSize().background(Color.White)) {
                StatusBar(statusBg)
                Box(Modifier.weight(1f).fillMaxWidth()) { content() }
            }
        }
        try {
            var t = 0L
            while (t < settleMs) {
                scene.render(t * 1_000_000L)
                delay(40)
                t += 80
            }
            val img = scene.render(t * 1_000_000L)
            File(outDir, "$name.png").writeBytes(img.encodeToData(EncodedImageFormat.PNG)!!.bytes)
            println("wrote $name.png")
        } catch (e: Throwable) {
            System.err.println("FAILED $name: $e"); e.printStackTrace()
        } finally {
            scene.close()
        }
    }

    /** Puts the user's book photos onto the seeded book documents, keyed by serial or title. */
    fun attachCovers(dir: File) {
        val files = dir.listFiles().orEmpty()
        FakeStore.docs.filterKeys { it.startsWith("books/") }.values.forEach { doc ->
            val serial = doc["serial"] as? String ?: ""
            val title = (doc["title"] as? String ?: "").replace(":", "")
            val f = files.firstOrNull { it.nameWithoutExtension == serial }
                ?: files.firstOrNull { it.name.startsWith("X-") && titleMatch(it.nameWithoutExtension.removePrefix("X-"), title) }
            if (f != null) doc["coverBase64"] = Base64.getEncoder().encodeToString(f.readBytes())
        }
        FakeStore.notifyAllListeners()
    }

    private fun titleMatch(fileTitle: String, title: String): Boolean {
        val words = fileTitle.split(' ', '-').map { it.trim() }.filter { it.length > 2 && it.all { c -> !c.isLetter() || c.code > 0x600 } }
        return words.isNotEmpty() && words.take(2).all { w -> title.contains(w.removeSuffix("ه").removeSuffix("ة")) }
    }
}
