# Tessera disk-rescue AI-model storage agent lane

Collected 2026-08-31. This lane studies local AI-model storage on macOS across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111 Stable Diffusion WebUI. It covers installed and loaded models, content-addressed blobs, cache revisions, partial downloads, model duplication, external-volume relocation, rebuild or download cost, and evidence of current use.

This is directional ethnographic evidence. Owner documentation establishes supported behavior. First-person reports show failure modes and user expectations. The reports do not establish current product behavior on every version, and this report does not estimate prevalence.

No cleanup, move, deletion, app launch, or configuration change was performed. No existing research file or ledger was edited.

## Result in one page

- 54 direct source URLs were selected. All 54 were absent from every current `*.md` and `*.jsonl` file under `docs/research` after canonical normalization.
- 29 sources are owner facts. They document paths, commands, cache structure, loaded-model probes, relocation settings, and supported deletion or import paths.
- 25 sources are first-person user reports. They describe hidden partial files, wrong-volume staging, shared blobs, confusing logical versus physical size, missing external drives, path regressions, and repeated downloads.
- The local machine does not show a current Ollama, LM Studio, ComfyUI, or Stable Diffusion model store at the common paths checked. It has a 40 KB Hugging Face Xet log cache and no open handle there.
- A 279 MB Hugging Face Hub cache is already in a dated Trash batch. It contains four old model repositories. This is historical evidence, not an active cache and not permission to delete it.
- Tessera must treat model cleanup as an owner-aware graph. A displayed model, a loaded model, a manifest, a shared blob, a revision, a partial transfer, and a model file used by another app are different objects.

## Method and novelty check

The source pass favored owner documentation for product behavior and direct first-person posts for experience. Search-result summaries were not counted as sources. Every record below points to the direct documentation, issue, discussion, or post.

The novelty check scanned all current `docs/research/*.md` and `docs/research/*.jsonl` files. It extracted HTTP and HTTPS URLs, lowercased scheme and host, removed fragments, removed trailing slash noise, and dropped common tracking parameters. The 54 selected canonical URLs were unique within this lane and had zero matches in the current corpus.

The local probe was read-only and bounded. It checked common model-store paths, installed apps and command-line tools, model-related processes, open handles, the user launch-service registry, a Spotlight query for `.gguf`, `.safetensors`, and `.ckpt`, the current Hugging Face cache, and the exact dated Trash location found in the prior disk-rescue work. Spotlight is not exhaustive because indexing can omit hidden or excluded volumes.

## Exact source counts

| Source family | Source type | Owner fact | User report | Total |
| --- | --- | ---: | ---: | ---: |
| Ollama owner documentation | Product documentation and API reference | 6 | 0 | 6 |
| Hugging Face owner documentation | Product and library documentation | 8 | 0 | 8 |
| LM Studio owner documentation | Product and CLI documentation | 6 | 0 | 6 |
| ComfyUI owner documentation and code | Product documentation and maintained config example | 6 | 0 | 6 |
| AUTOMATIC1111 owner wiki | Maintainer-owned wiki | 3 | 0 | 3 |
| Ollama GitHub Issues | First-person issue reports | 0 | 6 | 6 |
| Hugging Face GitHub Issues | First-person issue and feature reports | 0 | 5 | 5 |
| LM Studio bug tracker | First-person issue reports | 0 | 3 | 3 |
| Reddit r/LocalLLaMA | First-person questions and replies | 0 | 2 | 2 |
| Reddit r/LocalLLM | First-person failure discussion | 0 | 1 | 1 |
| ComfyUI GitHub Issues | First-person issue and feature reports | 0 | 5 | 5 |
| AUTOMATIC1111 GitHub community | First-person issues and discussions | 0 | 3 | 3 |
| **Total** |  | **29** | **25** | **54** |

Evidence-class totals are exactly 29 `owner_fact` and 25 `first_person_user_report` records.

## Current local evidence

### Common stores and current processes

- The checked Ollama, LM Studio, ComfyUI, DiffusionBee, Draw Things, and AUTOMATIC1111 application or model paths were absent. The `ollama`, `lms`, and `comfy` commands were not found.
- No matching model-server or UI process was running. No matching `.gguf`, `.safetensors`, or `.ckpt` file appeared in the bounded Spotlight result.
- The launch-service disabled registry reported `com.ollama.ollama` as enabled, but the service was not loaded, no Ollama app was found, and `~/.ollama` was absent. This is consistent with stale launch preference state. It is not proof of current Ollama use.
- `~/.cache/huggingface` used 40 KB. It held one Xet log from 2026-06-20 and no Hub model cache. No process had an open handle in this directory.
- The Xet log records a successful reconstruction of a 155,950,298-byte file for `chopratejas/kompress-base`. The transfer wrote through a `.incomplete` path before completion. This is historical transfer evidence, not proof that the model is in current use.

### Historical cache already in Trash

`~/.Trash/codex-disk-cleanup-2026-08-30-01/huggingface-hub` used 279 MB at collection time. It contained:

- `chopratejas/kompress-base`, 149 MB.
- `chopratejas/siglip-image-encoder-onnx`, 95 MB.
- `chopratejas/technique-router-onnx`, 34 MB.
- `answerdotai/ModernBERT-base`, 2.1 MB.

No `.incomplete` file was found in that trashed Hub cache. The paths contain blobs, refs, lock directories, snapshots, and negative lookup metadata. Their location in Trash means they are no longer the active default cache. It does not make permanent deletion safe or authorized.

### Local conclusion

There is no evidence of a large active local AI-model store on the checked machine today. The only identified model bytes are historical Hugging Face cache data already moved to Trash. Tessera should show this as `historical_or_trashed`, not as an urgent active-model cleanup candidate. A deeper scan should remain optional because hidden directories, unindexed external volumes, custom paths, and app-specific settings can escape the common-path probe.

