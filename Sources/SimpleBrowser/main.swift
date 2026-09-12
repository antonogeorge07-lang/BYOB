import SwiftUI
import WebKit
import AppKit
import Foundation
import Darwin

@main
struct SimpleBrowserApp: App {
    init() {
        // An executable launched from the command line should still become the
        // active application, ready to receive keyboard input.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            UpdateHandoff.removeOldAppAfterPreviousInstanceExitsIfRequested()
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

enum BrowserService: String, CaseIterable, Identifiable {
    case slack = "Slack"
    case googleWorkspace = "Google Workspace"
    case microsoftOffice = "MS Office"
    case news = "News"
    case localWeather = "Local Weather"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case vds = "VDS"
    case copilotKit = "Co-pilot Kit"
    case exa = "EXA"

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .slack: return URL(string: "https://app.slack.com/client")!
        case .googleWorkspace: return URL(string: "https://workspace.google.com")!
        case .microsoftOffice: return URL(string: "https://www.office.com")!
        case .news: return URL(string: "https://news.google.com")!
        case .localWeather: return URL(string: "https://www.google.com/search?q=weather+near+me")!
        case .openAI: return URL(string: "https://chatgpt.com")!
        case .openRouter: return URL(string: "https://openrouter.ai")!
        case .vds: return URL(string: "https://www.google.com/search?q=VDS+hosting")!
        case .copilotKit: return URL(string: "https://copilotkit.ai")!
        case .exa: return URL(string: "https://exa.ai")!
        }
    }
}

struct BrowserTab: Codable, Identifiable {
    let id: UUID
    var url: URL
    var address: String
    var title: String

    init(url: URL, title: String = "New tab") {
        self.id = UUID()
        self.url = url
        self.address = url.absoluteString
        self.title = title
    }
}

private struct BrowserSession: Codable {
    let tabs: [BrowserTab]
    let selectedTabID: UUID
}

private enum BrowserSessionStore {
    private static let key = "browser-session"

