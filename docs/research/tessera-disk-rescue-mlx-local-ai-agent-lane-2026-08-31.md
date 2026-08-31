# Tessera disk-rescue study: MLX and newer local-AI state on macOS

Collected 2026-08-31. This bounded lane asks one question: how do newer local-AI tools and user-created model state change safe disk-rescue behavior on macOS?

The answer is direct. A local-AI directory is not one kind of data. It can contain downloaded base weights, user-trained adapters, fused or quantized derivatives, training checkpoints, processed datasets, generated work, app projects, prompt caches, runtime state, or interrupted transfers. Tessera should classify these objects by owner, current use, recovery source, and rebuild cost before it offers cleanup.

## Scope and collection method

This pass covers MLX, MLX-LM, Draw Things, DiffusionBee, llama.cpp, and the Hugging Face Datasets code used by MLX-LM training workflows. It screens model and training checkpoints, LoRA and adapter files, fine-tunes, generated outputs, processed datasets, caches, partial downloads, external-volume settings, loaded or runtime state, and recovery cost.

The source rules were strict:

- Product behavior comes from owner documentation, owner repositories, and owner source code.
- User behavior and failure modes come from first-person reports in the owner's issue tracker.
- Search pages, generic articles, copied tutorials, and SEO pages do not count.
- An issue report proves that the reported experience occurred. It does not prove prevalence or current behavior in every version.
- No app, model, dataset, or local store was changed or launched for this lane.

The novelty check read the `.url` field from all 11 current `docs/research/*.jsonl` ledgers. Those ledgers held 2,543 unique URL strings at check time. The 61 selected URLs were sorted and compared against that set. Exact collisions were zero. A second repository-family check found no prior ledger URL from the five focused owner repositories. The Hugging Face Datasets source URL also had no exact ledger match. No fragments, tracking parameters, or trailing-slash variants were used to create artificial novelty.

## Counts

### By tool

| Tool or subject | Records |
| --- | ---: |
| MLX | 8 |
| MLX-LM | 14 |
| Hugging Face Datasets | 1 |
| Draw Things | 12 |
| DiffusionBee | 12 |
| llama.cpp | 14 |
| **Total** | **61** |

### By source type

| Source type | Records |
| --- | ---: |
| Owner repository documentation | 17 |
| Owner source code or maintained configuration | 11 |
| First-person report in owner issue tracker | 33 |
| **Total** | **61** |

### By evidence class

| Evidence class | Records |
| --- | ---: |
| `owner_fact` | 17 |
| `owner_implementation_fact` | 11 |
| `first_person_user_report` | 33 |
| **Total** | **61** |

## Screened source records

### 1. MLX repository overview

- URL: <https://github.com/ml-explore/mlx/blob/main/README.md>
- Source type: `owner_repository_documentation`
- Tool: `MLX`
- Evidence class: `owner_fact`
- Screened observation: MLX uses lazy computation and shared CPU/GPU memory on Apple silicon. A loaded model can be active through one process-wide unified-memory allocation rather than a separate disk copy and VRAM copy.

### 2. MLX saving and loading formats

- URL: <https://github.com/ml-explore/mlx/blob/main/docs/src/usage/saving_and_loading.rst>
- Source type: `owner_repository_documentation`
- Tool: `MLX`
- Evidence class: `owner_fact`
- Screened observation: MLX saves and loads `.npy`, `.npz`, `.safetensors`, and `.gguf`. The extension identifies a container format, not whether the file is a downloaded base model, a training result, or a user-created conversion.

### 3. MLX lazy evaluation

- URL: <https://github.com/ml-explore/mlx/blob/main/docs/src/usage/lazy_evaluation.rst>
- Source type: `owner_repository_documentation`
- Tool: `MLX`
- Evidence class: `owner_fact`
- Screened observation: MLX records computation before it evaluates it, and saving an array forces evaluation. A file-backed array can therefore remain part of live work after the load call has returned. Rescue must check the process and open file state before moving a weight file.

### 4. MLX memory-management API

- URL: <https://github.com/ml-explore/mlx/blob/main/docs/src/python/memory_management.rst>
- Source type: `owner_repository_documentation`
- Tool: `MLX`
- Evidence class: `owner_fact`
- Screened observation: MLX exposes separate active, peak, and cache-memory measurements plus cache and wired-memory controls. Runtime cache memory is a live-state signal. It is not a disk cache that Tessera can reclaim.

