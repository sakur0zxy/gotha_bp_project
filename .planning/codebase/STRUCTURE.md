# Codebase Structure

**Analysis Date:** 2026-04-18

## Directory Layout

```text
[project-root]/
├── .planning/
│   └── codebase/                # Generated architecture/reference docs
├── config/                      # Default runtime configuration for the BP workflow
├── cs_echo_recovery/            # Recovery experiment that reuses the core BP modules
│   └── results/                 # Generated recovery comparison outputs
├── src/                         # Reusable BP pipeline stages and analysis code
├── main_gotha_bp.m              # Primary MATLAB entry point
├── main_gotha_bp.ipynb          # Notebook-based entry point
├── open_vscode_matlab_notebook.cmd  # VS Code notebook launcher
└── README.md                    # Human-facing project overview
```

## Directory Purposes

**`config/`:**
- Purpose: Hold the canonical default config for the main imaging workflow.
- Contains: one MATLAB config builder file.
- Key files: `config/default_config.m`

**`src/`:**
- Purpose: Hold reusable BP imaging logic that can be called from both the main workflow and the recovery experiment.
- Contains: pipeline stages, validators, output writers, point-analysis code, and one algorithm note.
- Key files: `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_output_pipeline.m`, `src/bp_run_point_analysis.m`, `src/point_analysis.m`, `src/point_analysis_algorithm.md`

**`cs_echo_recovery/`:**
- Purpose: Hold an adjacent experimental workflow for sparse recovery of interrupted echoes.
- Contains: its own config, experiment orchestrator, two recovery algorithms, result writer, demo entry point, and a local `results/` tree.
- Key files: `cs_echo_recovery/run_cs_echo_recovery_demo.m`, `cs_echo_recovery/cs_default_config.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, `cs_echo_recovery/cs_recover_echo_fft2_ista.m`, `cs_echo_recovery/cs_save_results.m`

**`.planning/codebase/`:**
- Purpose: Hold generated mapping documents for other planning commands.
- Contains: Markdown reference files only.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`

## Key File Locations

**Entry Points:**
- `main_gotha_bp.m`: Primary BP imaging workflow entry point.
- `main_gotha_bp.ipynb`: Interactive notebook entry point that mirrors the main workflow.
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`: Entry point for the compressed-sensing recovery experiment.
- `open_vscode_matlab_notebook.cmd`: Windows launcher that prepares notebook environment variables and opens `main_gotha_bp.ipynb`.

**Configuration:**
- `config/default_config.m`: Default config for the standard BP workflow.
- `src/bp_merge_config.m`: Recursive merge utility for user config overrides.
- `src/bp_validate_config.m`: Central validator for the standard BP config contract.
- `cs_echo_recovery/cs_default_config.m`: Recovery experiment defaults, including nested overrides for the standard project config.

**Core Logic:**
- `src/bp_data_pipeline.m`: Workspace-relative data-root resolution and GOTCHA `.mat` loading.
- `src/bp_interruption_pipeline.m`: Gap generation and `cutInfo` construction for interrupted sampling.
- `src/bp_imaging_pipeline.m`: Backprojection image formation.
- `src/bp_output_pipeline.m`: Run-directory management and result export.
- `src/bp_run_point_analysis.m`: Adapter layer between BP imaging outputs and `src/point_analysis.m`.
- `src/point_analysis.m`: Point-target metric computation and optional tilt correction.
- `cs_echo_recovery/cs_recovery_pipeline.m`: Multi-case orchestration for original, interrupted, and recovered echo comparisons.

**Data Inputs:**
- Not stored under the repo root. `src/bp_data_pipeline.m` resolves `workspaceRoot` as the parent of the project root and searches `config.path.dataRootCandidates` for `data_3dsar_pass1_az%03d_VV.mat`.
- Current candidates come from `config/default_config.m`: `.` and `gotcha_BP`, both relative to the workspace root rather than `gotha_bp_project/`.

**Testing:**
- Not detected. There is no `tests/`, no MATLAB test suite, and no `*.test.*` or `*.spec.*` files in the current workspace.

## Naming Conventions

**Files:**
- Use `bp_*.m` for reusable main-pipeline modules under `src/`. Example: `src/bp_output_pipeline.m`.
- Use `cs_*.m` for recovery-only helpers under `cs_echo_recovery/`. Example: `cs_echo_recovery/cs_save_results.m`.
- Use `main_*.m` and `run_*.m` for user-facing entry points. Examples: `main_gotha_bp.m`, `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Keep project docs in Markdown with simple lowercase names. Examples: `README.md`, `src/point_analysis_algorithm.md`.

**Directories:**
- Keep stable source areas short and lowercase. Examples: `config`, `src`.
- Use lowercase snake_case for specialized workflow directories. Example: `cs_echo_recovery`.
- Reserve hidden dot-directories for generated planning artifacts. Example: `.planning/codebase`.

## Where to Add New Code

**New Feature:**
- Primary code: put reusable BP workflow logic in `src/`, usually as a new `bp_*.m` module if multiple entry points may call it.
- Integration point: update `main_gotha_bp.m` only when the new feature changes top-level workflow order or adds a new returned field.
- Tests: no current test location exists; the codebase does not define one.

**New Component or Module:**
- Implementation: place shared imaging, loading, interruption, analysis, or output logic in `src/`.
- Recovery-specific implementation: place code in `cs_echo_recovery/` only if it is exclusive to the sparse-recovery experiment and should not be reused by `main_gotha_bp.m`.

**Utilities:**
- Shared helpers: prefer `src/` when the helper could be reused across pipeline stages.
- File-private helpers: keep them as local functions inside the owning file when the logic is tightly coupled to one module, following the existing pattern in `src/bp_output_pipeline.m` and `src/point_analysis.m`.

## Special Directories

**`cs_echo_recovery/results/`:**
- Purpose: Store generated run folders such as `cs_echo_recovery/results/run_20260418_135753/` with `summary/`, `original/`, `interrupted/`, `recovered_1d/`, and `recovered_2d/`.
- Generated: Yes
- Committed: No

**`.planning/codebase/`:**
- Purpose: Store generated mapping documents consumed by planning and execution commands.
- Generated: Yes
- Committed: No

**Workspace-level data root outside the repo:**
- Purpose: Hold GOTCHA input files referenced by `src/bp_data_pipeline.m`.
- Generated: No
- Committed: Not applicable

---

*Structure analysis: 2026-04-18*
