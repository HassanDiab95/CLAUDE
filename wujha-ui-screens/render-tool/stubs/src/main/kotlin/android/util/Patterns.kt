package android.util

object Patterns {
    @JvmField val EMAIL_ADDRESS: java.util.regex.Pattern =
        java.util.regex.Pattern.compile("[a-zA-Z0-9+._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+")
}