### 5. MLX environment variables

- URL: <https://github.com/ml-explore/mlx/blob/main/docs/src/usage/environment_variables.rst>
- Source type: `owner_repository_documentation`
- Tool: `MLX`
- Evidence class: `owner_fact`
- Screened observation: MLX reads many settings before the process or subsystem starts, and later changes may have no effect. Tessera should inspect the running process environment and launch context rather than assume the current shell describes the active job.

### 6. Saving over a lazily loaded MLX file can corrupt it

- URL: <https://github.com/ml-explore/mlx/issues/4427>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter reproduced silent corruption when a lazily loaded safetensors file was saved back to the same path. A second user reproduced the failure on another macOS and MLX build. Tessera must never repair, compact, or replace an open model file in place.

### 7. MLX users are asking for on-disk model streaming

- URL: <https://github.com/ml-explore/mlx/issues/2878>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX`
- Evidence class: `first_person_user_report`
- Screened observation: The request asks MLX to stream weights from disk for models larger than RAM. A technical reply reports that mapped weights still become wired when Metal touches them, while an application-level expert cache can keep only part of a larger model resident. An external model file may remain an active backing store even when its resident footprint changes.

### 8. MLX peak memory can miss retained cache memory

- URL: <https://github.com/ml-explore/mlx/issues/3896>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX`
- Evidence class: `first_person_user_report`
- Screened observation: A macOS reporter measured about 46 GB from `mx.get_peak_memory()` while the process footprint was about 110 GB. A maintainer advised using active plus cache memory for long-running or parallel serving. Tessera should not treat one MLX counter as proof that a process is idle.

### 9. MLX-LM repository overview

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/README.md>
- Source type: `owner_repository_documentation`
- Tool: `MLX-LM`
- Evidence class: `owner_fact`
- Screened observation: MLX-LM downloads Hub models, accepts local model paths, converts and quantizes models, fine-tunes them, and writes prompt caches as safetensors files. The default conversion output is `mlx_model`, while a prompt-cache file records reusable context and model metadata.

### 10. MLX-LM LoRA and fine-tuning guide

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md>
- Source type: `owner_repository_documentation`
- Tool: `MLX-LM`
- Evidence class: `owner_fact`
- Screened observation: A fine-tune can depend on a base model, local or Hub dataset, adapter config, adapter weights, and an optional resume file. Adapters default to `adapters/`. Fusing creates another model under `fused_model/`. The adapter and its matching base remain the recoverable source until the fused model passes a real behavior check.

### 11. MLX-LM LoRA configuration

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/examples/lora_config.yaml>
- Source type: `owner_maintained_configuration`
- Tool: `MLX-LM`
- Evidence class: `owner_implementation_fact`
- Screened observation: The maintained config names the model and dataset, saves trained adapters under `adapters`, supports a resume adapter file, and defaults to a save every 100 iterations. Intermediate checkpoints can be the only surviving work after a failed long run.

### 12. MLX-LM dataset loader

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/tuner/datasets.py>
- Source type: `owner_source_code`
- Tool: `MLX-LM`
- Evidence class: `owner_implementation_fact`
- Screened observation: The loader treats an existing path as local `train.jsonl`, `valid.jsonl`, and `test.jsonl` data. Otherwise it treats the value as a Hugging Face dataset identifier. Tessera must preserve local training corpora and distinguish them from remotely recoverable dataset caches.

### 13. MLX-LM prompt-cache writer

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/cache_prompt.py>
- Source type: `owner_source_code`
- Tool: `MLX-LM`
- Evidence class: `owner_implementation_fact`
- Screened observation: `mlx_lm.cache_prompt` writes a user-named prompt-cache file and stores the model identifier plus tokenizer configuration in its metadata. The file is derived, but its rebuild cost includes model access and prompt processing.

### 14. MLX-LM conversion path

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/convert.py>
- Source type: `owner_source_code`
- Tool: `MLX-LM`
- Evidence class: `owner_implementation_fact`
- Screened observation: Conversion loads a local or Hub model lazily, can change precision or quantization, and writes to a new output directory. It refuses an output path that already exists. A failed conversion directory is neither a verified model nor automatically cheap to rebuild.

