<p align="center">
  <img src="resources/logo.svg" alt="VeloxUI Logo" width="540" />
</p>

<p align="center">
  <a href="#-19-framework-modules-7-core--12-expansion"><img src="https://img.shields.io/badge/Modules-19%20Zero--Dependency%20Units-6366f1?style=for-the-badge" alt="19 Modules" /></a>
  <a href="#-getting-started--installation"><img src="https://img.shields.io/badge/Compilers-Delphi%20VCL%20%7C%20Free%20Pascal%203.2.2%20LCL-38bdf8?style=for-the-badge" alt="Compilers" /></a>
  <a href="#-before-vs-after-85-less-boilerplate"><img src="https://img.shields.io/badge/Boilerplate%20Reduction--85%25%20LOC-10b981?style=for-the-badge" alt="Boilerplate Reduction" /></a>
  <a href="#-automated-verification-suite-100100-passing"><img src="https://img.shields.io/badge/Tests-100%2F100%20Passing-34d399?style=for-the-badge" alt="Tests" /></a>
  <a href="#-12-hard-won-win32--vcl--lcl-gotchas-solved"><img src="https://img.shields.io/badge/Win11%20Fluent-DWM%20Mica%20%7C%20GDI%2B%20%7C%20High--DPI-f59e0b?style=for-the-badge" alt="Win11 Fluent" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-f43f5e?style=for-the-badge" alt="License" /></a>
</p>

<p align="center">
  <strong>VeloxUI</strong> is a high-velocity, zero-dependency <strong>Object Pascal (Delphi VCL &amp; Lazarus / Free Pascal LCL)</strong> desktop UI and MVVM micro-framework. It distills every hard-won Win32, Windows 11 DWM (Mica/Acrylic/Dark Titlebar), undocumented <code>uxtheme.dll</code> dark scrollbar, High-DPI control alignment, hardware-accelerated <code>GDI+</code> vector rendering, flicker-free virtual <code>TListView</code>, reactive MVVM data-binding, and NT Kernel pattern into <strong>19 drop-in units</strong>.
</p>

---

## 🎯 Why VeloxUI Exists

Native Object Pascal (`Delphi` and `Free Pascal / Lazarus`) is one of the most productive secrets in systems software: it compiles in **~2 seconds** into a **~1.8 MB standalone native executable** that starts in **45 ms**, uses **~11 MB of RAM**, and requires **zero external runtime DLLs** (compared to 180+ MB and 300+ MB RAM for Electron/WebView2).

However, building a **modern Windows 11 Fluent Dark Mode** application in raw VCL/LCL traditionally forces developers to fight dozens of undocumented Win32 quirks:
- Native `TComboBox` controls ignore `.Height` and render taller than adjacent buttons at High-DPI.
- Standard bordered `TEdit` controls clip placeholder text against the top-left border with no vertical centering.
- Native `TCheckBox` and `TButton` controls draw black-on-dark unreadable captions or glaring white Win32 bevels on dark panels due to `UXTheme` overrides.
- Standard `TListView` tables flash white on background erase, lose row selection on refresh, and show blinding white scrollbars in dark mode.
- Standard `MessageDlg` and `InputQuery` dialogs pop up blinding white legacy Win32 windows inside a dark-themed app.
- Standard GDI `Canvas.RoundRect` and `Canvas.Polyline` look jagged and aliased on modern High-DPI displays.

**VeloxUI solves all of these permanently.** Drop the `src/` folder into any Delphi or Lazarus project and build production-grade, flicker-free Windows 11 telemetry dashboards and desktop tools with **85% less code**.

---

## ⚡ Before vs. After: 85% Less Boilerplate

