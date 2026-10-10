package com.wujha.admin.data.notify

import android.content.Context

/** Desktop stand-in: notifications are not posted when rendering screenshots. */
object Notifier {
    val permission: String = "android.permission.POST_NOTIFICATIONS"
    fun needsPermission(): Boolean = false
    fun hasPermission(context: Context): Boolean = true
    fun ensureChannel(context: Context) {}
    fun post(context: Context, event: LoanEvent) {}
}
