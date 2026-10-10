package com.google.firebase.firestore

import com.google.android.gms.tasks.Task
import com.google.firebase.Timestamp
import java.io.File
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.util.UUID

/** An in-memory stand-in for Cloud Firestore, enough for the app's repositories. */
object FakeStore {
    /** document path -> fields */
    val docs = java.util.TreeMap<String, MutableMap<String, Any?>>()
    internal val listeners = mutableListOf<() -> Unit>()
    private var notifying = false
    private var dirty = false

    fun notifyAllListeners() {
        if (notifying) { dirty = true; return }
        notifying = true
        try {
            do {
                dirty = false
                listeners.toList().forEach { it() }
            } while (dirty)
        } finally { notifying = false }
    }

    fun save(file: File) = ObjectOutputStream(file.outputStream()).use {
        it.writeObject(HashMap(docs.mapValues { (_, v) -> HashMap(v) }))
    }

    @Suppress("UNCHECKED_CAST")
    fun load(file: File) {
        val m = ObjectInputStream(file.inputStream()).use { it.readObject() } as Map<String, Map<String, Any?>>
        docs.clear(); m.forEach { (k, v) -> docs[k] = v.toMutableMap() }
        notifyAllListeners()
    }

    internal fun resolve(value: Any?): Any? = when (value) {
        is FieldValue.ServerTimestamp -> Timestamp.now()
        is Map<*, *> -> value.mapValues { resolve(it.value) }
        is List<*> -> value.map { resolve(it) }
        else -> value
    }

    internal fun write(path: String, data: Map<String, Any?>, merge: Boolean) {
        val existing = if (merge) docs[path] ?: mutableMapOf() else mutableMapOf()
        data.forEach { (k, v) -> applyField(existing, k, v) }
        docs[path] = existing
    }

    internal fun update(path: String, data: Map<String, Any?>) {
        val existing = docs[path] ?: throw FirebaseFirestoreException("NOT_FOUND: $path", FirebaseFirestoreException.Code.NOT_FOUND)
        data.forEach { (k, v) -> applyField(existing, k, v) }
    }

    private fun applyField(target: MutableMap<String, Any?>, key: String, v: Any?) {
        when (v) {
            is FieldValue.Delete -> target.remove(key)
            is FieldValue.Increment -> {
                val cur = target[key] as? Number
                target[key] = if (v.by is Double || cur is Double) (cur?.toDouble() ?: 0.0) + v.by.toDouble()
                else (cur?.toLong() ?: 0L) + v.by.toLong()
            }
            is FieldValue.ArrayUnion -> target[key] = ((target[key] as? List<*>).orEmpty() + v.items).distinct()
            is FieldValue.ArrayRemove -> target[key] = (target[key] as? List<*>).orEmpty() - v.items.toSet()
            else -> target[key] = resolve(v)
        }
    }
}

fun interface EventListener<T> {
    fun onEvent(value: T?, error: FirebaseFirestoreException?)
}

class ListenerRegistration internal constructor(private val fn: () -> Unit) {
    fun remove() { FakeStore.listeners.remove(fn) }
}

class FirebaseFirestoreException(message: String, val code: Code) : Exception(message) {
    enum class Code { OK, CANCELLED, UNKNOWN, INVALID_ARGUMENT, DEADLINE_EXCEEDED, NOT_FOUND, ALREADY_EXISTS, PERMISSION_DENIED, RESOURCE_EXHAUSTED, FAILED_PRECONDITION, ABORTED, OUT_OF_RANGE, UNIMPLEMENTED, INTERNAL, UNAVAILABLE, DATA_LOSS, UNAUTHENTICATED }
}

sealed class FieldValue {
    internal object ServerTimestamp : FieldValue()
    internal object Delete : FieldValue()
    internal class Increment(val by: Number) : FieldValue()
    internal class ArrayUnion(val items: List<Any?>) : FieldValue()
    internal class ArrayRemove(val items: List<Any?>) : FieldValue()
    companion object {
        @JvmStatic fun serverTimestamp(): FieldValue = ServerTimestamp
        @JvmStatic fun delete(): FieldValue = Delete
        @JvmStatic fun increment(l: Long): FieldValue = Increment(l)
        @JvmStatic fun increment(d: Double): FieldValue = Increment(d)
        @JvmStatic fun arrayUnion(vararg items: Any?): FieldValue = ArrayUnion(items.toList())
        @JvmStatic fun arrayRemove(vararg items: Any?): FieldValue = ArrayRemove(items.toList())
    }
}

