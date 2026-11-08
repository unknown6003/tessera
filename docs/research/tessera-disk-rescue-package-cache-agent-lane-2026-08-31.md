# Tessera disk-rescue research lane B: package caches and build storage on macOS

Collected 2026-08-31.

## Scope

This lane asks how Tessera should classify and safely reclaim storage when package managers and build systems mix global stores, project dependencies, hardlinks, APFS clones, content-addressed blobs, compiler output, downloaded archives, environments, lock state, and offline recovery inputs.

The answer is not "delete caches." Tessera must identify the owner, storage role, link topology, active use, recovery source, and exclusive reclaimable bytes for each object. A path can look disposable while it is an installed environment, a shared content store, or the only local input for an offline build.

The selected owner families are Homebrew, npm, pnpm, Yarn, Cargo, Gradle, Swift Package Manager, CocoaPods, pip, uv, and Conda.

## Method

I used two evidence tracks.

- Product facts come from official documentation, owner repositories, or maintained owner source.
- User evidence comes from first-person behavior reports and concrete requests in each owner's issue tracker.
- A report is `core` when the issue body gives a concrete behavior or failure and the title describes that behavior.
- A request, design discussion, or useful boundary case is `adjacent`.
- Owner facts stay separate as `owner_fact`.
- Generic Stack Overflow answers, search pages, third-party tutorials, copied support posts, fragments, tracking parameters, and artificial trailing-slash variants were excluded.
- Canonical redirects were followed. Seventeen documentation URLs were stored with the canonical trailing slash returned by the owner site.
- Every owner documentation URL returned HTTP 200. Every issue URL came from the authenticated API for the owner's repository.
- No package-manager cleanup command ran. No cache, environment, project dependency, or build output changed.

## Counts

### By owner family

| Owner family | Records |
| --- | ---: |
| Homebrew | 18 |
| npm | 19 |
| pnpm | 22 |
| Yarn | 20 |
| Cargo | 20 |
| Gradle | 21 |
| Swift Package Manager | 20 |
| CocoaPods | 22 |
| pip | 22 |
| uv | 24 |
| Conda | 16 |
| Total | 224 |

### By source type

| Source type | Records |
| --- | ---: |
| Owner fact | 66 |
| User report or boundary report in owner issue tracker | 158 |
| Total | 224 |

### By source kind

| Source kind | Records |
| --- | ---: |
| Official owner documentation | 52 |
| Owner repository documentation | 2 |
| Maintained owner source | 12 |
| Owner issue tracker | 158 |
| Total | 224 |

### By evidence class

| Evidence class | Records |
| --- | ---: |
| `core` | 104 |
| `adjacent` | 54 |
| `owner_fact` | 66 |
| Total | 224 |

## De-duplication proof

The baseline command was:

```bash
rg --files docs/research | rg '(ledger|market-scan)\.jsonl$'
```

At the first check, that selector returned 12 files with 2,683 unique exact URLs. Before the combined audit, the game-library and app-profile ledgers also finished. The comparison was rerun against all 14 other current corpus inputs. They contain 3,022 records and 3,022 unique exact URLs. Baseline duplicates remain zero.

The candidate comparison used exact strings:

```bash
comm -12 \
  <(jq -r '.url' docs/research/tessera-disk-rescue-package-cache-ledger.jsonl | sort -u) \
  <(rg --files docs/research \
      | rg '(ledger|market-scan)\.jsonl$' \
      | rg -v 'tessera-disk-rescue-package-cache-ledger\.jsonl$' \
      | xargs jq -r '.url' \
      | sort -u)
```

Result:

- Selected records: 224
- Unique selected URLs: 224
- Duplicate selected URLs: 0
- Exact overlap with the pre-existing corpus: 0
- Fragment URLs: 0
- Tracking-parameter URLs: 0
- Combined corpus with this ledger included: 3,246 unique URLs

## Screening limits

- Issue reports prove the reported case. They do not measure how common it is.
- Some issues may describe fixed or version-specific behavior.
- Search terms favor reports that name cache, store, clean, offline, link, build, lock, archive, environment, or disk behavior.
- Cross-platform reports were included when they reveal an owner storage rule that also affects macOS. The report does not claim that a Windows or Linux failure reproduces on macOS.
- The HTTP check proves that an owner page was reachable on 2026-08-31. It does not freeze future content.
- This lane did not run allocation experiments on APFS. Tessera still needs local tests for clone sharing, hardlink counts, sparse files, and actual free-space change.
- No prevalence estimate is made.

## What Tessera should classify

Tessera needs a typed storage model. A folder name is not enough.

| Storage role | Examples | Default treatment |
| --- | --- | --- |
| Owner-managed download cache | npm HTTP cache, pip HTTP cache, Homebrew downloads | Reclaim through the owner's scoped command after recovery checks |
| Content-addressed global store | pnpm store, npm cacache, Gradle dependency cache | Treat as shared. Use owner metadata and exclusive-byte estimates |
| Project dependency materialization | node_modules, Pods, SwiftPM checkouts | Treat as project state. Prove recreation before removal |
| Compiler and task output | Cargo target, SwiftPM .build, Gradle build cache | Regenerable, but show build cost and active locks |
| Installed environment | Conda env, Python venv, uv tool environment | Installed runtime, not cache |
| Global tool installation | Homebrew cellar entries, npm global packages, Cargo binaries | Installed software, not cache |
| Offline recovery input | Cargo vendor tree, pip wheelhouse, committed Yarn cache | Protect unless another verified source exists |
| Lock and resolution metadata | package-lock.json, pnpm-lock.yaml, yarn.lock, Cargo.lock, Package.resolved, Podfile.lock | Small, high-value evidence. Never offer as cleanup |
| Owner configuration and credentials | npmrc, yarnrc, condarc, Cargo config, registry credentials | Do not offer as cleanup |
| Temporary or partial transfer | staging directory, interrupted archive, incomplete blob | Inspect owner state. Repair or remove only the failed object |

## Patterns

1. Global store, project tree, and build output are separate classes. npm, pnpm, Yarn, Cargo, Gradle, SwiftPM, CocoaPods, pip, uv, and Conda all split storage into more than one role.

2. Logical size is not reclaimable size. pnpm, uv, and Conda use hardlinks, clones, or selectable link modes. APFS clones can share physical blocks. Tessera must show allocated bytes and an exclusive reclaim estimate.

3. A global store can serve many projects and users. Path age alone cannot prove that a blob is unreferenced.

4. Offline mode changes the value of cache data. Cargo fetch, pnpm fetch, pip download, Yarn project caches, Gradle offline mode, and Conda package caches can make a later build possible without a network.

5. Lockfiles are recovery evidence. They are small and should remain even when generated dependencies or compiler output are removed.

6. Environments are installed state. A Conda environment, venv, or uv tool environment can contain executables, local packages, editable installs, and files not represented by a lock.

7. Owner cleanup commands have different scopes. Some clean downloads, some old package versions, some build output, and some every cache class. Tessera must show the exact owner action.

8. Owner commands are not proof of safety. The issue set includes cleanup commands that skip work, remove too much, race with another process, or mishandle linked data.

9. Active work changes the answer. Build daemons, cache locks, concurrent installs, and open files can make an otherwise disposable path unsafe to touch.

10. Corruption is not the same as obsolescence. A stale or partial cache may need an owner integrity check, a targeted repair, or removal of one object.

11. Downloaded archives and extracted trees have different recovery value. Deleting both can turn an easy offline reinstall into a network-dependent rebuild.

12. Package-manager upgrades can leave old cache formats. Yarn migration and versioned Gradle or uv caches show why Tessera should attribute old stores to an owner version before calling them abandoned.

13. Project-local vendor trees and wheelhouses look like caches but are user-managed source inputs. Tessera should classify them as project assets.

14. Store location is configurable. Static path lists will miss external-volume stores and can mistake a relocated store for unrelated data.

## Counterexamples that block simple cleanup rules

- "Delete the largest folder" fails when most bytes are hardlinked or cloned elsewhere.
- "Delete anything called cache" fails for committed Yarn caches, Cargo vendor trees, pip wheelhouses, and offline package stores.
- "The package manager can rebuild it" fails when the network, registry version, credentials, Git revision, or binary archive is no longer available.
- "Owner cleanup is always safe" fails when a cleanup command races, skips its final phase, or removes linked state.
- "Old means unused" fails for pinned Homebrew versions, locked toolchains, archived environments, and rarely built projects.
- "A lockfile recreates everything" fails for editable installs, local paths, unpublished Git commits, locally built packages, pip-managed content inside Conda, and build tools outside the lock.
- "Reported folder size equals freed space" fails for APFS clones, hardlinks, sparse files, and shared blobs.
- "Environment equals package cache" fails because environments contain installed binaries and local state.

## Safe reclaim sequence for macOS

