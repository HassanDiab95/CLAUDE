package android.net

class Uri private constructor(private val s: String) {
    override fun toString() = s
    companion object {
        @JvmStatic fun parse(s: String) = Uri(s)
        @JvmStatic fun fromParts(scheme: String, ssp: String, fragment: String?) = Uri("$scheme:$ssp")
        @JvmStatic fun encode(s: String?) = s ?: ""
    }
}
