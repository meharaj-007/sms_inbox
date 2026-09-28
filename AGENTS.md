# Repository Guidelines

## Project Structure & Module Organization

`lib/sms_inbox.dart` is the public Dart entry point; implementation lives in `lib/src/`. `pigeons/messages.dart` defines platform messages; Kotlin implementation is under `android/src/main/kotlin/`. Dart tests live in `test/`; `example/` provides an Android host and integration tests.

## Build, Test, and Development Commands

Run `flutter pub get`, `flutter analyze`, and `flutter test` from the root. Regenerate platform bindings with `dart run pigeon --input pigeons/messages.dart`, then format `lib/src/messages.g.dart`. In `example/`, run `flutter build apk --debug`. `flutter pub publish --dry-run` validates packaging without publishing.

## Coding Style & Naming Conventions

Use `dart format` and the configured Flutter lints. Dart uses two-space indentation, snake_case filenames, UpperCamelCase types, and lowerCamelCase members. Match existing Kotlin conventions. Edit generator inputs rather than hand-editing generated output.

## Testing Guidelines

Name Dart tests `*_test.dart`. Keep generated Dart and Kotlin bindings synchronized; CI checks for generation drift. Use the example app on an Android device or emulator to verify permissions, filtering, incremental reads, and platform integration. No numerical coverage threshold is configured.

## Commit & Pull Request Guidelines

History currently contains only the initial project commit, so no detailed convention is established. Use short imperative subjects. Keep commits focused on one change. In pull requests, explain the problem, resulting behavior, and validation performed; link an issue when applicable. Include screenshots for visible UI changes and call out configuration or migration changes. These are contributor expectations, not a claim of enforced branch rules.

## Security & Data

Keep the plugin read-only, with no network or persistent storage. Never commit real SMS content. Changes to platform messages must update both generated bindings and their callers.