### 15. MLX-LM adapter fusion path

- URL: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/fuse.py>
- Source type: `owner_source_code`
- Tool: `MLX-LM`
- Evidence class: `owner_implementation_fact`
- Screened observation: Fusion loads a base plus adapter, writes a full fused model, and can also export GGUF or upload the result. The fused copy is derived data, but only after Tessera proves that the source pair still exists and the fused output is valid.

### 16. LoRA training can fail after earlier checkpoints

- URL: <https://github.com/ml-explore/mlx-lm/issues/1185>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter saw deterministic Metal resource-limit crashes at different iterations during LoRA training. The config saved every 100 iterations, and a second MLX process shortened the run. The latest saved adapter can be valuable even when the current training process has failed.

### 17. A fused model can fail while its adapter works

- URL: <https://github.com/ml-explore/mlx-lm/issues/1172>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter measured 95 to 100 percent task success with the adapter loaded over the base model and zero percent with the fused copies. File creation and changed hashes did not prove semantic success. Preserve the base and adapter until the fused model passes the user's task.

### 18. A dequantized fused model can contain incomplete weights

- URL: <https://github.com/ml-explore/mlx-lm/issues/223>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter found four large safetensors shards and quantization fields after a dequantizing fuse, then hit missing-parameter errors on load. A complete-looking shard set can still be invalid.

### 19. Fusion can lose fine-tuned behavior

- URL: <https://github.com/ml-explore/mlx-lm/issues/654>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: After 15,000 LoRA iterations, the reporter kept the intended behavior with dynamic adapters but lost part of it in the fused model. A small adapter can hold more unique value than a much larger derivative.

### 20. A cached safetensors shard can fail its header check

- URL: <https://github.com/ml-explore/mlx-lm/issues/435>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter's conversion failed because a cached Hub safetensors shard had an invalid header. Tessera should identify the exact bad shard and source revision. It should not delete an entire shared cache because one file is corrupt.

### 21. Model conversion can be too costly to repeat casually

- URL: <https://github.com/ml-explore/mlx-lm/issues/876>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The request describes conversion of very large models failing because the save path holds all quantized weight references before it writes shards. A converted model is derived, but its rebuild can require hundreds of gigabytes of source data, memory, disk writes, and time.

### 22. A warm MLX-LM cache can still avoid most load work

- URL: <https://github.com/ml-explore/mlx-lm/issues/1649>
- Source type: `owner_issue_tracker_report`
- Tool: `MLX-LM`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter measured two Hub checks during each load even when the model was fully cached, while local-only resolution was much faster. A warm cache still has recovery value on slow, flaky, or offline links.

### 23. Processed Hugging Face datasets use Arrow cache files

- URL: <https://github.com/huggingface/datasets/blob/main/src/datasets/arrow_dataset.py>
- Source type: `owner_source_code`
- Tool: `Hugging Face Datasets`
- Evidence class: `owner_implementation_fact`
- Screened observation: A processed dataset exposes the Arrow files that back it. Transformations can reuse or write cache files. The owner cleanup method warns that no other process should be using the other cache files. Processed data is reclaimable only after a live-use check and a clear recompute-cost explanation.

### 24. Draw Things projects, templates, and image history

- URL: <https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/1.UI.md>
- Source type: `owner_repository_documentation`
- Tool: `Draw Things`
- Evidence class: `owner_fact`
- Screened observation: Draw Things can save configuration templates, projects, prompt history, and generated-image history. The guide says project files grow with use and identifies separate controls for canvas clearing, history deletion, and image saving. These actions do not mean the same thing.

### 25. Draw Things model import, dependencies, and external folder

- URL: <https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/2.Models.md>
- Source type: `owner_repository_documentation`
- Tool: `Draw Things`
- Evidence class: `owner_fact`
- Screened observation: The model manager can download, delete, export, import, mix, and place models in an external folder. Imported models can depend on a separate VAE. The guide also describes a registry file and a post-import prompt to remove the original download. Tessera must keep registration, dependency, and duplicate-copy state together.

### 26. Draw Things LoRA import, export, delete, and training