| Task | Raw Win32 / VCL / LCL Boilerplate | With **VeloxUI** |
| :--- | :---: | :---: |
| **1-Line Windows 11 Fluent App Shell (Sidebar + Header Search + Multi-Page Router + Tray)** | ~240 lines (Panels, anchors, page visibility loops, status bar) | **1 line** (`TVeloxAppShell.CreateShell(...)`) |
| **Vertically Centered Search Box with Focus Ring & `Esc` Clear** | ~65 lines (`TPanel` + `bsNone` `TEdit` + 4 event handlers) | **1 line** (`TVeloxSearchBox.CreateBox(...)`) |
| **High-DPI `TComboBox` Pixel-Matched to `TButton` Height** | ~45 lines (`CB_SETITEMHEIGHT` + `GetWindowRect` loop + `OnDrawItem`) | **1 line** (`TVeloxControls.SyncComboBoxHeight(...)`) |
| **Dark-Panel CheckBox (Bypassing Win32 UXTheme Black Text Bug)** | ~30 lines (Captionless `TCheckBox` + synced `crHandPoint` `TLabel`) | **1 line** (`TVeloxDarkCheckBox.CreateCheck(...)`) |
| **GDI+ Custom-Drawn Button & Mutual-Exclusion Filter Chip Bar** | ~150 lines (`TCustomControl` hover/press state machine + pill math) | **1 line** (`TVeloxChipGroup.CreateGroup(...)`) |
| **Win11 Dark Title Bar + Mica Backdrop + Dark Scrollbars + Recursive Theme** | ~120 lines (`dwmapi.dll` + `uxtheme.dll` ordinals `133`/`135` + tree walk) | **2 lines** (`ApplyFormTheme` + `ApplySystemBackdrop`) |
| **GDI+ Anti-Aliased KPI Card, Donut Gauge, Dual Sparkline & HeatGrid** | ~280 lines (GDI+ Flat API loader + arcs + polygon fill + grid math) | **1 line** (`DrawMetricCard` / `DrawDonutGauge` / `DrawHeatGrid`) |
| **Flicker-Free Virtual `TListView` (`OwnerData` + QuickSort + `▲`/`▼` Arrows)** | ~160 lines (`LVS_EX_DOUBLEBUFFER` + QuickSort + UTF-8/UTF-16 arrows) | **4 lines** (`TVeloxVirtualGrid<T>.Create(...)`) |
| **VS Code / Raycast `Ctrl+K` Fuzzy-Search Command Palette** | ~210 lines (Subsequence scorer + owner-draw list + keyboard nav) | **2 lines** (`TVeloxCommandPalette` + `ShowPaletteModal`) |
| **Theme-Aware Fluent `Confirm` / `Alert` / `Prompt` TaskDialogs** | ~110 lines (Replaces blinding white `MessageDlg` & `InputQuery`) | **1 line** (`TVeloxTaskDialog.Confirm(...)`) |

### Side-by-Side Code Comparison

```pascal
// ❌ WITHOUT VELOXUI (~650+ lines of manual Win32 / DWM / GDI+ / ListView / Dialog plumbing)
// Requires manual LoadLibrary('dwmapi.dll'), MAKEINTRESOURCEA(135) uxtheme ordinals,
// manual GDI+ startup token & path arcs, manual pnlSearchBox wrapper events,
// manual CB_SETITEMHEIGHT ($0151) feedback loop, and manual QuickSort.

// ✅ WITH VELOXUI (~25 lines for a Multi-Page Windows 11 Fluent Dark App)
procedure TMainForm.FormCreate(Sender: TObject);
begin
  FColors := TVeloxUtils.GetThemeColors(vtDark);

  // 1. Scaffold complete Windows 11 App Shell (Sidebar, Header Search, Page Router, Status Bar)
  FShell := TVeloxAppShell.CreateShell(Self, 'NovaMonitor', 'LIVE KERNEL TELEMETRY', FColors);
  FTabProcesses := FShell.AddPage('processes', 'Processes');
  FTabServices  := FShell.AddPage('services', 'Services');

  // 2. Segmented GDI+ Filter Chip Bar (All | Heavy RAM | Active CPU | Alerts)
  FChips := TVeloxChipGroup.CreateGroup(Self, FTabProcesses, 16, 12, 28,
    ['All', 'Heavy RAM', 'Active CPU', 'Alerts'], FColors, OnFilterChipSelect);

  // 3. Flicker-free OwnerData Virtual Grid with LVS_EX_DOUBLEBUFFER & natural sorting
  FGrid := TVeloxVirtualGrid<TProcessRow>.Create(lvProcesses);
  FGrid.AddColumn('PID', 70, taLeftJustify, False);                // Text/ID: Ascending first
  FGrid.AddColumn('Process Name', 200, taLeftJustify, False);      // Text: Ascending first
  FGrid.AddColumn('Working Set (RAM)', 130, taRightJustify, True); // Numeric: Descending first!

  // 4. Register Ctrl+K Command Palette & Declarative Hotkeys
  FCmdPalette := TVeloxCommandPalette.Create(Self);
  FCmdPalette.RegisterCommand('export.csv', 'Export Table to CSV', 'Data', 'Ctrl+E', ExportCsv);

  // 5. Apply Win11 Dark Titlebar, Mica Backdrop, Dark Scrollbars & Recursive Theme
  TVeloxThemeEngine.ApplyFormTheme(Self, vtDark);
  TVeloxThemeEngine.ApplySystemBackdrop(Handle, vbtMica);
end;
```

---

## 📦 19 Framework Modules (7 Core + 12 Expansion)

