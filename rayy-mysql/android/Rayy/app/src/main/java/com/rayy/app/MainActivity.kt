package com.rayy.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rayy.app.ui.AppScreen
import com.rayy.app.ui.LoginScreen
import com.rayy.app.ui.RayyTheme

class MainActivity : ComponentActivity() {

    private val vm: RayyViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            RayyTheme {
                val user by vm.user.collectAsStateWithLifecycle()
                val starting by vm.starting.collectAsStateWithLifecycle()
                val u = user
                when {
                    starting -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                    u == null -> LoginScreen(vm)
                    else -> AppScreen(vm, u)
                }
            }
        }
    }
}
