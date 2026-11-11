# Rescue release qualification

Current status: incomplete. No Rescue redesign release is published. The working version remains 0.2.2 build 14 until the next release candidate is prepared.

The full goal is the confirmed design in `docs/research/rescue-2026-11-11/design-spec.md`. A passing compiler, a source review or a mocked filesystem does not prove the whole flow. The release stays in 0.x.x.

| Requirement | Evidence so far | Required before release |
| --- | --- | --- |
| Largest-first discovery and 12 consumer families | Source review; discovery tests compiled at 1f44e66 within the failed 134-test run | Full passing exact-candidate tests and native fixture results |
| Group review, explicit selection, Back, exclusions | Coordinator tests and source review; later keyboard changes uncompiled | Native keyboard and 100,000-item review, same-source/revision checks, kept identity replacement |
| Owner routes, Retry, return refresh | Coordinator tests and source review | Verify installed app IDs and supported routes; native one-return refresh, failed owner, source change and busy cases |
| Additional-GB goal and capacity labels | Coordinator tests; old 75% confirmation text removed | Native same-volume capacity success/failure, negative change and post-action refresh |
| Recoverable moves and actual Trash destinations | 1f44e66 compiled, but common tracking checks failed | Diagnose the first rejecting guard; passing controlled red/green and full suite; disposable real Finder Trash on supported local volumes |
| Operation-scoped permanent finishing | Separate Risk reviews; acquired-object helper and recovery-map tests written | Native descriptor/durability tests, deterministic replacement, partial failure, cancellation, owner changes, recovery reveal and no unrelated deletion |
| Confirmations and held results | Empty initial selection and Cancel-default source; rejected IDs and recovery paths retained | Native initial focus, Return/Escape, Cancel keeps review, accurate moved/held/failed results |
| Window and appearance | Flat existing surfaces retained; latest Rescue layout unqualified | Captures at minimum, standard and wide sizes; sheets, long names and focus without overlap |
| Accessibility | Source labels, keyboard handling and contrast tokens | Real VoiceOver narration; Increase Contrast and Reduce Motion with restored settings; fixed ten-area rubric with reference evidence |
| Privacy and analytics | No new path-bearing analytics in reviewed changes; production policy unchanged | Automated-run exclusion and allowed new-flow payload checks; no names, paths, search, exclusion identity or raw errors sent |
| Release CI | Existing owned-hardware lanes and exact-head gates | Both signed reports for the final clean commit, full 400-trial campaign, unchanged limits and valid baseline comparison |
| Publication and updater | Existing 0.2.2 release infrastructure | Next 0.x version/build, signing and smoke, matching symbols, verified Sparkle feed and DMG, public asset readback and update path |

The last completed native run is 1f44e66: compilation passed; 134 tests ran and the suite failed with 13 issues across 11 tests. Release was held. Later changes, including the acquired-object helper, are not covered by that run.

The first attempted diagnosis after reconnecting read the earlier evidence but ran no loop and proved no cause. A narrower native task is now assigned to execute one red loop and identify the exact guard. Do not classify that read-only attempt as a successful diagnosis or an external blocker.

Record new evidence with its exact source hash. Preserve failed runs and all performance samples. Use fresh production-state baselines for each Mac run. No agent score is a recruited user study, and no area receives 9/10 without its own native evidence.

## Tracked Trash diagnosis, 12 November

The minimal native loop at 1f44e66 reproduced `subset` and `budgetReplacement`.
Foundation resolved the temporary path to `/var`, leaving a symlink that the
ancestor guard correctly rejected. `realpath` kept `/private/var`. The replacement
hook also missed its target because URL equality distinguished a trailing slash.
The native private-copy patch passed both focused tests. Its evidence is retained
at `/Users/abdwy/.local/share/tessera-trash-diag-nov12/`, including red.log,
green3.log, instrumentation.diff and fix.patch.

The branch now uses physical paths for tracking and path comparison in that hook.
Both disposable test fixtures also retain the physical temporary root. Symlink,
identity, volume and protected-path checks remain in place. The full Trash suites,
the newer descriptor helper and the full current suite still need native proof.
