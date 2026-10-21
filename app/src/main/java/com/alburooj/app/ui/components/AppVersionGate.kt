package com.alburooj.app.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.alburooj.app.services.VersionService

/** Mapped from AppVersionGate.swift: blocks content with an update dialog when a forced update exists. */
@Composable
fun AppVersionGate(storeUrl: String, content: @Composable () -> Unit) {
    val context = LocalContext.current
    var requiresUpdate by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        // On any error (network/decoding), do not block the app (matches the Swift behaviour).
        requiresUpdate = runCatching { VersionService(context).checkVersion() }.getOrDefault(false)
    }

    Box { content() }

    if (requiresUpdate) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text("Update Required") },
            text = { Text("A new version of the app is available and is required to continue.") },
            confirmButton = {
                TextButton(onClick = {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(storeUrl)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }) { Text("Update Now") }
            }
        )
    }
}