- URL: <https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/3.LoRa.md>
- Source type: `owner_repository_documentation`
- Tool: `Draw Things`
- Evidence class: `owner_fact`
- Screened observation: The app manages downloaded and imported LoRAs, supports export and deletion, and can train a new LoRA from user images. A trained LoRA is user-created model state, not a normal downloadable model cache.

### 27. Draw Things Core ML setup needs free working space

- URL: <https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/7.CoreML.md>
- Source type: `owner_repository_documentation`
- Tool: `Draw Things`
- Evidence class: `owner_fact`
- Screened observation: The maintained guide recommends about 5 GiB of free disk before enabling Core ML and restarting the app. Disk rescue should reserve setup and conversion headroom rather than fill the disk to the last reported byte.

### 28. Draw Things lost track of external models after an update

- URL: <https://github.com/drawthingsai/draw-things-community/issues/31>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter says models remained on an external SSD but disappeared from the app after an update. Re-importing the app's converted files failed, leaving a claimed redownload cost of hundreds of gigabytes. A missing registry entry is not proof that external files are orphaned.

### 29. A user mounted an APFS volume at the app container path

- URL: <https://github.com/drawthingsai/draw-things-community/issues/22>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: After a symbolic link was ignored, the reporter mounted a separate APFS volume at the Draw Things Documents path. Tessera cannot infer physical storage ownership from the visible app-container path alone.

### 30. A self-trained Draw Things LoRA became hard to export

- URL: <https://github.com/drawthingsai/draw-things-community/issues/20>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter says the trained-LoRA export option disappeared and a manual attempt to find and convert the checkpoint failed. Lack of a working export path raises the rescue priority of the in-app copy.

### 31. Imported and self-trained Draw Things LoRAs delete differently

- URL: <https://github.com/drawthingsai/draw-things-community/issues/19>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter could delete an imported LoRA with the app control but could not delete a self-trained SDXL LoRA. Tessera should not assume one owner action covers every object that shares a LoRA label.

### 32. Users want faster cleanup of generated Draw Things images

- URL: <https://github.com/drawthingsai/draw-things-community/issues/34>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter describes a multi-click, per-image delete flow and asks for keyboard deletion without confirmation. Generated outputs can become clutter, but deletion must still be user-selected and recoverable in a rescue product.

### 33. Draw Things project deletion is hard to discover

- URL: <https://github.com/drawthingsai/draw-things-community/issues/25>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter found that project deletion appears only after selecting a different project. Tessera can guide users to the owner action, but it should not replace a hard-to-find action with raw SQLite or project-file deletion.

### 34. Draw Things loaded-state settings can disagree with behavior

- URL: <https://github.com/drawthingsai/draw-things-community/issues/33>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter says Flux and HiDream models unloaded despite the Keep Model In Memory setting, while SDXL stayed loaded. A preference value alone is weak evidence of current runtime state.

### 35. Draw Things LoRA training can fail early on current Apple hardware

- URL: <https://github.com/drawthingsai/draw-things-community/issues/118>
- Source type: `owner_issue_tracker_report`
- Tool: `Draw Things`
- Evidence class: `first_person_user_report`
- Screened observation: An M5 user reports repeated LoRA training failure under one default path and only two successful runs in more than 100 attempts. A surviving trained checkpoint deserves high rescue priority because recreation may be unreliable.

### 36. DiffusionBee stores models and generation history locally

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/README.md>
- Source type: `owner_repository_documentation`
- Tool: `DiffusionBee`
- Evidence class: `owner_fact`
- Screened observation: DiffusionBee runs models locally, downloads models in the app, supports LoRA, and keeps generation history. Model data and user output both belong to the product, but they have different recovery value.

### 37. DiffusionBee's model store converts imported files

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/pages/ModelStore.vue>
- Source type: `owner_source_code`
- Tool: `DiffusionBee`
- Evidence class: `owner_implementation_fact`
- Screened observation: The model store imports a selected weight file, converts it to the app's internal format, records metadata, and rejects a duplicate model name. The downloaded original and the imported internal model can coexist but are not interchangeable files.

### 38. DiffusionBee's asset manager owns integrity and deletion

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/AssetsManager.vue>
- Source type: `owner_source_code`
- Tool: `DiffusionBee`
- Evidence class: `owner_implementation_fact`
- Screened observation: The asset manager keeps separate downloaded and local registries, verifies an MD5 after download, and has one delete path that removes registry entries plus the recorded file. Its conversion path can delete the original download after a successful conversion. Owner-managed deletion has more context than raw folder cleanup.