### Part I — 7 Core Foundation Modules

#### 1. [`src/Velox.Types.pas`](src/Velox.Types.pas) — Tokens, Ring Buffers & Cross-Compiler Glyphs
| Component | Purpose |
| :--- | :--- |
| **`TVeloxThemeColors`** | Semantic Fluent Dark (`vtDark`) and Daylight (`vtLight`) palettes (`Background`, `Surface`, `SurfaceCard`, `Accent`, `Success`, `Warning`, `Danger`, `Border`) |
| **`TVeloxRingBuffer`** | Fixed-capacity `O(1)` zero-allocation circular buffer for rolling sparkline histories with `.Latest`, `.Average`, `.Peak`, and `.ToArray` |
| **Cross-Compiler Unicode Constants** | `VELOX_ARROW_ASC` (`▲`), `VELOX_ARROW_DESC` (`▼`), `VELOX_TREE_BRANCH` (`└─`), and `VELOX_MIDDOT` (`·`) encoded automatically as UTF-8 for FPC/LCL and UTF-16 for Delphi VCL |
| **`TVeloxUtils`** | `BlendColor`, `FormatBytes`, `FormatMegabytes` (auto-scales to `GB`), `FormatRateKBps` (auto-scales to `MB/s`), `FormatPercent`, and `FormatDuration` |

#### 2. [`src/Velox.Theme.pas`](src/Velox.Theme.pas) — Win11 DWM Mica, Dark Titlebars & Undocumented `uxtheme.dll`
| Component | Purpose |
| :--- | :--- |
| **`TVeloxThemeEngine.ApplyFormTheme`** | Recursively styles any `TForm` and all nested controls (`TPanel`, `TLabel`, `TEdit`, `TMemo`, `TListView`, `TComboBox`) in one call |
| **`TVeloxThemeEngine.ApplyDarkTitleBar`** | Enables Windows 10/11 Immersive Dark Title Bar via `DwmSetWindowAttribute` (`Attr 20` with automatic fallback to `Attr 19`) |
| **`TVeloxThemeEngine.ApplySystemBackdrop`** | Enables Windows 11 22H2+ **Mica** (`vbtMica`), **Acrylic** (`vbtAcrylic`), or **Mica Alt** (`vbtTabbed`) via `DWMWA_SYSTEMBACKDROP_TYPE` (`Attr 38`) |
| **`TVeloxThemeEngine.ApplyDarkScrollbars`** | Resolves undocumented `uxtheme.dll` ordinals `135` (`SetPreferredAppMode`), `133` (`AllowDarkModeForWindow`), and `SetWindowTheme('DarkMode_Explorer', nil)` for native dark scrollbars on `TListView` and `TMemo` |
| **`TVeloxThemeEngine.DetectSystemTheme`** | Reads `HKCU\...\Personalize\AppsUseLightTheme` to match the user's Windows OS theme automatically |

#### 3. [`src/Velox.GdiPlus.pas`](src/Velox.GdiPlus.pas) — Hardware-Accelerated `GDI+` Vector & Telemetry Engine
| Component | Purpose |
| :--- | :--- |
| **`TVeloxGdiPlus.DrawMetricCard`** | Complete 1-call KPI Card renderer with title, auto-fitting primary metric value (shrinks font size if needed so it never collides with the upper-right sparkline), subtitle, rolling sparkline, and bottom progress bar |
| **`TVeloxGdiPlus.DrawSparkline`** | Sub-pixel anti-aliased (`SmoothingModeAntiAlias`) time-series polyline with translucent vertical polygon area fill |
| **`TVeloxGdiPlus.DrawCard`** | Crisp rounded rectangle container with `1px` border and automatic GDI fallback |
| **`TVeloxGdiPlus.DrawProgressBar` / `DrawBadge`** | Smooth pill-shaped progress bars and centered bold status badges |

#### 4. [`src/Velox.Controls.pas`](src/Velox.Controls.pas) — Fluent Control Factories & High-DPI Fixers
| Component | Purpose |
| :--- | :--- |
| **`TVeloxSearchBox`** | Wraps a borderless `bsNone` `TEdit` inside a custom-bordered `TPanel` with exact vertical centering (`Top = (Height - 16) div 2`), `10px` left margin, focus ring highlight, and `Esc`-to-clear |
| **`TVeloxControls.SyncComboBoxHeight`** | Uses `CB_SETITEMHEIGHT` (`$0151`) + `GetWindowRect` feedback loop + `SetWindowPos` so `csOwnerDrawFixed` `TComboBox` controls match adjacent `TButton` heights to the exact pixel at any DPI |
| **`TVeloxDarkCheckBox`** | Pairs a captionless `TCheckBox` with a synchronized `crHandPoint` `TLabel` so dark-mode checkboxes never suffer from the Win32 `UXTheme` black-text bug |
| **`TVeloxControls.CreateModalDialog`** | Scaffolds a themed modal dialog (`HeaderPanel`, `TitleLabel`, `SubtitleLabel`, `BodyPanel` or `Consolas` `TMemo`, `FooterPanel`, `PrimaryButton`, `CancelButton`) in 1 call |