## Owner facts

### O01. Ollama FAQ

- URL: https://docs.ollama.com/faq
- Source family/type: Ollama owner documentation, FAQ.
- Evidence class: `owner_fact`.
- Observed behavior: On macOS the default model directory is `~/.ollama/models`. `OLLAMA_MODELS` selects another directory, and app-launched environment variables must be set where the app process can read them.
- Product implication: Resolve the running process environment and the configured store before scanning. Do not assume the shell and app use the same path.
- Quality caveat: Current owner documentation, but it does not prove which path a specific running process has opened.

### O02. Ollama CLI reference

- URL: https://docs.ollama.com/cli
- Source family/type: Ollama owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: `ollama pull`, `ollama rm`, `ollama ls`, and `ollama ps` separate downloading, logical removal, installed-model inventory, and loaded-model inventory.
- Product implication: Tessera needs separate installed and loaded states. It should route removal through Ollama after a fresh `ls` and `ps` probe.
- Quality caveat: The reference documents commands, not raw blob reclamation or hidden partial-file handling.

### O03. Ollama list-models API

- URL: https://docs.ollama.com/api/tags
- Source family/type: Ollama owner documentation, local API reference.
- Evidence class: `owner_fact`.
- Observed behavior: `/api/tags` returns logical models with name, digest, modified time, total size, format, family, parameter size, and quantization.
- Product implication: Use the API as the owner inventory and retain digest plus quantization as model identity. Do not infer inventory only from filenames.
- Quality caveat: Reported logical size can overlap shared blobs and does not equal independently reclaimable bytes.

### O04. Ollama running-models API

- URL: https://docs.ollama.com/api/ps
- Source family/type: Ollama owner documentation, local API reference.
- Evidence class: `owner_fact`.
- Observed behavior: `/api/ps` returns models currently loaded with expiry, context length, total size, and VRAM size.
- Product implication: A cleanup candidate must be checked against current loaded state immediately before action. Loaded and merely installed are not the same risk.
- Quality caveat: A momentary API response cannot prove future use or references from a stopped client.

### O05. Ollama delete-model API

- URL: https://docs.ollama.com/api/delete
- Source family/type: Ollama owner documentation, local API reference.
- Evidence class: `owner_fact`.
- Observed behavior: The supported delete endpoint accepts a logical model name and returns success after owner-managed deletion.
- Product implication: Tessera should call or guide the owner delete operation. It should not delete manifests or blobs directly.
- Quality caveat: The page does not promise a specific freed-byte result because blobs can be shared.

### O06. Ollama pull-model API

- URL: https://docs.ollama.com/api/pull
- Source family/type: Ollama owner documentation, local API reference.
- Evidence class: `owner_fact`.
- Observed behavior: Pull is a streamed transaction that resolves a model name and downloads its required content.
- Product implication: Record pull state, model identity, expected content, and progress as one transfer. An interrupted pull is not an installed model.
- Quality caveat: The API page does not define a public cleanup interface for every partial file left by an interrupted transfer.

### O07. Hugging Face cache guide

- URL: https://huggingface.co/docs/huggingface_hub/guides/manage-cache
- Source family/type: Hugging Face owner documentation, cache guide.
- Evidence class: `owner_fact`.
- Observed behavior: The Hub uses a file cache and an Xet cache. Repository revisions point to content-addressed blobs, old revisions stay until cleaned, and current `hf cache prune` can remove detached revisions and incomplete downloads with a preview.
- Product implication: Build a revision-to-blob graph, surface incomplete files separately, and preserve a dry-run preview before any owner cleanup.
- Quality caveat: The exact CLI behavior is version-sensitive. Older installations can lack the current incomplete-file support.

### O08. Hugging Face environment variables

- URL: https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables
- Source family/type: Hugging Face owner documentation, configuration reference.
- Evidence class: `owner_fact`.
- Observed behavior: `HF_HOME` holds token and cache state, while `HF_HUB_CACHE`, `HF_XET_CACHE`, and `HF_ASSETS_CACHE` can relocate narrower stores. Variables are read when the library imports.
- Product implication: Prefer store-specific relocation. Moving all of `HF_HOME` can also move credentials, so Tessera must not treat it as a model-only directory.
- Quality caveat: Downstream tools can override `cache_dir` per call and bypass the environment defaults.

### O09. Hugging Face download guide

- URL: https://huggingface.co/docs/huggingface_hub/guides/download
- Source family/type: Hugging Face owner documentation, download guide.
- Evidence class: `owner_fact`.
- Observed behavior: Downloads can use the shared cache or a custom `cache_dir`. A `local_dir` gets its own `.cache/huggingface` metadata, and deleting that metadata can increase later recovery time without deleting the downloaded files.
- Product implication: Scan both the shared cache and project-local metadata. Explain the next-download cost before removing either.
- Quality caveat: The guide covers supported helpers, not every third-party downloader that uses Hugging Face files.

### O10. Hugging Face CLI reference

- URL: https://huggingface.co/docs/huggingface_hub/package_reference/cli
- Source family/type: Hugging Face owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: The CLI can list, verify, remove, and prune cache entries, select an alternate cache directory, emit machine-readable output, and preview destructive work.
- Product implication: Tessera should prefer the current CLI inventory and dry-run output, then compare it with filesystem allocation and incomplete-file state.
- Quality caveat: CLI inventory has had version-specific accounting defects, so it cannot be the only byte measurement.

### O11. Hugging Face cache-system reference

