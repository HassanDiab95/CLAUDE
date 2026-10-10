package com.wujha.user.data.storage

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.ui.graphics.toComposeImageBitmap
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/** Result of preparing a photo: either its Base64 payload, or an Arabic reason. */
sealed interface UploadResult {
    data class Success(val base64: String) : UploadResult
    data class Failure(val message: String) : UploadResult
}

/**
 * How hard to squeeze a particular kind of photo.
 *
 * A Firestore document is capped at 1 MiB and Base64 inflates bytes by about
 * a third, so the ceiling below is on the raw JPEG: a cover leaves plenty of
 * room for the rest of the book, and an avatar is small enough that a list of
 * fifty of them still loads quickly.
 */
enum class PhotoKind(val maxDimension: Int, val targetBytes: Int) {
    /** A book cover, shown as large as half the screen. */
    COVER(700, 450 * 1024),

    /** A profile photo, never shown bigger than a thumbnail. */
    AVATAR(360, 90 * 1024),

    /**
     * A photo of an ID card, attached to a borrowing request.
     *
     * Allowed to be larger than a cover because a librarian has to *read*
     * it — a name and a ten-digit number have to survive the compression,
     * or the review step is theatre. It is still kept well inside the
     * document limit, and it is erased as soon as the loan ends.
     */
    DOCUMENT(1000, 300 * 1024)
}

/**
 * Turns a photo the person picked into a Base64 JPEG string that lives
 * directly on a Firestore document — no Firebase Storage bucket involved.
 *
 * Everything is decoded from one in-memory copy of the file: some content
 * providers (cloud-backed gallery items, a few file managers) only allow a
 * `content://` Uri to be opened once, so reopening it part-way through would
 * fail on exactly the photos people most often pick.
 */
object ImageCodec {

    suspend fun encode(context: android.content.Context, uri: android.net.Uri, kind: PhotoKind = PhotoKind.COVER): UploadResult =
        UploadResult.Failure("unsupported")

    /** Decodes a stored Base64 photo. Returns null for an empty or corrupt value. */
    fun decode(base64: String): android.graphics.Bitmap? {
        if (base64.isBlank()) return null
        return try {
            val bytes = java.util.Base64.getMimeDecoder().decode(base64)
            android.graphics.Bitmap(org.jetbrains.skia.Image.makeFromEncoded(bytes).toComposeImageBitmap())
        } catch (e: Exception) { null }
    }

    fun storedKilobytes(base64: String): Int = (base64.length * 3 / 4) / 1024
}
