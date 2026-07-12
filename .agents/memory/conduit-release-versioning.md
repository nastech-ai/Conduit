---
name: Conduit Release workflow auto-bumps version
description: pubspec.yaml version is CI-managed for the Release GitHub Actions workflow
---

`.github/workflows/release.yml` bumps `pubspec.yaml`'s version (patch + build number) and pushes a `[skip ci]` commit as the very first step of every run, looping until it finds a version whose `vX.Y.Z` tag doesn't already exist locally or on the remote.

**Why:** the workflow used to read whatever version was committed in `pubspec.yaml` and tag/release from it directly — re-running on the same commit (e.g. via `workflow_dispatch`) or forgetting to bump the version before pushing caused duplicate-tag failures.

**How to apply:** don't hand-edit `pubspec.yaml`'s `version:` field expecting it to stick — CI overwrites it on every run. If you need a specific version number, change the workflow's bump logic instead of the file.
