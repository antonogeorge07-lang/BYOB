# Simple Browser

Simple Browser is a minimal native macOS browser window that you can customize for yourself, by yourself, with Codex working behind the scenes. Use the built-in requirements pane to describe a feature; Codex can turn that request into a GitHub Issue and implement it through the repository workflow.

The project relies on GitHub functionality including Issues, Actions, and Releases. To use the customization flow, you need access to the GitHub repository and the command-line GitHub tool (`gh`) authorized to access GitHub on your Mac.

The **Services** menu opens Slack, Google Workspace, MS Office, News, Local Weather, OpenAI, OpenRouter, VDS hosting search, Co-pilot Kit, and EXA directly in the browser pane.

## Download and run

1. Download [SimpleBrowser-macos.zip from v1.0.1](https://github.com/antonogeorge07-lang/BYOB/releases/download/v1.0.1/SimpleBrowser-macos.zip).
2. Double-click the ZIP file in Finder to extract **Simple Browser.app**.
3. Move the app to your Applications folder if you want to keep it there, then double-click it to open.
4. Because this is a hackathon build and is not notarized, macOS may block the first launch. Control-click the app, choose **Open**, then choose **Open** again in the confirmation dialog.

## BYOB automation

Address issues in [https://github.com/antonogeorge07-lang/BYOB](https://github.com/antonogeorge07-lang/BYOB)

Handle issues one by another.

Read user name and requirements from the issue. Implement it in a branch which name is `user/` following by the user name. Create such a branch if necessary. Once done, push the branch to GitHub.

Then add a comment to the issue explaining in details what was done.

Finally, mark the issue as closed.

## Page context boundary

After each rendered page finishes loading, the app extracts the current URL, title, up to 6,000 characters of visible text, and up to 40 visible interactive elements into Swift-only `PageContext` data. No context is stored or displayed. Run `swift test` to verify the JavaScript-to-Swift parsing boundary.

## License

Licensed under the [MIT License](LICENSE). You may use, modify, and redistribute this software, including commercially, provided you retain the copyright and license notices.
