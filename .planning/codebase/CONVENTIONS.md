# Coding Conventions

**Analysis Date:** 2026-04-18

## Naming Patterns

**Files:**
- Use one public top-level function per `.m` file, and keep the filename identical to that function name, e.g. `main_gotha_bp.m`, `src/bp_validate_config.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.
- Use lower snake case for exported MATLAB functions. Core imaging files use the `bp_` prefix under `src/`, compressed-sensing recovery files use the `cs_` prefix under `cs_echo_recovery/`, and demo entry points use `main_` or `run_`, e.g. `main_gotha_bp.m` and `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Keep config factory names literal and singular: `config/default_config.m` and `cs_echo_recovery/cs_default_config.m`.

**Functions:**
- Match the exported function name to the file name exactly.
- Name private helpers with a `local` prefix and lowerCamelCase, e.g. `localPrepareRunDir`, `localResolvePRF`, `localAnalyzeRandomGapConstraints`, and `localRunFista` in `src/bp_output_pipeline.m`, `src/bp_run_point_analysis.m`, `src/bp_interruption_pipeline.m`, and `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`.
- Keep action-oriented function names. Verbs such as `build`, `save`, `validate`, `resolve`, `run`, `load`, and `recover` dominate the current codebase.

**Variables:**
- Use lowerCamelCase for local variables and struct fields, e.g. `projectRoot`, `workspaceRoot`, `rangeUpsampleFactor`, `randomSeedUsed`, `pointAnaCfg`, and `progressUpdateInterval` in `main_gotha_bp.m`, `config/default_config.m`, and `src/bp_output_pipeline.m`.
- Use descriptive temporary names instead of single-letter loop state outside tight numeric formulas, e.g. `candidateRoot`, `meanStep`, `constraintInfo`, `imageBP`, `echoCut`, `profileData`, and `selectInfo`.
- Add unit suffixes when storing derived metadata in structs, e.g. `Br_Hz`, `PRF_Hz`, `lambda_m`, `meanAzimuthStep_m`, and `runtimeSec` in `src/bp_run_point_analysis.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_save_results.m`.

**Types:**
- Use nested `struct` values as the primary data model. Config is grouped under `config.general`, `config.radar`, `config.interruption`, `config.analysis`, and `config.output` in `config/default_config.m`.
- Return aggregate result structs rather than custom classes or tables, e.g. `result` in `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`, `cutInfo` in `src/bp_interruption_pipeline.m`, and `pointAnaResult` in `src/point_analysis.m`.
- MATLAB classes, packages, and `classdef` types are not used anywhere in the repository.

## Code Style

**Formatting:**
- No formatter configuration is detected at repo root. `.editorconfig`, MATLAB project settings, ESLint, Prettier, Biome, and comparable formatting files are absent.
- Use 4-space indentation inside `if`, `for`, `switch`, and `try/catch` blocks throughout `main_gotha_bp.m`, `src/`, and `cs_echo_recovery/`.
- Separate logical phases with blank lines and `%%` section headers in entry points and config builders, e.g. `main_gotha_bp.m` and `config/default_config.m`.
- Wrap long expressions, assertions, and struct constructors with `...` and align continuation lines vertically, e.g. the assertions in `src/bp_validate_config.m`, the `localBuildCutInfo(...)` call in `src/bp_interruption_pipeline.m`, and the `localEmptyPointFiles()` struct in `main_gotha_bp.m`.
- Prefer MATLAB filesystem and string helpers such as `fullfile(...)`, `fileparts(...)`, `sprintf(...)`, and `char(string(...))` over manual path or conversion logic. This pattern is consistent in `main_gotha_bp.m`, `src/bp_data_pipeline.m`, `src/bp_read_seed_from_run_dir.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.

**Linting:**
- No linter configuration is detected.
- The repository depends on runtime contracts instead of lint rules. `assert(...)` and explicit `error(...)` calls are the main enforcement mechanism in `src/bp_validate_config.m`, `src/bp_data_pipeline.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.
- Do not introduce tool-specific style exceptions unless the repository also adds the corresponding config file.

## Import Organization

**Order:**
1. Resolve the current file path with `mfilename('fullpath')` and `fileparts(...)`.
2. Build project-relative directories with `fullfile(...)`.
3. Call `addpath(...)` only at entry points or module boundaries, e.g. `main_gotha_bp.m`, `cs_echo_recovery/run_cs_echo_recovery_demo.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.

**Path Aliases:**
- MATLAB package aliases are not used.
- Shared code is exposed by adding `config/`, `src/`, and `cs_echo_recovery/` to the MATLAB path, then calling functions directly by name.
- Internal helpers remain file-local instead of being imported across files. `src/bp_data_pipeline.m`, `src/bp_output_pipeline.m`, and `src/point_analysis.m` each group private helpers inside the same file.

## Error Handling

**Patterns:**
- Validate inputs early with `assert(...)`. `src/bp_validate_config.m` is the central contract for configuration shape, while `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, and `src/point_analysis.m` validate runtime assumptions before expensive work begins.
- Use `error('<module>:<Reason>', ...)` when callers may need a stable failure ID, e.g. `bp_interruption_pipeline:UnsupportedMode`, `bp_interruption_pipeline:GapRangeMismatch`, `bp_output_pipeline:FileOpenFailed`, `bp_output_pipeline:ExportFailed`, and `bp_read_seed_from_run_dir:MissingSeed`.
- Reserve `try/catch` for optional branches. `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m` wrap point-target analysis so the main pipeline can continue unless `failOnPointAnalysisError` is enabled.
- Restore mutable global state with `onCleanup(...)`, e.g. RNG state in `src/bp_interruption_pipeline.m`, temporary MATLAB path changes in `src/bp_run_point_analysis.m`, and file or figure cleanup in `src/bp_output_pipeline.m` and `cs_echo_recovery/cs_save_results.m`.