1. Detect the owner from paths, metadata, configuration, and executable state.
2. Resolve the configured store, environment, build, archive, and project roots. Do not rely only on default paths.
3. Classify each object by storage role.
4. Check open files, owner processes, daemon state, and lock files.
5. Detect hardlinks, symlinks, mount boundaries, and clone-capable volumes.
6. Measure logical bytes, allocated bytes, and the best available exclusive reclaim estimate.
7. Find project references and lock or resolution files.
8. Record the recovery source. This can be a reachable registry, Git revision, local archive, vendor tree, or none.
9. Prefer a scoped owner inventory or cleanup command. Show the command and its exact target before confirmation.
10. Treat owner cleanup as permanent unless the owner documents a recoverable path. Do not imply that it uses Trash.
11. If no safe owner action exists, offer only an exact-path action with separate confirmation.
12. Rescan the filesystem and owner state after the action. Report actual free-space change, not the pre-action estimate.

## Decision rules for Tessera

A reclaim proposal is green only when all of these checks pass:

- The owner and storage role are known.
- No owner process, open file, or lock is active.
- The object is not an environment, global installation, lockfile, configuration, credential, vendor tree, or user-authored file.
- A recovery source is known and reachable, or the user accepts loss of offline recovery.
- Link topology is understood.
- The estimate uses allocated or exclusive bytes, not only logical size.
- The action is scoped and shown before confirmation.

Use amber when the object is regenerable but expensive, shared, offline-sensitive, or weakly referenced. Keep red for active state, installed environments, global tools, configuration, credentials, lock data, local-only packages, unpublished sources, and any object with unknown ownership.

## Product implications

- Group findings by owner and role, not only by folder.
- Show "download cache," "shared store," "project dependencies," "build output," "environment," "tool," and "recovery input" as different labels.
- Show logical size and estimated reclaimable size as separate values.
- Add badges for hardlinked, cloned, shared, locked, offline asset, and owner-managed.
- Keep lockfiles and owner configuration out of deletion lists.
- Use owner status and cleanup commands when available.
- Show the exact command, paths, and whether the action bypasses Trash.
- Let the user protect a project or an offline build.
- After cleanup, verify both disk space and package-manager health.
- Record source URLs and the owner version used for every rule.

## Selected records

### Homebrew

- `PC001` | `owner_fact` | `owner_documentation` | Homebrew manual. <https://docs.brew.sh/Manpage> Homebrew documents cleanup, cache paths, autoremove, and bundle cleanup as separate owner commands.
- `PC002` | `owner_fact` | `owner_documentation` | Homebrew FAQ. <https://docs.brew.sh/FAQ> Homebrew says brew cleanup removes old formula versions and old downloads, while pinned versions remain installed.
- `PC003` | `owner_fact` | `owner_documentation` | Homebrew installation guide. <https://docs.brew.sh/Installation> Homebrew installs into a prefix and uses architecture-specific default prefixes on macOS.
- `PC004` | `owner_fact` | `owner_source` | Homebrew cleanup command source. <https://github.com/Homebrew/brew/blob/master/Library/Homebrew/cmd/cleanup.rb> The cleanup command owns rules for stale downloads, old versions, dry-run behavior, pruning age, and scrub behavior.
- `PC005` | `owner_fact` | `owner_source` | Homebrew cache command source. <https://github.com/Homebrew/brew/blob/master/Library/Homebrew/cmd/--cache.rb> The cache command resolves the owner-defined cache location for formulae, casks, and the whole cache.
- `PC006` | `owner_fact` | `owner_source` | Homebrew package-manager cache source. <https://github.com/Homebrew/brew/blob/master/Library/Homebrew/package_manager_cache.rb> Homebrew tracks caches created by other package managers during formula builds as a distinct cleanup concern.
- `PC007` | `core` | `owner_issue_tracker` | brew testbot uses bottle cache, even when patch has changed. <https://github.com/Homebrew/brew/issues/23588> A reporter describes this concrete behavior: brew testbot uses bottle cache, even when patch has changed.
- `PC008` | `adjacent` | `owner_issue_tracker` | Show estimated disk space needed before upgrade. <https://github.com/Homebrew/brew/issues/23668> An owner issue asks for or tests this boundary: Show estimated disk space needed before upgrade.
- `PC009` | `core` | `owner_issue_tracker` | `brew bundle cleanup --force` silently skips its final `brew cleanup` when any warning is printed (stderr is closed via IO.popen). <https://github.com/Homebrew/brew/issues/23053> A reporter describes this concrete behavior: `brew bundle cleanup --force` silently skips its final `brew cleanup` when any warning is printed (stderr is closed via IO.popen).
- `PC010` | `adjacent` | `owner_issue_tracker` | Feature Request: Interactive Dependency Explanation & Tidy Tool (`brew why` / `brew tidy`). <https://github.com/Homebrew/brew/issues/22954> An owner issue asks for or tests this boundary: Feature Request: Interactive Dependency Explanation & Tidy Tool (`brew why` / `brew tidy`).
- `PC011` | `core` | `owner_issue_tracker` | brew update can permanently stick on a stale internal packages.*.jws.json after 304 + touch. <https://github.com/Homebrew/brew/issues/23485> A reporter describes this concrete behavior: brew update can permanently stick on a stale internal packages.*.jws.json after 304 + touch.
- `PC012` | `core` | `owner_issue_tracker` | `brew services cleanup` removes service file. <https://github.com/Homebrew/brew/issues/23217> A reporter describes this concrete behavior: `brew services cleanup` removes service file.
- `PC013` | `core` | `owner_issue_tracker` | brew bundle cleanup untrusts previously trusted taps, etc. <https://github.com/Homebrew/brew/issues/22826> A reporter describes this concrete behavior: brew bundle cleanup untrusts previously trusted taps, etc.
- `PC014` | `core` | `owner_issue_tracker` | Portable Ruby 4 causes brew cleanup to become slower. <https://github.com/Homebrew/brew/issues/21859> A reporter describes this concrete behavior: Portable Ruby 4 causes brew cleanup to become slower.
- `PC015` | `core` | `owner_issue_tracker` | Brew bundle vs cleanup with tap in Brewfile causes weird issues. <https://github.com/Homebrew/brew/issues/22129> A reporter describes this concrete behavior: Brew bundle vs cleanup with tap in Brewfile causes weird issues.
- `PC016` | `core` | `owner_issue_tracker` | `brew bundle cleanup` uninstalls Mac App Store apps that were never installed via Homebrew. <https://github.com/Homebrew/brew/issues/22450> A reporter describes this concrete behavior: `brew bundle cleanup` uninstalls Mac App Store apps that were never installed via Homebrew.
- `PC017` | `core` | `owner_issue_tracker` | `brew upgrade` may treat failed download cache as already downloaded until cleanup. <https://github.com/Homebrew/brew/issues/22089> A reporter describes this concrete behavior: `brew upgrade` may treat failed download cache as already downloaded until cleanup.
- `PC018` | `core` | `owner_issue_tracker` | Ctrl+C during cask download leaves curl running in background. <https://github.com/Homebrew/brew/issues/22200> A reporter describes this concrete behavior: Ctrl+C during cask download leaves curl running in background.

### npm

