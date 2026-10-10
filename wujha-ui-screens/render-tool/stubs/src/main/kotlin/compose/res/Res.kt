package androidx.compose.ui.res

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.toComposeImageBitmap

/** Resource ids are registered by each app's generated R object. */
object DrawableRegistry {
    val paths = HashMap<Int, String>()
}

@Composable
fun painterResource(id: Int): Painter {
    val path = DrawableRegistry.paths[id] ?: error("Unknown drawable $id")
    return remember(id) {
        val bytes = Thread.currentThread().contextClassLoader.getResourceAsStream(path)!!.readBytes()
        BitmapPainter(org.jetbrains.skia.Image.makeFromEncoded(bytes).toComposeImageBitmap())
    }
}
