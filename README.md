# Simple Browser

A minimal native macOS browser window with an address field, name field, embedded web page, and a feature-requirements pane. Submitting a requirement opens a GitHub issue in `antonogeorge07-lang/BYOB` using the signed-in GitHub CLI account on the Mac.

## Run

Open this folder in Xcode and run the `SimpleBrowser` executable target, or run:

```sh
swift run
```

The app accepts `http` and `https` addresses. If a scheme is omitted, it uses `https` automatically.

## Downloadable releases

Push a version tag such as `v1.0.0`, push to any branch named `user/...`, or run the **Build macOS release** workflow manually from GitHub's Actions page. The workflow builds an Apple Silicon macOS app and attaches `SimpleBrowser-macos.zip` to a GitHub Release. Builds from `user/...` branches are prereleases named after the user (the part after `user/`) and their version number is the number of commits ahead of `main`.
