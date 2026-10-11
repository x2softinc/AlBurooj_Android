import SwiftUI
import WebKit

// MARK: - Document catalog

/// Legal documents linked from the Settings "Legal" section.
///
/// `.privacyPolicy` fetches and displays its remote HTML page inside the shared
/// `LegalDocumentView`. `.termsOfUse` is currently presented as an in-app,
/// native `EULAView`; once a hosted page exists, give it a `hostedURLString`
/// below and route the Settings row to `LegalDocumentView` instead.
enum LegalDocument: String, CaseIterable, Identifiable {
    case termsOfUse
    case privacyPolicy

    var id: String { rawValue }

    /// Title shown in the Settings row and the pushed screen's navigation bar.
    var title: String {
        switch self {
        case .termsOfUse:
            return "Terms of Use (EULA)"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }

    var systemImage: String {
        switch self {
        case .termsOfUse:
            return "doc.text.fill"
        case .privacyPolicy:
            return "hand.raised.fill"
        }
    }

    /// Remote HTML page for this document, when hosted online.
    /// `nil` means the document is shown in-app instead.
    var hostedURLString: String? {
        switch self {
        case .termsOfUse:
            return nil
        case .privacyPolicy:
            return LegalDocumentURLs.privacyPolicy
        }
    }
}

// MARK: - Hosted URLs

/// One place to update when the hosted legal pages move.
/// These must be real, publicly reachable (HTTPS) document URLs.
private enum LegalDocumentURLs {
    static let privacyPolicy = "https://x2softinc.com/privacy-policy-al-burooj/"
}

// MARK: - Shared hosted viewer

/// A common viewer that renders the remote HTML content of a hosted legal
/// document inside the app.
///
/// On iOS 26 and later Apple offers a native SwiftUI `WebView` in WebKit; this
/// wrapper intentionally uses `WKWebView` so the viewer also works on every OS
/// version this app deploys to (iOS 17.6+).
struct LegalDocumentView: View {
    let document: LegalDocument

    @State private var isLoading = true
    @State private var didFailToLoad = false
    @State private var retryToken = 0

    var body: some View {
        content
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        if let urlString = document.hostedURLString, let url = URL(string: urlString) {
            if didFailToLoad {
                loadFailedView
            } else {
                LegalDocumentWebView(
                    url: url,
                    onLoadingChange: { isLoading = $0 },
                    onError: { didFailToLoad = true }
                )
                .id(retryToken)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("Document Unavailable", systemImage: "doc.questionmark")
            } description: {
                Text("The document address for \(document.title) has not been configured.")
            }
        }
    }

    private var loadFailedView: some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your internet connection and try again.")
        } actions: {
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("themeColor"))
        }
    }

    private func retry() {
        didFailToLoad = false
        isLoading = true
        retryToken += 1
    }
}

// MARK: - WKWebView bridge

private struct LegalDocumentWebView: UIViewRepresentable {
    let url: URL
    let onLoadingChange: (Bool) -> Void
    let onError: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load only once per web view; `.id(retryToken)` recreates it on retry.
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var parent: LegalDocumentWebView

        init(_ parent: LegalDocumentWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onLoadingChange(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onLoadingChange(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onLoadingChange(false)
            parent.onError()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onLoadingChange(false)
            parent.onError()
        }
    }
}

#Preview {
    NavigationStack {
        LegalDocumentView(document: .privacyPolicy)
    }
}
