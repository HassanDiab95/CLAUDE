# Wujha (وِجهة) UI/UX screenshots

PNG renders of every screen in the two Android apps from `wujha-final`. Each image is 1080×2400 (360×800 dp at 3×), in Arabic, right-to-left.

- `user-app/`: 18 screens of the visitor app (`com.wujha.user`)
- `admin-app/`: 27 screens of the librarian app (`com.wujha.admin`)
- `overview-user-app.png`, `overview-admin-app.png`: every screen of each app on one sheet
- `wujha-ui-screens.zip`: both folders and the overview sheets in one download

## User app
| File | Screen |
|---|---|
| 01_splash | Splash |
| 02_login | Sign in (email, Google, guest) |
| 03_signup | Create account |
| 04_home | Home: search, suggestions, categories |
| 05_search_all | Search, all categories |
| 06_search_category | Search, filtered to Science |
| 07_favorites | Favorites |
| 08_book_detail | Book detail: location and borrowing |
| 09_navigation_no_destination | Navigation tab with no book chosen (floor map) |
| 10_navigation_route_to_book | Route from the entrance to the book's shelf |
| 11_borrow_request | Borrow request form |
| 12_my_loans | My loans: request, held copy, active, history |
| 13_account | Account / profile |
| 14_notifications | Notifications |
| 15_notification_settings | Notification settings |
| 16_language | Language |
| 17_help | Help and support |
| 18_about | About |

## Admin app
| File | Screen |
|---|---|
| 01_splash | Splash |
| 02_login | Admin sign in |
| 03_signup | Admin sign up |
| 04_dashboard | Dashboard |
| 05_books | Manage books |
| 06_book_detail | Book detail |
| 07_book_form_new | Add a book |
| 08_book_form_edit | Edit a book |
| 09_loans | Loans list |
| 10_loan_detail_request | Loan detail: pending request with ID review |
| 11_loan_detail_active | Loan detail: active loan with a renewal request |
| 12_new_loan | New desk loan |
| 13_members | Manage members |
| 14_settings | Settings |
| 15_library_map | Library map |
| 16_reports | Reports and statistics |
| 17_locations_floors | Manage locations: floors |
| 18_floor_editor | Floor editor: blocks and aisles |
| 19_shelves | Manage shelves |
| 20_categories | Manage categories |
| 21_loan_settings | Loan settings |
| 22_admins_permissions | Admins and permissions |
| 23_notification_settings | Notification settings |
| 24_backup | Backup / export |
| 25_activity_log | Activity log |
| 26_language | Language |
| 27_help | Help |

## How these were made
The screens come from the apps' own Jetpack Compose code, compiled unchanged for Compose Desktop. Each one is rendered off-screen with `ImageComposeScene`. Firebase Auth and Firestore are replaced by an in-memory fake, so the apps' real repository code runs against data instead of a live project. That data is the admin app's built-in `SeedData` (4 floors, 50 shelves, 61 books, sample loans and members). The supplied book photos are attached as covers, matched by serial number (WJ-xxxx).

Some differences from a device:
- The status bar is drawn by the renderer.
- Fonts are Roboto with Noto Naskh Arabic UI, the Android defaults.
- Each PNG shows the first viewport of its screen. Long screens continue further down when scrolled.

`render-tool/` has the Gradle project that produced the images. It expects the app sources at `../src/wujha-final`. Run `gradle :admin:run --args="<out> <covers dir> <db file>"` first, then `gradle :user:run --args="<out> <db file>"`.
