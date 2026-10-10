package androidx.activity.compose

import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

class ManagedActivityResultLauncher<I, O> : ActivityResultLauncher<I>()

@Composable
fun <I, O> rememberLauncherForActivityResult(
    contract: ActivityResultContract<I, O>,
    onResult: (O) -> Unit
): ManagedActivityResultLauncher<I, O> = remember { ManagedActivityResultLauncher() }

@Composable
fun BackHandler(enabled: Boolean = true, onBack: () -> Unit) {}
