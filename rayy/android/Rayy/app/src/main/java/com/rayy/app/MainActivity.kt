package com.rayy.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.ui.LoginScreen
import com.rayy.app.ui.MainScreen
import com.rayy.app.ui.RayyTheme

class MainActivity : ComponentActivity() {

    private val vm: PlantViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            RayyTheme {
                val signedIn by vm.signedIn.collectAsStateWithLifecycle()
                if (signedIn) MainScreen(vm) else LoginScreen(vm)
            }
        }
    }
}
