# ARCHITECTURE.md

## 1. Overview

This project follows a strict **Feature-First Clean Architecture** powered by **Riverpod** for state management and dependency injection.

The core principle: **pure business logic (Domain Layer) must be completely isolated** from external dependencies, UI frameworks, data sources, and platform specifics.

The architecture is designed to be:
- **Testable** — every layer can be unit-tested in isolation
- **Scalable** — new features never break existing ones
- **Swappable** — any DataSource (API, local DB, mock) can be replaced without touching Domain or UI

---

## 2. Layer Definitions & Dependency Flow

Dependencies flow **strictly inward** toward the Domain Layer.
The Domain Layer has **zero knowledge** of any outer layer.

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                      │
│                                                             │
│   Widgets (ConsumerWidget)  ──>  Controllers (Notifier)    │
└──────────────────────────────┬──────────────────────────────┘
                               │  calls Use Cases only
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       DOMAIN LAYER                          │
│                    (Pure Dart — no imports)                 │
│                                                             │
│   Use Cases  ──>  Entities  ──>  Repository Interfaces     │
└──────────────────────────────▲──────────────────────────────┘
                               │  implements interfaces
                               │
┌──────────────────────────────┴──────────────────────────────┐
│                        DATA LAYER                           │
│                                                             │
│   Repository Impl  ──>  DataSources  ──>  Data Models      │
└─────────────────────────────────────────────────────────────┘
```

**The one absolute rule:**
> Outer layers may depend on inner layers. Inner layers must **never** depend on outer layers.

---

## 3. Layer Responsibilities

### A. Domain Layer — The Core (Pure Dart)

This layer must have **zero** imports from `flutter`, `flutter_riverpod`, `supabase_flutter`, `dio`, `dart:io`, or any third-party package.

| Component | Responsibility | Rules |
|---|---|---|
| **Entity** | Immutable business object representing a core concept | No `fromJson`/`toJson`. No Flutter. Pure Dart only. |
| **Repository Interface** | Abstract contract defining *what* data operations exist | Only entities and other domain types in signatures |
| **Use Case** | Encapsulates one atomic business operation | Calls one repository interface. Returns `Result<Failure, T>`. |
| **Failure** | Typed domain error (e.g. `NetworkFailure`, `ServerFailure`) | Defined in `core/errors/` |
| **Result<F, T>** | Functional monad wrapping success or failure | Defined in `core/errors/` |

**Entity rules:**
```dart
// ✅ Correct — pure, immutable, no serialization
class Message {
  const Message({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;

  Message copyWith({String? content}) => Message(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}

// ❌ Wrong — JSON inside Entity
class Message {
  factory Message.fromJson(Map<String, dynamic> json) => ...; // belongs in data/models/
}
```

**Use Case rules:**
```dart
// ✅ Correct — one responsibility, returns Result
class GetTodayTasksUseCase {
  const GetTodayTasksUseCase(this._repository);
  final TaskRepository _repository;

  Future<Result<Failure, List<Task>>> call(NoParams params) =>
      _repository.getTodayTasks();
}

// ❌ Wrong — multiple operations in one use case
class TaskUseCase {
  Future<void> getAll() { ... }
  Future<void> save(Task t) { ... }  // split into separate use cases
  Future<void> delete(String id) { ... }
}
```

---

### B. Data Layer — Infrastructure

| Component | Responsibility |
|---|---|
| **Data Model** | Extends or wraps a Domain Entity. Adds `fromJson`, `toJson`, `toDbMap`. |
| **DataSource** | Executes raw I/O — HTTP calls, DB queries, cache reads. No business logic. |
| **Repository Impl** | Orchestrates DataSources, applies caching strategy, catches raw exceptions and maps them to `Failure`. |

**Repository Impl rules:**
```dart
// ✅ Correct — catches low-level exceptions, returns Result
@override
Future<Result<Failure, List<Task>>> getTodayTasks() async {
  try {
    final remote = await _remote.fetchTodayTasks();
    await _local.cacheTasks(remote);
    return Result.success(remote);
  } on SocketException {
    final cached = await _local.getCachedTasks();
    return cached.isNotEmpty
        ? Result.success(cached)
        : Result.error(const NetworkFailure(message: 'No internet connection'));
  } on PostgrestException catch (e) {
    return Result.error(ServerFailure(message: e.message, code: e.code));
  } catch (e) {
    return Result.error(ServerFailure(message: 'Unexpected error: $e'));
  }
}

// ❌ Wrong — raw exception leaks out
Future<List<Task>> getTodayTasks() async {
  return await _remote.fetchTodayTasks(); // throws on error — breaks UI
}
```

---

### C. Presentation Layer — UI

| Component | Responsibility |
|---|---|
| **Controller (Notifier)** | Manages reactive UI state. Calls Use Cases. Handles `Result` and updates state. |
| **Widget** | Renders state. Captures user input. Forwards actions to Controller via `ref.read()`. |
| **Provider** | Wires the dependency graph: DataSources → Repository → Use Cases → Controller. |

**Controller rules:**
```dart
// ✅ Correct — calls use case, handles Result, zero raw exceptions
Future<void> loadTasks() async {
  state = state.copyWith(isLoading: true);
  final result = await _getTodayTasks(const NoParams());
  result.when(
    success: (tasks) => state = state.copyWith(isLoading: false, tasks: tasks),
    error: (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
  );
}

// ❌ Wrong — try/catch in presentation, direct repo access
Future<void> loadTasks() async {
  try {
    final tasks = await ref.read(taskRepositoryProvider).getTodayTasks(); // forbidden
    state = TasksLoaded(tasks);
  } catch (e) {
    state = TasksError(e.toString()); // raw exception in UI
  }
}
```

**Widget rules:**
```dart
// ✅ Correct — pure rendering, delegates all logic to controller
class TaskListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskControllerProvider);
    return state.isLoading
        ? const CircularProgressIndicator()
        : ListView.builder(
            itemCount: state.tasks.length,
            itemBuilder: (_, i) => TaskTile(task: state.tasks[i]),
          );
  }
}

// ❌ Wrong — business logic inside Widget
Widget build(BuildContext context, WidgetRef ref) {
  final tasks = ref.watch(taskControllerProvider).tasks;
  final overdue = tasks.where((t) => t.dueDate.isBefore(DateTime.now())); // logic in UI
  ...
}
```

---

## 4. Project Structure (Feature-First)

Each feature is a self-contained vertical slice. Cross-feature code lives in `lib/core/`.

```
lib/
├── core/
│   ├── errors/
│   │   ├── failure.dart              # Failure sealed class hierarchy
│   │   └── result.dart               # Result<F, T> monad
│   ├── usecase/
│   │   └── usecase.dart              # Base UseCase interface + NoParams
│   ├── network/                      # HTTP client setup, interceptors
│   └── theme/                        # AppTheme, design tokens, typography
│
├── features/
│   └── <feature_name>/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── <name>_remote_datasource.dart
│       │   │   └── <name>_local_datasource.dart
│       │   ├── models/
│       │   │   └── <name>_model.dart
│       │   └── repositories/
│       │       └── <name>_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── <name>.dart
│       │   ├── repositories/
│       │   │   └── <name>_repository.dart       # abstract interface
│       │   └── usecases/
│       │       ├── get_<name>_usecase.dart
│       │       └── save_<name>_usecase.dart
│       └── presentation/
│           ├── controllers/
│           │   ├── <name>_controller.dart
│           │   ├── <name>_state.dart
│           │   └── <name>_providers.dart
│           └── widgets/
│               ├── <name>_screen.dart
│               └── <name>_card.dart
│
└── main.dart
```

---

## 5. Implementation Order (Mandatory for New Features)

Always implement components in this exact order. Never start from the UI.

```
Step 1 → Entity              in domain/entities/
Step 2 → Repository Interface in domain/repositories/
Step 3 → Use Cases           in domain/usecases/
Step 4 → Data Model          in data/models/
Step 5 → DataSources         in data/datasources/
Step 6 → Repository Impl     in data/repositories/
Step 7 → Providers + Controller in presentation/controllers/
Step 8 → Widgets             in presentation/widgets/
Step 9 → Tests               for all layers
```

---

## 6. State Management Patterns

### Recommended state shape
```dart
@immutable
class FeatureState {
  const FeatureState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<SomeEntity> items;
  final bool isLoading;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  FeatureState copyWith({
    List<SomeEntity>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,          // explicit flag to null out errorMessage
  }) {
    return FeatureState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
```

### Provider wiring pattern
```dart
// Always chain providers — no manual instantiation in widgets
final featureRepositoryProvider = Provider<FeatureRepository>((ref) {
  return FeatureRepositoryImpl(
    remote: ref.watch(featureRemoteDataSourceProvider),
    local: ref.watch(featureLocalDataSourceProvider),
  );
});

final featureControllerProvider =
    StateNotifierProvider.autoDispose<FeatureController, FeatureState>((ref) {
  return FeatureController(
    getItems: GetItemsUseCase(ref.watch(featureRepositoryProvider)),
    saveItem: SaveItemUseCase(ref.watch(featureRepositoryProvider)),
  );
});
```

---

## 7. Error Handling Strategy

### Failure hierarchy (extend as needed)
```dart
sealed class Failure {
  const Failure({required this.message});
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, this.code, this.statusCode});
  final String? code;
  final int? statusCode;
}

final class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}
```

### Result monad usage
```dart
// Returning a result
return Result.success(data);
return Result.error(NetworkFailure(message: 'Offline'));