#### 5. [`src/Velox.VirtualGrid.pas`](src/Velox.VirtualGrid.pas) — Generic Zero-Flicker Virtual Table (`TVeloxVirtualGrid<T>`)
| Component | Purpose |
| :--- | :--- |
| **`AttachListView` & `EnableNativeDoubleBuffer`** | Configures `OwnerData := True`, `RowSelect := True`, `ColumnClick := True`, and sends `LVM_SETEXTENDEDLISTVIEWSTYLE` (`$1036`) with `LVS_EX_DOUBLEBUFFER` (`$00010000`) |
| **`AddColumn` & `ClickColumn`** | Registers columns with `DefaultDescending` metadata: clicking a numeric/metric column sorts **descending first** (largest consumers on top); clicking a text/ID column sorts **ascending first** |
| **`SortList`** | Generic in-place `QuickSort` over `TList<T>` using a clean `TVeloxCompareFunc<T>` callback |
| **`RefreshCount` & `StretchLastColumn`** | Updates virtual row count without resetting selection/scroll position when row count is unchanged, and stretches the final column to `ClientWidth` |

#### 6. [`src/Velox.Async.pas`](src/Velox.Async.pas) — Interruptible Background Poller & Alert State Machine
| Component | Purpose |
| :--- | :--- |
| **`TVeloxPoller<T>`** | Generic background worker thread that runs collection callbacks off-thread, marshals results via `TThread.Queue`, supports live `SetInterval(Ms)`, and sleeps in `50ms` slices for `<50ms` instant shutdown |
| **`TVeloxThresholdAlert`** | Hysteresis + sustained streak + cooldown state machine for CPU/RAM/latency alerting without notification flapping |

#### 7. [`src/Velox.System.pas`](src/Velox.System.pas) — Win32 & NT Kernel Helpers (`TVeloxSystem`)
| Component | Purpose |
| :--- | :--- |
| **`GetProcessCommandLine(PID)`** | Queries `NtQueryInformationProcess` (`ProcessCommandLineInformation = 60` in `ntdll.dll`) using only `PROCESS_QUERY_LIMITED_INFORMATION` (`$1000`)—no `PROCESS_VM_READ` or Admin required for same-user processes |
| **`GetFileVersionMetadata(Path)`** | Extracts `FileDescription`, `CompanyName` (Digital Publisher), and `FileVersion` via `version.dll` |
| **`GetProcessGuiResources(PID)`** | Reads per-process `GDI` and `USER` object counts via `GetGuiResources` (`user32.dll`) for handle leak detection |
| **`GetProcessAffinity` / `SetProcessAffinity`** | Reads and updates logical CPU core affinity masks (`GetProcessAffinityMask` / `SetProcessAffinityMask`) with `PID 0`/`4` guards |
| **`TrimProcessWorkingSet(PID)`** | Reclaims unused physical RAM pages from a process via `EmptyWorkingSet` (`psapi.dll`) |
| **`RunTask(Cmd, RunAsAdmin)`** | Launches executables or commands with optional `'runas'` UAC Administrator elevation (`ShellExecuteExW`) |

---

### Part II — 12 Expansion & Ecosystem Modules

#### 8. [`src/Velox.Export.pas`](src/Velox.Export.pas) — Universal Tabular Exporter (`TVeloxExporter`)
- Exports any dataset or `OwnerData` virtual grid via a `TVeloxCellProvider` callback to **RFC-4180 CSV** (`BuildCsvTable` / `SaveCsvTable`), **Structured JSON** (`BuildJsonTable` / `SaveJsonTable`), **GitHub Flavored Markdown (GFM)** tables (`BuildMarkdownTable` with automatic `\|` escaping), or directly to the OS **Clipboard** (`CopyRowToClipboard`).

#### 9. [`src/Velox.Hotkeys.pas`](src/Velox.Hotkeys.pas) — Declarative Hotkey & Cheat-Sheet Registry (`TVeloxHotkeyRegistry`)
- Replaces sprawling `FormKeyDown` `if/else` chains with 1-line `Bind(Ord('F'), [ssCtrl], 'Ctrl+F', 'Focus search bar', OnFocusSearch, 'Navigation')` calls, dispatches keystrokes via `HandleKeyDown`, and auto-generates a formatted **Keyboard Shortcuts Cheat Sheet** (`GenerateCheatSheet` / `ShowCheatSheetModal`).

