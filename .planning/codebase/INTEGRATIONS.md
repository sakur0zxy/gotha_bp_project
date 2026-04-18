# External Integrations

**Analysis Date:** 2026-04-18

## APIs & External Services

**Research Data Input:**
- GOTCHA SAR `.mat` pass files - required input for both the main BP workflow and the compressed-sensing workflow.
  - SDK/Client: MATLAB `load` in `src/bp_data_pipeline.m`
  - Auth: None
  - Location contract: `src/bp_data_pipeline.m` resolves `config.path.dataRootCandidates` from `config/default_config.m` against the parent workspace directory, so the first expected files are `..\data_3dsar_pass1_az001_VV.mat` or `..\gotcha_BP\data_3dsar_pass1_az001_VV.mat` relative to the repo root.

**Developer Tooling:**
- Jupyter MATLAB notebook integration - optional interactive interface for `main_gotha_bp.ipynb`.
  - SDK/Client: `jupyter_matlab_kernel` kernelspec stored in `main_gotha_bp.ipynb`
  - Auth: None
- VS Code launcher - optional editor integration for opening the notebook.
  - SDK/Client: `code` CLI in `open_vscode_matlab_notebook.cmd`
  - Auth: None
- Local MATLAB-Web-Interface style launcher environment - optional notebook bootstrapping only.
  - SDK/Client: environment variables set in `open_vscode_matlab_notebook.cmd`
  - Auth: local MATLAB license reuse via `MWI_USE_EXISTING_LICENSE=true`; no application-level auth flow exists in repo code

**Network Services:**
- Not detected. No HTTP client calls, SaaS SDKs, cloud storage SDKs, or remote API wrappers were found in `main_gotha_bp.m`, `src/bp_data_pipeline.m`, `src/bp_output_pipeline.m`, `src/point_analysis.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, or `cs_echo_recovery/cs_recover_echo_fft2_ista.m`.

## Data Storage

**Databases:**
- None
  - Connection: Not applicable
  - Client: Not applicable

**File Storage:**
- Local filesystem only
  - Input data: GOTCHA `.mat` files loaded by `src/bp_data_pipeline.m`
  - Main pipeline outputs: workspace-level `..\img\` run directories created by `src/bp_output_pipeline.m`
  - Compressed-sensing outputs: repo-local `cs_echo_recovery/results/` run directories created by `cs_echo_recovery/cs_recovery_pipeline.m`
  - Saved artifact types: `.jpg`, `.txt`, and `.mat` files written by `src/bp_output_pipeline.m` and `cs_echo_recovery/cs_save_results.m`

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- None
  - Implementation: The algorithm code in `main_gotha_bp.m`, `src/bp_data_pipeline.m`, `src/bp_imaging_pipeline.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_recovery_pipeline.m` has no login, token, credential, or identity layer.

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- MATLAB console logging uses `fprintf` and `warning` in `main_gotha_bp.m`, `src/point_analysis.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, and `cs_echo_recovery/cs_recover_echo_fft2_ista.m`.
- Run summaries are persisted as text artifacts by `src/bp_output_pipeline.m` and `cs_echo_recovery/cs_save_results.m`.

## CI/CD & Deployment

**Hosting:**
- None. No web app, API server, container target, or deployment manifest was detected.

**CI Pipeline:**
- None. No `.github/workflows/`, GitLab CI, Azure Pipelines, or other CI config was found.

## Environment Configuration

**Required env vars:**
- None for the core MATLAB imaging and recovery pipelines in `main_gotha_bp.m` and `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Optional notebook-launch vars are set internally by `open_vscode_matlab_notebook.cmd`: `JUPYTER_DATA_DIR`, `JUPYTER_CONFIG_DIR`, `IPYTHONDIR`, `JUPYTER_RUNTIME_DIR`, `HOME`, `USERPROFILE`, `MWI_USE_EXISTING_LICENSE`, and `MWI_CUSTOM_MATLAB_ROOT`.

**Secrets location:**
- Not applicable. No secret store integration, credential file, or `.env*` file was detected in the repository root.

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-04-18*
