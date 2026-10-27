## Project

Native macOS menu-bar app, Swift and AppKit only; no packages, administrator access, Dock icon, network access, or persistent logging. Requires macOS 13+, Command Line Tools and `just`; no Xcode project or Swift package. Build for the host architecture with `just build`, launch with `just run`, and check live readings with `just check`. The app is ad-hoc signed, not notarized; quit an existing copy before launching a new build.

### Layout and changes

- `Sources/main.swift`: startup and Dock icon suppression.
- `Sources/MenuBarApp.swift`: menu bar, dropdown and five-second timer. Change the timer or status text here.
- `Sources/MemoryStats.swift`: system readings and GB formatting; change `%.2f` for precision.
- `Sources/AppMemory.swift`: process footprints and app grouping. To change the top-three count, update `.prefix(3)` here and `0..<3` in `MenuBarApp.swift` together.
- `Resources/Info.plist`: app metadata and menu-bar configuration.
- `Tests/SmokeCheck.swift`: live-counter sanity check. `justfile` builds the four source files directly into `build/RAM Monitor.app`.

### Measurement semantics

- RAM used: anonymous minus purgeable pages, plus wired and compressed pages, from `host_statistics64`. Cached: file-backed plus purgeable pages. Swap: `vm.swapusage` via `sysctlbyname`.
- Pressure: `kern.memorystatus_vm_pressure_level`, not RAM percentage. If unavailable, show unavailable/white rather than guessing; this counter is less stable than the core Mach API.
- App memory: sum `ri_phys_footprint` from `proc_pid_rusage` for processes with executable paths inside each running GUI app bundle. Helpers are included, but externally hosted services and restricted processes may be missed. Rankings are approximate and can differ from Activity Monitor.
- GB means 1,073,741,824 bytes. Failed reads show `—`, never a fabricated zero. System readings refresh every five seconds; enumerate processes only when the dropdown opens or refreshes while open.
- `just check` checks basic ranges, formatting and ranking order, not ±5% agreement. Compare with Activity Monitor at roughly the same time to assess accuracy; no exact accuracy or resource-usage benchmark is claimed.

## Environment Instructions

Follow these conventions for all tasks:

### Temporary Files

- Use `/private/tmp/tmpfs/swift` for ALL temporary files, including existing temporary files you create or manage and any new intermediate artifacts. Keep in mind that the folder size limit is 500 MB in total.
- Create `/private/tmp/tmpfs/swift` if it does not exist.
- Do not use `/tmp`, system temporary directories, or other locations for temporary files unless the program you use doesn't give you any control over it.
- Keep final deliverables in their intended output locations.

### Python Environment

- Use the current project's existing virtual environment (`.venv` or the active `VIRTUAL_ENV`).
- Use `uv` for Python package installation, dependency management, and environment operations.
- Prefer `uv run` for Python execution.
- Do not create or replace virtual environments unnecessarily.
- Do not use `pip` directly when `uv` can perform the operation.

### Swift environment

- There's no xcode installed but swift and swiftc are installed.

### PDF Utilities

The following tools are already installed and available on PATH:

- `pdftotext` — Extract text from PDF files.
- `pdftoppm` — Render PDF pages to images.
- `pdfinfo`

Use these tools directly when appropriate. Do not reinstall them.
