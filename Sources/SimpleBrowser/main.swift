import SwiftUI
import WebKit
import AppKit

@main
struct SimpleBrowserApp: App {
    init() {
        // An executable launched from the command line should still become the
        // active application, ready to receive keyboard input.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("Simple Browser") {
            BrowserScreen()
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1100, height: 720)
    }
}

struct BrowserScreen: View {
    @State private var address = "https://www.apple.com"
    @State private var userName = ""
    @State private var message = ""
    @State private var loadedURL = URL(string: "https://www.apple.com")!
    @State private var submittedMessage = ""
    @State private var loadError: String?
    @State private var webView: WKWebView?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
                .background(.bar)

            Divider()

            HSplitView {
                ZStack {
                    BrowserWebView(url: loadedURL) { createdWebView in
                        webView = createdWebView
                    }

                    if let loadError {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                            Text("Couldn't open that address")
                                .font(.headline)
                            Text(loadError)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(28)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(minWidth: 560)

                submissionPane
                    .frame(minWidth: 260, idealWidth: 310, maxWidth: 380)
                    .padding(16)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: { webView?.goBack() }) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .help("Return to the previous page")

                Image(systemName: "globe")
                    .foregroundStyle(.tint)

                NativeTextField(
                    placeholder: "https://example.com",
                    text: $address,
                    onReturn: openAddress
                )

                Button("Open", action: openAddress)
                    .keyboardShortcut(.return, modifiers: .command)
            }

            HStack(spacing: 10) {
                Text("Your name")
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)

                NativeTextField(placeholder: "Enter your name", text: $userName)
            }
        }
    }

    private var submissionPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Message", systemImage: "paperplane")
                .font(.headline)

            Text(userName.isEmpty ? "Write a message to submit." : "Writing as \(userName).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $message)
                .font(.body)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                }
                .frame(minHeight: 150)

            Button(action: submitMessage) {
                Label("Submit", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !submittedMessage.isEmpty {
                Divider()
                Text("Last submission")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(submittedMessage)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            Spacer()
        }
    }

    private func openAddress() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAddress: String

        if trimmedAddress.contains("://") {
            normalizedAddress = trimmedAddress
        } else {
            normalizedAddress = "https://\(trimmedAddress)"
        }

        guard let url = URL(string: normalizedAddress),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            loadError = "Enter a valid http or https web address."
            return
        }

        address = normalizedAddress
        loadError = nil
        loadedURL = url
    }

    private func submitMessage() {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        let sender = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        submittedMessage = sender.isEmpty ? trimmedMessage : "\(sender): \(trimmedMessage)"
        message = ""
    }
}

struct BrowserWebView: NSViewRepresentable {
    let url: URL
    let onWebViewCreated: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        DispatchQueue.main.async {
            onWebViewCreated(webView)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}

/// A direct AppKit-backed input field. It keeps the address and name inputs
/// editable even when the app is launched as a standalone Swift executable.
struct NativeTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onReturn: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
        field.delegate = context.coordinator
        field.focusRingType = .default
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.onReturn = onReturn
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onReturn: (() -> Void)?

        init(text: Binding<String>, onReturn: (() -> Void)?) {
            _text = text
            self.onReturn = onReturn
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onReturn?()
                return true
            }
            return false
        }
    }
}
