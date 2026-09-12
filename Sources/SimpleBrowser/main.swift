import SwiftUI
import WebKit
import AppKit
import Foundation

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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Simple Browser") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Simple Browser",
                        .applicationVersion: "\(BuildInfo.user)-\(BuildInfo.version)"
                    ])
                }
            }
        }
    }
}

enum BuildInfo {
    static let user = Bundle.main.object(forInfoDictionaryKey: "BuildUser") as? String ?? "local"
    static let version = Bundle.main.object(forInfoDictionaryKey: "BuildVersion") as? String ?? "0"
}

struct BrowserScreen: View {
    @State private var address = "https://www.apple.com"
    @State private var userName = ""
    @State private var requirements = ""
    @State private var loadedURL = URL(string: "https://www.apple.com")!
    @State private var submissionStatus = ""
    @State private var availableRelease: GitHubRelease?
    @State private var isSubmitting = false
    @State private var isCheckingReleases = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
                .background(.bar)

            Divider()

            HSplitView {
                ZStack {
                    BrowserWebView(url: loadedURL) { downloadStatus in
                        submissionStatus = downloadStatus
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
        .task {
            await watchForReleaseUpdates()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
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

                Button(isCheckingReleases ? "Checking…" : "Check updates") {
                    Task {
                        isCheckingReleases = true
                        await checkForReleaseUpdate(showMissingUserMessage: true)
                        isCheckingReleases = false
                    }
                }
                .disabled(isCheckingReleases)
                .help("Check GitHub for a newer release for this app user")
            }
        }
    }

    private var submissionPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New feature requirements", systemImage: "lightbulb")
                .font(.headline)

            Text("Enter your name above, describe the feature here, and Submit will create an issue in this repository.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $requirements)
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
                Label(isSubmitting ? "Creating issue…" : "Submit", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !submissionStatus.isEmpty {
                Divider()
                Text("Submission status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(submissionStatus)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            if let availableRelease {
                Divider()
                Text("Release update")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("A newer version is available: \(availableRelease.name)")
                    .font(.subheadline)
                Button("Open release") {
                    openInBrowser(availableRelease.url)
                }
                    .font(.subheadline)
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

    private func openInBrowser(_ url: URL) {
        address = url.absoluteString
        loadError = nil
        loadedURL = url
    }

    private func submitMessage() {
        let requester = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRequirements = requirements.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requester.isEmpty, !trimmedRequirements.isEmpty else { return }

        isSubmitting = true
        submissionStatus = "Creating GitHub issue…"

        Task {
            do {
                let issueURL = try await GitHubIssueService.createIssue(
                    requester: requester,
                    requirements: trimmedRequirements
                )
                requirements = ""
                submissionStatus = "Issue created: \(issueURL.absoluteString)"
            } catch {
                submissionStatus = "Couldn’t create the issue: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    private func watchForReleaseUpdates() async {
        while !Task.isCancelled {
            await checkForReleaseUpdate()
            try? await Task.sleep(nanoseconds: 300_000_000_000)
        }
    }

    private func checkForReleaseUpdate(showMissingUserMessage: Bool = false) async {
        let releaseUser = BuildInfo.user == "local"
            ? userName.trimmingCharacters(in: .whitespacesAndNewlines)
            : BuildInfo.user

        guard !releaseUser.isEmpty else {
            if showMissingUserMessage {
                submissionStatus = "Enter your name to check release updates."
            }
            return
        }

        guard let currentVersion = Int(BuildInfo.version) else {
            return
        }

        do {
            let releases = try await GitHubReleaseService.fetchReleases()
            let releasePrefix = "Simple Browser — \(releaseUser)-"
            availableRelease = releases
                .compactMap { release -> (GitHubRelease, Int)? in
                    guard release.name.hasPrefix(releasePrefix),
                          let version = Int(release.name.dropFirst(releasePrefix.count)),
                          version > currentVersion else {
                        return nil
                    }
                    return (release, version)
                }
                .max { $0.1 < $1.1 }?
                .0
        } catch {
            // A missed network check should not interrupt browsing or issue submission.
        }
    }
}

enum GitHubIssueService {
    private static let repository = "antonogeorge07-lang/BYOB"

    static func createIssue(requester: String, requirements: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let title = "Feature request from \(requester)"
            let body = "## Requested by\n\(requester)\n\n## Requirements\n\(requirements)"
            let payload = try JSONEncoder().encode(["title": title, "body": body])

            let process = Process()
            process.executableURL = githubCLIURL()
            process.arguments = [
                "api", "repos/\(repository)/issues",
                "--method", "POST",
                "--input", "-"
            ]

            let input = Pipe()
            let output = Pipe()
            let error = Pipe()
            process.standardInput = input
            process.standardOutput = output
            process.standardError = error

            try process.run()
            input.fileHandleForWriting.write(payload)
            input.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            let outputData = output.fileHandleForReading.readDataToEndOfFile()
            let errorData = error.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                throw IssueCreationError.failed(message?.isEmpty == false ? message! : "GitHub CLI exited with status \(process.terminationStatus).")
            }

            let response = try JSONDecoder().decode(GitHubIssueResponse.self, from: outputData)
            guard let url = URL(string: response.htmlURL) else {
                throw IssueCreationError.failed("GitHub returned an invalid issue URL.")
            }
            return url
        }.value
    }

    private static func githubCLIURL() -> URL {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: "/usr/bin/env")
    }

    private struct GitHubIssueResponse: Decodable {
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case htmlURL = "html_url"
        }
    }

    private enum IssueCreationError: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .failed(let message): return message
            }
        }
    }
}

