package com.google.firebase.auth

import com.google.android.gms.tasks.Task

open class FirebaseAuthException(message: String) : Exception(message)
class FirebaseAuthInvalidCredentialsException(m: String) : FirebaseAuthException(m)
class FirebaseAuthInvalidUserException(m: String) : FirebaseAuthException(m)
class FirebaseAuthUserCollisionException(m: String) : FirebaseAuthException(m)
class FirebaseAuthWeakPasswordException(m: String) : FirebaseAuthException(m)

interface UserInfo { val providerId: String }
open class AuthCredential(val provider: String)
object GoogleAuthProvider { fun getCredential(idToken: String?, accessToken: String?) = AuthCredential("google.com") }
class AuthResult(val user: FirebaseUser?)

class UserProfileChangeRequest private constructor(val displayName: String?) {
    class Builder { private var name: String? = null; fun setDisplayName(n: String?) = apply { name = n }; fun build() = UserProfileChangeRequest(name) }
}

class FirebaseUser(
    val uid: String,
    var displayName: String?,
    val email: String?,
    val isAnonymous: Boolean,
    provider: String = "password",
) {
    val providerData: List<UserInfo> = listOf(object : UserInfo { override val providerId = provider })
    val photoUrl: Any? = null
    fun updateProfile(req: UserProfileChangeRequest): Task<Unit> = Task.of { displayName = req.displayName; FirebaseAuth.getInstance().fire() }
}


class FirebaseAuth private constructor() {
    fun interface AuthStateListener { fun onAuthStateChanged(auth: FirebaseAuth) }
    var currentUser: FirebaseUser? = null
        private set
    private val listeners = mutableListOf<AuthStateListener>()

    fun addAuthStateListener(l: AuthStateListener) { listeners += l; l.onAuthStateChanged(this) }
    fun removeAuthStateListener(l: AuthStateListener) { listeners -= l }
    internal fun fire() = listeners.toList().forEach { it.onAuthStateChanged(this) }

    /** Test hook: sign a user in without going through a screen. */
    fun fakeSignIn(user: FirebaseUser?) { currentUser = user; fire() }

    private fun signIn(u: FirebaseUser): Task<AuthResult> = Task.of { currentUser = u; fire(); AuthResult(u) }
    fun signInWithEmailAndPassword(email: String, password: String) =
        signIn(FirebaseUser("uid-" + email.hashCode().toUInt(), null, email, false))
    fun createUserWithEmailAndPassword(email: String, password: String) = signInWithEmailAndPassword(email, password)
    fun signInAnonymously() = signIn(FirebaseUser("anon", null, null, true, "firebase"))
    fun signInWithCredential(c: AuthCredential) = signIn(FirebaseUser("google-user", "Google User", "user@gmail.com", false, c.provider))
    fun sendPasswordResetEmail(email: String): Task<Unit> = Task.of { }
    fun signOut() { currentUser = null; fire() }

    companion object {
        private val instance = FirebaseAuth()
        @JvmStatic fun getInstance() = instance
    }
}