- URL: https://huggingface.co/docs/huggingface_hub/main/en/package_reference/cache
- Source family/type: Hugging Face owner documentation, API reference.
- Evidence class: `owner_fact`.
- Observed behavior: Cache records distinguish repositories, revisions, files, shared blobs, and `CachedIncompleteFileInfo`. Expected freed size comes from a deletion strategy rather than a sum of displayed revision sizes.
- Product implication: Model incomplete files as first-class records and compute reclaimable bytes from the reference graph.
- Quality caveat: This is the main branch reference and can be newer than the library installed on the user's Mac.

### O12. Transformers installation and cache setup

- URL: https://huggingface.co/docs/transformers/installation
- Source family/type: Hugging Face owner documentation, Transformers guide.
- Evidence class: `owner_fact`.
- Observed behavior: `from_pretrained()` caches a model, checks for an updated version, and downloads a newer revision when needed. Environment variables can relocate the cache or force offline use.
- Product implication: Rebuild cost includes the exact revision, network access, and any gated-model authorization, not only file size.
- Quality caveat: This describes Transformers. Diffusers, Datasets, and third-party apps can add other stores.

### O13. Datasets cache management

- URL: https://huggingface.co/docs/datasets/cache
- Source family/type: Hugging Face owner documentation, Datasets guide.
- Evidence class: `owner_fact`.
- Observed behavior: Datasets separates raw Hub downloads from processed Arrow cache data. `HF_DATASETS_CACHE` changes only processed data, while `HF_HOME` or `HF_HUB_CACHE` changes other locations.
- Product implication: Do not label the whole Hugging Face tree as model weights. Show owner and data class for each store.
- Quality caveat: Dataset caches are adjacent AI storage, but they are not local model files.

### O14. Hugging Face Hub local-cache specification

- URL: https://github.com/huggingface/hub-docs/blob/main/docs/hub/local-cache.md
- Source family/type: Hugging Face owner documentation source, language-neutral cache specification.
- Evidence class: `owner_fact`.
- Observed behavior: The shared layout uses repository directories, blobs, snapshots, refs, locks, and negative lookups. Several libraries and apps can share this layout.
- Product implication: Detect one physical blob referenced by several tools or revisions. A path count is not a duplicate-byte count.
- Quality caveat: Tool-specific implementations can lag or deviate from the current specification.

### O15. LM Studio model download guide

- URL: https://lmstudio.ai/docs/app/basics/download-model
- Source family/type: LM Studio owner documentation, app guide.
- Evidence class: `owner_fact`.
- Observed behavior: LM Studio downloads supported Hugging Face models, presents several quantizations, and lets the user change the models directory from My Models.
- Product implication: Record model format and quantization, and read the app-selected directory before scanning the default path.
- Quality caveat: The page does not document every temporary or metadata directory used during a download.

### O16. LM Studio import-model guide

- URL: https://lmstudio.ai/docs/app/advanced/import-model
- Source family/type: LM Studio owner documentation, app guide.
- Evidence class: `owner_fact`.
- Observed behavior: Imported GGUF files use a publisher, model, and file hierarchy under the selected models directory.
- Product implication: Preserve the hierarchy when identifying or relocating an imported model. A loose GGUF file may not be app-visible.
- Quality caveat: The guide marks the CLI import flow as experimental and can change.

### O17. LM Studio local-model inventory

- URL: https://lmstudio.ai/docs/cli/local-models/ls
- Source family/type: LM Studio owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: `lms ls` lists downloaded models with size, architecture, parameters, type, details, and JSON output.
- Product implication: Use `lms ls --json` as the owner inventory and compare its sum with physical allocation.
- Quality caveat: It covers models known to LM Studio, not unrelated GGUF files or hidden download staging.

### O18. LM Studio model download CLI

- URL: https://lmstudio.ai/docs/cli/local-models/get
- Source family/type: LM Studio owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: `lms get` downloads a selected model and quantization into the current LM Studio model directory.
- Product implication: Save the exact model and quantization needed for a rebuild. A generic model family name is not enough.
- Quality caveat: The page does not document resume files or how failed downloads reserve space.

### O19. LM Studio model import CLI

- URL: https://lmstudio.ai/docs/cli/local-models/import
- Source family/type: LM Studio owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: Import can move, copy, hard-link, or symbolic-link a model. It also has a dry-run mode. The default action is move.
- Product implication: Detect link type and inode before calling two paths duplicates. Use dry-run before an import or relocation proposal.
- Quality caveat: Hard links cannot cross volumes, symbolic links can break, and the experimental command may change.

### O20. LM Studio loaded-model inventory

- URL: https://lmstudio.ai/docs/cli/local-models/ps
- Source family/type: LM Studio owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: `lms ps` lists models currently loaded in memory and can return JSON with identifier, path, type, architecture, and size.
- Product implication: Block or warn on cleanup of a loaded model and show the exact process state separately from disk inventory.
- Quality caveat: A stopped daemon or app provides no loaded-state result even if another workflow depends on the file later.

### O21. ComfyUI Desktop for macOS

- URL: https://docs.comfy.org/installation/desktop/macos
- Source family/type: ComfyUI owner documentation, macOS installation guide.
- Evidence class: `owner_fact`.
- Observed behavior: The installer lets the user select storage for the Python environment, models, and custom nodes. Migration links existing models instead of copying them. Desktop uses a dedicated extra-model config and leaves chosen model data outside the app during uninstall.
- Product implication: Read the Desktop config and selected install root. Do not assume deleting the app removes models, and do not classify linked migration paths as copies.
- Quality caveat: ComfyUI Desktop is beta and the guide says its process can change.

### O22. ComfyUI Model Library settings

- URL: https://docs.comfy.org/interface/settings/comfy
- Source family/type: ComfyUI owner documentation, settings reference.
- Evidence class: `owner_fact`.
- Observed behavior: Model Library includes the default and extra model folders. Loading every folder can be delayed because the app traverses them.
- Product implication: A full Tessera model scan needs progress and cancellation, especially across external or network volumes.
- Quality caveat: Library visibility does not prove a model is referenced by a current workflow.

