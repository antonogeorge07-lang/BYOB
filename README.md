# Simple Browser

A minimal native macOS browser window with an address field, name field, embedded web page, and a feature-requirements pane. Submitting a requirement opens a GitHub issue in `antonogeorge07-lang/BYOB` using the signed-in GitHub CLI account on the Mac.

## Run

Open this folder in Xcode and run the `SimpleBrowser` executable target, or run:

```sh
swift run
```

The app accepts `http` and `https` addresses. If a scheme is omitted, it uses `https` automatically.

## Downloadable releases

Push a version tag such as `v1.0.0`, push to any branch named `user/...`, or run the **Build macOS release** workflow manually from GitHub's Actions page. The workflow builds an Apple Silicon macOS app and attaches `SimpleBrowser-macos.zip` to a GitHub Release. Builds from `user/...` branches are prereleases named as `user-version` (for example, `alex-3`), where the version is the number of commits ahead of `main`.

The packaged app's **About Simple Browser** menu item shows the release user and version. Those values are embedded when GitHub Actions builds the release.

The app also checks GitHub for newer releases for the embedded user every five minutes, and the **Check updates** button beside the name field runs the check immediately. For a local development build, enter a name and it checks releases for that name. When it finds one, it displays an update link in the requirements submission-status area.

## License

Licensed under the [MIT License](LICENSE). You may use, modify, and redistribute this software, including commercially, provided you retain the copyright and license notices.