### 39. DiffusionBee history metadata and image files are separate

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/pages/History.vue>
- Source type: `owner_source_code`
- Tool: `DiffusionBee`
- Evidence class: `owner_implementation_fact`
- Screened observation: History loads from `history.json` and stores prompts, parameters, input-image paths, and output-image paths. Clearing or deleting a history entry mutates the history object in this component. It does not call the asset file-deletion path.

### 40. Clearing DiffusionBee history can leave generated files

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/376>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: Users report generated and input images under the hidden DiffusionBee directory. One report says clearing history removed references from the data file but left the image payloads. Tessera should show history records and unreferenced outputs separately.

### 41. DiffusionBee downloads can be large, hidden, and repeated

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/183>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: The issue reports about 9 GB of hidden model downloads. Replies report repeat downloads after an update and old files left behind. Old version candidates need a version and registry check before removal.

### 42. Removing DiffusionBee can leave its model data

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/262>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter removed the app, then found about 4 GB under the hidden DiffusionBee directory. App absence is useful orphan evidence, but it is not enough when user outputs, custom models, or training state can share the same root.

### 43. A broken model download restarted near completion

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/15>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: A connection break at about 3.9 GB caused the reporter's model download to restart from zero. Partial downloads can hold substantial bytes and recovery value. Tessera should verify transfer state and resume support before it labels them disposable.

### 44. DiffusionBee users could not cancel or resume stuck downloads

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/23>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter was unsure whether quitting was safe, then saw a stuck transfer. Another user reported repeated failures around 2 GB and wanted to reuse a local model instead of downloading it again. Active, stalled, and abandoned transfers need different states.

### 45. A DiffusionBee update left old and new model formats together

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/95>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: After an update, the reporter found the older 4.3 GB checkpoint beside newer H5 files and asked whether the old file was still needed. A successful manual test made deletion reasonable for that setup, but it is not a version-independent rule.

### 46. DiffusionBee users want explicit external-volume checks

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/531>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter wants models on a thumb drive and wants the app to ask for the missing drive at launch. Replies use a symbolic-link workaround that the reporter calls not foolproof. An unavailable external root must be `offline`, not `deleted` or `orphaned`.

### 47. Local-AI apps can duplicate one base model

- URL: <https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/382>
- Source type: `owner_issue_tracker_report`
- Tool: `DiffusionBee`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter worries that a CLI, DiffusionBee, and Photoshop each keep their own copy of one model. Tessera should compare content and allocation, then preserve app registration and format differences before it calls files duplicates.

### 48. llama.cpp can download and run a Hub model directly

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/README.md>
- Source type: `owner_repository_documentation`
- Tool: `llama.cpp`
- Evidence class: `owner_fact`
- Screened observation: The standard CLI and server can download and run a model from Hugging Face with `-hf`. A model fetched this way can enter an owner-managed cache without a separate install step.

### 49. llama.cpp accepts local GGUF and converted models

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/docs/models.md>
- Source type: `owner_repository_documentation`
- Tool: `llama.cpp`
- Evidence class: `owner_fact`
- Screened observation: llama.cpp runs local GGUF files or Hub models and provides paths for model, quantization, and LoRA conversion. A local GGUF can be a download, a costly quantization, or a unique user conversion.

### 50. llama.cpp cache source tracks repositories, snapshots, and temporary writes

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/common/hf-cache.cpp>
- Source type: `owner_source_code`
- Tool: `llama.cpp`
- Evidence class: `owner_implementation_fact`
- Screened observation: The cache location can come from `LLAMA_CACHE`. Repository folders contain snapshot state. Metadata writes use a `.tmp` file followed by rename, and the owner code has a repository-level cache removal function. Tessera should model the repository as a unit and expose incomplete temporary files separately.

### 51. llama.cpp LoRA conversion needs adapter and base identity

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/convert_lora_to_gguf.py>
- Source type: `owner_source_code`
- Tool: `llama.cpp`
- Evidence class: `owner_implementation_fact`
- Screened observation: The converter expects a PEFT adapter directory with config and weights. It also needs base-model configuration from a local directory, an explicit model ID, or the adapter config, and it supports dry-run. An adapter file without its base identity is not a complete backup.