// Consuming a result
final result = await _useCase(params);
result.when(
  success: (data) { /* update state */ },
  error: (failure) { /* show error */ },
);
```

---

## 8. Testing Strategy

| Layer | What to test | How |
|---|---|---|
| **Domain** | Use Case logic, Entity invariants | Pure unit tests, no mocks needed |
| **Data** | Repository Impl error mapping, Model serialization | Mock DataSources |
| **Presentation** | Controller state transitions | Mock Use Cases via `ProviderContainer` |
| **Widget** | UI renders correct state, user interactions | `WidgetTester` + mocked controller |

```
test/
└── features/
    └── <feature_name>/
        ├── domain/
        │   ├── entities/<name>_test.dart
        │   └── usecases/<name>_usecase_test.dart
        ├── data/
        │   ├── models/<name>_model_test.dart
        │   └── repositories/<name>_repository_impl_test.dart
        └── presentation/
            ├── controllers/<name>_controller_test.dart
            └── widgets/<name>_screen_test.dart
```

**Test naming convention:**
```dart
// Given / When / Then
test('returns NetworkFailure when device is offline', () async { ... });
test('caches tasks when remote fetch succeeds', () async { ... });
test('emits loading then success state on loadTasks call', () async { ... });
```

---

## 9. Strict Rules for AI Agents

When modifying this codebase, you **must** adhere to all of the following:

1. **No Leaky Dependencies** — Never import `flutter`, `riverpod`, or any third-party package inside `domain/`.
2. **Entity Isolation** — Entities must never contain `fromJson`/`toJson`. All serialization lives in `data/models/`.
3. **No Direct Data Access from UI** — Widgets call Controllers. Controllers call Use Cases. Use Cases call Repository interfaces. Nothing else.
4. **Functional Error Handling** — All async data operations return `Result<Failure, T>`. No raw exceptions in controllers or widgets.
5. **No New Abstractions Without Need** — Reuse existing entities, use cases, and repositories before creating new ones. Ask if unsure.
6. **Implementation Order** — Always follow the order in Section 5. Never start from the UI.
7. **Test Coverage** — Every new Use Case, Repository method, and Controller state transition must have a corresponding test.