#### 10. [`src/Velox.Config.pas`](src/Velox.Config.pas) — Zero-Dependency Config & Multi-Monitor Window Placement (`TVeloxConfig`)
- Persists `String`, `Int`, `Bool`, `TVeloxTheme`, and `CaptureFormBounds` / `RestoreFormBounds` (`Left`, `Top`, `Width`, `Height`, `fsStayOnTop`). Includes `ClampToDesktop` so an unplugged secondary monitor never strands a window off-screen.

#### 11. [`src/Velox.Charts.pas`](src/Velox.Charts.pas) — Advanced `GDI+` Visualizations (`TVeloxCharts`)
- **`DrawDonutGauge`**: Hardware-accelerated radial arc gauge (`GdipDrawArc`) with centered bold primary metric and sub-caption.
- **`DrawDualSparkline`**: Overlapping 2-series telemetry chart (e.g. Network Download vs. Upload, Disk Read vs. Write) with translucent polygon fills.
- **`DrawHeatGrid`**: Multi-cell utilization heatmap grid (e.g. 4..64 CPU cores) colored dynamically by load severity.

#### 12. [`src/Velox.Toast.pas`](src/Velox.Toast.pas) — Non-Blocking Floating GDI+ Toast Banner (`TVeloxToast`)
- Anchors a sleek severity-colored floating notification card to the bottom-right of any parent form/panel (`ShowToast`) with automatic `TTimer` dismissal (`Dismiss`) and click-to-close—zero UI thread blocking.

