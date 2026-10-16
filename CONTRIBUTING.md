# Contributing

Awake Glass is a native Objective-C app built with AppKit and public IOKit power APIs. Development requires a Mac with **macOS 26+**, **Xcode 26+**, and its command-line tools selected. There are no third-party dependencies.

## Build

From the repository directory:

```sh
./build.sh
```

The script uses `xcrun clang`, creates `build/Awake Glass.app`, and applies an ad-hoc signature for local use. It does not notarize the app or create an installer. A local build targets the host architecture; the published package currently targets Apple Silicon.

## Check a change

```sh
./test.sh
./test.sh --activity
```

The activity check briefly requests screen activity. Run it while using an unlocked Mac; do not interpret a passing assertion check as proof that every macOS or managed lock policy can be delayed.

For interface changes, check both Arabic and English, custom-duration validation, the countdown, hiding and reopening the widget, and menu bar controls. Confirm that a timed or stopped session releases its temporary requests. Check that background mode continues when the display turns off. Do not change a user's password or power preferences, trigger a lock, or interrupt unrelated work to run checks.

Keep the app lightweight: avoid extra dependencies, continuous polling, redundant redraws, and unnecessary background processes. Use public APIs and preserve the distinction between requesting activity and changing security policy. Build scripts run one compiler process; avoid concurrent heavy builds on memory-constrained Macs.

## Send a contribution

Open an issue or pull request describing the visible problem, the intended behavior, and the checks relevant to your change. Keep public screenshots and product copy free of personal information and local development details. Contributions are provided under the project's MIT License.