class SetOptions private constructor(val merge: Boolean) {
    companion object { @JvmStatic fun merge() = SetOptions(true) }
}

open class DocumentSnapshot internal constructor(val reference: DocumentReference, private val fields: Map<String, Any?>?) {
    val id: String get() = reference.id
    val data: Map<String, Any?>? get() = fields
    fun exists(): Boolean = fields != null
    operator fun contains(field: String): Boolean = fields?.containsKey(field) == true
    fun get(field: String): Any? = fields?.get(field)
    fun getString(field: String): String? = fields?.get(field) as? String
    fun getLong(field: String): Long? = (fields?.get(field) as? Number)?.toLong()
    fun getDouble(field: String): Double? = (fields?.get(field) as? Number)?.toDouble()
    fun getBoolean(field: String): Boolean? = fields?.get(field) as? Boolean
    fun getTimestamp(field: String): Timestamp? = fields?.get(field) as? Timestamp
    fun getDate(field: String): java.util.Date? = getTimestamp(field)?.toDate()
}

class QueryDocumentSnapshot internal constructor(reference: DocumentReference, fields: Map<String, Any?>) : DocumentSnapshot(reference, fields)

class QuerySnapshot internal constructor(val documents: List<QueryDocumentSnapshot>) : Iterable<QueryDocumentSnapshot> {
    val isEmpty: Boolean get() = documents.isEmpty()
    fun size(): Int = documents.size
    override fun iterator() = documents.iterator()
}

open class Query internal constructor(
    internal val path: String,
    private val filters: List<(Map<String, Any?>) -> Boolean> = emptyList(),
    private val order: Pair<String, Direction>? = null,
    private val max: Long? = null,
) {
    enum class Direction { ASCENDING, DESCENDING }

    fun whereEqualTo(field: String, value: Any?): Query = Query(path, filters + { it[field] == value }, order, max)
    fun whereIn(field: String, values: List<Any?>): Query = Query(path, filters + { it[field] in values }, order, max)
    fun orderBy(field: String, direction: Direction = Direction.ASCENDING): Query = Query(path, filters, field to direction, max)
    fun limit(n: Long): Query = Query(path, filters, order, n)

    internal fun snapshot(): QuerySnapshot {
        val prefix = "$path/"
        var docs = FakeStore.docs.entries
            .filter { it.key.startsWith(prefix) && !it.key.removePrefix(prefix).contains('/') }
            .filter { e -> filters.all { f -> f(e.value) } }
            .map { QueryDocumentSnapshot(DocumentReference(it.key), HashMap(it.value)) }
        order?.let { (f, d) ->
            @Suppress("UNCHECKED_CAST")
            val cmp = compareBy<QueryDocumentSnapshot> { it.get(f) as? Comparable<Any> }
            docs = docs.sortedWith(if (d == Direction.DESCENDING) cmp.reversed() else cmp)
        }
        max?.let { docs = docs.take(it.toInt()) }
        return QuerySnapshot(docs)
    }

    fun get(): Task<QuerySnapshot> = Task.of { snapshot() }

    fun addSnapshotListener(listener: EventListener<QuerySnapshot>): ListenerRegistration {
        val fn = { listener.onEvent(snapshot(), null) }
        FakeStore.listeners += fn
        fn()
        return ListenerRegistration(fn)
    }
}

class CollectionReference internal constructor(path: String) : Query(path) {
    val id: String get() = path.substringAfterLast('/')
    fun document(): DocumentReference = DocumentReference("$path/${UUID.randomUUID().toString().replace("-", "").take(20)}")
    fun document(id: String): DocumentReference = DocumentReference("$path/$id")
    fun add(data: Map<String, Any?>): Task<DocumentReference> = Task.of {
        val ref = document(); FakeStore.write(ref.path, data, false); FakeStore.notifyAllListeners(); ref
    }
}

