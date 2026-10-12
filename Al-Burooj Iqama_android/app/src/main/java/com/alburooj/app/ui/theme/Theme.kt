package com.alburooj.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** "themeColor" asset (maroon) from the SwiftUI project; maroonColor = 0x800000. */
val ThemeColor = Color(0xFF7D2722)
val MaroonColor = Color(0xFF800000)

private val Scheme = lightColorScheme(
    primary = ThemeColor,
    onPrimary = Color.White,
    secondary = MaroonColor
)

@Composable
fun AlBuroojTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Scheme, content = content)
}
