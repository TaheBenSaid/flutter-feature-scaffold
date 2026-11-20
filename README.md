# flutter-feature-scaffold

Creates a Flutter feature folder that starts small and grows into clean architecture without a rewrite.

Most features don't need three layers on day 1. Some of them do by month 6. This tool gives you the small version first, and moves your code into the bigger one when the feature earns it.

It works two ways:

- as a plain Dart script you run from the terminal,
- as an agent skill, so your AI coding agent can pick the right size, run it and wire the route for you.

## Run it

```bash
git clone https://github.com/TaheBenSaid/flutter-feature-scaffold.git
dart flutter-feature-scaffold/scripts/feature_scaffold.dart orders --lite
```

```
Feature scaffold: orders (lite)
  create  lib/features/orders/data/orders_repository.dart
  create  lib/features/orders/presentation/bloc/orders_bloc.dart
  create  lib/features/orders/presentation/bloc/orders_event.dart
  create  lib/features/orders/presentation/bloc/orders_state.dart
  create  lib/features/orders/presentation/pages/orders_page.dart

Needs flutter_bloc and equatable. Add OrdersPage to your router, then run flutter analyze.
```

The generated code uses `flutter_bloc` and `equatable`, so your app needs both:

```bash
flutter pub add flutter_bloc equatable
```

The script itself has no dependencies.

## Day 1 vs month 6

Day 1, `--lite`:

```
features/orders/
├── data/
│   └── orders_repository.dart
└── presentation/
    ├── bloc/
    │   ├── orders_bloc.dart
    │   ├── orders_event.dart
    │   └── orders_state.dart
    └── pages/
        └── orders_page.dart
```

Month 6, `--full` (the default):

```
features/profile/
├── data/
│   ├── datasources/
│   │   └── profile_remote_data_source.dart
│   ├── models/
│   │   └── profile_model.dart
│   └── repositories/
│       └── profile_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── profile_entity.dart
│   ├── repositories/
│   │   └── profile_repository.dart
│   └── usecases/
│       └── get_profile.dart
└── presentation/
    ├── bloc/
    │   ├── profile_bloc.dart
    │   ├── profile_event.dart
    │   └── profile_state.dart
    ├── pages/
    │   └── profile_page.dart
    └── widgets/
        └── profile_list.dart
```

Both trees are real output from a fresh `flutter create` app, and both pass `flutter analyze` with zero issues.

## What you get

| `--lite` | `--full` |
| --- | --- |
| A plain repository class with one method that returns a `Future` | Repository contract in `domain`, implementation in `data` |
| Bloc that calls the repository | Bloc that calls a use case |
| | Entity, model with a defensive `fromJson`, remote data source |
| | `lib/core/result.dart` with a small sealed `Result<T>` |

Both give you a bloc with `initial`, `loading`, `success`, `empty` and `failure` states, and a page with a `BlocProvider` and a `BlocBuilder` that handles every one of them. The failure state has a retry button.

`Result<T>` is two classes, `Success` and `Failure`. It's only written if `lib/core/result.dart` doesn't exist yet, so you're not forced onto `dartz` or anything else. If you already have your own `Either`, swap it in.

## Grow a lite feature

When a lite feature picks up validation, caching or a multi-step flow, upgrade it in place:

```bash
dart flutter-feature-scaffold/scripts/feature_scaffold.dart orders --upgrade
```

```
Feature scaffold: orders (upgrade)
  create  lib/features/orders/domain/repositories/orders_repository.dart
  create  lib/features/orders/domain/usecases/get_orders.dart
  move    lib/features/orders/data/orders_repository.dart  ->  lib/features/orders/data/repositories/orders_repository_impl.dart
  update  lib/locator.dart
  update  lib/features/orders/presentation/pages/orders_page.dart
  update  lib/features/orders/presentation/bloc/orders_bloc.dart
  skip    lib/core/result.dart (already exists)

The bloc now depends on the OrdersRepository contract. Switch it to GetOrders when you want the Result type end to end.
```

What it does:

- Moves your repository to `data/repositories/orders_repository_impl.dart` and renames it `OrdersRepositoryImpl`. Your method bodies stay as they are. It adds `implements OrdersRepository` and `@override` on the public methods.
- Writes the contract in `domain/repositories/` from your public method signatures, so whatever you added since day 1 ends up in it.
- Adds a `GetOrders` use case around the first method. If that method returns a `Future`, the use case wraps it in `Result`.
- Rewires imports across `lib`. Files that only use the type now import the contract. Files that build it, like the page, import the implementation.

It refuses to run if any of the target files already exist, and it never deletes code. Run `flutter analyze` after. If your signatures use types from third-party packages, add that import to the contract.

## Options

```
dart feature_scaffold.dart <feature_name> [--lite|--full|--upgrade] [--root lib] [--dry-run]
```

- `--root` is the folder that holds `features/` and `core/`. Default `lib`.
- `--dry-run` prints what would happen and writes nothing.
- The name can be `orders`, `order_history`, `OrderHistory` or `order-history`. Files are snake_case, classes PascalCase.
- Existing files are never overwritten. They're listed as skipped.
- Running `--full` on a lite feature stops and points you to `--upgrade`.

New files go through `dart format`, so they follow your project's page width.

## Use it as a skill

Clone it straight into your agent's skills folder, for example:

```bash
git clone https://github.com/TaheBenSaid/flutter-feature-scaffold.git ~/.claude/skills/flutter-feature-scaffold
```

Or into the skills folder inside one project. Then ask something like "add an orders feature" or "this feature got big, move it to clean architecture". The skill asks lite or full when it isn't clear, runs the script, adds the route if you use `go_router`, runs `flutter analyze`, and tells you when a lite feature is ready for `--upgrade`.

## More tools

This is part of a series of small Flutter tools, each tied to a problem I write about. The full list is in [flutter-skills](https://github.com/TaheBenSaid/flutter-skills).

## License

MIT
