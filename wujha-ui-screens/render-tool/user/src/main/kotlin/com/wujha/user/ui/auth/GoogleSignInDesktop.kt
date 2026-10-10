package com.wujha.user.ui.auth

import android.content.Context
import androidx.compose.runtime.Composable

data class GoogleSignInOutcome(
    val idToken: String?,
    val displayName: String,
    val email: String,
    val errorMessage: String?
)

@Composable
fun rememberGoogleSignIn(onOutcome: (GoogleSignInOutcome) -> Unit): () -> Unit = {}

fun clearGoogleSession(context: Context) {}