### O23. ComfyUI first-generation guide

- URL: https://docs.comfy.org/get_started/first_generation
- Source family/type: ComfyUI owner documentation, getting-started guide.
- Evidence class: `owner_fact`.
- Observed behavior: ComfyUI discovers models in known folders and paths configured through `extra_model_paths.yaml` at startup.
- Product implication: Verify relocation by restarting ComfyUI and confirming model discovery, not only by checking that files exist.
- Quality caveat: Desktop and manual installations can use different config names and locations.

### O24. ComfyUI startup flags

- URL: https://docs.comfy.org/development/comfyui-server/startup-flags
- Source family/type: ComfyUI owner documentation, server reference.
- Evidence class: `owner_fact`.
- Observed behavior: `--base-directory`, `--extra-model-paths-config`, `--output-directory`, `--temp-directory`, `--input-directory`, and `--user-directory` can place related data on different volumes.
- Product implication: Model storage, outputs, temp files, user state, and the base installation need separate path records and free-space checks.
- Quality caveat: A custom launch script can override the config file that Tessera finds on disk.

### O25. ComfyUI CLI model commands

- URL: https://docs.comfy.org/comfy-cli/reference
- Source family/type: ComfyUI owner documentation, CLI reference.
- Evidence class: `owner_fact`.
- Observed behavior: The CLI can download, list, and remove models under an explicit relative path.
- Product implication: Prefer the owner list and remove operation when the install uses this CLI. Keep its workspace and relative path in the action plan.
- Quality caveat: CLI-managed models do not cover every file installed by custom nodes or third-party managers.

### O26. ComfyUI extra-model-path example

- URL: https://github.com/Comfy-Org/ComfyUI/blob/master/extra_model_paths.yaml.example
- Source family/type: ComfyUI maintained configuration example.
- Evidence class: `owner_fact`.
- Observed behavior: The example maps model classes to one or more roots and includes a layout for sharing AUTOMATIC1111 model directories.
- Product implication: Parse configured roots and model classes. Preserve comments and user structure if Tessera later offers guided edits.
- Quality caveat: Custom nodes can register their own folders and ignore this core mapping.

### O27. AUTOMATIC1111 command-line paths

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Command-Line-Arguments-and-Settings
- Source family/type: AUTOMATIC1111 owner wiki, command reference.
- Evidence class: `owner_fact`.
- Observed behavior: Separate flags can relocate the base data directory, all models, checkpoints, VAE, LoRA, CLIP, upscalers, and other model classes.
- Product implication: Read the actual launch arguments and preserve per-class stores. One default `models` path is not enough.
- Quality caveat: The wiki can lag the installed checkout or a fork's argument set.

### O28. AUTOMATIC1111 model-folder relocation

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Change-model-folder-location
- Source family/type: AUTOMATIC1111 owner wiki, relocation guide.
- Evidence class: `owner_fact`.
- Observed behavior: The guide supports Finder aliases or symbolic links when the main disk is low or several tools need one model file.
- Product implication: Resolve aliases and symlinks before measuring duplication. Verify target availability before deleting or changing either path.
- Quality caveat: Link behavior can vary by platform, filesystem, app version, and whether the link targets a file or directory.

### O29. AUTOMATIC1111 Apple Silicon installation

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Installation-on-Apple-Silicon
- Source family/type: AUTOMATIC1111 owner wiki, macOS installation guide.
- Evidence class: `owner_fact`.
- Observed behavior: Checkpoints live under `models/Stable-diffusion`; the app also creates a Python environment and downloads repositories and dependencies. Some repair steps rebuild those non-model directories.
- Product implication: Separate model weights from rebuildable runtime and repository data. State which repair triggers downloads and environment setup.
- Quality caveat: The page has historical revisions and some instructions can be old for a current checkout.

## First-person user reports

### U01. Ollama partial pulls were hidden from the model list

- URL: https://github.com/ollama/ollama/issues/2892
- Source family/type: Ollama GitHub Issue, first-person feature report.
- Evidence class: `first_person_user_report`.
- Observed behavior: An interrupted pull left large `-partial` blob files that `ollama list` did not show and `ollama rm` could not name.
- Product implication: Scan partial transfer artifacts separately from installed models and show whether the same pull can resume.
- Quality caveat: The issue is older and closed. File naming and cleanup behavior can differ in current releases.

### U02. A canceled Ollama pull kept 17 GB on macOS

- URL: https://github.com/ollama/ollama/issues/14177
- Source family/type: Ollama GitHub Issue, first-person macOS report.
- Evidence class: `first_person_user_report`.
- Observed behavior: The reporter canceled an 18 GB model at 55 percent. A retry resumed, but the partial model was absent from `ollama list` and could not be removed with `ollama rm`.
- Product implication: Offer `Resume` and owner-supported partial cleanup as distinct choices. Do not call the partial file orphaned while a resumable transaction still exists.
- Quality caveat: One report on an unspecified latest version. The manual workaround shown in the issue is not a safe general command.

### U03. Ollama would not open without the configured external SSD

- URL: https://github.com/ollama/ollama/issues/12250
- Source family/type: Ollama GitHub Issue, first-person macOS report.
- Evidence class: `first_person_user_report`.
- Observed behavior: After `OLLAMA_MODELS` pointed to an external SSD, removing the SSD prevented the app from opening. Reinstalling did not help until the volume returned.
- Product implication: Relocation must define missing-volume behavior and retain a tested rollback path. Do not make app startup depend on a removable path without a clear recovery screen.
- Quality caveat: The issue was closed as a duplicate and does not establish behavior in every current version.

