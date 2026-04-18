# Architecture

**Analysis Date:** 2026-04-18

## Pattern Overview

**Overall:** Function-oriented pipeline architecture with shared `struct` contracts and an adjacent experimental extension.

**Key Characteristics:**
- `main_gotha_bp.m` is a thin orchestrator that sequences stage functions from `src/` instead of embedding heavy logic inline.
- Cross-stage state is passed through MATLAB `struct` values such as `config`, `pathInfo`, `track`, `radar`, `cutInfo`, `imageMeta`, `pointMeta`, and `result`; there are no classes, packages, or persistent service objects.
- `cs_echo_recovery/` is a second workflow that reuses `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_run_point_analysis.m`, and `src/bp_output_pipeline.m` rather than forking the main imaging pipeline.

## Layers

**Entry and orchestration:**
- Purpose: Start workflows, apply user overrides, validate configuration, and sequence the stage modules.
- Location: `main_gotha_bp.m`, `main_gotha_bp.ipynb`, `cs_echo_recovery/run_cs_echo_recovery_demo.m`, `open_vscode_matlab_notebook.cmd`
- Contains: top-level `addpath(...)` calls, configuration assembly, pipeline invocation order, notebook launch glue.
- Depends on: `config/default_config.m`, `src/bp_merge_config.m`, `src/bp_validate_config.m`, `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_run_point_analysis.m`, `src/bp_output_pipeline.m`, `cs_echo_recovery/cs_default_config.m`, `cs_echo_recovery/cs_recovery_pipeline.m`
- Used by: MATLAB command-window users, notebook users, and the VS Code launcher script in `open_vscode_matlab_notebook.cmd`

**Configuration and validation:**
- Purpose: Define the full runtime contract for imaging, interruption, display, output, and analysis settings.
- Location: `config/default_config.m`, `src/bp_merge_config.m`, `src/bp_validate_config.m`, `cs_echo_recovery/cs_default_config.m`
- Contains: default scalar values, nested config structs, recursive merge logic, and fail-fast assertions.
- Depends on: MATLAB built-ins only.
- Used by: `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`

**Data acquisition and preprocessing:**
- Purpose: Resolve the workspace-relative data root, load GOTCHA pass files, derive radar metadata, and synthesize interrupted azimuth sampling.
- Location: `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `cs_echo_recovery/cs_build_full_cutinfo.m`
- Contains: path-context building, `.mat` loading, `track` assembly, radar parameter derivation, gap-layout generation, and `cutInfo` construction.
- Depends on: the validated config from `config/default_config.m` and the data-file pattern in `config.general.dataFilePattern`
- Used by: `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`

**Imaging and recovery compute:**
- Purpose: Turn echo matrices into BP images and optionally reconstruct missing echo samples before imaging.
- Location: `src/bp_imaging_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, `cs_echo_recovery/cs_recover_echo_fft2_ista.m`, `cs_echo_recovery/cs_recovery_pipeline.m`
- Contains: backprojection loops, FFT upsampling, Hamming windows, iterative weights, FISTA-style recovery loops, and comparison metrics.
- Depends on: `track`, `radar`, `cutInfo`, and recovery settings from `cs_echo_recovery/cs_default_config.m`
- Used by: `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`

**Analysis and reporting:**
- Purpose: Compute point-target quality metrics and persist human-readable and machine-readable run artifacts.
- Location: `src/bp_run_point_analysis.m`, `src/point_analysis.m`, `src/point_analysis_algorithm.md`, `src/bp_output_pipeline.m`, `src/bp_read_seed_from_run_dir.m`, `cs_echo_recovery/cs_save_results.m`
- Contains: point-analysis input adaptation, tilt estimation, profile metrics, image export, summary text generation, and recovery comparison output.
- Depends on: BP image matrices, run directories, and config flags under `config.analysis` and `config.output`
- Used by: `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`

## Data Flow

**Standard BP imaging flow:**

