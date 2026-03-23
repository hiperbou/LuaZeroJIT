# Command Reference for zero-is-false spec

This document is the single source of truth for all commands used during task execution.
Check here before inventing a new command. Update when a new command is confirmed working.

---

## Clean command

Run this before any build to guarantee a fresh compile (the `mingw32-make clean` target fails in bash because it uses `del`):

```bat
.\src\w64clean.bat
```

This deletes all `.o`, `.exe`, `.dll`, `.a`, generated headers, and `host/` artifacts from `src/`.
The build scripts now call it automatically, so you only need this manually if you want to clean without building.

---

## Build commands

Each build script must be called from the repo root. They `cd` internally to `src/`.

```bat
# Phase 1 — 32-bit, JIT disabled
.\src\w64build_amalg_32bit_nojit.bat

# Phase 2 — 32-bit, JIT enabled
.\src\w64build_amalg_32bit.bat

# Phase 3 — 64-bit, JIT disabled
.\src\w64build_amalg_64bit_nojit.bat

# Phase 4 — 64-bit, JIT enabled
.\src\w64build_amalg_64bit.bat
```

The scripts call `mingw32-make clean` then `mingw32-make amalg` and output `src/luajit.exe`.

---

## Test commands

The test binary is always `src\luajit.exe` (updated in-place by each build).
Run each test file individually from the repo root:

```bat
.\src\luajit.exe test\test_zero.lua
.\src\luajit.exe test\test_truthiness.lua
.\src\luajit.exe test\test_zero_extra.lua
.\src\luajit.exe test\test_patterns.lua
.\src\luajit.exe test\test_properties.lua
```

Note: `test\luajit.exe` also exists but is a separate binary — always use `src\luajit.exe`
after a build to test the freshly compiled binary.

---

## Notes

- Do NOT use `&&` — this is a Windows bat/cmd environment. Use separate commands or `;` in PowerShell.
- The build scripts handle `clean` + `amalg` internally; no need to call make directly.
- After each build, `src\luajit.exe` is replaced with the new binary.
