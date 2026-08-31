# Tessera package-reclaim follow-up

Status: bounded evidence expansion. This lane is a title and body screen of public issue trackers, not a prevalence study.

Date: 2026-08-31

## Collection

The lane contains 71 new URLs from the latest 100 issue records returned for each of:

- [Poetry](https://github.com/python-poetry/poetry/issues)
- [pip](https://github.com/pypa/pip/issues)
- [vcpkg](https://github.com/microsoft/vcpkg/issues)

The records are in [tessera-disk-rescue-package-followup-ledger.jsonl](./tessera-disk-rescue-package-followup-ledger.jsonl). The first-person heuristic marked 61 as `core` and 10 as `adjacent`. These are automated candidate labels. They have not been manually coded one by one. The lane includes ordinary package correctness issues because package state, paths, and rebuild behavior are often described together.

The records carry `screening_status: automated_candidate`. Pull requests were excluded, and URLs already in the corpus were excluded before writing.

## Patterns to carry into Tessera

### 1. Removing one package can break another owner

The issue [pip deletion without dependency verification](https://github.com/pypa/pip/issues/14216) states the central risk: a package removal can affect another installed dependency. Poetry also reports silent use of a shared, non-isolated environment when version directories are symlinked: [Poetry shared environment](https://github.com/python-poetry/poetry/issues/10991).

Tessera implication: model package storage as a graph. Distinguish shared store, project materialization, hardlink or clone, environment, global tool, and local source. Show projects and tools that depend on a physical object. Sum exclusive reclaimable bytes, not every logical path.

### 2. Offline recovery and local dependencies are first-class state

Poetry path dependencies and pip directory or VCS installs show that a project may depend on a local folder, a private source, or a path that cannot be recreated from a public index: [Poetry path dependencies](https://github.com/python-poetry/poetry/issues/6752) and [pip dependency installation request](https://github.com/pypa/pip/issues/6115).

Tessera implication: protect lockfiles, configuration, credentials, local or unpublished dependencies, and offline sources. A cache is only safe when the owner can show the recovery source and the current project can rebuild under the user's actual network and volume conditions.

### 3. Package operations need a transaction budget

The lane contains lock resolution, install, update, and download failures. A user can need room for a new wheel, unpacked archive, build output, and rollback copy at the same time. A small cache deletion does not prove that the next install can finish.

Tessera implication: ask whether the goal is an update, install, build, or normal work. Show required usable space, temporary working space, the volume that needs it, and whether an active package operation or lock is present. Rank a candidate by usable space now, not only by stored bytes.

### 4. A package tool can touch source files and secrets

Poetry reports an interrupted in-place rewrite that can leave `pyproject.toml` empty: [Poetry interrupted rewrite](https://github.com/python-poetry/poetry/issues/11019). Pip also has an issue about a wheel-cache origin mismatch exposing URL credentials: [pip wheel-cache credential exposure](https://github.com/pypa/pip/issues/14232).

Tessera implication: a path named cache is not enough. Check active writers, locks, file identity, and credential-bearing metadata. Do not display full URLs or credentials in a rescue report. Keep owner cleanup inside the package manager where possible.

## Implementation boundary

Before changing the current `node_modules` or package-cache rule, add owner adapters for npm, pnpm, Yarn, Cargo, CocoaPods, Conda, Gradle, Homebrew, SwiftPM, pip, and uv. Each adapter should return configured roots, version, storage role, project references, link or clone topology, active locks, offline recovery source, dry-run result, supported cleanup action, and exclusive reclaimable bytes. The generic file rule remains review-only when the owner state is unknown.

## Limits and next pass

The latest issue page is time-biased and the repositories are not a user sample. Many records are correctness or platform issues with only an indirect storage implication. The next pass should paginate older history for cache and cleanup terms, inspect owner cleanup commands and dry-run output, and manually code reports about offline rebuild, local dependencies, partial downloads, permissions, and lock state. Do not use the 71-record count as prevalence.
