package androidx.activity.result

class PickVisualMediaRequest(val type: Any? = null)
class ActivityResult(val resultCode: Int, val data: android.content.Intent?)

open class ActivityResultLauncher<I> { open fun launch(input: I) {} }
