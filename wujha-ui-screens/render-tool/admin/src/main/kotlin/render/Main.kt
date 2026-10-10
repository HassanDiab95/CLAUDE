package render

import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.google.firebase.firestore.FakeStore
import com.wujha.admin.data.Localization
import com.wujha.admin.data.PreferencesProvider
import com.wujha.admin.data.auth.AuthProviderHolder
import com.wujha.admin.data.notify.NotificationStoreProvider
import com.wujha.admin.data.repository.AccountProvider
import com.wujha.admin.data.repository.LibraryRepositoryProvider
import com.wujha.admin.data.repository.SetupState
import com.wujha.admin.ui.components.AdminBottomBar
import com.wujha.admin.ui.screens.*
import com.wujha.admin.ui.theme.CreamBackground
import com.wujha.admin.ui.theme.WujhaTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.swing.Swing
import kotlinx.coroutines.Dispatchers
import java.io.File

@Composable
private fun AppFrame(tab: String? = null, content: @Composable () -> Unit) {
    WujhaTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            Scaffold(bottomBar = { if (tab != null) AdminBottomBar(currentRoute = tab) {} }) { p ->
                Box(Modifier.padding(p)) { content() }
            }
        }
    }
}

fun main(args: Array<String>) { runBlocking(Dispatchers.Swing) { run(args) }; kotlin.system.exitProcess(0) }

private suspend fun run(args: Array<String>) {
    Shot.outDir = File(args[0])
    val coversDir = File(args[1])
    val dbFile = File(args[2])
    com.wujha.admin.R.drawable.register()
    val ctx = Context.shared
    AuthProviderHolder.init(); LibraryRepositoryProvider.init(); AccountProvider.init()
    PreferencesProvider.init(ctx); NotificationStoreProvider.init(ctx); Localization.init(ctx)
    val repo = LibraryRepositoryProvider.repository
    val bg = CreamBackground

    // Signed out
    Shot.shot("01_splash", bg) { AppFrame { SplashScreen(onFinished = {}) } }
    Shot.shot("02_login", bg) { AppFrame { LoginScreen(onSignedIn = {}, onNavigateToSignUp = {}) } }
    Shot.shot("03_signup", bg) { AppFrame { SignUpScreen(onSignedUp = {}, onBackToLogin = {}) } }

    // The first account claims the empty library and the app seeds it.
    AuthProviderHolder.repository.signUpWithEmail("أمين المكتبة", "librarian@wujha.sa", "secret123")
    var waited = 0
    while (waited < 200 && !(repo.setup.value == SetupState.Idle && FakeStore.docs.keys.any { it.startsWith("books/") })) {
        delay(100); waited++
    }
    delay(500)
    println("seeded docs: ${FakeStore.docs.size}, setup=${repo.setup.value}")
    Shot.attachCovers(coversDir)
    FakeStore.save(dbFile)
    delay(300)

    Shot.shot("04_dashboard", bg) { AppFrame("home") { DashboardScreen(repository = repo, onOpenMap = {}, onOpenReports = {}, onOpenBooks = {}, onOpenLoans = {}) } }
    Shot.shot("05_books", bg) { AppFrame("books") { ManageBooksScreen(repository = repo, onBookClick = {}, onAddBook = {}) } }
    Shot.shot("06_book_detail", bg) { AppFrame { BookDetailScreen(bookId = "b_clean_code", repository = repo, onBack = {}, onEdit = {}, onDeleted = {}, onLendBook = {}, onOpenLoan = {}) } }
    Shot.shot("07_book_form_new", bg) { AppFrame { BookFormScreen(bookId = null, repository = repo, onDone = {}, onBack = {}) } }
    Shot.shot("08_book_form_edit", bg) { AppFrame { BookFormScreen(bookId = "b_gene", repository = repo, onDone = {}, onBack = {}) } }
    Shot.shot("09_loans", bg) { AppFrame("loans") { LoansScreen(repository = repo, onOpenLoan = {}, onNewLoan = {}) } }
    Shot.shot("10_loan_detail_request", bg) { AppFrame { LoanDetailScreen(loanId = "l01", repository = repo, onBack = {}) } }
    Shot.shot("11_loan_detail_active", bg) { AppFrame { LoanDetailScreen(loanId = "l03", repository = repo, onBack = {}) } }
    Shot.shot("12_new_loan", bg) { AppFrame { NewLoanScreen(repository = repo, onBack = {}, onDone = {}, initialMemberId = "", initialBookId = "") } }
    Shot.shot("13_members", bg) { AppFrame("users") { ManageUsersScreen(repository = repo, onOpenLoan = {}, onLendTo = {}) } }
    Shot.shot("14_settings", bg) { AppFrame("settings") { SettingsScreen(repository = repo, onOpen = {}, onSignedOut = {}) } }
    Shot.shot("15_library_map", bg) { AppFrame { LibraryMapScreen(repository = repo, onBack = {}) } }
    Shot.shot("16_reports", bg) { AppFrame { ReportsScreen(repository = repo, onBack = {}) } }
    Shot.shot("17_locations_floors", bg) { AppFrame { ManageFloorsScreen(repository = repo, onBack = {}, onOpenFloor = {}) } }
    Shot.shot("18_floor_editor", bg) { AppFrame { FloorEditorScreen(floorId = "ground", repository = repo, onBack = {}) } }
    Shot.shot("19_shelves", bg) { AppFrame { ManageShelvesScreen(repository = repo, onBack = {}) } }
    Shot.shot("20_categories", bg) { AppFrame { ManageCategoriesScreen(repository = repo, onBack = {}) } }
    Shot.shot("21_loan_settings", bg) { AppFrame { LoanSettingsScreen(repository = repo, onBack = {}) } }
    Shot.shot("22_admins_permissions", bg) { AppFrame { ManageAdminsScreen(repository = repo, onBack = {}) } }
    Shot.shot("23_notification_settings", bg) { AppFrame { NotificationSettingsScreen(onBack = {}) } }
    Shot.shot("24_backup", bg) { AppFrame { BackupScreen(repository = repo, onBack = {}) } }
    Shot.shot("25_activity_log", bg) { AppFrame { ActivityLogScreen(repository = repo, onBack = {}) } }
    Shot.shot("26_language", bg) { AppFrame { LanguageScreen(onBack = {}) } }
    Shot.shot("27_help", bg) { AppFrame { HelpScreen(onBack = {}) } }
}
