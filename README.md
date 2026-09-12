# Simple Browser

A minimal native macOS browser window with an address field, name field, embedded web page, and a feature-requirements pane. Submitting a requirement opens a GitHub issue in `antonogeorge07-lang/BYOB` using the signed-in GitHub CLI account on the Mac.

## Run

Open this folder in Xcode and run the `SimpleBrowser` executable target, or run:

```sh
swift run
```

The app accepts `http` and `https` addresses. If a scheme is omitted, it uses `https` automatically.
