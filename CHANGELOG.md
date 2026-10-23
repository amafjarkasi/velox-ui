# Changelog

All notable changes to **VeloxUI** are documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/).

---

## [v2.5.1] - 2026-10-22

### Added
- **Embedded ANSI Terminal & Interactive Process Workbench (`Velox.Terminal` - Unit #85)**:
  - Asynchronous, non-blocking sub-process hosting via native Win32 anonymous pipes (`CreatePipe`, `CreateProcessW`, `PeekNamedPipe` polling timer).
  - Comprehensive ANSI / VT100 / xterm-256 and 24-bit TrueColor (`\x1b[38;2;r;g;bm`) escape sequence parser.
  - Double-buffered fixed-pitch terminal canvas (`TVeloxTerminalDisplay`) with sub-pixel alignment, smooth vertical scrollbar, mouse drag selection, and `Ctrl+C` / `Ctrl+A` / `Ctrl+L` shortcuts.
  - Interactive bottom command prompt with vector chevron (`❯`), command history tracking (`↑`/`↓`), and 1-click execution (`Run ↵`).
  - Top toolbar with working directory badge, real-time process state indicators (`● IDLE`, `● RUNNING (PID)`, `● EXITED (Code)`), and quick action buttons (`Clear`, `Copy All`, `Stop`, `cmd`, `powershell`).
  - Zero-allocation plain text and ANSI scrollback buffer export.
- **Terminal Showcase Generator (`TVeloxScreenshot.RenderTerminalShowcase`)**: High-DPI programmatic rendering in Windows 11 Fluent Dark (`vtDark`) and Daylight (`vtLight`) modes.

### Fixed
- **Sub-Pixel Chevron & Input Baseline Centering (`Velox.Terminal`, `Velox.Screenshot`)**:
  - Replaced mismatched characters with mathematically centered anti-aliased GDI+ vector chevrons aligned to text centerlines.
  - Fixed terminal line prompt character spacing (`PromptW := C.TextWidth('> ')`) for natural font-metric separation.
  - Corrected 32-bit DIB alpha channel preservation (`pf24bit` RGB) in `SaveBitmapToPng` to prevent font transparency artifacts.

---

## [v2.5.0] - 2026-10-22

### Added
- **5 High-Value Composite Workflow Components (Expanding Framework to 84 Units)**:
  - **Real-Time Streaming Log Analyzer & Tail (`Velox.LiveLogStreamer` - Unit #80)**: High-throughput log viewer combining non-blocking file watcher (`TVeloxFileWatcher`), double-buffered virtual list (`TVeloxVirtualGrid`), multi-level severity filtering (`vsllDebug`..`vsllFatal`), audio alerts (`TVeloxAudio.ErrorChime`), and multi-format export (CSV, JSON, Markdown).
  - **Configuration Studio & Environment Settings Hub (`Velox.ConfigStudio` - Unit #81)**: Profile management console combining two-column property inspector (`TVeloxPropertyGrid`), regression diffing (`TVeloxDiffView`), multi-level transactional undo/redo (`TVeloxUndoStack`), and JSON profile persistence with instant Dev/Staging/Prod switching.
  - **Executive Mission Control Telemetry Wall (`Velox.TelemetryWall` - Unit #82)**: Multi-channel operations center combining responsive KPI cards (`TVeloxKpiGrid`), GDI+ donut gauges and dual-series sparklines (`TVeloxCharts`), hardware battery status (`TVeloxPower`), and anti-spike hysteresis alerting (`TVeloxThresholdAlert`).
  - **Crash Flight Recorder & Blackbox Diagnostic Center (`Velox.CrashFlightRecorder` - Unit #83)**: Comprehensive diagnostics console combining crash minidumps (`dbghelp.dll`), chronological breadcrumb event timeline (`TVeloxTimeline`), process memory footprint (`TVeloxMemory`), and BCrypt SHA-256 binary validation (`TVeloxCrypto`).
  - **Virtual Data Table, Filter Bar & Pagination Hub (`Velox.DataStudio` - Unit #84)**: High-capacity inventory and dataset workstation combining virtual `OwnerData` grid, pagination controller (`TVeloxPagination`), segmented filter chip bar, instant search filtering, column sorting, and tabular export.
- **Embedded HTTP Workbench & API Debugger (`Velox.RestStudio` - Unit #79)**: Full-featured API debugger combining native WinHTTP TLS 1.3 requests, two-column header & parameter property grid, JSON pretty-printer, payload baseline regression diffing (`TVeloxDiffView`), latency telemetry sparklines (`TVeloxRingBuffer`), and 1-click executable cURL export.
- **Windows 11 DWM Desktop Acrylic (`Velox.Backdrop`)**: Zero-dependency integration of `DWMSBT_TRANSIENTWINDOW` (Attribute 38) and `DWMWA_SYSTEMBACKDROP_TYPE` for real desktop translucent blur-behind on popup flyouts and floating dialogs.
- **Focus Rings & Tab Traversal (`Velox.Accessibility`)**: Universal `TVeloxFocusManager` and `TVeloxFocusRing` handling standard Windows tab/shift-tab cycling, directional arrows, and high-contrast Fluent outer focus rings.
- **Per-Monitor v2 Auto-Rescaling Canvas (`Velox.DpiCanvas`)**: DPI-aware GDI+ drawing context with automatic scaling of rectangles, fonts, cards, and icons across mixed-DPI multi-monitor setups.
- **Smooth 60 FPS Animated Sidebar (`Velox.AppShell`)**: Added animated cubic-ease width transitions between expanded navigation rail (210px) and compact icon-only rail (56px) without frame drops.
- **Infinite Virtual Streaming & Lazy Loading (`Velox.VirtualGrid`)**: Added `OnNeedMoreData` threshold events and `AppendBatch` for smooth telemetry streams and paginated server payloads.

### Fixed
- **Diff Visualizer Sign & Column Alignment (`Velox.DiffView`, `Velox.Screenshot`)**:
  - Replaced hand-drawn line segments with a dedicated 20px centered sign column for `+` and `-` glyphs.
  - Aligned all code lines (added, deleted, unmodified) to a uniform left margin (`X = 488`).
  - Corrected Delphi `TColor` `$00BBGGRR` color inversion (swapped web `#RRGGBB` to native Pascal BGR so deletion text renders vibrant coral red `$7171F8` and background renders dark rose `$1F1836`).
  - Added dynamic light/dark luminance detection in `TVeloxDiffView.ApplyColors`.

---

## [v2.4.0] - 2026-10-21

### Added
- **Scalable GDI+ Vector Icon Engine (`Velox.Icons`)**: 35+ native geometric vector icons (Home, Settings, Search, Terminal, Shield, Cpu, Refresh, etc.) drawn with anti-aliasing without icon fonts or external asset files.
- **Responsive Stack Layout Panel (`Velox.Layout`)**: Added `TVeloxStackPanel` supporting horizontal and vertical auto-wrapping, gap spacing, and dynamic child arrangement.
- **Controls Studio Showcase**: Added unified demonstration studio rendering PropertyGrid, Timeline, DiffView, Stepper, TagInput, Breadcrumb, Rating, and Glass panels in Dark and Daylight themes.

### Fixed
- **Text & Icon Baseline Alignment Across All Controls**:
  - Adjusted vertical centering and optical margins for icons, pills, badges, stepper indicators, and timeline nodes with adjacent text.
  - Fixed button and checkbox label vertical offset on High-DPI displays.

---

## [v2.3.0] - 2026-10-20

### Added
- **8 Composite Workflow Components (Expanding to 73 Units)**:
  - `Velox.InspectorStudio`: Two-column live property grid paired with transactional Undo/Redo rollback stacks.
  - `Velox.DiffInspector`: Side-by-side and unified Myers LCS line diff viewer with similarity scoring.
  - `Velox.ClipboardPalette`: Windows `Win+V` style clipboard history listener (`WM_CLIPBOARDUPDATE`) with fuzzy search and pin favorites.
  - `Velox.NetworkMonitor`: Multi-host ICMP ping monitor with latency tracking and packet-loss calculations.
  - `Velox.TaskExplorer`: Windows NT process diagnostics, working set memory inspection, and service control.
  - `Velox.AuditSecurityLog`: Chronological file system audit log backed by BCrypt SHA-256 integrity hashes.
  - `Velox.JsonTreeViewer`: Hierarchical JSON DOM explorer with color-coded token badges and breadcrumb navigation.
  - `Velox.UpdateFlyout`: GitHub Releases update notification flyout with acrylic backdrop and progress spinner.

---

## [v2.2.0] - 2026-10-19

### Added
- Reached **65 Zero-Dependency Units** milestone.
- Added Explorer breadcrumb navigation (`Velox.Breadcrumb`), MRU list manager (`Velox.Mru`), RGB/HSV color picker (`Velox.ColorPicker`), multi-step pipeline stepper (`Velox.Stepper`), Windows battery & power status monitor (`Velox.Power`), and native WAV audio synthesizer (`Velox.Audio`).
- Added Myers LCS diff calculation (`Velox.Diff`), syntax-highlighted diff viewer (`Velox.DiffView`), and undo/redo command stack (`Velox.Undo`).

---

## [v2.1.0] - 2026-10-18

### Added
- Reached **50 Zero-Dependency Units** milestone.
- Added zero-dependency RFC-8259 JSON parser and builder (`Velox.Json`).
- Added zero-COM Windows Explorer shell drag-and-drop (`Velox.DragDrop`) and non-blocking directory watcher (`Velox.FileWatcher`).
- Added Windows CNG BCrypt cryptographic hashing engine (`Velox.Crypto`) supporting SHA-256, SHA-1, MD5, and CRC32.
- Added native Windows minidump crash reporter (`Velox.CrashReporter`).

---

## [v2.0.0] - 2026-10-16

### Initial Release
- **Initial Open-Source Release of VeloxUI**:
  - 40 core & expansion units for Delphi VCL and Lazarus Free Pascal LCL.
  - Windows 11 Fluent Dark Mode, DWM Mica/Acrylic backdrops, and `uxtheme.dll` dark scrollbars.
  - Hardware-accelerated anti-aliased GDI+ rendering engine (`Velox.GdiPlus`).
  - High-frequency virtual grid (`Velox.VirtualGrid`) and sparkline telemetry grid (`Velox.SparkGrid`).
  - VS Code / Raycast fuzzy command palette (`Velox.CommandPalette`).
  - Complete automated test suite passing with 100% pass rate.
