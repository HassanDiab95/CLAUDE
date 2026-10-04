package com.smartplant.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.smartplant.app.ui.LoginScreen
import com.smartplant.app.ui.MainScreen
import com.smartplant.app.ui.SmartPlantTheme

class MainActivity : ComponentActivity() {

    private val vm: PlantViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SmartPlantTheme {
                val signedIn by vm.signedIn.collectAsStateWithLifecycle()
                if (signedIn) MainScreen(vm) else LoginScreen(vm)
            }
        }
    }
}