class DocumentReference internal constructor(val path: String) {
    val id: String get() = path.substringAfterLast('/')
    val parent: CollectionReference get() = CollectionReference(path.substringBeforeLast('/'))
    fun collection(name: String) = CollectionReference("$path/$name")
    private fun snap() = DocumentSnapshot(this, FakeStore.docs[path]?.let { HashMap(it) })
    fun get(): Task<DocumentSnapshot> = Task.of { snap() }
    fun set(data: Any): Task<Unit> = set(data, null)
    @Suppress("UNCHECKED_CAST")
    fun set(data: Any, options: SetOptions?): Task<Unit> = Task.of {
        FakeStore.write(path, data as Map<String, Any?>, options?.merge == true); FakeStore.notifyAllListeners()
    }
    fun update(data: Map<String, Any?>): Task<Unit> = Task.of { FakeStore.update(path, data); FakeStore.notifyAllListeners() }
    fun update(field: String, value: Any?, vararg more: Any?): Task<Unit> {
        val m = mutableMapOf(field to value)
        more.toList().chunked(2).forEach { m[it[0] as String] = it.getOrNull(1) }
        return update(m)
    }
    fun delete(): Task<Unit> = Task.of { FakeStore.docs.remove(path); FakeStore.notifyAllListeners() }
    fun addSnapshotListener(listener: EventListener<DocumentSnapshot>): ListenerRegistration {
        val fn = { listener.onEvent(snap(), null) }
        FakeStore.listeners += fn
        fn()
        return ListenerRegistration(fn)
    }
    override fun equals(other: Any?) = other is DocumentReference && other.path == path
    override fun hashCode() = path.hashCode()
}

class WriteBatch internal constructor() {
    private val ops = mutableListOf<() -> Unit>()
    fun set(ref: DocumentReference, data: Any): WriteBatch = set(ref, data, null)
    @Suppress("UNCHECKED_CAST")
    fun set(ref: DocumentReference, data: Any, options: SetOptions?): WriteBatch = apply { ops += { FakeStore.write(ref.path, data as Map<String, Any?>, options?.merge == true) } }
    fun update(ref: DocumentReference, data: Map<String, Any?>): WriteBatch = apply { ops += { FakeStore.update(ref.path, data) } }
    fun update(ref: DocumentReference, field: String, value: Any?): WriteBatch = update(ref, mapOf(field to value))
    fun delete(ref: DocumentReference): WriteBatch = apply { ops += { FakeStore.docs.remove(ref.path) } }
    fun commit(): Task<Unit> = Task.of { ops.forEach { it() }; FakeStore.notifyAllListeners() }
}

class Transaction internal constructor() {
    fun interface Function<T> { fun apply(transaction: Transaction): T }
    internal val batch = WriteBatch()
    fun get(ref: DocumentReference): DocumentSnapshot = ref.get().result!!
    fun set(ref: DocumentReference, data: Any): Transaction = apply { batch.set(ref, data) }
    fun set(ref: DocumentReference, data: Any, options: SetOptions): Transaction = apply { batch.set(ref, data, options) }
    fun update(ref: DocumentReference, data: Map<String, Any?>): Transaction = apply { batch.update(ref, data) }
    fun update(ref: DocumentReference, field: String, value: Any?): Transaction = apply { batch.update(ref, field, value) }
    fun delete(ref: DocumentReference): Transaction = apply { batch.delete(ref) }
}

class FirebaseFirestore private constructor() {
    fun collection(path: String) = CollectionReference(path)
    fun document(path: String) = DocumentReference(path)
    fun batch() = WriteBatch()
    fun <T> runTransaction(fn: Transaction.Function<T>): Task<T> = Task.of {
        val tx = Transaction(); val r = fn.apply(tx); tx.batch.commit().result; r
    }
    companion object {
        private val instance = FirebaseFirestore()
        @JvmStatic fun getInstance() = instance
    }
}
