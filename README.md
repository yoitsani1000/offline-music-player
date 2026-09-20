# Local Player (Phase 1 UI)

## Run in Chrome (needs Flutter installed once)
    flutter create . --platforms=web,ios --project-name local_player
    flutter pub get
    flutter run -d chrome
`flutter create .` only adds the missing platform folders; it keeps lib/main.dart and pubspec.yaml.
Tip: press F12 -> device toolbar (Ctrl+Shift+M) and pick "iPhone 14 Pro" to see the phone layout.

## Run in Chrome with no local Flutter (GitHub Pages)
1. Push this folder to a GitHub repo (branch `main`).
2. Repo Settings -> Pages -> Source: "GitHub Actions".
3. The `build` workflow publishes the web build at https://<you>.github.io/<repo>/.

## iOS .ipa for AltStore/SideStore
The same workflow's `ios` job uploads `LocalPlayer.ipa` (unsigned) as a build artifact.
Add the keys in ios_snippets/Info.plist.additions.xml if you build locally instead (the workflow patches them for you).
