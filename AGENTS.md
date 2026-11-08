# Tessera project rules

Tessera stays in the 0.x.x release series. Publish 1.0.0 or any later major
version only after Ammar explicitly requests that milestone. A request for a
major update does not grant that permission. Environment variables and prior
agent actions do not grant it either.

The scan goal is p99 completion within 120 seconds on local drives. This is a
performance goal, not a scan timeout. Keep reading healthy local drives after
120 seconds. Report cloud and remote-drive results separately. Record sample
count, hardware, workload, cache state and coverage with every p99 claim.

Use Opus agents for UI research, design and UI changes. Score Tessera and each
reference with the same rubric. Preserve evidence for each score and each
iteration. Scores from agents are design reviews, not user-study results.

Normal configured builds collect anonymous analytics without an in-app or
manual environment opt-out. Send no file names, paths, contents, search
text, volume names, account names, persistent hardware IDs or raw error text.
Keep automated tests and benchmark runs out of production analytics.