### U04. Ollama ignored a shell-set path after app start or update

- URL: https://github.com/ollama/ollama/issues/4749
- Source family/type: Ollama GitHub Issue, first-person macOS report.
- Evidence class: `first_person_user_report`.
- Observed behavior: A path set in `.zshrc` worked for a terminal launch but was not read by the app at initial start or after an update, risking use of the default internal store.
- Product implication: Verify the environment of the actual app process after restart and update. Detect split stores before declaring relocation complete.
- Quality caveat: The report spans macOS release changes and community workarounds. It is not a stable setup recipe.

### U05. Removing an Ollama model appeared to free only kilobytes

- URL: https://github.com/ollama/ollama/issues/4122
- Source family/type: Ollama GitHub Issue, first-person macOS report with maintainer explanation.
- Evidence class: `first_person_user_report`.
- Observed behavior: The reporter saw a small manifest disappear while large blobs remained. The thread explains that models can share blobs, so removing one model need not remove every large file it referenced.
- Product implication: Show shared reference count and independently reclaimable bytes. A small reclaimed result can be correct.
- Quality caveat: The issue mixes user observations, later restart advice, and shared-blob explanation. Tessera must verify the current graph.

### U06. Ollama model creation needed room for a second copy

- URL: https://github.com/ollama/ollama/issues/5388
- Source family/type: Ollama GitHub Issue, first-person import report.
- Evidence class: `first_person_user_report`.
- Observed behavior: Creating a model from an existing blob appeared to copy it to a temporary file before deduplication, so a full disk blocked the import despite the final blob already existing.
- Product implication: Include operation-time working space on every affected volume. Final deduplication does not remove the need for staging capacity.
- Quality caveat: The report is from Windows and an older release. The macOS implementation must be tested before applying the same mechanism.

### U07. Hugging Face reported success with incomplete Xet blobs

- URL: https://github.com/huggingface/huggingface_hub/issues/4223
- Source family/type: Hugging Face GitHub Issue, first-person bug report.
- Evidence class: `first_person_user_report`.
- Observed behavior: A large Xet-backed download exited with status zero while `.incomplete` blobs remained, and later model loading failed.
- Product implication: Verify filesystem completion and model loadability after a download. Exit status alone is not enough.
- Quality caveat: The reproduction used Linux and a specific Xet stack. It supports a verification rule, not a macOS prevalence claim.

### U08. A user reported repeated model copies after symlink behavior changed

- URL: https://github.com/huggingface/huggingface_hub/issues/2548
- Source family/type: Hugging Face GitHub Issue, first-person feature report.
- Evidence class: `first_person_user_report`.
- Observed behavior: The reporter said third-party tools downloaded the same weights into separate locations after local-dir symlink behavior changed.
- Product implication: Identify identical content across app stores, then distinguish copies, hard links, symlinks, and shared Hub blobs before proposing consolidation.
- Quality caveat: The reported byte total is one person's experience. It does not estimate frequency or prove every file was physically duplicated.

### U09. Hugging Face cache inventory omitted a large model directory

- URL: https://github.com/huggingface/huggingface_hub/issues/4420
- Source family/type: Hugging Face GitHub Issue, first-person accounting report.
- Evidence class: `first_person_user_report`.
- Observed behavior: `hf cache list` reported only small dataset and Space entries while filesystem tools showed a much larger model repository and partial-file usage.
- Product implication: Cross-check owner inventory with physical allocation and warning state. Show disagreements instead of choosing one number silently.
- Quality caveat: The report used a development library version on Linux and was later closed.

### U10. A bad Xet setting made zero-byte files look complete

- URL: https://github.com/huggingface/huggingface_hub/issues/3047
- Source family/type: Hugging Face GitHub Issue, first-person configuration report.
- Evidence class: `first_person_user_report`.
- Observed behavior: Setting Xet range concurrency to zero produced apparent completion with zero-byte cached model files. A retry reused the bad state until the cache was repaired.
- Product implication: Validate file size and model load, and capture non-default transfer settings before treating a cache entry as healthy.
- Quality caveat: This is an edge configuration on Linux, not a default macOS path.

### U11. Interrupted Hugging Face downloads were outside revision cleanup

- URL: https://github.com/huggingface/huggingface_hub/issues/4412
- Source family/type: Hugging Face GitHub Issue, first-person feature proposal.
- Evidence class: `first_person_user_report`.
- Observed behavior: The report describes `.incomplete` files that were not shown by the revision inventory and could not be selected by revision removal. The later owner docs show this gap was addressed in current prune behavior.
- Product implication: Feature-detect the installed CLI. Use the current owner command when available and keep an older-version fallback read-only until the user approves an update or manual repair.
- Quality caveat: This record captures the pre-fix experience. Current releases can behave differently.

### U12. A Mac user wanted one external model store for several tools

- URL: https://www.reddit.com/r/LocalLLaMA/comments/1f9rnli
- Source family/type: Reddit r/LocalLLaMA, first-person Mac question and peer replies.
- Evidence class: `first_person_user_report`.
- Observed behavior: The user had limited internal storage and wanted Ollama, Hugging Face, LM Studio, and project data on an external SSD. Replies proposed links so several tools could reference one model file.
- Product implication: Make cross-app consolidation explicit and show which apps can read each format and path. A shared file is useful only if all owners recognize it.
- Quality caveat: Peer advice was not verified on the poster's exact app versions or filesystems.

### U13. LM Studio staged downloads on the internal disk

