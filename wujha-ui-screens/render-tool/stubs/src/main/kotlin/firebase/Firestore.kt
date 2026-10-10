package com.google.firebase

import java.io.Serializable
import java.util.Date

class Timestamp(val seconds: Long, val nanoseconds: Int) : Serializable, Comparable<Timestamp> {
    constructor(date: Date) : this(date.time / 1000, ((date.time % 1000) * 1_000_000).toInt())
    fun toDate(): Date = Date(seconds * 1000 + nanoseconds / 1_000_000)
    override fun compareTo(other: Timestamp): Int = compareValuesBy(this, other, { it.seconds }, { it.nanoseconds })
    companion object { fun now() = Timestamp(Date()) }
}
