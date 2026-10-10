package android.graphics

/** Desktop stand-in: wraps an already-decoded Compose image. */
class Bitmap(val image: androidx.compose.ui.graphics.ImageBitmap) {
    val width: Int get() = image.width
    val height: Int get() = image.height
}
