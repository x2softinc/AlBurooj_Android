package com.alburooj.app.ui.components

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import com.alburooj.app.data.network.RecoveryAction
import com.alburooj.app.data.network.UserFriendlyError
import kotlinx.coroutines.launch

/** Compose equivalent of View.userFriendlyAlert(error:). */
@Composable
fun UserFriendlyAlert(error: UserFriendlyError?, onDismiss: () -> Unit) {
    if (error == null) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val action = error.recoveryAction

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(error.title) },
        text = { Text(error.message) },
        confirmButton = {
            TextButton(onClick = {
                when (action) {
                    is RecoveryAction.Retry -> scope.launch { action.action(); onDismiss() }
                    RecoveryAction.OpenSettings -> { openAppSettings(context); onDismiss() }
                    RecoveryAction.Contact -> { openSupportMail(context); onDismiss() }
                    else -> onDismiss()
                }
            }) { Text(action?.buttonTitle ?: "OK") }
        },
        dismissButton = {
            if (action != null && action != RecoveryAction.None) {
                TextButton(onClick = onDismiss) { Text("Dismiss") }
            }
        }
    )
}

private fun openAppSettings(context: Context) {
    context.startActivity(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
}

private fun openSupportMail(context: Context) {
    context.startActivity(
        Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:support@alburoojiqama.com")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
}
