# Technology Stack

**Analysis Date:** 2026-04-18

## Languages

**Primary:**
- MATLAB `.m` codebase; version is not pinned in-repo, but `R2022b` is the observed local runtime in `open_vscode_matlab_notebook.cmd`. Core entry points and algorithm code live in `main_gotha_bp.m`, `config/default_config.m`, `src/bp_data_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.

**Secondary:**
- Jupyter notebook JSON wrapping MATLAB code in `main_gotha_bp.ipynb`; notebook metadata declares the `jupyter_matlab_kernel` MATLAB kernel.
- Windows batch scripting in `open_vscode_matlab_notebook.cmd`; this is optional developer tooling for opening the notebook in VS Code.
- Markdown documentation in `README.md`, `cs_echo_recovery/README.md`, and `src/point_analysis_algorithm.md`.

## Runtime

**Environment:**
- MATLAB runtime is required for all executable code in `main_gotha_bp.m`, `src/bp_data_pipeline.m`, `src/bp_output_pipeline.m`, `src/point_analysis.m`, `cs_echo_recovery/run_cs_echo_recovery_demo.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, and `cs_echo_recovery/cs_recover_echo_fft2_ista.m`.
- The optional notebook workflow uses `main_gotha_bp.ipynb` plus the environment bootstrap in `open_vscode_matlab_notebook.cmd`.
- Core execution is direct function/script invocation; there is no compiled binary, container, or server runtime.

**Package Manager:**
- Not detected. No `package.json`, `requirements.txt`, `pyproject.toml`, `Pipfile`, `Cargo.toml`, or `go.mod` exists at the repository root.
- Lockfile: missing

## Frameworks

**Core:**
- MATLAB numerical computing environment drives the entire imaging pipeline in `main_gotha_bp.m`, `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_recover_echo_fft2_ista.m`.
- Optional Jupyter integration uses the `jupyter_matlab_kernel` kernelspec embedded in `main_gotha_bp.ipynb`.

**Testing:**
- Not detected. No `*.test.*`, `*.spec.*`, `matlab.unittest` suites, or test runner config files were found.

**Build/Dev:**
- No build system is present. Execution starts from `main_gotha_bp.m` for the base workflow and `cs_echo_recovery/run_cs_echo_recovery_demo.m` for the compressed-sensing workflow.
- VS Code `code` CLI is used only by `open_vscode_matlab_notebook.cmd` to open `main_gotha_bp.ipynb`.
- Python user-space tooling is referenced only by `open_vscode_matlab_notebook.cmd`, which hard-codes local Python `Python313` paths for notebook support.

## Key Dependencies

**Critical:**
- MATLAB runtime functions such as `load`, `save`, `fft`, `fft2`, `ifft`, `ifft2`, `hamming`, `imwrite`, `interp2`, and `exportgraphics` are central to the implementation in `src/bp_data_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_output_pipeline.m`, `src/point_analysis.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, `cs_echo_recovery/cs_recover_echo_fft2_ista.m`, and `cs_echo_recovery/cs_save_results.m`.
- The GOTCHA SAR pass files are a hard external data dependency. `config/default_config.m` defines the filename pattern `data_3dsar_pass1_az%03d_VV.mat`, and `src/bp_data_pipeline.m` loads those `.mat` files with `load`.
- The compressed-sensing module reuses the main pipeline rather than introducing a separate stack; `cs_echo_recovery/cs_recovery_pipeline.m` calls `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `src/bp_imaging_pipeline.m`, and `src/bp_output_pipeline.m`.

**Infrastructure:**
- Local filesystem input/output is part of the design. The main pipeline reads data outside the repo root via `src/bp_data_pipeline.m` and writes run artifacts outside the repo root via `src/bp_output_pipeline.m`.
- The optional notebook launcher in `open_vscode_matlab_notebook.cmd` expects local VS Code, local Python, a local MATLAB installation, and writable workspace-local Jupyter/IPython directories.

## Configuration

**Environment:**
- Use MATLAB struct-based configuration. Default main-pipeline settings live in `config/default_config.m`; compressed-sensing defaults live in `cs_echo_recovery/cs_default_config.m`.
- Override settings by passing `userConfig` into `main_gotha_bp(userConfig)` in `main_gotha_bp.m` or `run_cs_echo_recovery_demo(userConfig)` in `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Path resolution is code-driven, not environment-variable-driven, for the core algorithm. `src/bp_data_pipeline.m` resolves input data relative to the parent workspace of the repo, and `src/bp_output_pipeline.m` resolves output directories the same way.
- No `.env*` files were detected in the repository root.

**Build:**
- No build config files were detected.
- Notebook-launch configuration is embedded in `open_vscode_matlab_notebook.cmd`.
- Notebook kernel metadata is embedded in `main_gotha_bp.ipynb`.

## Platform Requirements

**Development:**
- MATLAB with graphics and file I/O support is required by `src/bp_output_pipeline.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_save_results.m`.
- The expected data files are not stored under the repo root by default. `src/bp_data_pipeline.m` looks for `..\data_3dsar_pass1_az001_VV.mat` first and then `..\gotcha_BP\data_3dsar_pass1_az001_VV.mat`, relative to the project root.
- Windows is required only for the convenience launcher `open_vscode_matlab_notebook.cmd`; the core `.m` files themselves are standard MATLAB source files.

**Production:**
- Not a deployed service. The current target is local, offline research execution from MATLAB or a local Jupyter notebook session.

---

*Stack analysis: 2026-04-18*