- `PC019` | `owner_fact` | `owner_documentation` | npm cache command. <https://docs.npmjs.com/cli/v11/commands/npm-cache/> npm describes its cache as self-healing and provides verify and clean commands; clean requires force.
- `PC020` | `owner_fact` | `owner_documentation` | npm folders reference. <https://docs.npmjs.com/cli/v11/configuring-npm/folders/> npm separates local node_modules, global installs, executables, cache, and temporary files.
- `PC021` | `owner_fact` | `owner_documentation` | npm ci command. <https://docs.npmjs.com/cli/v11/commands/npm-ci/> npm ci requires a lockfile, removes an existing node_modules tree, and performs a frozen install.
- `PC022` | `owner_fact` | `owner_documentation` | npm install command. <https://docs.npmjs.com/cli/v11/commands/npm-install/> npm install can populate local or global dependency trees from registry, archive, folder, URL, or Git sources.
- `PC023` | `owner_fact` | `owner_documentation` | npm configuration reference. <https://docs.npmjs.com/cli/v11/using-npm/config/> npm exposes cache, offline, prefer-offline, global, prefix, and lock-related settings.
- `PC024` | `owner_fact` | `owner_repository_documentation` | cacache repository. <https://github.com/npm/cacache/blob/main/README.md> cacache is npm's content-addressable cache and verifies integrity on read.
- `PC025` | `core` | `owner_issue_tracker` | npm install removes resolved and integrity properties from package-lock.json if installed from cache. <https://github.com/npm/cli/issues/4263> A reporter describes this concrete behavior: npm install removes resolved and integrity properties from package-lock.json if installed from cache.
- `PC026` | `core` | `owner_issue_tracker` | Global Install from git repository fails when using 'prepare' script and 'bin' path. <https://github.com/npm/cli/issues/3692> A reporter describes this concrete behavior: Global Install from git repository fails when using 'prepare' script and 'bin' path.
- `PC027` | `adjacent` | `owner_issue_tracker` | [BUG] npm self-upgrade on Node 24.14.1 (npm 11.11.0 to 11.15.0) crashes with "Class extends value undefined" due to stale minipass@3.x. <https://github.com/npm/cli/issues/9472> An owner issue asks for or tests this boundary: [BUG] npm self-upgrade on Node 24.14.1 (npm 11.11.0 to 11.15.0) crashes with "Class extends value undefined" due to stale minipass@3.x.
- `PC028` | `core` | `owner_issue_tracker` | [BUG] ETARGET installing package I just published (not invalidating cache?). <https://github.com/npm/cli/issues/4513> A reporter describes this concrete behavior: [BUG] ETARGET installing package I just published (not invalidating cache?).
- `PC029` | `core` | `owner_issue_tracker` | [BUG] Installing with --prefer-offline does not work if dependencies are not available in the cache. <https://github.com/npm/cli/issues/6367> A reporter describes this concrete behavior: [BUG] Installing with --prefer-offline does not work if dependencies are not available in the cache.
- `PC030` | `core` | `owner_issue_tracker` | [BUG] Extra .npm directory created in user's home while npm_config_cache set. <https://github.com/npm/cli/issues/3350> A reporter describes this concrete behavior: [BUG] Extra .npm directory created in user's home while npm_config_cache set.
- `PC031` | `core` | `owner_issue_tracker` | [BUG] Silent conflict when both prefer-offline=true and prefer-online=true are set, causing npm view to return stale cached data. <https://github.com/npm/cli/issues/9113> A reporter describes this concrete behavior: [BUG] Silent conflict when both prefer-offline=true and prefer-online=true are set, causing npm view to return stale cached data.
- `PC032` | `core` | `owner_issue_tracker` | [BUG] Ineffective caching of git dependencies. <https://github.com/npm/cli/issues/5170> A reporter describes this concrete behavior: [BUG] Ineffective caching of git dependencies.
- `PC033` | `core` | `owner_issue_tracker` | [BUG] fallback behaviour when hard links aren't supported. <https://github.com/npm/cli/issues/5951> A reporter describes this concrete behavior: [BUG] fallback behaviour when hard links aren't supported.
- `PC034` | `core` | `owner_issue_tracker` | [BUG] Cannot read property 'pickAlgorithm' of null. <https://github.com/npm/cli/issues/5496> A reporter describes this concrete behavior: [BUG] Cannot read property 'pickAlgorithm' of null.
- `PC035` | `core` | `owner_issue_tracker` | [BUG] npx is too slow for already cached package with specific version requested. <https://github.com/npm/cli/issues/7295> A reporter describes this concrete behavior: [BUG] npx is too slow for already cached package with specific version requested.
- `PC036` | `core` | `owner_issue_tracker` | [BUG] `npm i` tries to recreate root directory (drive letter) in Windows. <https://github.com/npm/cli/issues/6412> A reporter describes this concrete behavior: [BUG] `npm i` tries to recreate root directory (drive letter) in Windows.
- `PC037` | `core` | `owner_issue_tracker` | [BUG] npm ERR! ENOTEMPTY: directory not empty, rename '/usr/local/lib/node_modules/tls-test' -> '/usr/local/lib/node_modules/.tls-test-ow7IxLcQ'. <https://github.com/npm/cli/issues/5825> A reporter describes this concrete behavior: [BUG] npm ERR! ENOTEMPTY: directory not empty, rename '/usr/local/lib/node_modules/tls-test' -> '/usr/local/lib/node_modules/.tls-test-ow7IxLcQ'.

### pnpm

- `PC038` | `owner_fact` | `owner_documentation` | pnpm store command. <https://pnpm.io/cli/store> pnpm documents store status, prune, and path commands for the content-addressable store.
- `PC039` | `owner_fact` | `owner_documentation` | pnpm fetch command. <https://pnpm.io/cli/fetch> pnpm fetch loads packages into the virtual store from a lockfile without creating a normal install.
- `PC040` | `owner_fact` | `owner_documentation` | pnpm install command. <https://pnpm.io/cli/install> pnpm install supports offline, frozen lockfile, and package import choices that affect dependency materialization.
- `PC041` | `owner_fact` | `owner_documentation` | pnpm settings. <https://pnpm.io/settings> pnpm settings define store directories, virtual stores, package import methods, side-effects cache, and locks.
- `PC042` | `owner_fact` | `owner_documentation` | pnpm symlinked node_modules structure. <https://pnpm.io/symlinked-node-modules-structure> pnpm hardlinks package files from its content-addressable store into a virtual store and uses symlinks for the dependency graph.
- `PC043` | `owner_fact` | `owner_documentation` | pnpm continuous integration guide. <https://pnpm.io/continuous-integration> pnpm's CI guide treats the store as reusable cache but warns that caching it does not always improve install speed.
- `PC044` | `core` | `owner_issue_tracker` | packageImportMethod caching breaks it on import from vfs. <https://github.com/pnpm/pnpm/issues/10134> A reporter describes this concrete behavior: packageImportMethod caching breaks it on import from vfs.
- `PC045` | `core` | `owner_issue_tracker` | `pnpm store prune` doesn't work correctly when files from the store are cloned. <https://github.com/pnpm/pnpm/issues/7192> A reporter describes this concrete behavior: `pnpm store prune` doesn't work correctly when files from the store are cloned.
- `PC046` | `core` | `owner_issue_tracker` | pnpm auto mode falls back to copying instead of hardlinks on macOS APFS. <https://github.com/pnpm/pnpm/issues/9935> A reporter describes this concrete behavior: pnpm auto mode falls back to copying instead of hardlinks on macOS APFS.
- `PC047` | `core` | `owner_issue_tracker` | Broken symlink/hardlink is not detected by pnpm as invalid when running install. <https://github.com/pnpm/pnpm/issues/9758> A reporter describes this concrete behavior: Broken symlink/hardlink is not detected by pnpm as invalid when running install.
- `PC048` | `core` | `owner_issue_tracker` | pnpm install with --offline should only consider versions with cached tarballs, not all versions in metadata. <https://github.com/pnpm/pnpm/issues/10715> A reporter describes this concrete behavior: pnpm install with --offline should only consider versions with cached tarballs, not all versions in metadata.
- `PC049` | `core` | `owner_issue_tracker` | pnpm pack should dereference hardlinks. <https://github.com/pnpm/pnpm/issues/2592> A reporter describes this concrete behavior: pnpm pack should dereference hardlinks.
- `PC050` | `core` | `owner_issue_tracker` | All `pnpm` commands hanging without message when offline. <https://github.com/pnpm/pnpm/issues/12755> A reporter describes this concrete behavior: All `pnpm` commands hanging without message when offline.
- `PC051` | `adjacent` | `owner_issue_tracker` | Only symlink the folder instead of hardlinking every single file. <https://github.com/pnpm/pnpm/issues/3109> An owner issue asks for or tests this boundary: Only symlink the folder instead of hardlinking every single file.
- `PC052` | `core` | `owner_issue_tracker` | pnpm seemingly uses hard links instead of APFS cloning on macOS. <https://github.com/pnpm/pnpm/issues/2761> A reporter describes this concrete behavior: pnpm seemingly uses hard links instead of APFS cloning on macOS.
- `PC053` | `core` | `owner_issue_tracker` | Offline install with `pnpm fetch` breaks on pnpm upgrade. <https://github.com/pnpm/pnpm/issues/11808> A reporter describes this concrete behavior: Offline install with `pnpm fetch` breaks on pnpm upgrade.
- `PC054` | `core` | `owner_issue_tracker` | Hardlinks for empty files. <https://github.com/pnpm/pnpm/issues/4382> A reporter describes this concrete behavior: Hardlinks for empty files.
- `PC055` | `core` | `owner_issue_tracker` | ERR_PNPM_NO_OFFLINE_META in docker. <https://github.com/pnpm/pnpm/issues/6058> A reporter describes this concrete behavior: ERR_PNPM_NO_OFFLINE_META in docker.
- `PC056` | `core` | `owner_issue_tracker` | ERR_PNPM_NO_OFFLINE_META when using pnpm deploy --offline. <https://github.com/pnpm/pnpm/issues/5315> A reporter describes this concrete behavior: ERR_PNPM_NO_OFFLINE_META when using pnpm deploy --offline.
- `PC057` | `core` | `owner_issue_tracker` | ENOENT: no such file or directory, copyfile '/project/.pnpm-store/... -> '/project/node_modules/... <https://github.com/pnpm/pnpm/issues/5803> A reporter describes this concrete behavior: ENOENT: no such file or directory, copyfile '/project/.pnpm-store/... -> '/project/node_modules/...
- `PC058` | `core` | `owner_issue_tracker` | "pnpm install" or "pnpm install --offline" deletes or modifies files from the .pnpm-store. <https://github.com/pnpm/pnpm/issues/7876> A reporter describes this concrete behavior: "pnpm install" or "pnpm install --offline" deletes or modifies files from the .pnpm-store.
- `PC059` | `core` | `owner_issue_tracker` | Getting `ERR_PNPM_HARDLINK_FAILED Error: EEXIST: file already exists, link` when pnpm install. <https://github.com/pnpm/pnpm/issues/7713> A reporter describes this concrete behavior: Getting `ERR_PNPM_HARDLINK_FAILED Error: EEXIST: file already exists, link` when pnpm install.