#### 13. [`src/Velox.EventBus.pas`](src/Velox.EventBus.pas) — Thread-Safe Pub/Sub Message Aggregator (`TVeloxEventBus`)
- Inspired by [`spinettaro/delphi-event-bus`](https://github.com/spinettaro/delphi-event-bus) and `Spring4D`. Decouples background collectors, ViewModels, and UI views using `TCriticalSection`-protected `Subscribe(Topic, Handler)`, wildcard `'*'` listeners, and `Publish(Topic, Payload, Value, Severity)`.

#### 14. [`src/Velox.Reactive.pas`](src/Velox.Reactive.pas) — Generic `TVeloxObservable<T>` & `TVeloxDebouncer`
- **`TVeloxObservable<T>`**: Inspired by Grijjy MVVM & RxDelphi. Wraps any typed value, notifies subscribers on change, and supports 1-line `BindLabel(lblCount, 'Processes: ', ' active', FormatInt)` automatic caption binding.
- **`TVeloxDebouncer`**: Coalesces rapid-fire UI events (such as search-as-you-type keystrokes or resize events) via `Trigger` / `Flush` / `Cancel`.

#### 15. [`src/Velox.TreeBuilder.pas`](src/Velox.TreeBuilder.pas) — Generic `O(N)` Flat-to-Hierarchical Tree Flattener (`TVeloxTreeBuilder<T>`)
- Inspired by [`JAM-Software/Virtual-TreeView`](https://github.com/JAM-Software/Virtual-TreeView) and System Informer. Reconstructs parent-child trees in `O(N)` from any flat `TList<T>`, guards against cyclic parent chains (`MaxDepth = 32`), and formats indented `└─ ` branch labels (`FormatIndentedCaption`).

#### 16. [`src/Velox.StyledButton.pas`](src/Velox.StyledButton.pas) — GDI+ Custom Button & Filter Chip Bar (`TVeloxStyledButton` & `TVeloxChipGroup`)
- Inspired by [`EtheaDev/StyledComponents`](https://github.com/EtheaDev/StyledComponents) and [`bgrabitmap/bgracontrols`](https://github.com/bgrabitmap/bgracontrols).
- **`TVeloxStyledButton`**: Custom-drawn GDI+ rounded button with hover/press states and semantic variants (`vsbSurface`, `vsbPrimary`, `vsbDanger`, `vsbOutline`)—never shows white Win32 borders in dark mode.
- **`TVeloxChipGroup`**: Mutual-exclusion segmented pill filter bar (`['All', 'Heavy RAM', 'Active CPU', 'Alerts']`) with true active accent fills.

#### 17. [`src/Velox.TaskDialog.pas`](src/Velox.TaskDialog.pas) — Fluent Theme-Aware TaskDialog (`TVeloxTaskDialog`)
- Dark/Light theme-aware replacement for legacy VCL/LCL `MessageDlg` and `InputQuery`. Provides `Confirm`, `ConfirmEx` (with a dark-safe `"Don't ask again"` checkbox), `Alert`, `Prompt` (themed text input), and headless `BuildDialog`.

#### 18. [`src/Velox.CommandPalette.pas`](src/Velox.CommandPalette.pas) — VS Code / Raycast Fuzzy Command Palette (`TVeloxCommandPalette`)
- Drop-in `Ctrl+K` / `Ctrl+Shift+P` command overlay with subsequence fuzzy scoring (`FuzzyMatchScore`), category badges, keyboard navigation (`Up`/`Down`/`Enter`/`Esc`), and instant execution (`ShowPaletteModal` / `ExecuteById`).

#### 19. [`src/Velox.AppShell.pas`](src/Velox.AppShell.pas) — 1-Line Windows 11 Desktop Application Shell (`TVeloxAppShell`)
- Inspired by [`WPFLiteUI/LiteUI`](https://github.com/WPFLiteUI/LiteUI) NavigationView. Scaffolds a complete Windows 11 desktop layout (`SidebarPanel`, `BrandPanel`, `HeaderPanel`, `SearchBox`, `ContentPanel`, `FooterPanel`, `AddPage`/`SwitchPage` router, `SetStatusMessage`, and `EnableTrayIcon`) in a single constructor call.

---

## 🏗 Compact Architecture Diagrams

### 1. High-Level Layer Flow

```mermaid
flowchart LR
    OS["Win32 / NT Kernel / DWM"] -->|"Syscalls"| SYS["Velox.System & Velox.Async"]
    SYS -->|"EventBus & Observable<T>"| VM["Velox.Reactive & Velox.TreeBuilder<T>"]
    VM -->|"OwnerData"| GRID["Velox.VirtualGrid<T> & Velox.Export"]
    THEME["Velox.Theme, Velox.GdiPlus & Velox.Charts"] --> SHELL["Velox.AppShell & Velox.Controls"]
    GRID --> SHELL
```

### 2. Win11 Dark Mode & GDI+ Rendering Pipeline

```mermaid
flowchart TD
    DWM["dwmapi.dll\nDark Titlebar (20)\nMica Backdrop (38)"] --> TE["Velox.ThemeEngine"]
    UX["uxtheme.dll\nOrdinals 135 & 133\nDarkMode_Explorer"] --> TE
    GP["gdiplus.dll\nSmoothingModeAntiAlias\nCards, Gauges & Sparklines"] --> GE["Velox.GdiPlus & Velox.Charts"]
```

### 3. Interruptible Async Polling & Reactive Binding Lifecycle

```mermaid
sequenceDiagram
    autonumber
    participant WT as TVeloxWorkerThread<T>
    participant BUS as TVeloxEventBus / Observable<T>
    participant UI as Main GUI Thread (AppShell)

    loop 50ms Interruptible Sleep Slices
        WT->>UI: Queue(SyncDeliver)
        UI->>BUS: Publish Telemetry & Update Observable<T>
        BUS->>UI: Update Bound Labels, Toast Alerts & VirtualGrid
    end
```

---

## 🧠 12 Hard-Won Win32 / VCL / LCL Gotchas Solved

We built **VeloxUI** so you never have to waste hours debugging these 12 obscure Delphi, Lazarus/FPC, and Win32 desktop traps again:

| # | The Win32 / Delphi / Lazarus Trap | Root Cause | How **VeloxUI** Solves It Automatically |
| :---: | :--- | :--- | :--- |
| **1** | **`TComboBox` ignores `.Height`** and renders too tall or too short next to `TButton` at High-DPI | Win32 `ComboBox` computes its outer height from `CB_SETITEMHEIGHT ($0151) + 2*SM_CYEDGE` instead of `WM_SIZE` | [`TVeloxControls.SyncComboBoxHeight`](src/Velox.Controls.pas) measures the reference button via `GetWindowRect` and runs a 2-pass `CB_SETITEMHEIGHT` feedback loop |
| **2** | **`TEdit` placeholder & text are pinned to the top-left border** with no vertical centering | Standard Win32 single-line edit controls do not support vertical internal padding | [`TVeloxSearchBox`](src/Velox.Controls.pas) wraps a borderless `bsNone` `TEdit` at `Top = (Height - 16) div 2` inside a custom-painted `TPanel` with `10px` left margin |
| **3** | **`TCheckBox` caption renders black-on-dark** and is invisible on dark panels | Windows `UXTheme` overrides `TCheckBox` text color when themes are enabled | [`TVeloxDarkCheckBox`](src/Velox.Controls.pas) sets `CheckBox.Caption := ''` and pairs a synchronized `crHandPoint` `TLabel` |
| **4** | **`TListView` flashes white on update** and loses selected row / scroll position | Assigning `Items.Count` unconditionally triggers `WM_ERASEBKGND` and resets viewport state | [`TVeloxVirtualGrid<T>`](src/Velox.VirtualGrid.pas) enables `LVS_EX_DOUBLEBUFFER ($10000)` and only updates `Items.Count` when the count changes, calling `Invalidate` otherwise |
| **5** | **`TListView` and `TMemo` show bright white scrollbars** in dark mode | Win32 common controls default to the light `"Explorer"` theme unless opted in via undocumented `uxtheme.dll` ordinals | [`TVeloxThemeEngine`](src/Velox.Theme.pas) invokes `uxtheme.dll` Ordinal `135` (`SetPreferredAppMode`), Ordinal `133` (`AllowDarkModeForWindow`), and `SetWindowTheme('DarkMode_Explorer', nil)` |
| **6** | **Compile Error on `Rect(0, 0, W, H)`** (`Incompatible types: got "RECT" expected "TRect"`) | Putting `Windows` after `Types` in `uses` causes the `Windows.RECT` struct to shadow `Types.Rect()` function | All VeloxUI units enforce `Windows` **before** `Types` in `uses` |
| **7** | **Compile Error on `GetEnvironmentVariable` / `DeleteFile`** (`Wrong number of parameters` / `PChar`) | `Windows.GetEnvironmentVariable` and `Windows.DeleteFile` shadow `SysUtils` overloads | Always qualify `SysUtils.GetEnvironmentVariable` and `SysUtils.DeleteFile` when `Windows` is in `uses` |
| **8** | **Compile Error on `odSelected in State`** in `OnDrawItem` under Lazarus/FPC | `Types` defines a conflicting `TOwnerDrawState`; LCL requires `LCLType` after `Types` | [`Velox.Controls.pas`](src/Velox.Controls.pas) and [`Velox.CommandPalette.pas`](src/Velox.CommandPalette.pas) include `{$IFDEF FPC} LCLType, {$ENDIF}` immediately after `Types` |
| **9** | **FPC 3.2.2 Error `(3339)`**: `Global Generic template references static symtable` | Free Pascal generic classes cannot reference constants declared in the `implementation` global scope | [`Velox.VirtualGrid.pas`](src/Velox.VirtualGrid.pas) and [`Velox.TreeBuilder.pas`](src/Velox.TreeBuilder.pas) scope constants locally inside generic methods or in `interface` |
| **10** | **FPC 3.2.2 `TThread.Queue` incompatibility** with anonymous closures | FPC 3.2.2 `TThread.Queue` expects a `TThreadMethod` (`procedure of object`) | [`TVeloxWorkerThread<T>`](src/Velox.Async.pas) uses a typed `FPendingData: T` field and `Queue(SyncDeliver)` method |
| **11** | **Corrupted `▲`/`▼` sort arrows (Mojibake)** between Delphi and Lazarus | Lazarus LCL strings are UTF-8 while Delphi VCL strings are UTF-16 | [`Velox.Types.pas`](src/Velox.Types.pas) defines `VELOX_ARROW_ASC` / `VELOX_ARROW_DESC` using `#$E2#$96#$B2` on FPC and `#$25B2` on Delphi |
| **12** | **`OpenProcess(PROCESS_VM_READ)` fails with Access Denied** when reading process command lines | Reading another process's PEB directly requires `PROCESS_VM_READ` | [`TVeloxSystem.GetProcessCommandLine`](src/Velox.System.pas) queries `NtQueryInformationProcess` Class `60` (`ProcessCommandLineInformation`), which only requires `PROCESS_QUERY_LIMITED_INFORMATION ($1000)` |

---

## 🧪 Automated Verification Suite (`100/100 Passing`)

VeloxUI includes a self-contained console verification suite ([`tests/veloxtest.lpr`](tests/veloxtest.lpr)) that tests all **19 modules** headlessly in ~2.5 seconds:

```powershell
# Compile and run the 100-assertion verification suite with Lazarus / Free Pascal
lazbuild -B tests\veloxtest.lpi
.\tests\lib\veloxtest.exe
```

| Test Suite Section | Assertions | What Is Verified |
| :--- | :---: | :--- |
| **`[1/19]` RingBuffer & Utils** | `15` | Circular capacity cap, oldest eviction, `.Latest`/`.Peak`/`.Average`, Dark/Light token palettes, `BlendColor`, `FormatBytes`/`MB`/`KBps`/`Percent`/`Duration`, UTF-8/UTF-16 arrows |
| **`[2/19]` GDI+ Vector Engine** | `4` | Hardware-accelerated `DrawCard`, `DrawProgressBar`, `DrawBadge`, and `DrawSparkline` on offscreen bitmaps |
| **`[3/19]` DWM & UXTheme Engine** | `2` | Process-wide `InitializeProcessDarkMode` (Ordinal 135) and OS registry `DetectSystemTheme` |
| **`[4/19]` Fluent Controls & Modals** | `12` | `TVeloxSearchBox` 28px wrapper, `bsNone`, `Top=6` vertical centering, `Left=10` margin; `TVeloxDarkCheckBox` caption decoupling; `SyncComboBoxHeight`; `ApplyFormTheme`; `CreateModalDialog` |
| **`[5/19]` Generic VirtualGrid** | `9` | Automatic `OwnerData`, column registration, numeric column defaulting to **descending** on first click, text column defaulting to **ascending** on first click, QuickSort ordering, header arrows, `RefreshCount` |
| **`[6/19]` Async Poller & Alerts** | `9` | Sustained streak gating (`2/2`), immediate escalation to `vsCritical`, hysteresis recovery margin, live `SetInterval`, and `<50ms` interruptible thread shutdown |
| **`[7/19]` Win32 & NT System** | `8` | `NtQueryInformationProcess(60)` command-line extraction, `PID 0` guard, `version.dll` Microsoft publisher metadata on `kernel32.dll`, `GetGuiResources`, CPU affinity masks, `EmptyWorkingSet`, and `RunTask` guards |
| **`[8/19]` Universal Exporter** | `5` | RFC-4180 CSV field quoting, JSON escaping, `BuildCsvTable`, `BuildJsonTable`, and GFM `BuildMarkdownTable` pipe escaping |
| **`[9/19]` Declarative Hotkeys** | `3` | Shortcut registration, `HandleKeyDown` key interception (`Ctrl+F`), and `GenerateCheatSheet` output |
| **`[10/19]` Config & Bounds Clamp** | `6` | INI key/value persistence (`String`, `Int`, `Bool`, `Theme`) and `ClampToDesktop` off-screen monitor rescue |
| **`[11/19]` Advanced GDI+ Charts** | `3` | `DrawDonutGauge`, `DrawDualSparkline`, and multi-cell `DrawHeatGrid` rendering |
| **`[12/19]` Floating Toast Banner** | `2` | Non-blocking `ShowToast` visibility/severity state and `Dismiss` lifecycle |
| **`[13/19]` Thread-Safe EventBus** | `4` | Topic subscription, wildcard `'*'` routing, synchronous `Publish` delivery count, and `Unsubscribe` |
| **`[14/19]` Reactive Observable & Debouncer** | `4` | `TVeloxObservable<T>.BindLabel` live caption formatting, subscriber notification, and `TVeloxDebouncer` `Trigger`/`Flush` coalescing |
| **`[15/19]` Generic TreeBuilder** | `2` | `O(N)` DFS hierarchy flattening (`root -> child -> grandchild` depths `0, 1, 2`) and `FormatIndentedCaption` (`└─ `) |
| **`[16/19]` StyledButton & ChipGroup** | `3` | `TVeloxStyledButton` custom variant creation and `TVeloxChipGroup` mutual-exclusion chip switching |
| **`[17/19]` Fluent TaskDialog** | `1` | Headless `BuildDialog` verification of themed `BodyLabel`, `InputEdit`, and `TVeloxDarkCheckBox` |
| **`[18/19]` Fuzzy Command Palette** | `4` | Command registration, subsequence `FuzzyMatchScore`, ranked `FilterCommands`, and `ExecuteById` callback invocation |
| **`[19/19]` Win11 Desktop AppShell** | `4` | `CreateShell` scaffolding, `AddPage`/`SwitchPage` multi-page routing, `SetStatusMessage`, and `ApplyColors` live theme switching |

---

## 🚀 Getting Started & Installation

### 1. Clone the Repository
```powershell
git clone https://github.com/amafjarkasi/velox-ui.git
```

### 2. Add to Lazarus (`LCL`) or Delphi (`VCL`)
- **Lazarus**: In **Project → Project Options → Compiler Options → Paths**, add `..\velox-ui\src` to **Other unit files (`-Fu`)**.
- **Delphi**: In **Project → Options → Delphi Compiler → Search path**, add `..\velox-ui\src`.

### 3. Check Out the Complete Quick-Start Example
See [`examples/QuickStartDashboard.pas`](examples/QuickStartDashboard.pas) for a complete, ready-to-run Windows 11 Dark Mode telemetry dashboard.

---

## 📄 License

Released under the [MIT License](LICENSE).
