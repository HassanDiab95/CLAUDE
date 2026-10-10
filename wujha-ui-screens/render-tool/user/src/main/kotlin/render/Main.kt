package render

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.FakeStore
import com.wujha.user.data.DestinationStore
import com.wujha.user.data.Localization
import com.wujha.user.data.PreferencesProvider
import com.wujha.user.data.auth.AuthProviderHolder
import com.wujha.user.data.notify.NotificationStoreProvider
import com.wujha.user.data.repository.AccountProvider
import com.wujha.user.data.repository.BookRepositoryProvider
import com.wujha.user.data.repository.FavoritesProvider
import com.wujha.user.data.repository.LoansProvider
import com.wujha.user.ui.components.WujhaBottomBar
import com.wujha.user.ui.screens.*
import com.wujha.user.ui.theme.CreamBackground
import com.wujha.user.ui.theme.WujhaTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.swing.Swing
import java.io.File

@Composable
private fun AppFrame(tab: String? = null, content: @Composable () -> Unit) {
    WujhaTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            Scaffold(bottomBar = { if (tab != null) WujhaBottomBar(currentRoute = tab) {} }) { p ->
                Box(Modifier.padding(p)) { content() }
            }
        }
    }
}

fun main(args: Array<String>) { runBlocking(Dispatchers.Swing) { run(args) }; kotlin.system.exitProcess(0) }

private suspend fun run(args: Array<String>) {
    Shot.outDir = File(args[0])
    com.wujha.user.R.drawable.register()
    val ctx = Context.shared
    AuthProviderHolder.init(); BookRepositoryProvider.init(); FavoritesProvider.init()
    AccountProvider.init(); LoansProvider.init()
    PreferencesProvider.init(ctx); NotificationStoreProvider.init(ctx); Localization.init(ctx)
    val repo = BookRepositoryProvider.repository
    val bg = CreamBackground

    Shot.shot("01_splash", bg) { AppFrame { SplashScreen(onFinished = {}) } }
    Shot.shot("02_login", bg) { AppFrame { LoginScreen(onSignedIn = {}, onNavigateToSignUp = {}) } }
    Shot.shot("03_signup", bg) { AppFrame { SignUpScreen(onSignedUp = {}, onBackToLogin = {}) } }

    // The library the admin app seeded, with the book photos attached.
    FakeStore.load(File(args[1]))
    val uid = "visitor-noura"
    val name = "نورة سعد القحطاني"
    // Give this visitor a request, a held copy, a running loan and a returned one.
    val loans = FakeStore.docs.filterKeys { it.startsWith("loans/") }.values
    listOf("REQUESTED", "APPROVED", "ACTIVE", "RETURNED").forEach { st ->
        loans.firstOrNull { it["status"] == st }?.let { it["requesterUid"] = uid; it["memberName"] = name }
    }
    listOf("b_clean_code", "b_gene", "b_mawsim", "b_atomic").forEach {
        FakeStore.docs["users/$uid/favorites/$it"] = mutableMapOf("addedAt" to com.google.firebase.Timestamp.now())
    }
    FirebaseAuth.getInstance().fakeSignIn(FirebaseUser(uid, name, "noura@example.com", false))
    delay(800)
    println("books=${repo.books.value.size} loans=${LoansProvider.repository.myLoans.value.size}")

    Shot.shot("04_home", bg) { AppFrame("home") { HomeScreen(repository = repo, onBookClick = {}, onCategoryClick = {}, onOpenSearch = {}, onOpenAccount = {}, onOpenNotifications = {}) } }
    Shot.shot("05_search_all", bg) { AppFrame("search") { SearchScreen(repository = repo, onBookClick = {}, initialCategoryId = null) } }
    Shot.shot("06_search_category", bg) { AppFrame("search") { SearchScreen(repository = repo, onBookClick = {}, initialCategoryId = "science") } }
    Shot.shot("07_favorites", bg) { AppFrame("favorites") { FavoritesScreen(repository = repo, onBookClick = {}) } }
    Shot.shot("08_book_detail", bg) { AppFrame { BookDetailScreen(bookId = "b_gene", repository = repo, onBack = {}, onLocateBook = {}, onSimilarBookClick = {}, onBorrow = {}, onOpenMyLoans = {}) } }
    Shot.shot("09_navigation_no_destination", bg) { AppFrame("navigation") { NavigationMapScreen(repository = repo, onBack = {}, onSearch = {}) } }
    DestinationStore.set("b_clean_code")
    Shot.shot("10_navigation_route_to_book", bg) { AppFrame("navigation") { NavigationMapScreen(repository = repo, onBack = {}, onSearch = {}) } }
    Shot.shot("11_borrow_request", bg) { AppFrame { BorrowRequestScreen(bookId = "b_origin", repository = repo, onBack = {}, onSent = {}) } }
    Shot.shot("12_my_loans", bg) { AppFrame { MyLoansScreen(onBack = {}, onOpenBook = {}) } }
    Shot.shot("13_account", bg) { AppFrame("account") { AccountScreen(onSignedOut = {}, onOpenFavorites = {}, onOpen = {}) } }
    Shot.shot("14_notifications", bg) { AppFrame { NotificationsScreen(onBack = {}, onOpenLoans = {}, onOpenSettings = {}) } }
    Shot.shot("15_notification_settings", bg) { AppFrame { UserNotificationSettingsScreen(onBack = {}) } }
    Shot.shot("16_language", bg) { AppFrame { LanguageScreen(onBack = {}) } }
    Shot.shot("17_help", bg) { AppFrame { UserHelpScreen(onBack = {}) } }
    Shot.shot("18_about", bg) { AppFrame { AboutScreen(onBack = {}) } }
}