### Yarn

- `PC060` | `owner_fact` | `owner_documentation` | Yarn cache feature. <https://yarnpkg.com/features/caching> Yarn distinguishes a shared global cache from a project-local cache and documents cache compression tradeoffs.
- `PC061` | `owner_fact` | `owner_documentation` | Yarn installation files guide. <https://yarnpkg.com/getting-started/qa> Yarn explains which cache, Plug'n'Play, install-state, unplugged, and release files belong in version control for different project models.
- `PC062` | `owner_fact` | `owner_documentation` | Yarn Plug'n'Play feature. <https://yarnpkg.com/features/pnp> Plug'n'Play replaces node_modules with a loader file and archive-backed dependency map.
- `PC063` | `owner_fact` | `owner_documentation` | Yarn cache clean command. <https://yarnpkg.com/cli/cache/clean> Yarn cache clean can remove local cache, mirror cache, or both.
- `PC064` | `owner_fact` | `owner_documentation` | Yarn install command. <https://yarnpkg.com/cli/install> Yarn installation has resolution, fetch, link, and build steps, each with different stored outputs.
- `PC065` | `owner_fact` | `owner_documentation` | Yarn configuration reference. <https://yarnpkg.com/configuration/yarnrc> Yarn settings control cache location, global cache use, immutable caches, compression, node linker, and unplugged folders.
- `PC066` | `core` | `owner_issue_tracker` | [Bug?]: Migration to Yarn 4 does not remove Yarn 3 cache. <https://github.com/yarnpkg/berry/issues/5820> A reporter describes this concrete behavior: [Bug?]: Migration to Yarn 4 does not remove Yarn 3 cache.
- `PC067` | `core` | `owner_issue_tracker` | Dependencies are stored in unplugged, so zero install is not possible. <https://github.com/yarnpkg/berry/issues/5379> A reporter describes this concrete behavior: Dependencies are stored in unplugged, so zero install is not possible.
- `PC068` | `adjacent` | `owner_issue_tracker` | guidance for using Yarn 2 in CI (caching, --immutable, etc). <https://github.com/yarnpkg/berry/issues/2528> An owner issue asks for or tests this boundary: guidance for using Yarn 2 in CI (caching, --immutable, etc).
- `PC069` | `adjacent` | `owner_issue_tracker` | [Feature] migrate offline cache from v1 to v2. <https://github.com/yarnpkg/berry/issues/2465> An owner issue asks for or tests this boundary: [Feature] migrate offline cache from v1 to v2.
- `PC070` | `core` | `owner_issue_tracker` | [Bug]: Yarn creates an unplugged package which is not needed on current OS (fsevents + node-gyp). <https://github.com/yarnpkg/berry/issues/5995> A reporter describes this concrete behavior: [Bug]: Yarn creates an unplugged package which is not needed on current OS (fsevents + node-gyp).
- `PC071` | `adjacent` | `owner_issue_tracker` | [Feature] Only Refetch Checksums When Running yarn install --check-cache. <https://github.com/yarnpkg/berry/issues/2918> An owner issue asks for or tests this boundary: [Feature] Only Refetch Checksums When Running yarn install --check-cache.
- `PC072` | `adjacent` | `owner_issue_tracker` | [Feature] Provide a package-level cache management library. <https://github.com/yarnpkg/berry/issues/918> An owner issue asks for or tests this boundary: [Feature] Provide a package-level cache management library.
- `PC073` | `adjacent` | `owner_issue_tracker` | [Feature] Cache pruning support. <https://github.com/yarnpkg/berry/issues/2775> An owner issue asks for or tests this boundary: [Feature] Cache pruning support.
- `PC074` | `adjacent` | `owner_issue_tracker` | [Feature] Yarn environment variable for ".yarn" folder. <https://github.com/yarnpkg/berry/issues/6462> An owner issue asks for or tests this boundary: [Feature] Yarn environment variable for ".yarn" folder.
- `PC075` | `core` | `owner_issue_tracker` | [Bug?]: `yarn rebuild <module>` still rebuilds all other modules that haven't previously been built. <https://github.com/yarnpkg/berry/issues/3166> A reporter describes this concrete behavior: [Bug?]: `yarn rebuild <module>` still rebuilds all other modules that haven't previously been built.
- `PC076` | `adjacent` | `owner_issue_tracker` | [Feature] A flag to enforce consistency of unplugged files and node_modules. <https://github.com/yarnpkg/berry/issues/3210> An owner issue asks for or tests this boundary: [Feature] A flag to enforce consistency of unplugged files and node_modules.
- `PC077` | `adjacent` | `owner_issue_tracker` | [Feature] Download and cache dependencies from yarn.lock lockfile. <https://github.com/yarnpkg/berry/issues/5998> An owner issue asks for or tests this boundary: [Feature] Download and cache dependencies from yarn.lock lockfile.
- `PC078` | `core` | `owner_issue_tracker` | [Bug?]: Error "Required package missing from disk" when building with Node 23.0.0. <https://github.com/yarnpkg/berry/issues/6570> A reporter describes this concrete behavior: [Bug?]: Error "Required package missing from disk" when building with Node 23.0.0.
- `PC079` | `core` | `owner_issue_tracker` | [macOS to Linux]: In PnP the `unplugged` folder causes build errors for any linux build initiated on macOS host. <https://github.com/yarnpkg/berry/issues/3526> A reporter describes this concrete behavior: [macOS to Linux]: In PnP the `unplugged` folder causes build errors for any linux build initiated on macOS host.

### Cargo

