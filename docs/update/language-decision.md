# Keep Swift and the C scanner bridge

Decision, 8 November 2026. Keep SwiftUI and Swift for the app. Keep a small C bridge for Darwin bulk metadata reads. A whole-app Rust rewrite is not justified by the evidence collected so far.

## What the native trial showed

On the same M1 Max and the same warm fixture, the saved Release app took 0.825, 0.818 and 0.802 seconds for a serial scan. The first update took 0.309, 0.307 and 0.314 seconds. The fixture had 124,581 files and 455 directories, including a wide folder and a 444-level tree. Both versions passed native tests and Release builds. The update also preserved Unicode paths that collided in the saved version.

That trial changed the enumeration strategy, not the app language. It does not establish a cold whole-drive time or a two-minute guarantee. Raw evidence is in the linked Mac's /tmp/tessera-native-verification.1GZiGk/REPORT.md. Final whole-volume, memory and combined-app checks remain separate gates.

A later alternating trial compared `301cb25` with `f80598c` on the same warm fixture, with three measured processes per revision. Both found every expected file and no coverage gap. Median peak RSS fell from 61,538,304 to 50,003,968 bytes, or 18.74 percent. Median child-build time fell from 18.302 to 12.053 ms. Total time ranges overlapped, so the small total-time difference is not a robust speed claim. The native Release app also completed its scan and diagnosis in 132.56 seconds. Samples at 60 and 120 seconds found cleanup rule evaluation, rather than node allocation, as the active work. That finding calls for a classifier fix before a new language.

## Where time and memory went

The saved scanner stopped bulk enumeration at 8,192 entries and reread wide folders with one lstat per file. Cloud reads could spend ten seconds on each stalled folder. Unsafe directory-mtime reuse skipped deeper changes. File removal blocked the main actor. Repeated pruning and capacity samples added work for each item.

The update streams bulk records on one descriptor, bounds worker and helper counts, holds a stalled provider for the current scan, checks cancellation between batches and reads fresh metadata on a rescan. Cleanup validates an immutable action record off the main actor and samples capacity around the batch. The UI stays available while disk work runs. Reader scratch storage is 1,024 records per worker. Compact identity storage lowers measured fixture memory without changing the language. Root app and engine-only RSS are distinct measures and must not be mixed.

## Language options

| Option | Likely value | Cost or limit |
| --- | --- | --- |
| Swift plus C | Keeps the native UI and direct bulk calls. Fixes the measured enumeration problem now. | ARC and object-per-file storage still need native profiles on large trees. |
| Rust core plus SwiftUI | Could use an arena of records, explicit ownership and a small FFI. | Still calls Darwin and waits for the same device. Adds a second toolchain, data bridge and migration of scan identity and cleanup rules. |
| C++ core plus SwiftUI | Can use compact records and existing Swift interop. | Adds manual lifetime and concurrency risks. No measured advantage here over improving the current C bridge. |
| C or Zig core | Gives direct control of record layout and allocation. | More lifetime and ABI work. Does not make blocked disk I/O return sooner. |
| Go core | Could simplify some concurrent jobs. | Adds a runtime and FFI. A garbage collector and a new runtime have no demonstrated gain for this workload. |

A compact record store can be built in Swift, C, C++ or Rust. Its layout and allocation policy are the hypothesis to test. The language name alone does not prove lower memory or faster scans.

## Reconsideration test

Try a Rust core only if final native profiles show node allocation, ARC or layout is the remaining bottleneck. Compare the same cold and warm datasets, exact identities, allocated bytes, coverage, peak RSS, cancellation and time until the UI responds. Keep the SwiftUI shell. Accept a replacement only when it improves those results without weakening safety or scan depth.

## Primary sources

- Apple's getattrlistbulk manual describes repeated reads on an open descriptor and per-entry errors: https://github.com/apple-oss-distributions/xnu/blob/main/bsd/man/man2/getattrlistbulk.2 . This is the OS interface all of the native options would need.
- Rust's FFI guide describes C ABI calls and the unsafe boundary that the programmer must validate: https://doc.rust-lang.org/nomicon/ffi.html . Rust would not remove this boundary or the OS wait.
- Swift documents native C++ interoperability: https://www.swift.org/documentation/cxx-interop/ . A measured core replacement can stay behind the existing native app instead of requiring a whole-app rewrite.

The language comparison is an engineering assessment, not a cross-language benchmark. No Rust, C++, Zig or Go scanner was measured in this update.

The later classifier change completed the actual root app pipeline in 96.69
seconds at `5836a68`. That run did not expose its coverage-gap count and the live
filesystem changed between trials. The [qualification record](qualification.md)
keeps those limits beside the native results. It supports improving the existing
implementation, not a cross-language performance claim.


Final source `cbdeeb9` completed the actual root app pipeline in 56.37 seconds,
with 4,478,551 files and explicit partial coverage of 303 gaps. Its longest
heartbeat was 113.9 ms. The controlled classifier trial reduced median CPU time
by 11.331-fold with matching result fields. These results justify the Swift and
C repairs. They do not compare languages or guarantee every whole-drive time.