### 52. llama.cpp can verify GGUF content by tensor

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/examples/gguf-hash/README.md>
- Source type: `owner_repository_documentation`
- Tool: `llama.cpp`
- Evidence class: `owner_fact`
- Screened observation: `llama-gguf-hash` can make and check whole-model and per-tensor manifests, including SHA-256. Tessera can verify a moved, restored, or suspected-corrupt GGUF before it removes another copy.

### 53. llama-server has separate model, RAM-cache, and disk-slot state

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md>
- Source type: `owner_repository_documentation`
- Tool: `llama.cpp`
- Evidence class: `owner_fact`
- Screened observation: The server has a RAM prompt-cache limit, context checkpoints, a model directory, a simultaneous-model limit, and an optional path for saving slot state to disk. Installed models, loaded models, RAM cache, and saved disk state are distinct inventories.

### 54. A split GGUF is a multi-file set

- URL: <https://github.com/ggml-org/llama.cpp/blob/master/tools/gguf-split/README.md>
- Source type: `owner_repository_documentation`
- Tool: `llama.cpp`
- Evidence class: `owner_fact`
- Screened observation: The split tool writes several GGUF parts, and merge uses the first part to find the rest in the same folder. Tessera must not present one shard as an independent old model.

### 55. llama.cpp model updates can retain old cached versions

- URL: <https://github.com/ggml-org/llama.cpp/issues/26249>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter discovered several old versions of multiple model variants after `-hf` updates and removed them manually. Old revisions are good review candidates, but only after current revision, model registration, and runtime use are known.

### 56. llama.cpp users lack a complete cache inventory and delete command

- URL: <https://github.com/ggml-org/llama.cpp/issues/16393>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter describes cached models as grouped manifests, GGUF files, ETags, and sometimes projector files. They built a script because manual file cleanup was cumbersome. Tessera should group these parts before it estimates reclaimable bytes.

### 57. llama.cpp users want valuable context checkpoints on disk

- URL: <https://github.com/ggml-org/llama.cpp/issues/20697>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: The request proposes disk-backed context checkpoints because RAM and VRAM share one pool on unified-memory systems. It estimates that restoring a checkpoint can avoid full processing of very long prompts. A large disk cache can be active acceleration state, not abandoned residue.

### 58. llama.cpp slot-state save does not cover every model

- URL: <https://github.com/ggml-org/llama.cpp/issues/19466>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: A vision-model user received a not-supported response when saving slot state and faced long prompt reprocessing. Tessera cannot promise that a runtime cache is easy to recreate or persist across every model type.

### 59. A llama.cpp disk-cache restore can report success but save no work

- URL: <https://github.com/ggml-org/llama.cpp/issues/25913>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: On macOS, the reporter restored a saved slot with the full token count, but a hybrid model reprocessed the full prompt because context checkpoints were not persisted. A success response is not enough. Recovery proof must observe reuse, output, or measured rebuild time.

### 60. llama.cpp prompt cache identity must include the LoRA

- URL: <https://github.com/ggml-org/llama.cpp/issues/26207>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: The reporter says the server reused prompt KV state across requests that selected different LoRAs, which mixed the previous adapter's effect into the next output. Cache identity includes the base model, adapter set, scales, and prompt.

### 61. Rebuilding a llama.cpp prompt cache can take much longer than expected

- URL: <https://github.com/ggml-org/llama.cpp/issues/20033>
- Source type: `owner_issue_tracker_report`
- Tool: `llama.cpp`
- Evidence class: `first_person_user_report`
- Screened observation: In a multi-agent server report, two prompt-cache updates took tens of milliseconds and a later replacement took about 80 seconds. Rebuild cost depends on workload and cache policy, not only file size.

## Patterns

### User-created state is often small but hard to replace

The clearest high-risk objects are adapter weights, resume checkpoints, local training JSONL, trained Draw Things LoRAs, project files, prompts, and generated images. MLX-LM records an explicit adapter output and resume file in its [LoRA guide](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md). Draw Things documents local projects and image history in its [UI guide](https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/1.UI.md). DiffusionBee stores prompt and image references in [history source](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/pages/History.vue). These objects should outrank downloaded base weights in rescue priority.