- `PC080` | `owner_fact` | `owner_documentation` | Cargo home guide. <https://doc.rust-lang.org/cargo/guide/cargo-home.html> Cargo home contains registry indexes, downloaded crate archives, extracted source, Git databases, Git checkouts, and installed binaries.
- `PC081` | `owner_fact` | `owner_documentation` | cargo clean command. <https://doc.rust-lang.org/cargo/commands/cargo-clean.html> cargo clean removes generated artifacts from the target directory and can scope cleanup by package, profile, target, or doc output.
- `PC082` | `owner_fact` | `owner_documentation` | cargo fetch command. <https://doc.rust-lang.org/cargo/commands/cargo-fetch.html> cargo fetch downloads dependencies ahead of time so later Cargo commands can run offline.
- `PC083` | `owner_fact` | `owner_documentation` | cargo vendor command. <https://doc.rust-lang.org/cargo/commands/cargo-vendor.html> cargo vendor copies remote dependency sources into a local directory for source replacement and offline builds.
- `PC084` | `owner_fact` | `owner_documentation` | Cargo configuration reference. <https://doc.rust-lang.org/cargo/reference/config.html> Cargo configuration controls target directories, source replacement, offline mode, credential providers, and cache behavior.
- `PC085` | `owner_fact` | `owner_documentation` | Cargo environment variables. <https://doc.rust-lang.org/cargo/reference/environment-variables.html> Cargo environment variables can relocate Cargo home and target output and can force offline or frozen operation.
- `PC086` | `adjacent` | `owner_issue_tracker` | Per-user compiled artifact cache. <https://github.com/rust-lang/cargo/issues/5931> An owner issue asks for or tests this boundary: Per-user compiled artifact cache.
- `PC087` | `core` | `owner_issue_tracker` | `cargo clean --offline` fails. <https://github.com/rust-lang/cargo/issues/12989> A reporter describes this concrete behavior: `cargo clean --offline` fails.
- `PC088` | `adjacent` | `owner_issue_tracker` | gc: Determine max-size use cases, and consider design changes. <https://github.com/rust-lang/cargo/issues/13062> An owner issue asks for or tests this boundary: gc: Determine max-size use cases, and consider design changes.
- `PC089` | `adjacent` | `owner_issue_tracker` | Cache usage meta tracking issue. <https://github.com/rust-lang/cargo/issues/7150> An owner issue asks for or tests this boundary: Cache usage meta tracking issue.
- `PC090` | `adjacent` | `owner_issue_tracker` | gc: get_registry_items_to_clean_size_both can orphan src directories. <https://github.com/rust-lang/cargo/issues/13063> An owner issue asks for or tests this boundary: gc: get_registry_items_to_clean_size_both can orphan src directories.
- `PC091` | `adjacent` | `owner_issue_tracker` | Add an info subcommand for `cargo clean`. <https://github.com/rust-lang/cargo/issues/13059> An owner issue asks for or tests this boundary: Add an info subcommand for `cargo clean`.
- `PC092` | `core` | `owner_issue_tracker` | Reported size of `cargo clean` is incorrect?. <https://github.com/rust-lang/cargo/issues/15823> A reporter describes this concrete behavior: Reported size of `cargo clean` is incorrect?.
- `PC093` | `adjacent` | `owner_issue_tracker` | Garbage collect whole `target/`. <https://github.com/rust-lang/cargo/issues/13136> An owner issue asks for or tests this boundary: Garbage collect whole `target/`.
- `PC094` | `adjacent` | `owner_issue_tracker` | gc: Determine CLI design for manual cleaning. <https://github.com/rust-lang/cargo/issues/13060> An owner issue asks for or tests this boundary: gc: Determine CLI design for manual cleaning.
- `PC095` | `adjacent` | `owner_issue_tracker` | Tracking Issue for garbage collection. <https://github.com/rust-lang/cargo/issues/12633> An owner issue asks for or tests this boundary: Tracking Issue for garbage collection.
- `PC096` | `adjacent` | `owner_issue_tracker` | Decide if `CARGO_HOME` is truly cache or not. <https://github.com/rust-lang/cargo/issues/10252> An owner issue asks for or tests this boundary: Decide if `CARGO_HOME` is truly cache or not.
- `PC097` | `adjacent` | `owner_issue_tracker` | Pin cache entries still in use. <https://github.com/rust-lang/cargo/issues/13137> An owner issue asks for or tests this boundary: Pin cache entries still in use.
- `PC098` | `core` | `owner_issue_tracker` | Multiple simultaneous `cargo build`s that depend on the same git repo can fail. <https://github.com/rust-lang/cargo/issues/15267> A reporter describes this concrete behavior: Multiple simultaneous `cargo build`s that depend on the same git repo can fail.
- `PC099` | `adjacent` | `owner_issue_tracker` | A way to verify the integrity of caches. <https://github.com/rust-lang/cargo/issues/16850> An owner issue asks for or tests this boundary: A way to verify the integrity of caches.

### Gradle

- `PC100` | `owner_fact` | `owner_documentation` | Gradle directory layout. <https://docs.gradle.org/current/userguide/directory_layout.html> Gradle separates project build output from Gradle User Home caches, wrapper distributions, daemon state, and version-specific files.
- `PC101` | `owner_fact` | `owner_documentation` | Gradle dependency caching. <https://docs.gradle.org/current/userguide/dependency_caching.html> Gradle stores downloaded artifacts and metadata under checksum-based paths and supports offline cache use.
- `PC102` | `owner_fact` | `owner_documentation` | Gradle build cache. <https://docs.gradle.org/current/userguide/build_cache.html> Gradle's build cache reuses task outputs locally or remotely and differs from the dependency cache.
- `PC103` | `owner_fact` | `owner_documentation` | Gradle dependency locking. <https://docs.gradle.org/current/userguide/dependency_locking.html> Gradle lock state records resolved dependency versions and is part of reproducible builds.
- `PC104` | `owner_fact` | `owner_documentation` | Gradle wrapper. <https://docs.gradle.org/current/userguide/gradle_wrapper.html> The wrapper downloads and stores a named Gradle distribution, which is separate from project dependencies.
- `PC105` | `owner_fact` | `owner_documentation` | Gradle configuration cache. <https://docs.gradle.org/current/userguide/configuration_cache.html> The configuration cache stores serialized task graph state and has different invalidation and cleanup rules from task outputs.
- `PC106` | `core` | `owner_issue_tracker` | `ProjectBuilder` silently bypasses the dependency cache, causing full re-downloads per test run - now triggers Maven Central 429 blocks. <https://github.com/gradle/gradle/issues/38915> A reporter describes this concrete behavior: `ProjectBuilder` silently bypasses the dependency cache, causing full re-downloads per test run - now triggers Maven Central 429 blocks.
- `PC107` | `adjacent` | `owner_issue_tracker` | Provide size-based threshold to trigger cache auto-cleaning. <https://github.com/gradle/gradle/issues/35133> An owner issue asks for or tests this boundary: Provide size-based threshold to trigger cache auto-cleaning.
- `PC108` | `core` | `owner_issue_tracker` | Gradle build stuck and consume all disk space. <https://github.com/gradle/gradle/issues/21175> A reporter describes this concrete behavior: Gradle build stuck and consume all disk space.
- `PC109` | `adjacent` | `owner_issue_tracker` | Support cache cleaning from CLI. <https://github.com/gradle/gradle/issues/37849> An owner issue asks for or tests this boundary: Support cache cleaning from CLI.
- `PC110` | `adjacent` | `owner_issue_tracker` | Make localhost repositories accessible with --offline. <https://github.com/gradle/gradle/issues/12988> An owner issue asks for or tests this boundary: Make localhost repositories accessible with --offline.
- `PC111` | `core` | `owner_issue_tracker` | File locking fails on ExFAT SD card. <https://github.com/gradle/gradle/issues/4329> A reporter describes this concrete behavior: File locking fails on ExFAT SD card.
- `PC112` | `core` | `owner_issue_tracker` | With CC enabled no dependency lock state should be persisted on build failure. <https://github.com/gradle/gradle/issues/36733> A reporter describes this concrete behavior: With CC enabled no dependency lock state should be persisted on build failure.
- `PC113` | `adjacent` | `owner_issue_tracker` | Clean up old configuration cache reports. <https://github.com/gradle/gradle/issues/36663> An owner issue asks for or tests this boundary: Clean up old configuration cache reports.
- `PC114` | `core` | `owner_issue_tracker` | TestKit timeouts waiting to lock Generated Gradle JARs cache. <https://github.com/gradle/gradle/issues/35592> A reporter describes this concrete behavior: TestKit timeouts waiting to lock Generated Gradle JARs cache.
- `PC115` | `adjacent` | `owner_issue_tracker` | Review version-bound and cross-version global caches. <https://github.com/gradle/gradle/issues/27145> An owner issue asks for or tests this boundary: Review version-bound and cross-version global caches.
- `PC116` | `adjacent` | `owner_issue_tracker` | Allow the location of the Gradle cache to be specified independent of the user configuration files. <https://github.com/gradle/gradle/issues/1319> An owner issue asks for or tests this boundary: Allow the location of the Gradle cache to be specified independent of the user configuration files.
- `PC117` | `core` | `owner_issue_tracker` | GRADLE_RO_DEP_CACHE is recognized, but no artifacts are found. <https://github.com/gradle/gradle/issues/22849> A reporter describes this concrete behavior: GRADLE_RO_DEP_CACHE is recognized, but no artifacts are found.
- `PC118` | `core` | `owner_issue_tracker` | Configuration cache size published in build scans does not include entry/fingerprint sizes. <https://github.com/gradle/gradle/issues/30809> A reporter describes this concrete behavior: Configuration cache size published in build scans does not include entry/fingerprint sizes.
- `PC119` | `core` | `owner_issue_tracker` | Configuration Cache should not consider dynamic dependencies expired if used with --offline. <https://github.com/gradle/gradle/issues/32837> A reporter describes this concrete behavior: Configuration Cache should not consider dynamic dependencies expired if used with --offline.
- `PC120` | `adjacent` | `owner_issue_tracker` | Allow Gradle User Home cleanup to be configured via properties file. <https://github.com/gradle/gradle/issues/37184> An owner issue asks for or tests this boundary: Allow Gradle User Home cleanup to be configured via properties file.

### Swift Package Manager