1. `main_gotha_bp.m` loads defaults from `config/default_config.m`, merges `userConfig` through `src/bp_merge_config.m`, and validates the result through `src/bp_validate_config.m`.
2. `src/bp_data_pipeline.m` resolves `workspaceRoot` as the parent of the project root, searches `config.path.dataRootCandidates`, loads `data_3dsar_pass1_az%03d_VV.mat` files, and returns `pathInfo`, `track`, `echoData`, `radar`, and `dataRoot`.
3. `src/bp_interruption_pipeline.m` zeros the selected azimuth gaps, computes sampling constraints, and emits the shared `cutInfo` contract used by downstream imaging and output code.
4. `src/bp_output_pipeline.m` prepares the run directory and writes interruption summaries before imaging starts.
5. `src/bp_imaging_pipeline.m` iterates over `cutInfo.activeAzIndices`, forms range-upsampled pulses, accumulates the complex BP image, and returns `imageBP` plus `imageMeta`.
6. `src/bp_run_point_analysis.m` adapts imaging outputs into the call signature expected by `src/point_analysis.m`, which computes PSLR, ISLR, IRW, tilt alignment, and profiles.
7. `src/bp_output_pipeline.m` saves the final image and point-analysis artifacts, and `main_gotha_bp.m` assembles a final `result` struct with file paths and metadata.

**CS echo recovery experiment flow:**

1. `cs_echo_recovery/run_cs_echo_recovery_demo.m` loads `cs_echo_recovery/cs_default_config.m`, merges user overrides, and delegates to `cs_echo_recovery/cs_recovery_pipeline.m`.
2. `cs_echo_recovery/cs_recovery_pipeline.m` converts `csCfg.project` into a standard project config by calling `config/default_config.m`, `src/bp_merge_config.m`, and `src/bp_validate_config.m`.
3. `cs_echo_recovery/cs_recovery_pipeline.m` reuses `src/bp_data_pipeline.m` and `src/bp_interruption_pipeline.m`, then creates recovery cases for `original`, `interrupted`, `recovered_1d`, and `recovered_2d`.
4. `cs_echo_recovery/cs_recover_azimuth_fft_ista.m` and `cs_echo_recovery/cs_recover_echo_fft2_ista.m` reconstruct echo matrices; the pipeline then reuses `src/bp_imaging_pipeline.m` and `src/bp_run_point_analysis.m` for side-by-side comparison.
5. `cs_echo_recovery/cs_save_results.m` writes per-case images, point-analysis outputs, summary text, and `.mat` exports into `cs_echo_recovery/results/`.

**State Management:**
- Use nested config structs from `config/default_config.m` and `cs_echo_recovery/cs_default_config.m` as the only runtime configuration source.
- Pass domain state explicitly between functions as structs: `pathInfo`, `track`, `radar`, `cutInfo`, `anaInfo`, `cases`, and `result`.
- Treat `cutInfo` as the core cross-module contract between `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_build_full_cutinfo.m`.
- Expect path resolution to be runtime-global because entry points call `addpath(...)` instead of using package namespaces.

## Key Abstractions

**Runtime config struct:**
- Purpose: Hold all user-tunable parameters for loading, interruption, imaging, display, output, and point analysis.
- Examples: `config/default_config.m`, `src/bp_merge_config.m`, `src/bp_validate_config.m`, `cs_echo_recovery/cs_default_config.m`
- Pattern: define defaults once, recursively override with user values, then assert invariants before any data access.

**Path context struct:**
- Purpose: Capture `srcRoot`, `projectRoot`, and `workspaceRoot` so data lookup and outputs remain location-aware.
- Examples: `src/bp_data_pipeline.m`
- Pattern: compute path context once near the start of a run and pass it forward instead of repeatedly querying the filesystem.