## Logging

**Framework:** `fprintf` and `warning`

**Patterns:**
- Use `fprintf(...)` for progress, numeric iteration status, and output locations, e.g. the random seed and output directory messages in `main_gotha_bp.m`, solver progress in `cs_echo_recovery/cs_recover_azimuth_fft_ista.m` and `cs_echo_recovery/cs_recover_echo_fft2_ista.m`, and final result directory logging in `cs_echo_recovery/cs_recovery_pipeline.m`.
- Use `warning(...)` only when a step is optional and execution can continue, e.g. point-analysis failures in `main_gotha_bp.m`.
- There is no structured logging library. Messages are concise one-line strings with interpolated numeric context such as `%d`, `%g`, `%.6f`, and `%.3e`.

## Comments

**When to Comment:**
- Put a function header comment directly below the signature. The normal pattern is `%FUNCTION_NAME ...` followed by short input/output notes, as seen in nearly every `.m` file under `config/`, `src/`, and `cs_echo_recovery/`.
- Use `%%` section comments to split top-level workflows into stages. This is common in `main_gotha_bp.m` and `config/default_config.m`.
- Keep dense logic readable through helper extraction rather than heavy inline commentary. `src/point_analysis.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_recovery_pipeline.m` are large files, but each stage is delegated to named `local*` helpers.
- Keep long-form algorithm explanation in Markdown beside the implementation. `src/point_analysis_algorithm.md` documents the point-target analysis instead of duplicating that narrative inside `src/point_analysis.m`.
- Prefer Chinese prose for comments, validation text, and most user-facing summaries in MATLAB source files. English remains common in identifiers and some console progress messages, so new prose should match the surrounding file rather than force a language switch.

**JSDoc/TSDoc:**
- Not applicable.
- MATLAB `%` doc comments are used instead of external docblock standards.

## Function Design

**Size:**
- Keep one public entry point per file.
- When a file grows large, preserve a single public API and move substeps into `local*` helpers rather than adding multiple exported functions. `src/point_analysis.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_recovery_pipeline.m` show the accepted pattern.
- Prefer the smaller helper-first style seen in `src/bp_data_pipeline.m`, `src/bp_run_point_analysis.m`, and `src/bp_read_seed_from_run_dir.m` when adding new functionality.

**Parameters:**
- Pass related settings as structs, not long flat parameter lists. Examples include `config` in `main_gotha_bp.m`, `cfg` in `src/bp_data_pipeline.m`, and `csCfg` in `cs_echo_recovery/cs_recovery_pipeline.m`.
- Accept user overrides as a single struct and merge recursively. This is the standard extension point in `main_gotha_bp.m`, `src/bp_merge_config.m`, and `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Use explicit scalar parameters only for low-level numeric routines that represent physical quantities, e.g. `point_analysis(imgBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg)` in `src/point_analysis.m`.

**Return Values:**
- Return rich structs that preserve both primary outputs and provenance, e.g. `result.meta`, `result.interruptionFiles`, `result.pointAnalysisMeta`, `cases.original.imageMetrics`, and `files.summary`.
- Use multiple outputs when the caller naturally consumes a compact bundle of parallel values, e.g. `[pathInfo, track, echoData, radar, dataRoot]` in `src/bp_data_pipeline.m` and `[echoCut, cutInfo]` in `src/bp_interruption_pipeline.m`.

## Module Design

**Exports:**
- Export plain functions from directories, not packages or classes.
- Keep repo-level or module-level entry points close to the folder root: `main_gotha_bp.m` in the repository root and `cs_echo_recovery/run_cs_echo_recovery_demo.m` in the recovery module.
- Put reusable imaging helpers under `src/` and recovery-specific helpers under `cs_echo_recovery/`.

**Barrel Files:**
- Not used.
- Composition happens by calling specific files directly after `addpath(...)`, e.g. `main_gotha_bp.m` calling `default_config`, `bp_merge_config`, `bp_validate_config`, and `bp_output_pipeline`, and `cs_echo_recovery/cs_recovery_pipeline.m` calling both `src/` and `cs_echo_recovery/` functions explicitly.

---

*Convention analysis: 2026-04-18*