- `PC121` | `owner_fact` | `owner_source` | SwiftPM package purge-cache command. <https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageManagerDocs/Documentation.docc/Package/PackagePurgeCache.md> SwiftPM provides an owner command to purge shared repository and manifest caches while leaving project output as a separate concern.
- `PC122` | `owner_fact` | `owner_repository_documentation` | SwiftPM package registry usage. <https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md> SwiftPM supports registry downloads and configuration alongside source-control dependencies.
- `PC123` | `owner_fact` | `owner_source` | SwiftPM workspace source. <https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Workspace/Workspace.swift> The workspace tracks managed dependencies, repositories, checkouts, artifacts, and state under owner-defined locations.
- `PC124` | `owner_fact` | `owner_source` | SwiftPM resolved-packages source. <https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Workspace/Workspace%2BResolvedPackages.swift> SwiftPM reads and writes resolved package state separately from downloaded checkouts and build output.
- `PC125` | `owner_fact` | `owner_source` | SwiftPM binary-artifacts source. <https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Workspace/Workspace%2BBinaryArtifacts.swift> SwiftPM downloads, validates, extracts, and tracks binary artifacts as managed workspace objects.
- `PC126` | `owner_fact` | `owner_source` | SwiftPM source-control workspace source. <https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Workspace/Workspace%2BSourceControl.swift> SwiftPM manages repository caches and working checkouts as distinct source-control objects.
- `PC127` | `core` | `owner_issue_tracker` | `swift build` release-mode rebuild using previously cached `.build` fails with `error: undefined reference to 'xxx'`. <https://github.com/swiftlang/swift-package-manager/issues/8260> A reporter describes this concrete behavior: `swift build` release-mode rebuild using previously cached `.build` fails with `error: undefined reference to 'xxx'`.
- `PC128` | `core` | `owner_issue_tracker` | SwiftPM requires downloading entire git repository, which can be much larger than necessary. <https://github.com/swiftlang/swift-package-manager/issues/6062> A reporter describes this concrete behavior: SwiftPM requires downloading entire git repository, which can be much larger than necessary.
- `PC129` | `core` | `owner_issue_tracker` | Long cache retrieval when resolving dependencies. <https://github.com/swiftlang/swift-package-manager/issues/8123> A reporter describes this concrete behavior: Long cache retrieval when resolving dependencies.
- `PC130` | `core` | `owner_issue_tracker` | [SR-8262] Swift Package Manager fails at checkout when dependent repository contains Git LFS objects. <https://github.com/swiftlang/swift-package-manager/issues/5351> A reporter describes this concrete behavior: [SR-8262] Swift Package Manager fails at checkout when dependent repository contains Git LFS objects.
- `PC131` | `core` | `owner_issue_tracker` | Build can overlap with resolve packages resulting in corrupted dependencies checkouts. <https://github.com/swiftlang/swift-package-manager/issues/6643> A reporter describes this concrete behavior: Build can overlap with resolve packages resulting in corrupted dependencies checkouts.
- `PC132` | `core` | `owner_issue_tracker` | [SR-7982] Swift build forces recompilation with Makefile. <https://github.com/swiftlang/swift-package-manager/issues/5353> A reporter describes this concrete behavior: [SR-7982] Swift build forces recompilation with Makefile.
- `PC133` | `core` | `owner_issue_tracker` | SwiftPM unconditionally rebuilds artefacts that should be cached for command plugins. <https://github.com/swiftlang/swift-package-manager/issues/7210> A reporter describes this concrete behavior: SwiftPM unconditionally rebuilds artefacts that should be cached for command plugins.
- `PC134` | `adjacent` | `owner_issue_tracker` | Cross package build caching. <https://github.com/swiftlang/swift-package-manager/issues/7234> An owner issue asks for or tests this boundary: Cross package build caching.
- `PC135` | `core` | `owner_issue_tracker` | [SR-13484] Use `--no-checkout` when cloning packages, since it's immediately followed by a `checkout` anyway. <https://github.com/swiftlang/swift-package-manager/issues/4503> A reporter describes this concrete behavior: [SR-13484] Use `--no-checkout` when cloning packages, since it's immediately followed by a `checkout` anyway.
- `PC136` | `core` | `owner_issue_tracker` | `.binaryTarget` gives an unhelpful error if a zip file on disk ends in `.artifactbundle`. <https://github.com/swiftlang/swift-package-manager/issues/10077> A reporter describes this concrete behavior: `.binaryTarget` gives an unhelpful error if a zip file on disk ends in `.artifactbundle`.
- `PC137` | `core` | `owner_issue_tracker` | `dump-symbol-graph` / plugin `getSymbolGraph` force-enable all traits, downloading binary artifacts for trait-gated dependencies the user disabled. <https://github.com/swiftlang/swift-package-manager/issues/10448> A reporter describes this concrete behavior: `dump-symbol-graph` / plugin `getSymbolGraph` force-enable all traits, downloading binary artifacts for trait-gated dependencies the user disabled.
- `PC138` | `core` | `owner_issue_tracker` | `Context.gitInformation` is stale in incremental builds. <https://github.com/swiftlang/swift-package-manager/issues/8202> A reporter describes this concrete behavior: `Context.gitInformation` is stale in incremental builds.
- `PC139` | `adjacent` | `owner_issue_tracker` | Build: binary-target framework paths are emitted in hash-seeded order, so every plan regeneration recompiles all xcframework-dependent modules (llbuild counterpart of #10345/#10353). <https://github.com/swiftlang/swift-package-manager/issues/10451> An owner issue asks for or tests this boundary: Build: binary-target framework paths are emitted in hash-seeded order, so every plan regeneration recompiles all xcframework-dependent modules (llbuild counterpart of #10345/#10353).
- `PC140` | `core` | `owner_issue_tracker` | SwiftPM tries to build _everything_ instead of just what is needed for `swift test` or `swift build --product XYZ`. <https://github.com/swiftlang/swift-package-manager/issues/9272> A reporter describes this concrete behavior: SwiftPM tries to build _everything_ instead of just what is needed for `swift test` or `swift build --product XYZ`.

### CocoaPods

- `PC141` | `owner_fact` | `owner_documentation` | CocoaPods command guide. <https://guides.cocoapods.org/terminal/commands.html> CocoaPods documents cache list and cache clean commands, repo maintenance, install, update, and deintegrate as separate operations.
- `PC142` | `owner_fact` | `owner_documentation` | CocoaPods install versus update guide. <https://guides.cocoapods.org/using/pod-install-vs-update.html> CocoaPods says Podfile.lock controls repeat installation while pod update intentionally changes selected versions.
- `PC143` | `owner_fact` | `owner_source` | CocoaPods cache command source. <https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/command/cache.rb> The cache command owns list and clean subcommands for downloaded pods.
- `PC144` | `owner_fact` | `owner_source` | CocoaPods cache-clean source. <https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/command/cache/clean.rb> The clean command can remove all cached pods or scoped pod versions and has an all flag.
- `PC145` | `owner_fact` | `owner_source` | CocoaPods downloader-cache source. <https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/downloader/cache.rb> CocoaPods stores downloaded source by request slug and uses staging and versioned cache paths.
- `PC146` | `owner_fact` | `owner_source` | CocoaPods pod directory cleaner source. <https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/sandbox/pod_dir_cleaner.rb> CocoaPods has project-sandbox cleanup rules that preserve paths selected by pod specifications.
- `PC147` | `core` | `owner_issue_tracker` | Concurrent building occasionally cleans the Pods cache directory. <https://github.com/CocoaPods/CocoaPods/issues/11826> A reporter describes this concrete behavior: Concurrent building occasionally cleans the Pods cache directory.
- `PC148` | `core` | `owner_issue_tracker` | `repo push` caches revision of git tag. <https://github.com/CocoaPods/CocoaPods/issues/8829> A reporter describes this concrete behavior: `repo push` caches revision of git tag.
- `PC149` | `core` | `owner_issue_tracker` | Pod cache automatically clean on CI machine. <https://github.com/CocoaPods/CocoaPods/issues/9864> A reporter describes this concrete behavior: Pod cache automatically clean on CI machine.
- `PC150` | `core` | `owner_issue_tracker` | podinstall : repo repeat download. <https://github.com/CocoaPods/CocoaPods/issues/11756> A reporter describes this concrete behavior: podinstall : repo repeat download.
- `PC151` | `core` | `owner_issue_tracker` | pod install --repo-update command fails. <https://github.com/CocoaPods/CocoaPods/issues/11944> A reporter describes this concrete behavior: pod install --repo-update command fails.
- `PC152` | `core` | `owner_issue_tracker` | Installation of a lot (100+) pods from a single (private) repo takes a long time. <https://github.com/CocoaPods/CocoaPods/issues/11171> A reporter describes this concrete behavior: Installation of a lot (100+) pods from a single (private) repo takes a long time.
- `PC153` | `core` | `owner_issue_tracker` | Local Podspec may got wrong cache. <https://github.com/CocoaPods/CocoaPods/issues/9358> A reporter describes this concrete behavior: Local Podspec may got wrong cache.
- `PC154` | `core` | `owner_issue_tracker` | Local cache directory may be empty. <https://github.com/CocoaPods/CocoaPods/issues/10452> A reporter describes this concrete behavior: Local cache directory may be empty.
- `PC155` | `adjacent` | `owner_issue_tracker` | Add command for validating the cache. <https://github.com/CocoaPods/CocoaPods/issues/10053> An owner issue asks for or tests this boundary: Add command for validating the cache.
- `PC156` | `core` | `owner_issue_tracker` | Pod lib lint do not currectly copy pod from Caches to build folder. <https://github.com/CocoaPods/CocoaPods/issues/12544> A reporter describes this concrete behavior: Pod lib lint do not currectly copy pod from Caches to build folder.
- `PC157` | `core` | `owner_issue_tracker` | Cocoapods Won't Download Source if Podfile Uses `:path` or `:git` to Refer to Podspec File. <https://github.com/CocoaPods/CocoaPods/issues/11867> A reporter describes this concrete behavior: Cocoapods Won't Download Source if Podfile Uses `:path` or `:git` to Refer to Podspec File.
- `PC158` | `core` | `owner_issue_tracker` | pod_dir_cleaner keeps files that should be cleaned. <https://github.com/CocoaPods/CocoaPods/issues/11742> A reporter describes this concrete behavior: pod_dir_cleaner keeps files that should be cleaned.
- `PC159` | `core` | `owner_issue_tracker` | Pod install with verbose option should also include verbose option of git clone repo. <https://github.com/CocoaPods/CocoaPods/issues/11492> A reporter describes this concrete behavior: Pod install with verbose option should also include verbose option of git clone repo.
- `PC160` | `core` | `owner_issue_tracker` | >=1.16 cocoapods Podfile.lock hash mismatch on git worktree repo VS non worktree. <https://github.com/CocoaPods/CocoaPods/issues/12741> A reporter describes this concrete behavior: >=1.16 cocoapods Podfile.lock hash mismatch on git worktree repo VS non worktree.
- `PC161` | `adjacent` | `owner_issue_tracker` | Allow different versions of CocoaPods to use the same cache (at the same time). <https://github.com/CocoaPods/CocoaPods/issues/10030> An owner issue asks for or tests this boundary: Allow different versions of CocoaPods to use the same cache (at the same time).
- `PC162` | `core` | `owner_issue_tracker` | `pod cache list` print incorrect pod path. <https://github.com/CocoaPods/CocoaPods/issues/8422> A reporter describes this concrete behavior: `pod cache list` print incorrect pod path.

### pip

- `PC163` | `owner_fact` | `owner_documentation` | pip caching topic. <https://pip.pypa.io/en/stable/topics/caching/> pip documents separate HTTP and locally built wheel caches and warns that cached wheels may encode optional build results.
- `PC164` | `owner_fact` | `owner_documentation` | pip cache command. <https://pip.pypa.io/en/stable/cli/pip_cache/> pip cache provides dir, info, list, remove, and purge owner commands for wheel and HTTP cache data.
- `PC165` | `owner_fact` | `owner_documentation` | pip install command. <https://pip.pypa.io/en/stable/cli/pip_install/> pip install resolves, builds, and installs packages from indexes, archives, local projects, VCS, and requirements files.
- `PC166` | `owner_fact` | `owner_documentation` | pip download command. <https://pip.pypa.io/en/stable/cli/pip_download/> pip download can collect distributions for later offline installation without installing them.
- `PC167` | `owner_fact` | `owner_documentation` | pip repeatable installs. <https://pip.pypa.io/en/stable/topics/repeatable-installs/> pip recommends pinned requirements, hashes, wheelhouses, and lock-style inputs for repeatable installation.
- `PC168` | `owner_fact` | `owner_documentation` | pip wheel command. <https://pip.pypa.io/en/stable/cli/pip_wheel/> pip wheel builds wheel archives for requirements and can populate a reusable wheelhouse.
- `PC169` | `core` | `owner_issue_tracker` | `pip install` can cache invalid wheels when the cache directory fills up. <https://github.com/pypa/pip/issues/9964> A reporter describes this concrete behavior: `pip install` can cache invalid wheels when the cache directory fills up.
- `PC170` | `adjacent` | `owner_issue_tracker` | Possible to add option limit wheel cache size?. <https://github.com/pypa/pip/issues/3138> An owner issue asks for or tests this boundary: Possible to add option limit wheel cache size?.
- `PC171` | `core` | `owner_issue_tracker` | List HTTP caches as well in `pip cache list`. <https://github.com/pypa/pip/issues/10460> A reporter describes this concrete behavior: List HTTP caches as well in `pip cache list`.
- `PC172` | `core` | `owner_issue_tracker` | Cache wheel files retrieved from HTTP cache. <https://github.com/pypa/pip/issues/12588> A reporter describes this concrete behavior: Cache wheel files retrieved from HTTP cache.
- `PC173` | `adjacent` | `owner_issue_tracker` | Should 'pip cache purge' remove more than wheel files?. <https://github.com/pypa/pip/issues/7372> An owner issue asks for or tests this boundary: Should 'pip cache purge' remove more than wheel files?.
- `PC174` | `core` | `owner_issue_tracker` | pip install "offline mode". <https://github.com/pypa/pip/issues/8057> A reporter describes this concrete behavior: pip install "offline mode".
- `PC175` | `adjacent` | `owner_issue_tracker` | Option to cache git clones, LRU cache. <https://github.com/pypa/pip/issues/9665> An owner issue asks for or tests this boundary: Option to cache git clones, LRU cache.
- `PC176` | `adjacent` | `owner_issue_tracker` | Do something about cache housekeeping?. <https://github.com/pypa/pip/issues/6956> An owner issue asks for or tests this boundary: Do something about cache housekeeping?.
- `PC177` | `adjacent` | `owner_issue_tracker` | Consider `--config-settings` in wheel cache keys. <https://github.com/pypa/pip/issues/11164> An owner issue asks for or tests this boundary: Consider `--config-settings` in wheel cache keys.
- `PC178` | `core` | `owner_issue_tracker` | concurrent pip-install fails to build wheel due to race. <https://github.com/pypa/pip/issues/9034> A reporter describes this concrete behavior: concurrent pip-install fails to build wheel due to race.
- `PC179` | `adjacent` | `owner_issue_tracker` | Document shared cache dir. <https://github.com/pypa/pip/issues/11032> An owner issue asks for or tests this boundary: Document shared cache dir.
- `PC180` | `core` | `owner_issue_tracker` | Display path to corrupted files when pip fails to load wheel. <https://github.com/pypa/pip/issues/13147> A reporter describes this concrete behavior: Display path to corrupted files when pip fails to load wheel.
- `PC181` | `core` | `owner_issue_tracker` | Cache wheels built from VCS branches and tags. <https://github.com/pypa/pip/issues/11166> A reporter describes this concrete behavior: Cache wheels built from VCS branches and tags.
- `PC182` | `core` | `owner_issue_tracker` | no-cache-dir is not respected for deps that require building. <https://github.com/pypa/pip/issues/12031> A reporter describes this concrete behavior: no-cache-dir is not respected for deps that require building.
- `PC183` | `core` | `owner_issue_tracker` | pip should not cache large files in /tmp or TMPDIR. <https://github.com/pypa/pip/issues/12868> A reporter describes this concrete behavior: pip should not cache large files in /tmp or TMPDIR.
- `PC184` | `core` | `owner_issue_tracker` | Pip will use a corrupt HTTP cache. <https://github.com/pypa/pip/issues/3792> A reporter describes this concrete behavior: Pip will use a corrupt HTTP cache.

### uv

- `PC185` | `owner_fact` | `owner_documentation` | uv cache documentation. <https://docs.astral.sh/uv/concepts/cache/> uv uses a versioned cache and documents clean, prune, cache keys, dynamic metadata, and cache safety.
- `PC186` | `owner_fact` | `owner_documentation` | uv command reference. <https://docs.astral.sh/uv/reference/cli/> uv's CLI reference defines cache clean, prune, dir, size, and temporary no-cache behavior.
- `PC187` | `owner_fact` | `owner_documentation` | uv environment variables. <https://docs.astral.sh/uv/reference/environment/> uv variables control cache location, link mode, offline behavior, managed Python storage, and project environments.
- `PC188` | `owner_fact` | `owner_documentation` | uv Docker integration guide. <https://docs.astral.sh/uv/guides/integration/docker/> uv's Docker guide separates mounted caches from installed environments and warns against persisting editable project installs in cache layers.
- `PC189` | `owner_fact` | `owner_documentation` | uv project sync documentation. <https://docs.astral.sh/uv/concepts/projects/sync/> uv sync manages a project environment from lock and project metadata, with exact and inexact sync choices.
- `PC190` | `owner_fact` | `owner_documentation` | uv tool environments documentation. <https://docs.astral.sh/uv/concepts/tools/> uv tools use isolated environments and cache-managed executables that are installed state, not ordinary download cache.
- `PC191` | `core` | `owner_issue_tracker` | `UV_LINK_MODE=hardlink` does not work with bind mounts. <https://github.com/astral-sh/uv/issues/17962> A reporter describes this concrete behavior: `UV_LINK_MODE=hardlink` does not work with bind mounts.
- `PC192` | `core` | `owner_issue_tracker` | uv 0.10.5 performance regression due to change in default link mode to clone/reflink on Linux. <https://github.com/astral-sh/uv/issues/18259> A reporter describes this concrete behavior: uv 0.10.5 performance regression due to change in default link mode to clone/reflink on Linux.
- `PC193` | `adjacent` | `owner_issue_tracker` | uv cache {clean, prune} fails with os error 63. <https://github.com/astral-sh/uv/issues/15569> An owner issue asks for or tests this boundary: uv cache {clean, prune} fails with os error 63.
- `PC194` | `adjacent` | `owner_issue_tracker` | Should/make `uv cache prune` delete packages that are not used anywhere via link count. <https://github.com/astral-sh/uv/issues/16008> An owner issue asks for or tests this boundary: Should/make `uv cache prune` delete packages that are not used anywhere via link count.
- `PC195` | `adjacent` | `owner_issue_tracker` | Failed to hardlink files with cache and target on same filesystem. <https://github.com/astral-sh/uv/issues/15149> An owner issue asks for or tests this boundary: Failed to hardlink files with cache and target on same filesystem.
- `PC196` | `adjacent` | `owner_issue_tracker` | How to prefer cached package version?. <https://github.com/astral-sh/uv/issues/16108> An owner issue asks for or tests this boundary: How to prefer cached package version?.
- `PC197` | `adjacent` | `owner_issue_tracker` | Set `UV_CACHE_DIR` for different drives. <https://github.com/astral-sh/uv/issues/15878> An owner issue asks for or tests this boundary: Set `UV_CACHE_DIR` for different drives.
- `PC198` | `adjacent` | `owner_issue_tracker` | Document strategies for sharing the cache. <https://github.com/astral-sh/uv/issues/5611> An owner issue asks for or tests this boundary: Document strategies for sharing the cache.
- `PC199` | `adjacent` | `owner_issue_tracker` | Feature req: cache auto-prune. <https://github.com/astral-sh/uv/issues/8908> An owner issue asks for or tests this boundary: Feature req: cache auto-prune.
- `PC200` | `adjacent` | `owner_issue_tracker` | uv run appears to hold the cache lock for its entire lifetime, blocking uv cache prune. <https://github.com/astral-sh/uv/issues/19317> An owner issue asks for or tests this boundary: uv run appears to hold the cache lock for its entire lifetime, blocking uv cache prune.
- `PC201` | `core` | `owner_issue_tracker` | uvx offline fallback mode?. <https://github.com/astral-sh/uv/issues/10380> A reporter describes this concrete behavior: uvx offline fallback mode?.
- `PC202` | `core` | `owner_issue_tracker` | uv cache size limit. <https://github.com/astral-sh/uv/issues/5731> A reporter describes this concrete behavior: uv cache size limit.
- `PC203` | `adjacent` | `owner_issue_tracker` | Feature: Named, shared environments independent of a project directory. <https://github.com/astral-sh/uv/issues/20247> An owner issue asks for or tests this boundary: Feature: Named, shared environments independent of a project directory.
- `PC204` | `core` | `owner_issue_tracker` | uv cache management strategies for always-growing caches?. <https://github.com/astral-sh/uv/issues/9790> A reporter describes this concrete behavior: uv cache management strategies for always-growing caches?.
- `PC205` | `adjacent` | `owner_issue_tracker` | Support proactive cache pruning. <https://github.com/astral-sh/uv/issues/16761> An owner issue asks for or tests this boundary: Support proactive cache pruning.
- `PC206` | `core` | `owner_issue_tracker` | Dependency resolution failed in offline mode. <https://github.com/astral-sh/uv/issues/9277> A reporter describes this concrete behavior: Dependency resolution failed in offline mode.
- `PC207` | `core` | `owner_issue_tracker` | Write `--no-cache`'s temporary cache into venv not /tmp to allow use of hardlinks in more cases. <https://github.com/astral-sh/uv/issues/11385> A reporter describes this concrete behavior: Write `--no-cache`'s temporary cache into venv not /tmp to allow use of hardlinks in more cases.
- `PC208` | `adjacent` | `owner_issue_tracker` | Build intermittently fails when uv cache is on NFS mount. <https://github.com/astral-sh/uv/issues/12036> An owner issue asks for or tests this boundary: Build intermittently fails when uv cache is on NFS mount.

### Conda

- `PC209` | `owner_fact` | `owner_documentation` | conda clean command. <https://docs.conda.io/projects/conda/en/stable/commands/clean.html> conda clean separates index cache, lock files, unused packages, tarballs, logs, and temporary files, and warns that force-pkgs-dirs can break linked environments.
- `PC210` | `owner_fact` | `owner_documentation` | conda configuration guide. <https://docs.conda.io/projects/conda/en/stable/user-guide/configuration/use-condarc.html> Conda configuration can relocate package caches and environments and control offline, safety, and linking behavior.
- `PC211` | `owner_fact` | `owner_documentation` | conda environment management guide. <https://docs.conda.io/projects/conda/en/stable/user-guide/tasks/manage-environments.html> Conda environments contain installed packages and can be recreated from environment files, explicit specs, or history with different fidelity.
- `PC212` | `owner_fact` | `owner_documentation` | conda package concepts. <https://docs.conda.io/projects/conda/en/stable/user-guide/concepts/packages.html> Conda packages are archives with metadata and files that conda links into environments from package caches.
- `PC213` | `owner_fact` | `owner_documentation` | conda install deep dive. <https://docs.conda.io/projects/conda/en/stable/dev-guide/deep-dives/install.html> Conda separates solving, fetching, extracting, linking, prefix replacement, and transaction execution.
- `PC214` | `owner_fact` | `owner_documentation` | conda create command. <https://docs.conda.io/projects/conda/en/stable/commands/create.html> conda create supports clone, offline, copy, lock-timeout, download-only, and explicit environment locations.
- `PC215` | `core` | `owner_issue_tracker` | Windows: cached locally built packages fail to install from @EXPLICIT file in offline mode. <https://github.com/conda/conda/issues/15831> A reporter describes this concrete behavior: Windows: cached locally built packages fail to install from @EXPLICIT file in offline mode.
- `PC216` | `core` | `owner_issue_tracker` | conda package` fails on Windows with FileNotFoundError during temp-dir cleanup. <https://github.com/conda/conda/issues/16539> A reporter describes this concrete behavior: conda package` fails on Windows with FileNotFoundError during temp-dir cleanup.
- `PC217` | `adjacent` | `owner_issue_tracker` | Add option to ignore cache temporarily. <https://github.com/conda/conda/issues/7741> An owner issue asks for or tests this boundary: Add option to ignore cache temporarily.
- `PC218` | `core` | `owner_issue_tracker` | Regression: `conda doctor` reports false-positive altered files for all binary prefix-replaced files. <https://github.com/conda/conda/issues/16590> A reporter describes this concrete behavior: Regression: `conda doctor` reports false-positive altered files for all binary prefix-replaced files.
- `PC219` | `core` | `owner_issue_tracker` | Missing files in conda cache should not be fatal for environment creation. <https://github.com/conda/conda/issues/13976> A reporter describes this concrete behavior: Missing files in conda cache should not be fatal for environment creation.
- `PC220` | `core` | `owner_issue_tracker` | `conda install --name` fails if I am already in the target environment. <https://github.com/conda/conda/issues/15737> A reporter describes this concrete behavior: `conda install --name` fails if I am already in the target environment.
- `PC221` | `adjacent` | `owner_issue_tracker` | Add a new pkg_env_layout configuration option. <https://github.com/conda/conda/issues/15092> An owner issue asks for or tests this boundary: Add a new pkg_env_layout configuration option.
- `PC222` | `core` | `owner_issue_tracker` | can't install any packages -- conda can't solve environment. <https://github.com/conda/conda/issues/9894> A reporter describes this concrete behavior: can't install any packages -- conda can't solve environment.
- `PC223` | `adjacent` | `owner_issue_tracker` | InvalidArchiveError("Error with archive ....). <https://github.com/conda/conda/issues/9142> An owner issue asks for or tests this boundary: InvalidArchiveError("Error with archive ....).
- `PC224` | `core` | `owner_issue_tracker` | pip-installed packages not in "conda list --explicit". <https://github.com/conda/conda/issues/8372> A reporter describes this concrete behavior: pip-installed packages not in "conda list --explicit".

## Files and validation

- `docs/research/tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md`
- `docs/research/tessera-disk-rescue-package-cache-ledger.jsonl`

Validation result: PASS. All 224 JSONL lines parse with `jq`. Every record has the required 13 fields. Record IDs run from `PC001` through `PC224` with no gap. The ledger has 224 total URLs, 224 unique URLs, 0 internal duplicates, and 0 exact overlaps with the 3,022 URLs in all 14 other current corpus inputs.
