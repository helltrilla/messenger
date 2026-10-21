# GIT_CONVENTIONS.md

You are an autonomous AI software engineer.
When interacting with Git, creating commits, or preparing releases in this repository, you **MUST** follow these rules strictly. No exceptions.

---

## 1. Commit Messages (Conventional Commits)

All commit messages must follow the **Conventional Commits** standard in **English**, using the **imperative mood** ("add", not "added" or "adds").

### Format
```
<type>(<optional scope>): <description>

[optional body]

[optional footer]
```

### Rules for the description line
- Maximum **72 characters**
- Start with a **lowercase** letter
- **No period** at the end
- Must be meaningful — describe *what* and *why*, not *how*

### Allowed Types

| Type | When to use |
|---|---|
| `feat` | A new user-facing feature |
| `fix` | A bug fix |
| `refactor` | Code restructuring with no behavior change |
| `perf` | Performance improvement |
| `test` | Adding or updating tests only |
| `docs` | Documentation changes only |
| `style` | Formatting, whitespace, missing semicolons (no logic change) |
| `chore` | Build process, CI config, tooling, dependency updates |
| `revert` | Reverting a previous commit |

### Scope (optional but recommended)
Use the feature or module name as scope:
```
feat(auth): add anonymous sign-in on cold start
fix(messages): prevent duplicate entries on rapid scroll
perf(feed): replace ListView with SliverList for large lists
test(tasks): add unit tests for cursor-based pagination
chore(deps): upgrade supabase_flutter to 2.8.1
```

### Commit Body (when needed)
Add a body when the change needs context — especially for `fix` and `refactor`:
```
fix(auth): handle token expiry during background sync

Previously, a 401 response during background task would crash the app
because the error handler assumed a valid session always exists.
Now we refresh the token first and retry the request once before failing.

Closes #142
```

### What Makes a BAD Commit Message
```
❌ fix bug
❌ WIP
❌ updated stuff
❌ asdfgh
❌ Fixed the thing that was broken
❌ feat: Add new feature for users to be able to log in using their phone number and receive an OTP code via SMS
```

### What Makes a GOOD Commit Message
```
✅ feat(auth): add phone OTP sign-in flow
✅ fix(chat): prevent empty message from being sent
✅ refactor(tasks): extract date parsing into TaskDateUtils
✅ chore: add pre-commit lint hook
✅ docs: document RLS policies for messages table
```

---

## 2. Atomic Commit Strategy

- **One logical change per commit.** Never mix a new feature, a bug fix, and a refactor in one commit.
- **Review before every commit:**
  ```bash
  git status      # see what changed
  git diff        # review the actual diff
  git diff --staged  # review what's staged
  ```
- **Never commit:**
  - API keys, tokens, passwords, or `.env` files
  - `print()` / `console.log()` / `debugPrint()` debug statements left in production code
  - Build artifacts, generated files, or IDE-specific configs (check `.gitignore`)
  - Commented-out blocks of dead code
  - Unrelated whitespace or formatting changes mixed with logic changes

- **Prefer small, frequent commits** over large, rare ones. If you can't describe a commit in one line — split it.

---

## 3. Branching Strategy (GitHub Flow)

### Branch Naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feature/<short-description>` | `feature/voice-message-recording` |
| Bug fix | `bugfix/<short-description>` | `bugfix/auth-token-refresh-crash` |
| Hotfix (prod) | `hotfix/<short-description>` | `hotfix/message-deletion-rls` |
| Release prep | `release/<version>` | `release/2.1.0` |
| Tooling/chore | `chore/<short-description>` | `chore/add-github-actions-ci` |

### Rules
- **Never commit directly to `main`.** Main is protected and must always be production-ready.
- Branch off from `main` for all new work.
- Keep branches **short-lived** — merge within days, not weeks.
- Delete branches after merging.
- **One branch = one feature or one fix.** Do not accumulate multiple unrelated changes on a single branch.

### Workflow
```
1. git checkout main && git pull origin main
2. git checkout -b feature/<name>
3. [implement, commit atomically]
4. git push origin feature/<name>
5. Open Pull Request → peer review → merge → delete branch
```

---

## 4. Pull Request Rules

- **Title** must follow the same Conventional Commits format as commit messages.
- **Description** must include:
  - What was changed and why
  - How to test it manually (if applicable)
  - Screenshots / screen recordings for UI changes
  - Reference to linked issue (e.g. `Closes #42`)
- A PR must pass **all CI checks** (lint, tests, build) before it can be merged.
- Squash-merge or rebase-merge only — no merge commits on `main`.
- Do not approve your own PRs.

**PR Title Examples:**
```
feat(notifications): add push notification support for new messages
fix(feed): correct infinite scroll trigger threshold
chore: configure GitHub Actions for automated testing
```

---

## 5. Versioning and Releases (SemVer)

We follow **Semantic Versioning** (`MAJOR.MINOR.PATCH`).

| Version part | When to bump | Commit types |
|---|---|---|
| `PATCH` (x.x.**1**) | Backwards-compatible bug fixes | `fix`, `perf`, `docs` |
| `MINOR` (x.**1**.x) | New backwards-compatible features | `feat` |
| `MAJOR` (**1**.x.x) | Breaking changes, API redesign, major rewrites | any with `!` or `BREAKING CHANGE` |

### Breaking Change Notation
```
feat(api)!: replace REST polling with WebSocket realtime

BREAKING CHANGE: The `getMessages()` method has been removed.
Consumers must now subscribe to `watchMessages()` stream instead.
```

### Release Process
When instructed to prepare a release:

```bash
# 1. Make sure main is up to date
git checkout main && git pull origin main

# 2. Bump the version in config (pubspec.yaml / package.json / pyproject.toml)
# Edit manually — commit as:
git commit -m "chore: release v2.1.0"

# 3. Tag the release
git tag v2.1.0

# 4. Push commit and tag
git push origin main
git push origin v2.1.0
```

> CI/CD (GitHub Actions) will automatically pick up the tag, build artifacts, and publish the GitHub Release.
> **Do not** manually upload build artifacts.

---

## 6. What to NEVER Do

```
❌ git push --force          # rewrites history, destroys teammates' work
❌ git reset --hard HEAD~N   # without coordination — loses committed work
❌ git commit -m "fix"       # non-descriptive message
❌ git add .                 # always stage selectively, not blindly
❌ Committing directly to main
❌ Leaving merge conflicts markers (<<<<<<<) in committed code
❌ Tagging a version without testing the build first
```

---

## 7. Quick Reference

```bash
# Start new feature
git checkout main && git pull origin main
git checkout -b feature/<name>

# Stage selectively (never git add . blindly)
git add path/to/file.dart
git status && git diff --staged

# Commit with Conventional Commits
git commit -m "feat(scope): short imperative description"

# Push and open PR
git push origin feature/<name>

# After PR merge — clean up
git checkout main && git pull origin main
git branch -d feature/<name>
```
