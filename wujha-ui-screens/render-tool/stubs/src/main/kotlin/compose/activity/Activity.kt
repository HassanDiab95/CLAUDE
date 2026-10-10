package androidx.activity.result.contract

abstract class ActivityResultContract<I, O>

object ActivityResultContracts {
    class PickVisualMedia : ActivityResultContract<androidx.activity.result.PickVisualMediaRequest, android.net.Uri?>() {
        interface VisualMediaType
        object ImageOnly : VisualMediaType
        object ImageAndVideo : VisualMediaType
        companion object {
            val ImageOnly = PickVisualMedia.ImageOnly
        }
    }
    class RequestPermission : ActivityResultContract<String, Boolean>()
    class StartActivityForResult : ActivityResultContract<android.content.Intent, androidx.activity.result.ActivityResult>()
    class GetContent : ActivityResultContract<String, android.net.Uri?>()
}