- URL: https://www.reddit.com/r/LocalLLaMA/comments/1nznsx2/lm_studio_download_cache_location
- Source family/type: Reddit r/LocalLLaMA, first-person storage report.
- Evidence class: `first_person_user_report`.
- Observed behavior: The selected final models directory was on another drive, but download activity still filled the internal drive. Replies also show confusion about split model files and directory structure.
- Product implication: Measure final destination and temporary download location before a large pull. Show both free-space requirements.
- Quality caveat: The original report was on Windows. Replies span versions and include unverified manual workarounds.

### U14. LM Studio downloads to an external NAS crashed on macOS

- URL: https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/568
- Source family/type: LM Studio bug tracker, first-person macOS report.
- Evidence class: `first_person_user_report`.
- Observed behavior: A model download directed to a network drive overwhelmed the NAS, paused transfer, and crashed LM Studio.
- Product implication: Treat network storage separately from a local external SSD. Relocation needs throughput, latency, disconnection, and resume checks.
- Quality caveat: The report lacks logs and exact model size details, and the issue remains open.

### U15. One LM Studio directory could not serve both travel and archive use

- URL: https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/478
- Source family/type: LM Studio bug tracker, first-person MacBook report.
- Evidence class: `first_person_user_report`.
- Observed behavior: The user repeatedly deleted and re-downloaded models because one internal directory stayed fast and portable while one external directory had capacity but was slower and unavailable on the road.
- Product implication: A hot and cold model-store design is more useful than forcing one global directory. Tessera should show availability and last use before proposing movement.
- Quality caveat: This is a feature request, not proof that automatic tiering is safe or supported by LM Studio.

### U16. LM Studio metadata and weights looked like duplicate model trees

- URL: https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/686
- Source family/type: LM Studio bug tracker, first-person backup report.
- Evidence class: `first_person_user_report`.
- Observed behavior: A user found model metadata under one hierarchy and GGUF weights under another, making external backup and completeness hard to understand.
- Product implication: Do not flag two model-named trees as duplicate bytes until Tessera classifies metadata versus weights. Backup guidance needs a complete owner manifest.
- Quality caveat: The report used Windows and LM Studio 0.3.16. Current layouts can differ.

### U17. Low disk space appeared as endless LM Studio resume timeouts

- URL: https://www.reddit.com/r/LocalLLM/comments/1ozj7o2/lm_studio_having_to_repeatedly_resume_download
- Source family/type: Reddit r/LocalLLM, first-person failure discussion.
- Evidence class: `first_person_user_report`.
- Observed behavior: Several users described repeated resume prompts. One later found the destination lacked space, but the app showed a timeout instead of a storage error.
- Product implication: Preflight destination and staging capacity, then name low space directly. Do not send the user into network troubleshooting first.
- Quality caveat: The thread contains conflicting diagnoses and hostile replies. It supports an error-classification need, not one confirmed cause for all posters.

### U18. ComfyUI logged an extra path but did not show its models

- URL: https://github.com/Comfy-Org/ComfyUI/issues/2389
- Source family/type: ComfyUI GitHub Issue, first-person path report.
- Evidence class: `first_person_user_report`.
- Observed behavior: Startup logs said checkpoint, LoRA, and VAE paths were added, yet existing models in those folders were absent from the UI.
- Product implication: Verify discovery through the Model Library or a load test. A parsed configuration and startup log are not enough.
- Quality caveat: The issue is older and closed. The failure may include user path syntax.

### U19. Shared ComfyUI models failed across different installers

- URL: https://github.com/Comfy-Org/ComfyUI/issues/7516
- Source family/type: ComfyUI GitHub Issue, first-person feature report.
- Evidence class: `first_person_user_report`.
- Observed behavior: A user tried to share one model store across portable, desktop, Stability Matrix, and other layouts. Paths appeared correct in some installs but model discovery still failed.
- Product implication: Identify installation type, folder taxonomy, and manager-created links before consolidation. Do not offer one generic YAML template.
- Quality caveat: The thread mixes several installations and later support replies. It does not isolate one root cause.

### U20. ComfyUI custom nodes overrode the shared model path

- URL: https://github.com/Comfy-Org/ComfyUI/issues/2630
- Source family/type: ComfyUI GitHub Issue, first-person integration report.
- Evidence class: `first_person_user_report`.
- Observed behavior: Core extra paths worked, but several custom nodes registered their own default model directories and bypassed the shared network store.
- Product implication: Scan custom-node registrations and runtime logs. Core configuration cannot prove that every model class moved.
- Quality caveat: Custom-node behavior belongs to many independent repositories and can change without a ComfyUI core update.

### U21. A ComfyUI update made second-drive models unavailable

- URL: https://github.com/Comfy-Org/ComfyUI/issues/14325
- Source family/type: ComfyUI GitHub Issue, first-person regression report.
- Evidence class: `first_person_user_report`.
- Observed behavior: After an update, the user could not access models on a second drive and found that the extra-model config name or location had changed.
- Product implication: Revalidate configured paths after updates and retain the old config until the new app passes a discovery test.
- Quality caveat: The issue was open at collection time and has no logs, so the exact regression is unresolved.

### U22. Multiple ComfyUI versions used symlinks to avoid copies

- URL: https://github.com/Comfy-Org/ComfyUI/issues/15043
- Source family/type: ComfyUI GitHub Issue, first-person feature report.
- Evidence class: `first_person_user_report`.
- Observed behavior: The user kept several ComfyUI versions and linked their models, input, output, and workflows to shared roots to avoid repeated migration and copies.
- Product implication: Recognize versioned installations and shared targets. A cleanup in one install can affect all linked installs.
- Quality caveat: The report uses Windows symlinks and requests behavior beyond current model-path support.