**Track and radar structs:**
- Purpose: Separate platform geometry (`track.X`, `track.Y`, `track.Z`) from derived radar sampling metadata (`radar.deltaR`, `radar.freqVectorHz`, `radar.numRangeSamplesUp`).
- Examples: `src/bp_data_pipeline.m`, `src/bp_imaging_pipeline.m`
- Pattern: derive them during loading, then treat them as read-only inputs to imaging and analysis code.

**`cutInfo` sampling contract:**
- Purpose: Describe active azimuth indices, segment boundaries, gap boundaries, meters-per-gap, random seed, and constraint diagnostics.
- Examples: `src/bp_interruption_pipeline.m`, `cs_echo_recovery/cs_build_full_cutinfo.m`, `src/bp_output_pipeline.m`
- Pattern: produce one normalized sampling description and reuse it for imaging, summaries, run-directory naming, and recovery comparisons.

**Case/result aggregates:**
- Purpose: Bundle outputs, metrics, and file paths from a whole workflow or experiment.
- Examples: `main_gotha_bp.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_save_results.m`
- Pattern: build one top-level struct for downstream inspection instead of returning many positional outputs from entry-point functions.

## Entry Points

**Primary MATLAB entry point:**
- Location: `main_gotha_bp.m`
- Triggers: direct function call from MATLAB.
- Responsibilities: add project paths, merge config, execute the standard BP pipeline, optionally run point analysis, and return the final `result`.

**Interactive notebook entry point:**
- Location: `main_gotha_bp.ipynb`
- Triggers: opening the notebook in VS Code or Jupyter-compatible tooling.
- Responsibilities: expose the primary workflow in notebook form; the current notebook content mirrors the top-level MATLAB function rather than introducing a separate architecture.

**Notebook launcher:**
- Location: `open_vscode_matlab_notebook.cmd`
- Triggers: Windows shell execution.
- Responsibilities: prepare local Jupyter-related environment variables and open `main_gotha_bp.ipynb` in VS Code.

**Recovery experiment entry point:**
- Location: `cs_echo_recovery/run_cs_echo_recovery_demo.m`
- Triggers: direct function call from MATLAB.
- Responsibilities: initialize the recovery experiment config and run `cs_echo_recovery/cs_recovery_pipeline.m`.

**Utility entry point:**
- Location: `src/bp_read_seed_from_run_dir.m`
- Triggers: ad hoc tooling or manual reuse of historical `random_gap` seeds.
- Responsibilities: parse a run directory name or `interruption_summary.txt` to recover the random seed used in a previous run.

## Error Handling

**Strategy:** Fail fast on invalid configuration or missing data, but downgrade optional point-analysis failures to warnings unless the config explicitly requires a hard failure.

**Patterns:**
- Use `assert(...)` heavily in `src/bp_validate_config.m`, `src/bp_data_pipeline.m`, and `src/bp_interruption_pipeline.m` to reject invalid inputs before computation starts.
- Use explicit `error(...)` identifiers in modules such as `src/bp_interruption_pipeline.m`, `src/bp_output_pipeline.m`, and `src/bp_read_seed_from_run_dir.m` when recovery or export cannot continue.
- Use localized `try/catch` only around optional point analysis in `main_gotha_bp.m` and `cs_echo_recovery/cs_recovery_pipeline.m`; these code paths emit `warning(...)` and continue unless `failOnPointAnalysisError` is enabled.
- Use collision-avoidance loops in `src/bp_output_pipeline.m` and `cs_echo_recovery/cs_recovery_pipeline.m` to create unique run directories rather than overwriting existing outputs.

## Cross-Cutting Concerns

**Logging:** Use console output only. `main_gotha_bp.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_recovery_pipeline.m` rely on `fprintf`, `disp`, and `warning` for progress and diagnostics.

**Validation:** Centralize config validation in `src/bp_validate_config.m`, then add module-local assertions in `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, and recovery helpers when the module needs stronger assumptions.

**Authentication:** Not applicable. The codebase reads local `.mat` files and writes local run artifacts; there is no network or identity layer.

---

*Architecture analysis: 2026-04-18*
