# Simple Browser

Simple Browser is a minimal native macOS browser window that you can customize for yourself, by yourself, with Codex working behind the scenes. Use the built-in requirements pane to describe a feature; Codex can turn that request into a GitHub Issue and implement it through the repository workflow.

The project relies on GitHub functionality including Issues, Actions, and Releases. To use the customization flow, you need access to the GitHub repository and the command-line GitHub tool (`gh`) authorized to access GitHub on your Mac.

## Run

Open this folder in Xcode and run the `SimpleBrowser` executable target, or run:

```sh
swift run
```

The app accepts `http` and `https` addresses. If a scheme is omitted, it uses `https` automatically.

## Downloadable releases

Push a version tag such as `v1.0.0`, push to any branch named `user/...`, or run the **Build macOS release** workflow manually from GitHub's Actions page. The workflow builds an Apple Silicon macOS app and attaches `SimpleBrowser-macos.zip` to a GitHub Release. Builds from `user/...` branches are prereleases named as `user-version` (for example, `alex-3`), where the version is the number of commits ahead of `main`.

### Download and run

1. Download [SimpleBrowser-macos.zip from v1.0.1](https://github.com/antonogeorge07-lang/BYOB/releases/download/v1.0.1/SimpleBrowser-macos.zip).
2. Double-click the ZIP file in Finder to extract **Simple Browser.app**.
3. Move the app to your Applications folder if you want to keep it there, then double-click it to open.
4. Because this is a hackathon build and is not notarized, macOS may block the first launch. Control-click the app, choose **Open**, then choose **Open** again in the confirmation dialog.

The packaged app's **About Simple Browser** menu item shows the release user and version. Those values are embedded when GitHub Actions builds the release.

The name field starts with the user embedded in the current app release. The app checks GitHub for newer releases for that user every five minutes, and the **Check updates** button beside the name field runs the check immediately. For a local development build, enter a name and it checks releases for that name.

When a newer release is found, the app downloads its ZIP archive in the background and asks whether to switch once it is ready. Choosing **Not now** leaves an **Update now** button beside **Check updates**. Choosing either switch action launches the new app, closes the old instance, and the new instance moves the old app bundle to the Trash after the previous process exits.

Downloads started from a rendered web page are saved to the Mac's Downloads folder. Their status appears in the requirements submission-status area.

## BYOB automation

Address issues in [https://github.com/antonogeorge07-lang/BYOB](https://github.com/antonogeorge07-lang/BYOB)

Handle issues one by another.

Read user name and requirements from the issue. Implement it in a branch which name is `user/` following by the user name. Create such a branch if necessary. Once done, push the branch to GitHub.

Then add a comment to the issue explaining in details what was done.

Finally, mark the issue as closed.

## License

Licensed under the [MIT License](LICENSE). You may use, modify, and redistribute this software, including commercially, provided you retain the copyright and license notices.
