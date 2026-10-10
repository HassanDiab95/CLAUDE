package android.content

interface SharedPreferences {
    fun getString(key: String, def: String?): String?
    fun getBoolean(key: String, def: Boolean): Boolean
    fun getInt(key: String, def: Int): Int
    fun getLong(key: String, def: Long): Long
    fun getStringSet(key: String, def: Set<String>?): Set<String>?
    fun contains(key: String): Boolean
    fun edit(): Editor
    interface Editor {
        fun putString(key: String, v: String?): Editor
        fun putBoolean(key: String, v: Boolean): Editor
        fun putInt(key: String, v: Int): Editor
        fun putLong(key: String, v: Long): Editor
        fun putStringSet(key: String, v: Set<String>?): Editor
        fun remove(key: String): Editor
        fun clear(): Editor
        fun apply()
        fun commit(): Boolean
    }
}

class MemoryPrefs : SharedPreferences {
    val map = HashMap<String, Any?>()
    @Suppress("UNCHECKED_CAST")
    private fun <T> g(k: String, d: T): T = (map[k] as? T) ?: d
    override fun getString(key: String, def: String?) = g(key, def)
    override fun getBoolean(key: String, def: Boolean) = g(key, def)
    override fun getInt(key: String, def: Int) = g(key, def)
    override fun getLong(key: String, def: Long) = g(key, def)
    override fun getStringSet(key: String, def: Set<String>?) = g(key, def)
    override fun contains(key: String) = map.containsKey(key)
    override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
        override fun putString(key: String, v: String?) = apply { map[key] = v }
        override fun putBoolean(key: String, v: Boolean) = apply { map[key] = v }
        override fun putInt(key: String, v: Int) = apply { map[key] = v }
        override fun putLong(key: String, v: Long) = apply { map[key] = v }
        override fun putStringSet(key: String, v: Set<String>?) = apply { map[key] = v?.toSet() }
        override fun remove(key: String) = apply { map.remove(key) }
        override fun clear() = apply { map.clear() }
        override fun apply() {}
        override fun commit() = true
    }
}

class Intent(val action: String? = null) {
    constructor(action: String, uri: android.net.Uri?) : this(action)
    private val extras = HashMap<String, Any?>()
    var data: android.net.Uri? = null
    var type: String? = null
    var flags: Int = 0
    fun putExtra(k: String, v: Any?): Intent = apply { extras[k] = v }
    fun setType(t: String?): Intent = apply { type = t }
    fun addFlags(f: Int): Intent = apply { flags = flags or f }
    companion object {
        const val ACTION_SEND = "android.intent.action.SEND"
        const val ACTION_VIEW = "android.intent.action.VIEW"
        const val ACTION_DIAL = "android.intent.action.DIAL"
        const val ACTION_SENDTO = "android.intent.action.SENDTO"
        const val EXTRA_TEXT = "android.intent.extra.TEXT"
        const val EXTRA_SUBJECT = "android.intent.extra.SUBJECT"
        const val EXTRA_TITLE = "android.intent.extra.TITLE"
        const val FLAG_ACTIVITY_NEW_TASK = 0x10000000
        fun createChooser(i: Intent, title: CharSequence?): Intent = i
    }
}

open class Context {
    open val applicationContext: Context get() = this
    open val packageName: String get() = "com.wujha"
    private val prefs = HashMap<String, MemoryPrefs>()
    fun getSharedPreferences(name: String, mode: Int): SharedPreferences = prefs.getOrPut(name) { MemoryPrefs() }
    fun startActivity(intent: Intent) {}
    class Resources { fun getIdentifier(n: String, t: String, p: String): Int = 0 }
    val resources = Resources()
    fun getString(id: Int): String = ""
    companion object {
        const val MODE_PRIVATE = 0
        /** The single context used by the desktop renderer. */
        val shared = Context()
    }
}