### U23. A Mac user relocated AUTOMATIC1111 checkpoints to an external disk

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/9000
- Source family/type: AUTOMATIC1111 GitHub Discussion, first-person macOS question and peer answer.
- Evidence class: `first_person_user_report`.
- Observed behavior: The user wanted Stable Diffusion models on an external disk. The reply used `--ckpt-dir` in the macOS launch environment.
- Product implication: Show the exact launch argument and mounted destination, then verify model loading after restart.
- Quality caveat: The shell snippet in the thread has fragile quoting and is peer advice, not a tested general command.

### U24. An AUTOMATIC1111 update broke a linked model folder

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/10405
- Source family/type: AUTOMATIC1111 GitHub Issue, first-person regression report.
- Evidence class: `first_person_user_report`.
- Observed behavior: Models on another disk were visible through a symbolic-link subfolder before an update, then disappeared from the checkpoint picker.
- Product implication: Relocation completion needs an update-survival test or a clear repair path. Preserve the source until the owner app confirms discovery.
- Quality caveat: The report is from Windows and an older version. macOS aliases and direct path flags can behave differently.

### U25. Stable Diffusion storage growth came from several owners

- URL: https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/5176
- Source family/type: AUTOMATIC1111 GitHub Discussion, first-person storage question and peer breakdown.
- Evidence class: `first_person_user_report`.
- Observed behavior: The user saw the WebUI directory grow and did not know whether use caused unbounded model state. Replies separated models, runtime environments, repositories, outputs, temp files, and extension data.
- Product implication: Present a per-owner breakdown and growth source. Do not label the whole WebUI tree as model storage.
- Quality caveat: The size examples are old Windows reports and must not be used as current macOS estimates.

## Recurring patterns

### Logical models hide physical storage

Ollama manifests and Hugging Face snapshots are small references to larger blobs. LM Studio can split metadata and weights across different trees. ComfyUI and AUTOMATIC1111 can point several installations at one file. Tessera cannot calculate reclaimable bytes by summing paths or displayed model sizes. It needs physical identity, link type, and all known references.

### Installed, loaded, and referenced are different states

`ollama ls` and `lms ls` describe installed models. `ollama ps` and `lms ps` describe models loaded now. ComfyUI workflows, custom nodes, presets, and launch arguments can reference a file that is not loaded. A safe decision needs all three states and must mark unknown references honestly.

### Partial transfers live outside normal inventory

Both Ollama and Hugging Face reports describe large partial files that logical model lists did not show. Newer Hugging Face tools can now expose and prune them, which is a useful counterexample to permanent raw-file cleanup logic. Tessera should feature-detect owner tools and classify a partial as resumable, active, stale, or unknown before offering an action.

### The final model directory is not the whole write path

LM Studio users reported internal staging while final storage was external. Ollama import reports show operation-time copies. ComfyUI separates base, model, output, temp, input, and user directories. A relocation or download preflight must check every write path and must not promise success from destination capacity alone.

### External storage trades capacity for availability and speed

External SSDs solve internal capacity pressure, but missing volumes can prevent startup. Network stores can pause or crash downloads. A single external LM Studio directory can make models unavailable during travel. The product must show mount state, volume identity, expected speed class, current path, and fallback behavior.

### Shared stores reduce copies but increase blast radius

Hugging Face symlinks, LM Studio hard or symbolic imports, ComfyUI extra paths, and AUTOMATIC1111 aliases can prevent duplicate bytes. They also connect several apps to one target. Deleting, renaming, ejecting, or changing permissions on that target can break every owner at once.

### Rebuild cost is not only bytes

Recovery can require the exact model revision, quantization, companion config, runtime packages, network access, authorization for a gated repository, and enough staging space. Older or removed revisions can be difficult to recreate. Tessera should say `redownload required` only when the owner source and exact identity are known.

### Accounting tools can disagree

Owner inventory, Finder, `du`, logical file size, allocated size, symlink targets, APFS clones, and cache deletion estimates can report different numbers. Tessera should display the disagreement and explain which number predicts physical free space.

## Counterexamples that constrain the design

- An Ollama remove operation can reclaim little space because another model still references the blob. That is shared storage, not automatically a cleanup failure.
- A Hugging Face snapshot can show many model paths without storing the underlying bytes many times. Symlink-aware accounting must not call those duplicates.
- LM Studio can import by hard link or symbolic link, which can avoid a copy. A hard link only works on one volume, and a symbolic link can become unavailable.
- Current Hugging Face owner docs include incomplete-file inventory and prune support. Tessera must not assume every version still needs manual repair.
- ComfyUI core extra paths can work while custom nodes keep separate model roots. Passing a core model-library test does not prove complete relocation.
- AUTOMATIC1111 supports direct model-directory flags as well as links. A direct path can avoid a fragile symlink, but launch scripts and updates still need verification.
- The local machine currently has almost no active model cache. A model lane must be able to return `no material active candidates` instead of manufacturing a cleanup recommendation.

## Safety boundaries

1. Do not directly delete Ollama blobs or manifests, Hugging Face blobs, refs, snapshots, locks, or LM Studio metadata. Use an owner operation after a current inventory and dry run when the owner provides one.
2. Do not remove a partial transfer merely because it is absent from the installed-model list. Check process state, open handles, recent writes, owner resume behavior, and the user's intent.
3. Do not treat a symbolic link, Finder alias, hard link, APFS clone, snapshot reference, and full copy as the same object. Resolve the link and compare volume, device, inode, allocation, and digest where available.
4. Do not move all of `HF_HOME` as a model-only relocation. It can contain authentication tokens. Prefer `HF_HUB_CACHE` and `HF_XET_CACHE` when the goal is model and transfer storage.
5. Do not switch an app to an external path until the volume is mounted, writable, has enough final and staging space, and has a stable identity. A path string under `/Volumes` is not enough.
6. Do not remove the source after relocation until copy or link verification, owner restart, model discovery, one real load, and rollback-path capture pass. Source removal is a separate user-approved action.
7. Do not promise reclaimed bytes from logical size. Compute independently reclaimable allocated bytes after shared-reference analysis.
8. Do not scan or delete through an unresolved symlink into another volume. Show the resolved target and all known owners first.
9. Do not unload a current model or stop a model server as a side effect of a disk scan. Ask before interrupting a live workflow.
10. Do not permanently delete the dated Trash cache identified in the local probe. It remains recoverable and needs separate exact authorization.