struct GitHubRelease: Decodable {
    let name: String
    let htmlURL: String

    var url: URL {
        URL(string: htmlURL)!
    }

    enum CodingKeys: String, CodingKey {
        case name
        case htmlURL = "html_url"
    }
}

enum GitHubReleaseService {
    private static let releasesURL = URL(string: "https://api.github.com/repos/antonogeorge07-lang/BYOB/releases")!

    static func fetchReleases() async throws -> [GitHubRelease] {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SimpleBrowser", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw ReleaseLookupError.unavailable
        }
        return try JSONDecoder().decode([GitHubRelease].self, from: data)
    }

    private enum ReleaseLookupError: Error {
        case unavailable
    }
}

struct BrowserWebView: NSViewRepresentable {
    let url: URL
    let onDownloadStatus: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDownloadStatus: onDownloadStatus)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onDownloadStatus = onDownloadStatus
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var onDownloadStatus: (String) -> Void
        private var destinations: [ObjectIdentifier: URL] = [:]

        init(onDownloadStatus: @escaping (String) -> Void) {
            self.onDownloadStatus = onDownloadStatus
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            prepare(download)
        }

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            prepare(download)
        }

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let destination = uniqueDownloadsURL(for: suggestedFilename)
            destinations[ObjectIdentifier(download)] = destination
            report("Downloading \(suggestedFilename)…")
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            let destination = destinations.removeValue(forKey: ObjectIdentifier(download))
            let fileName = destination?.lastPathComponent ?? "file"
            report("Downloaded \(fileName) to your Downloads folder.")
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            destinations.removeValue(forKey: ObjectIdentifier(download))
            report("Download failed: \(error.localizedDescription)")
        }

        private func prepare(_ download: WKDownload) {
            download.delegate = self
            report("Preparing download…")
        }

        private func uniqueDownloadsURL(for filename: String) -> URL {
            let fileManager = FileManager.default
            let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            let originalURL = downloadsDirectory.appendingPathComponent(filename)

            guard fileManager.fileExists(atPath: originalURL.path) else { return originalURL }

            let baseName = originalURL.deletingPathExtension().lastPathComponent
            let fileExtension = originalURL.pathExtension
            var copyIndex = 2
            var candidate = originalURL

            while fileManager.fileExists(atPath: candidate.path) {
                let copyName = "\(baseName) \(copyIndex)"
                candidate = downloadsDirectory
                    .appendingPathComponent(copyName)
                    .appendingPathExtension(fileExtension)
                copyIndex += 1
            }
            return candidate
        }

        private func report(_ message: String) {
            DispatchQueue.main.async {
                self.onDownloadStatus(message)
            }
        }
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