### Derived does not mean cheap

Fused models, quantizations, processed Arrow data, prompt caches, and converted app models are reproducible in principle. The evidence shows costly exceptions. MLX-LM conversion can exceed available memory for very large models in [issue 876](https://github.com/ml-explore/mlx-lm/issues/876). llama.cpp prompt-cache replacement took about 80 seconds in [issue 20033](https://github.com/ggml-org/llama.cpp/issues/20033). Hugging Face warns its [dataset cache cleanup](https://github.com/huggingface/datasets/blob/main/src/datasets/arrow_dataset.py) caller to ensure no other process uses the files. Tessera should show estimated download, conversion, preprocessing, and prompt-rebuild cost as separate numbers.

### A successful derivative does not prove it can replace its source

MLX-LM users report fused models that were incomplete or lost trained behavior in [issue 223](https://github.com/ml-explore/mlx-lm/issues/223), [issue 654](https://github.com/ml-explore/mlx-lm/issues/654), and [issue 1172](https://github.com/ml-explore/mlx-lm/issues/1172). The safe rule is to retain base plus adapter until a load test and a task-specific behavior test pass.

### External storage is configuration, not a detached pile of files

Draw Things officially exposes an external model folder in its [model guide](https://github.com/drawthingsai/community-docs/blob/main/Documentation.docc/2.Models.md), yet one user reports that the app lost its registry after an update while the SSD files remained in [issue 31](https://github.com/drawthingsai/draw-things-community/issues/31). A DiffusionBee user asks for a missing-drive prompt in [issue 531](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/531). Tessera needs `online`, `offline`, `unmounted`, `unregistered`, and `missing` states. Only `missing` means the bytes are gone.

### Loaded state is not one flag

MLX distinguishes active and cache memory in its [memory API](https://github.com/ml-explore/mlx/blob/main/docs/src/python/memory_management.rst), and one report shows a large gap between the peak counter and the macOS process footprint in [issue 3896](https://github.com/ml-explore/mlx/issues/3896). Draw Things users report that the Keep Model In Memory preference does not match every model in [issue 33](https://github.com/drawthingsai/draw-things-community/issues/33). llama-server separately tracks loaded models, prompt RAM, and saved slot files in its [server guide](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md). A safe action needs a fresh process, open-handle, owner-inventory, and transfer-state check.

### Partial transfer files are not all disposable

DiffusionBee users report restart-from-zero behavior near 3.9 GB in [issue 15](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/15) and repeated stalls near 2 GB in [issue 23](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/23). llama.cpp uses temporary metadata writes before rename in its [cache source](https://github.com/ggml-org/llama.cpp/blob/master/common/hf-cache.cpp). Tessera should separate active transfer, resumable partial, stale partial, and corrupt complete file. Age alone is not enough.

### File names do not prove duplicate bytes or duplicate meaning

One DiffusionBee user worries about the same model being copied by several apps in [issue 382](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/issues/382). MLX supports safetensors and GGUF in its [format guide](https://github.com/ml-explore/mlx/blob/main/docs/src/usage/saving_and_loading.rst), while Draw Things can convert imports and keep registry metadata in its [model store](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/pages/ModelStore.vue). Tessera should compare content hashes, allocated blocks, links, format, quantization, app registration, and dependency use before proposing deduplication.

## Counterexamples

- Some caches are valid cleanup targets. Hugging Face provides `cleanup_cache_files`, but its [source](https://github.com/huggingface/datasets/blob/main/src/datasets/arrow_dataset.py) warns about other processes. The counterexample supports a checked owner action, not blanket cache deletion.
- Some generated images are deliberate clutter. A Draw Things user asks for faster deletion in [issue 34](https://github.com/drawthingsai/draw-things-community/issues/34). Tessera should make review fast, keep selection explicit, and use Trash so a mistaken choice can be undone.
- Some old model versions are truly stale. A llama.cpp user found several retained revisions in [issue 26249](https://github.com/ggml-org/llama.cpp/issues/26249). The stale label becomes strong only after the current revision, rollback value, loaded state, and shared projectors are known.
- Some large derivatives are safer to remove than tiny adapters. A fused or converted model can be rebuilt from a verified base and adapter, while [issue 20](https://github.com/drawthingsai/draw-things-community/issues/20) shows a trained Draw Things LoRA with no working export path. Size must not set rescue priority.

## Product implications for Tessera

1. Build an owner graph before a size list. Nodes should include base model, revision, quantization, shard set, VAE or projector, adapter, adapter config, training dataset, checkpoint, fused model, processed dataset, prompt cache, project, generated output, and transfer.
2. Give each node a recovery class: `user_created`, `derived_expensive`, `redownloadable_verified`, `redownloadable_unverified`, `runtime_active`, `partial_active`, `partial_stale`, or `unknown`.
3. Read owner state first. Use app registries, MLX-LM metadata, llama.cpp cache manifests, external-folder settings, and model dependencies before filesystem heuristics. The need for grouped cache records is visible in [llama.cpp issue 16393](https://github.com/ggml-org/llama.cpp/issues/16393).
4. Block mutation when a process has an open handle, a model is loaded, training is active, a transfer is active, or an external root is offline. MLX's same-path corruption report in [issue 4427](https://github.com/ml-explore/mlx/issues/4427) makes the open-file rule non-negotiable.
5. Show recovery cost in plain units: bytes to download, expected network time, conversion or preprocessing work, required free working space, and whether the source needs credentials or a specific revision.
6. Use owner deletion where it exists. DiffusionBee's [asset manager](https://github.com/divamgupta/diffusionbee-stable-diffusion-ui/blob/master/electron_app/src/AssetsManager.vue) updates registry state and deletes the recorded file together. Raw deletion can leave an app database wrong.
7. Move reviewed items to Trash by default. Keep user-created adapters, datasets, projects, and outputs out of batch cleanup unless the user selects them directly.
8. Verify before final reclaim. Use owner inventory, model load, a small behavior test for a fine-tune, and a content check such as [llama-gguf-hash](https://github.com/ggml-org/llama.cpp/blob/master/examples/gguf-hash/README.md). A successful API response alone is weak evidence, as the slot-restore failure in [issue 25913](https://github.com/ggml-org/llama.cpp/issues/25913) shows.

## Candidates for structured ledger conversion

These records have the clearest direct product value:

- Record 6. MLX same-path save corruption. Safety boundary for open files.
- Record 8. MLX process-memory undercount. Runtime-state evidence.
- Record 10. MLX-LM LoRA object graph. Base, data, adapter, resume, and fuse.
- Record 11. MLX-LM checkpoint cadence and adapter path.
- Record 17. Fused failure with working adapter. Verification boundary.
- Record 20. Corrupt cached safetensors shard. Targeted repair case.
- Record 23. Processed Arrow cache and live-process warning.
- Record 28. Draw Things external registry loss with files intact.
- Record 30. Self-trained LoRA without a working export path.
- Record 38. DiffusionBee owner registry, hash, conversion, and delete path.
- Record 40. History deletion leaving image payloads.
- Record 50. llama.cpp cache layout, temporary writes, and repository removal.
- Record 55. Old model revisions retained after updates.
- Record 60. Prompt-cache identity contaminated across LoRAs.

## De-duplication result

- Existing ledgers checked: 11 JSONL files.
- Existing unique `.url` values: 2,543.
- Selected records in this report: 61.
- Unique selected URLs: 61.
- Exact selected-to-ledger URL collisions: 0.
- New URLs after de-duplication: 61.

## Limitations

- This is a source study, not a local disk scan. It did not inspect Ammar's active MLX, Draw Things, DiffusionBee, or llama.cpp state.
- Owner issue reports are first-person evidence. They can be version-specific, incomplete, or fixed later. They do not measure prevalence.
- Repository links point to `main` or `master` and can change. A ledger conversion should also capture collection date, commit SHA, issue state, and product version where available.
- Draw Things documentation is maintained in the owner organization but includes community-authored guidance. The app should verify current owner behavior before it turns any documented path into an action.
- Download and rebuild times depend on model size, network, hardware, quantization, dataset transformations, and authentication. This pass records mechanisms and reported failures, not universal time estimates.
- The novelty result is valid against the ledgers present on 2026-08-31. A later ledger update can change that result.

## Final validation

The report contains **61 unique new source URLs**. All 61 were absent from every current `/Users/abdwy/development/tessera/docs/research/*.jsonl` ledger at validation time.