    static func load() -> BrowserSession? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let session = try? JSONDecoder().decode(BrowserSession.self, from: data),
              session.tabs.contains(where: { $0.id == session.selectedTabID }) else {
            return nil
        }
        return session
    }

    static func save(tabs: [BrowserTab], selectedTabID: UUID) {
        let session = BrowserSession(tabs: tabs, selectedTabID: selectedTabID)
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct BrowserScreen: View {
    @State private var address = "https://www.apple.com"
    @State private var userName = BuildInfo.user
    @State private var requirements = ""
    @State private var loadedURL = URL(string: "https://www.apple.com")!
    @State private var navigationRequestID = 0
    @State private var submissionStatus = ""
    @State private var availableRelease: GitHubRelease?
    @State private var downloadedUpdate: DownloadedUpdate?
    @State private var isSubmitting = false
    @State private var isCheckingReleases = false
    @State private var isDownloadingUpdate = false
    @State private var isSwitchingToUpdate = false
    @State private var isUpdatePromptPresented = false
    @State private var loadError: String?
    @State private var currentPageContext: PageContext?
    @State private var tabs: [BrowserTab]
    @State private var selectedTabID: UUID

    init() {
        if let session = BrowserSessionStore.load(),
           let selectedTab = session.tabs.first(where: { $0.id == session.selectedTabID }) {
            _tabs = State(initialValue: session.tabs)
            _selectedTabID = State(initialValue: selectedTab.id)
            _address = State(initialValue: selectedTab.address)
            _loadedURL = State(initialValue: selectedTab.url)
        } else {
            let firstTab = BrowserTab(url: URL(string: "https://www.apple.com")!, title: "Apple")
            _tabs = State(initialValue: [firstTab])
            _selectedTabID = State(initialValue: firstTab.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
                .background(.bar)

            Divider()

            HSplitView {
                ZStack {
                    BrowserWebView(
                        url: loadedURL,
                        requestID: navigationRequestID,
                        onDownloadStatus: { downloadStatus in
                            submissionStatus = downloadStatus
                        },
                        onPageContext: { pageContext in
                            currentPageContext = pageContext
                            updateSelectedTab(url: pageContext.url, title: pageContext.title)
                        }
                    )

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
        .alert("Update ready", isPresented: $isUpdatePromptPresented) {
            Button("Switch now") {
                switchToDownloadedUpdate()
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("\(downloadedUpdate?.release.name ?? "The new version") has downloaded. Would you like to switch to it now?")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabBar

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

                Menu {
                    ForEach(BrowserService.allCases) { service in
                        Button(service.rawValue) {
                            openInBrowser(service.url)
                        }
                    }
                } label: {
                    Label("Services", systemImage: "square.grid.2x2")
                }
                .help("Open a connected service in this browser pane")
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

                if downloadedUpdate != nil {
                    Button(isSwitchingToUpdate ? "Switching…" : "Update now") {
                        switchToDownloadedUpdate()
                    }
                    .disabled(isSwitchingToUpdate)
                    .help("Switch to the downloaded version")
                }
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    Button(action: { select(tab) }) {
                        Text(tab.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 150)
                    }
                    .buttonStyle(.bordered)
                    .tint(tab.id == selectedTabID ? .accentColor : .gray)
                    .contextMenu {
                        Button("Close tab") {
                            close(tab)
                        }
                        .disabled(tabs.count == 1)
                    }
                }

                Button(action: addTab) {
                    Image(systemName: "plus")
                }
                .help("Open a new tab")
            }
        }
    }

    private var submissionPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New feature requirements", systemImage: "lightbulb")
                .font(.headline)

            Text("Enter your name above, describe the feature here, then select Submit to get it implemented.")
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
            .keyboardShortcut(.return, modifiers: .shift)
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
        navigationRequestID += 1
        updateSelectedTab(url: url, title: url.host ?? url.absoluteString)
    }

    private func openInBrowser(_ url: URL) {
        address = url.absoluteString
        loadError = nil
        loadedURL = url
        navigationRequestID += 1
        updateSelectedTab(url: url, title: url.host ?? url.absoluteString)
    }

    private func addTab() {
        let tab = BrowserTab(url: URL(string: "https://www.apple.com")!, title: "New tab")
        tabs.append(tab)
        select(tab)
    }

    private func select(_ tab: BrowserTab) {
        selectedTabID = tab.id
        address = tab.address
        loadedURL = tab.url
        loadError = nil
        navigationRequestID += 1
        persistSession()
    }

    private func close(_ tab: BrowserTab) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)

        if selectedTabID == tab.id {
            select(tabs[min(index, tabs.count - 1)])
        } else {
            persistSession()
        }
    }

    private func updateSelectedTab(url: URL, title: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        tabs[index].url = url
        tabs[index].address = url.absoluteString
        tabs[index].title = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? title!
            : (url.host ?? url.absoluteString)
        address = url.absoluteString
        persistSession()
    }

    private func persistSession() {
        BrowserSessionStore.save(tabs: tabs, selectedTabID: selectedTabID)
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
            let newerRelease = releases
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

            availableRelease = newerRelease

            guard let newerRelease,
                  downloadedUpdate?.release.tagName != newerRelease.tagName,
                  !isDownloadingUpdate else {
                return
            }

            await downloadUpdate(newerRelease)
        } catch {
            // A missed network check should not interrupt browsing or issue submission.
        }
    }

    private func downloadUpdate(_ release: GitHubRelease) async {
        isDownloadingUpdate = true
        submissionStatus = "Downloading \(release.name) in the background…"
        defer { isDownloadingUpdate = false }

        do {
            let archiveURL = try await AppUpdateService.downloadArchive(for: release)
            downloadedUpdate = DownloadedUpdate(release: release, archiveURL: archiveURL)
            submissionStatus = "\(release.name) has downloaded and is ready to install."
            isUpdatePromptPresented = true
        } catch {
            submissionStatus = "Couldn’t download \(release.name): \(error.localizedDescription)"
        }
    }

    private func switchToDownloadedUpdate() {
        guard let downloadedUpdate else { return }

        isSwitchingToUpdate = true
        submissionStatus = "Preparing the new version…"

        Task {
            do {
                let newAppURL = try await AppUpdateService.extractApp(from: downloadedUpdate.archiveURL)
                try AppUpdateService.launchReplacement(
                    appURL: newAppURL,
                    oldAppURL: Bundle.main.bundleURL,
                    oldProcessID: ProcessInfo.processInfo.processIdentifier
                )
                await MainActor.run {
                    NSApp.terminate(nil)
                }
            } catch {
                isSwitchingToUpdate = false
                submissionStatus = "Couldn’t switch to the new version: \(error.localizedDescription)"
            }
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
    let tagName: String
    let htmlURL: String
    let assets: [GitHubReleaseAsset]

    var url: URL {
        URL(string: htmlURL)!
    }

    var appArchiveURL: URL? {
        let asset = assets.first { $0.name == "SimpleBrowser-macos.zip" }
            ?? assets.first { $0.name.hasSuffix(".zip") }
        return asset.flatMap { URL(string: $0.browserDownloadURL) }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct DownloadedUpdate {
    let release: GitHubRelease
    let archiveURL: URL
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

enum AppUpdateService {
    static func downloadArchive(for release: GitHubRelease) async throws -> URL {
        guard let archiveURL = release.appArchiveURL else {
            throw UpdateError.missingArchive
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: archiveURL)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw UpdateError.downloadFailed
        }

        let updatesDirectory = try updateStorageDirectory()
        let destination = updatesDirectory.appendingPathComponent("update-\(UUID().uuidString).zip")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func extractApp(from archiveURL: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let destination = try updateStorageDirectory()
                .appendingPathComponent("app-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            let extraction = Process()
            extraction.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            extraction.arguments = ["-x", "-k", archiveURL.path, destination.path]
            try extraction.run()
            extraction.waitUntilExit()

            guard extraction.terminationStatus == 0 else {
                throw UpdateError.extractionFailed
            }

            let appURL = destination.appendingPathComponent("Simple Browser.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                throw UpdateError.extractionFailed
            }
            return appURL
        }.value
    }

    static func launchReplacement(appURL: URL, oldAppURL: URL, oldProcessID: Int32) throws {
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/SimpleBrowser")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw UpdateError.extractionFailed
        }

        let replacement = Process()
        replacement.executableURL = executableURL
        replacement.arguments = [
            "--trash-old-app", oldAppURL.path,
            "--old-process-id", String(oldProcessID)
        ]
        try replacement.run()
    }

    private static func updateStorageDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SimpleBrowser/Updates", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private enum UpdateError: LocalizedError {
        case missingArchive
        case downloadFailed
        case extractionFailed

        var errorDescription: String? {
            switch self {
            case .missingArchive: return "The release has no macOS ZIP archive."
            case .downloadFailed: return "The release download failed."
            case .extractionFailed: return "The downloaded app could not be prepared."
            }
        }
    }
}

enum UpdateHandoff {
    static func removeOldAppAfterPreviousInstanceExitsIfRequested() {
        let arguments = CommandLine.arguments
        guard let appIndex = arguments.firstIndex(of: "--trash-old-app"),
              let pidIndex = arguments.firstIndex(of: "--old-process-id"),
              arguments.indices.contains(appIndex + 1),
              arguments.indices.contains(pidIndex + 1),
              let oldProcessID = Int32(arguments[pidIndex + 1]) else {
            return
        }

        let oldAppURL = URL(fileURLWithPath: arguments[appIndex + 1])
        guard oldAppURL.pathExtension == "app", oldAppURL != Bundle.main.bundleURL else { return }

        DispatchQueue.global(qos: .utility).async {
            for _ in 0..<240 {
                if kill(oldProcessID, 0) == -1, errno == ESRCH {
                    try? FileManager.default.trashItem(at: oldAppURL, resultingItemURL: nil)
                    return
                }
                usleep(250_000)
            }
        }
    }
}

struct PageContext: Equatable {
    let url: URL
    let title: String
    let visibleText: String
    let interactiveElements: [InteractiveElement]
}

struct InteractiveElement: Equatable {
    let tag: String
    let label: String
    let href: String?
    let type: String?
}

enum PageContextExtractor {
    static let script = """
    (() => {
      const textLimit = 6000;
      const elementLimit = 40;
      const visible = element => {
        const style = window.getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
      };
      const labelFor = element =>
        element.getAttribute('aria-label') || element.innerText || element.value || element.placeholder || element.title || '';
      const elements = Array.from(document.querySelectorAll('a, button, input, textarea, select, [role="button"], [contenteditable="true"]'))
        .filter(visible)
        .slice(0, elementLimit)
        .map(element => ({
          tag: element.tagName.toLowerCase(),
          label: labelFor(element).trim().replace(/\\s+/g, ' ').slice(0, 200),
          href: element.href || null,
          type: element.type || null
        }));
      return {
        url: window.location.href,
        title: document.title || '',
        visibleText: (document.body?.innerText || '').trim().replace(/\\s+/g, ' ').slice(0, textLimit),
        interactiveElements: elements
      };
    })();
    """

    static func parse(_ value: Any, fallbackURL: URL) -> PageContext? {
        guard let dictionary = value as? [String: Any] else { return nil }

        let url = (dictionary["url"] as? String).flatMap(URL.init(string:)) ?? fallbackURL
        let title = dictionary["title"] as? String ?? ""
        let visibleText = dictionary["visibleText"] as? String ?? ""
        let elements = (dictionary["interactiveElements"] as? [[String: Any]] ?? []).compactMap { element -> InteractiveElement? in
            guard let tag = element["tag"] as? String else { return nil }
            return InteractiveElement(
                tag: tag,
                label: element["label"] as? String ?? "",
                href: element["href"] as? String,
                type: element["type"] as? String
            )
        }

        return PageContext(url: url, title: title, visibleText: visibleText, interactiveElements: elements)
    }
}

struct BrowserWebView: NSViewRepresentable {
    let url: URL
    let requestID: Int
    let onDownloadStatus: (String) -> Void
    let onPageContext: (PageContext) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDownloadStatus: onDownloadStatus, onPageContext: onPageContext)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        context.coordinator.requestID = requestID
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onDownloadStatus = onDownloadStatus
        context.coordinator.onPageContext = onPageContext
        guard context.coordinator.requestID != requestID else { return }
        context.coordinator.requestID = requestID
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var onDownloadStatus: (String) -> Void
        var onPageContext: (PageContext) -> Void
        var requestID = -1
        private var destinations: [ObjectIdentifier: URL] = [:]

        init(onDownloadStatus: @escaping (String) -> Void, onPageContext: @escaping (PageContext) -> Void) {
            self.onDownloadStatus = onDownloadStatus
            self.onPageContext = onPageContext
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let pageURL = webView.url else { return }
            webView.evaluateJavaScript(PageContextExtractor.script) { [weak self] value, _ in
                guard let context = PageContextExtractor.parse(value as Any, fallbackURL: pageURL) else { return }
                DispatchQueue.main.async {
                    self?.onPageContext(context)
                }
            }
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
