package com.google.android.gms.tasks

open class Task<T>(private val value: T?, private val error: Exception?) {
    val isSuccessful: Boolean get() = error == null
    val isComplete: Boolean get() = true
    val result: T? get() = if (error != null) throw RuntimeException(error) else value
    val exception: Exception? get() = error
    fun addOnSuccessListener(l: (T) -> Unit): Task<T> { if (error == null) @Suppress("UNCHECKED_CAST") l(value as T); return this }
    fun addOnFailureListener(l: (Exception) -> Unit): Task<T> { if (error != null) l(error); return this }
    fun addOnCompleteListener(l: (Task<T>) -> Unit): Task<T> { l(this); return this }

    companion object {
        fun <T> of(block: () -> T): Task<T> = try { Task(block(), null) } catch (e: Exception) { Task(null, e) }
    }
}