## Exact Tessera handoff

### Add one owner-aware model lane

Create a top-level `AI models` lane with adapters for Ollama, Hugging Face Hub, LM Studio, ComfyUI, and AUTOMATIC1111. Keep generic file discovery as a fallback, not the primary owner.

Each adapter should return:

- Owner name, installed version, process state, and supported owner commands.
- Configured store roots, default roots, temporary roots, and resolved external-volume identity.
- Logical model identifier, revision or digest, format, quantization, and companion files.
- Physical artifact identity with canonical path, resolved target, device, inode when useful, logical size, allocated size, and content digest when affordable.
- Reference edges from manifests, snapshots, app inventory, links, known workflows, custom-node registrations, and loaded-model probes.
- Transfer state as `complete`, `active`, `resumable_partial`, `stale_partial_suspected`, or `unknown`.
- Use state as `loaded_now`, `installed_not_loaded`, `referenced_not_loaded`, `historical_or_trashed`, or `unknown`.
- Recovery facts: owner source, exact revision, authentication requirement, expected download bytes when the owner provides them, and measured local bandwidth only if a user starts a test.

### Show five byte values, not one

For each logical model or transfer, show:

1. Logical model size from the owner.
2. Physical allocated bytes on the current volume.
3. Shared bytes referenced elsewhere.
4. Independently reclaimable bytes from the owner dry run or reference graph.
5. Operation-time working space needed for download, import, move, or rebuild when known.

If two methods disagree, show both values and the reason. Do not collapse them into one estimate.

### Keep actions narrow

The first version should expose these actions:

- `Open in owner` for a model or cache.
- `Verify` to refresh owner inventory, links, volume state, partial files, and loaded state.
- `Resume download` only when the owner recognizes the transfer.
- `Remove with owner` with owner preview and exact expected freed bytes when available.
- `Relocate` as a copy, verify, switch, restart, load-test, and rollback transaction.
- `Ignore` or `Keep` for intentional archives and shared stores.

Do not add a raw `Delete blobs` action.

### Relocation transaction

Use this exact order:

1. Resolve the active owner path from process environment, app setting, config, or launch arguments.
2. Record loaded models, open handles, active transfers, links, source volume, and destination volume.
3. Check destination format, permissions, free space, expected speed class, and what happens when it is missing.
4. Choose the owner-supported mechanism. Examples are `OLLAMA_MODELS`, Hugging Face cache variables, the LM Studio models directory, ComfyUI extra paths, or AUTOMATIC1111 path flags.
5. Copy or link without removing the source. Preserve model hierarchy and companion metadata.
6. Verify digest or owner checksum where available. Confirm allocated bytes and all link targets.
7. Restart the owner only with user consent if it interrupts work. Confirm inventory and load one selected model through the real app or API.
8. Capture a one-click rollback to the original config and path.
9. Present source removal as a separate action with a new scan and exact authorization.

### Adapter acceptance tests

- Ollama: configured path matches the running process; `/api/tags` inventory matches `ollama ls`; `/api/ps` loaded state is fresh; shared blobs are not over-counted; a partial pull is visible even when no logical model exists; a missing external volume produces a recovery state instead of a cleanup prompt.
- Hugging Face: `HF_HOME`, `HF_HUB_CACHE`, `HF_XET_CACHE`, per-call and local-dir caches are distinguished; tokens are excluded from model actions; revisions and blobs form a reference graph; `.incomplete` files are detected; current CLI dry-run behavior is feature-tested; filesystem and CLI byte totals can be compared.
- LM Studio: the selected My Models directory is read; `lms ls --json` and `lms ps --json` are separate; import link type is preserved; metadata and GGUF weights are not called duplicates; staging capacity is checked on the actual temporary volume.
- ComfyUI: install type is identified; Desktop and manual config locations are handled; extra paths and launch flags are parsed; Model Library discovery passes after restart; custom-node registrations and runtime logs are checked; model, temp, output, input, user, and runtime roots stay separate.
- AUTOMATIC1111: actual launch arguments are captured; per-class model paths are scanned; aliases and symlinks resolve correctly; the checkpoint picker sees the relocated model; runtime, repository, extension, output, temp, and model storage remain separate.

### User-facing language

Use concrete states:

- `Loaded now by Ollama`.
- `Installed, not loaded`.
- `Shared by 3 model records`.
- `Partial download, can resume`.
- `Partial file, owner status unknown`.
- `External volume is not mounted`.
- `279 MB in Trash, not active`.
- `Removing this model is expected to free 0 bytes because its blob is shared`.
- `Redownload source and exact revision verified`.
- `Rebuild cost unknown because the original revision was not identified`.

Avoid `safe to delete`, `duplicate`, `cache`, and `unused` unless the evidence for that exact state is shown beside the label.

## Research limits

- The local common-path and Spotlight probes can miss unindexed, hidden, encrypted, offline, or custom external-volume stores.
- User reports span macOS, Windows, and Linux. Cross-platform reports are used only for workflow or safety implications that Tessera must verify on macOS.
- Issues can describe old releases, unusual settings, or user error. They are evidence of product friction, not proof of a current defect.
- Owner documentation can change after collection. Adapters must feature-detect installed commands and read live configuration.
- No measured local download time or network cost was collected. The report does not convert model size into a time estimate.
- No prevalence estimate was made.
