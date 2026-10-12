package com.alburooj.app.ui.screens

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

/** Mapped from LegalDocument in LegalDocumentView.swift. */
enum class LegalDocument(val title: String, val hostedUrl: String?) {
    TermsOfUse("Terms of Use (EULA)", null),
    PrivacyPolicy("Privacy Policy", "https://x2softinc.com/privacy-policy-al-burooj/")
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun LegalDocumentScreen(document: LegalDocument) {
    var isLoading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }
    var retryToken by remember { mutableIntStateOf(0) }
    val url = document.hostedUrl

    when {
        url == null -> Message("Document Unavailable", "The document address for ${document.title} has not been configured.")
        failed -> Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
            Text("Unable to Load")
            Text("Check your internet connection and try again.", Modifier.padding(vertical = 8.dp))
            Button({ failed = false; isLoading = true; retryToken++ }) { Text("Retry") }
        }
        else -> Box(Modifier.fillMaxSize()) {
            key(retryToken) {
                AndroidView(factory = { ctx ->
                    WebView(ctx).apply {
                        webViewClient = object : WebViewClient() {
                            override fun onPageStarted(view: WebView?, u: String?, favicon: Bitmap?) { isLoading = true }
                            override fun onPageFinished(view: WebView?, u: String?) { isLoading = false }
                            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                                if (request?.isForMainFrame == true) { isLoading = false; failed = true }
                            }
                        }
                        loadUrl(url)
                    }
                }, modifier = Modifier.fillMaxSize())
            }
            if (isLoading) CircularProgressIndicator(Modifier.align(Alignment.Center))
        }
    }
}

@Composable
private fun Message(title: String, body: String) {
    Column(Modifier.fillMaxSize().padding(24.dp), Arrangement.Center, Alignment.CenterHorizontally) {
        Text(title); Text(body, Modifier.padding(top = 8.dp))
    }
}
