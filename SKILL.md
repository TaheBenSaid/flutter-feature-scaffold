---
name: flutter-feature-scaffold
description: Create a new Flutter feature folder with bloc, either lean (repository, bloc, page) or full clean architecture (data, domain, presentation), and upgrade a lean feature to the full layout later without rewriting it. Use when the user wants to add a feature, screen or module, scaffold a bloc feature, or says a feature has grown and needs clean architecture, a use case or a repository contract.
---

# Flutter feature scaffold

The script is `scripts/feature_scaffold.dart` in this skill's folder. It has no dependencies, so it runs anywhere Dart runs.

## Steps

1. Pick the size.

   - `--lite` for a new, small feature: one screen, one data call, no rules of its own. This is the default for a new small feature.
   - `--full` when the feature already has validation, caching, several data sources, a multi-step flow, or logic shared with other screens.
   - `--upgrade` when a lite feature already exists and has grown.

   If the request doesn't make it clear, ask once: "Lite (repository, bloc, page) or full clean architecture?" Then go.

2. Check `pubspec.yaml` for `flutter_bloc` and `equatable`. If either is missing, ask before adding them with `flutter pub add`.

3. From the Flutter project root, preview, then run:

   ```bash
   dart <skill-folder>/scripts/feature_scaffold.dart <name> --lite --dry-run
   dart <skill-folder>/scripts/feature_scaffold.dart <name> --lite
   ```

   Use `--root` if the project keeps features somewhere other than `lib`, for example `--root lib/src`.

4. Show the user what was created and anything skipped. Skipped means the file already existed and was left alone.

5. Wire the route. If the app uses `go_router`, find where the routes are defined and add a `GoRoute` that builds the new page, following the style of the routes already there. If it uses something else, tell the user which page to add and where it lives.

6. Run `flutter analyze` and fix anything in the new files.

## Upgrading a lite feature

Suggest `--upgrade` when a lite feature gains any of these:

- validation or business rules,
- caching or a second data source,
- a multi-step flow,
- logic another screen needs too.

```bash
dart <skill-folder>/scripts/feature_scaffold.dart <name> --upgrade
```

It moves the repository to `data/repositories/<name>_repository_impl.dart`, writes the domain contract from its public methods, adds a `Get<Name>` use case, and rewires imports. It refuses if the target files exist. After it runs:

1. Run `flutter analyze`. If the contract uses types from third-party packages, add those imports to it.
2. Offer to switch the bloc from the repository to the new use case. That's a small edit: take `Get<Name>` in the constructor, call it, and switch on `Success` and `Failure`.
3. Add an entity, model and data source only when the feature needs them. Don't create empty ones.

## Notes

- `lib/core/result.dart` is only created if it's missing. If the project already has its own `Either` or `Result`, use that instead and tell the user.
- The script never overwrites a file. To regenerate one, the user has to delete it first, so ask before you do.
