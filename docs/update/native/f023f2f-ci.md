# Native compile failure

Both macOS jobs failed before tests at `f023f2f`:

- [App CI](https://github.com/unknown6003/tessera/actions/runs/42511856065)
- [Stress qualification](https://github.com/unknown6003/tessera/actions/runs/42511856069)

The compiler resolved `[statfs]` as an array literal containing the C function.
It then rejected the attempted array initializer call. The cached mount reader
now uses explicit `Array<statfs>` generic syntax to select the imported struct
type. Its native source-metadata regression remains in the test suite.

Neither failed job reached the new native tests or the 400-trial campaign.
The fix needs a fresh macOS build and test result. Linux cannot compile Darwin.
