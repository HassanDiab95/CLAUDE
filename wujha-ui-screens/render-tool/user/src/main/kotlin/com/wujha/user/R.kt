package com.wujha.user

import androidx.compose.ui.res.DrawableRegistry

object R {
    object drawable {
        const val library_background = 1
        const val wujha_lockup = 2
        const val wujha_mark = 3
        const val ic_notification = 4
        const val splash_icon = 5
        fun register() {
            DrawableRegistry.paths[library_background] = "drawable-nodpi/library_background.jpg"
            DrawableRegistry.paths[wujha_lockup] = "drawable-nodpi/wujha_lockup.png"
            DrawableRegistry.paths[wujha_mark] = "drawable-nodpi/wujha_mark.png"
            DrawableRegistry.paths[splash_icon] = "drawable-nodpi/splash_icon.png"
        }
    }
}
