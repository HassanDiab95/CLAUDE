package com.rayy.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.R
import com.rayy.app.RayyViewModel

/** Sign in, or create a new account (role "user") */
@Composable
fun LoginScreen(vm: RayyViewModel) {
    val busy by vm.busy.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()
    LoginContent(busy, error, vm::signIn, vm::register, vm::clearMessages)
}

@Composable
fun LoginContent(
    busy: Boolean,
    error: String?,
    onSignIn: (String, String) -> Unit,
    onRegister: (String, String, String) -> Unit,
    onModeChange: () -> Unit,
) {
    var mode by rememberSaveable { mutableIntStateOf(0) }          // 0 = sign in, 1 = create account
    var name by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    val register = mode == 1

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Leaf900, Leaf700, Leaf500, MaterialTheme.colorScheme.background))),
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().imePadding().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(28.dp))
            Box(
                Modifier.size(112.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.16f)),
                contentAlignment = Alignment.Center,
            ) { FloatingEmoji("🌱", fontSize = 64) }
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.app_name), color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold)
            Text(
                stringResource(R.string.tagline), color = Color.White.copy(alpha = 0.9f),
                style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
            )
            Text("🍓  🍅  🌿  🌵  🌴", fontSize = 22.sp, modifier = Modifier.padding(top = 4.dp, bottom = 20.dp))

            Card(
                Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.extraLarge,
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
            ) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Segmented(
                        listOf(stringResource(R.string.sign_in), stringResource(R.string.create_account)), mode,
                        { mode = it; onModeChange() },
                    )
                    Text(
                        stringResource(if (register) R.string.welcome_new else R.string.welcome_back),
                        style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 4.dp),
                    )
                    AnimatedVisibility(register) {
                        Field(stringResource(R.string.full_name), name, { name = it }, icon = Icons.Filled.Person)
                    }
                    Field(stringResource(R.string.email), email, { email = it }, keyboard = KeyboardType.Email, icon = Icons.Filled.Email)
                    Field(stringResource(R.string.password), password, { password = it }, keyboard = KeyboardType.Password,
                        password = true, icon = Icons.Filled.Lock)
                    if (register) Text(stringResource(R.string.password_hint), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (error != null) Text(
                        "⚠️  $error", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.fillMaxWidth().clip(MaterialTheme.shapes.small)
                            .background(MaterialTheme.colorScheme.error.copy(alpha = 0.08f)).padding(10.dp),
                    )
                    Button(
                        onClick = { if (register) onRegister(name, email, password) else onSignIn(email, password) },
                        enabled = !busy && email.isNotBlank() && password.isNotBlank() && (!register || name.isNotBlank()),
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                        shape = MaterialTheme.shapes.medium,
                    ) {
                        if (busy) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp, color = Color.White)
                        else Text(stringResource(if (register) R.string.create_account else R.string.sign_in), fontSize = 17.sp)
                    }
                }
            }
            Text(
                stringResource(R.string.footer), color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 20.dp),
            )
        }
    }
}
