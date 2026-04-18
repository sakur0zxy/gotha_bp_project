# Codebase Concerns

**Analysis Date:** 2026-04-18

## Tech Debt

**Generated experiment artifacts are tracked inside the repository:**
- Issue: `cs_echo_recovery/results/` stores generated `.mat`, `.jpg`, and `.txt` outputs such as `cs_echo_recovery/results/run_20260418_135753/summary/recovery_result.mat`, `cs_echo_recovery/results/run_20260418_135753/original/image.jpg`, and `cs_echo_recovery/results/run_20260418_135753/recovered_2d/point_analysis_summary.txt`. The results tree is about 33.193 MB across 32 files, while `src/` is about 0.066 MB.
- Files: `cs_echo_recovery/results/`, `cs_echo_recovery/results/run_20260418_135753/summary/recovery_result.mat`, `cs_echo_recovery/results/run_20260418_135753/original/image.jpg`
- Impact: repository bloat, noisy diffs, harder code review, and accidental coupling of source control history to one local experiment run.
- Fix approach: ignore `cs_echo_recovery/results/` and root-level runtime outputs such as `img/`, keep reproducible summaries outside the tracked tree, and use Git LFS only for curated benchmark artifacts that must remain versioned.

**Entrypoint logic is duplicated between script and notebook:**
- Issue: `main_gotha_bp.ipynb` embeds a full copy of the `main_gotha_bp.m` function body instead of calling `main_gotha_bp.m`.
- Files: `main_gotha_bp.m`, `main_gotha_bp.ipynb`, `open_vscode_matlab_notebook.cmd`
- Impact: notebook and script behavior can drift silently, bug fixes must be applied twice, and users can execute stale logic depending on which entrypoint they choose.
- Fix approach: keep executable logic only in `main_gotha_bp.m`; make `main_gotha_bp.ipynb` a thin wrapper that imports the project path and calls the function.

**Large orchestration files mix pure computation, I/O, plotting, and reporting:**
- Issue: several modules combine too many responsibilities in one file, including `src/point_analysis.m` (~557 lines), `src/bp_output_pipeline.m` (~355 lines), `cs_echo_recovery/cs_recovery_pipeline.m` (~303 lines), and `src/bp_interruption_pipeline.m` (~274 lines).
- Files: `src/point_analysis.m`, `src/bp_output_pipeline.m`, `cs_echo_recovery/cs_recovery_pipeline.m`, `src/bp_interruption_pipeline.m`
- Impact: small changes have wide blast radius, regression isolation is difficult, and the lack of seams prevents targeted unit tests.
- Fix approach: split these files into pure computational helpers, I/O adapters, and presentation/reporting modules with stable input and output structs.

**Configuration overrides accept unknown fields without rejection:**
- Issue: recursive merge helpers copy any user-supplied key into the config tree without checking whether the field is supported.
- Files: `src/bp_merge_config.m`, `main_gotha_bp.m`, `cs_echo_recovery/run_cs_echo_recovery_demo.m`
- Impact: misspelled keys such as `showProgess` or misplaced nested fields are ignored instead of failing fast, which creates silent misconfiguration and misleading experiment settings.
- Fix approach: validate override structs against an allowed schema before merge and fail on unknown keys at every level.

**The notebook launcher is hard-coded to one Windows workstation layout:**
- Issue: the launcher references user-specific Python, Jupyter, temp, and MATLAB paths through absolute paths such as `C:\Users\zxy\AppData\Roaming\Python\Python313` and `E:\Program Files (x86)\Matlab\R2022b`.
- Files: `open_vscode_matlab_notebook.cmd`
- Impact: onboarding on another machine requires manual edits, automation is brittle, and the launcher is not portable across users or environments.
- Fix approach: resolve Python and MATLAB from `%PATH%`, environment variables, or a checked-in local template file rather than absolute machine-specific paths.

## Known Bugs

**Point-analysis auto-derivation assigns the same value to bandwidth and sampling frequency:**
- Symptoms: `src/bp_run_point_analysis.m` assigns `Br` from `radar.bandwidthHz` and also assigns `Fr` from `radar.bandwidthHz` when auto values are used. `src/point_analysis.m` then computes `geom.rangeUnit = c / (2 * Fr)` and `theory.rangeIRW = 0.886 * c / (2 * Br)`, so two different physical quantities are sourced from the same field.
- Files: `src/bp_run_point_analysis.m`, `src/point_analysis.m`, `config/default_config.m`
- Trigger: any run that relies on auto-derived point-analysis physics instead of manually setting `config.analysis.physics.Fr`.
- Workaround: explicitly set `config.analysis.physics.Fr` to the intended range sampling rate before calling `main_gotha_bp` or `bp_run_point_analysis`.

**`random_gap` mode randomizes gap lengths but not gap placement:**
- Symptoms: `src/bp_interruption_pipeline.m` uses `localGenerateRandomGaps` to randomize only `gapLengths`, while `segmentLengths` come from deterministic `localBalancedLengths(totalValid, numSegments)` and `localBuildRandomGapLayout` lays segments and gaps sequentially from index 1.
- Files: `src/bp_interruption_pipeline.m`
- Trigger: `config.interruption.mode = 'random_gap'`.
- Workaround: not exposed through the public API; use a code change or a custom interruption generator if truly random gap positions are required.

**Point-analysis image export is coupled to interactive figure settings:**
- Symptoms: `src/bp_output_pipeline.m` only writes point-analysis images when `config.output.savePointAnalysisImage` and `config.analysis.pointAnaCfg.showFigures` are both true. Turning figures off for batch runs disables image exports even when saving is requested. `cs_echo_recovery/cs_save_results.m` works around this by forcing `showFigures = true`.
- Files: `src/bp_output_pipeline.m`, `config/default_config.m`, `cs_echo_recovery/cs_save_results.m`, `cs_echo_recovery/cs_default_config.m`
- Trigger: headless or scripted runs that disable `showFigures`.
- Workaround: none in the main BP pipeline; the CS recovery path contains a local config rewrite to bypass the coupling.

## Security Considerations

**Local launcher trusts fixed user and temp locations:**
- Risk: `open_vscode_matlab_notebook.cmd` rewrites `HOME`, `USERPROFILE`, `HOMEDRIVE`, `HOMEPATH`, `JUPYTER_*`, and `PATH` to fixed local locations. On a shared or differently configured machine this can launch the wrong interpreter or write notebooks and runtime files into unexpected writable directories.
- Files: `open_vscode_matlab_notebook.cmd`
- Current mitigation: Not detected beyond directory creation checks.
- Recommendations: make the launcher opt-in, parameterize all paths, and resolve executables from trusted environment variables instead of fixed user directories.

## Performance Bottlenecks

**Backprojection imaging is fully serial and recomputes a full range grid per pulse:**
- Problem: `src/bp_imaging_pipeline.m` loops over every active azimuth sample, computes a full `rangeMat` over the entire image grid, performs an FFT for each pulse, and updates three full image-history buffers on every iteration.
- Files: `src/bp_imaging_pipeline.m`
- Cause: MATLAB-side per-pulse full-grid math with no block vectorization, no parallel loop, and no GPU or compiled hot path.
- Improvement path: precompute invariant grids, batch azimuth processing where possible, add `parfor` or GPU execution, and consider moving the hot loop into MEX or CUDA if performance matters.

**CS comparison keeps multiple full echoes and images in memory and on disk:**
- Problem: `cs_echo_recovery/cs_recovery_pipeline.m` stores `original`, `interrupted`, `recovered_1d`, and `recovered_2d` echoes and images simultaneously, and `cs_echo_recovery/cs_save_results.m` persists the full `result` struct with `-v7.3`.
- Files: `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_save_results.m`
- Cause: all cases are retained for one consolidated report instead of streaming or pruning intermediate states.
- Improvement path: make per-case execution optional, drop large arrays before saving summary files, and persist only the metrics and paths needed for downstream comparison.

**The data pipeline loads the entire dataset before any sub-selection:**
- Problem: `src/bp_data_pipeline.m` loads and concatenates every configured `.mat` file first, while `cs_echo_recovery/cs_recovery_pipeline.m` applies `rangeIndexRange` and `azimuthIndexRange` only after the full load completes.
- Files: `src/bp_data_pipeline.m`, `cs_echo_recovery/cs_recovery_pipeline.m`
- Cause: eager loading design with no streaming or partial-load entrypoint.
- Improvement path: support selection during load, allow file-by-file processing, and avoid concatenating unused data for debugging or small benchmark runs.

## Fragile Areas

**Point-target analysis is a high-risk modification zone:**
- Files: `src/point_analysis.m`, `src/bp_run_point_analysis.m`, `src/point_analysis_algorithm.md`
- Why fragile: physical assumptions, tilt estimation heuristics, FFT upsampling, PSLR/ISLR/IRW metrics, figure generation, and console reporting are all intertwined in one call path.
- Safe modification: change one helper at a time, capture expected PSLR/ISLR/IRW values for a fixed fixture image, and separate plotting from metric computation before larger refactors.
- Test coverage: no automated coverage detected for these files.

**Output behavior is controlled by scattered flags with hidden coupling:**
- Files: `main_gotha_bp.m`, `src/bp_output_pipeline.m`, `cs_echo_recovery/cs_save_results.m`, `cs_echo_recovery/cs_default_config.m`
- Why fragile: directory creation, summary files, image export, and point-analysis artifacts depend on a mix of output flags and display flags across two different pipelines.
- Safe modification: introduce one explicit output policy struct, keep saving decisions independent from interactive figure visibility, and centralize run-directory ownership.
- Test coverage: no automated coverage detected for these files.

**Interruption generation semantics are embedded in one large module:**
- Files: `src/bp_interruption_pipeline.m`
- Why fragile: constraint analysis, seed handling, layout generation, index bookkeeping, and actual echo zeroing all live together and share one `cutInfo` contract.
- Safe modification: preserve the `cutInfo` schema, add deterministic fixtures for `tail_gap` and `random_gap`, and verify both missing-sample counts and actual index placement after any change.
- Test coverage: no automated coverage detected for these files.

**The CS recovery experiment matrix has many branches and little fault isolation:**
- Files: `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, `cs_echo_recovery/cs_recover_echo_fft2_ista.m`
- Why fragile: run/skip behavior, imaging, and point analysis are gated by multiple flags, but only point-analysis failures are downgraded into per-case warnings. Recovery or imaging failures can abort the whole run.
- Safe modification: make each case an isolated execution unit, record errors per case, and validate `cases.*.status` transitions with explicit branch tests.
- Test coverage: no automated coverage detected for these files.

## Scaling Limits

**Four-case comparison multiplies memory and disk use quickly:**
- Current capacity: one run can retain up to 4 full echo matrices and up to 4 full images in `cs_echo_recovery/cs_recovery_pipeline.m`, plus iteration histories and a full `summary/recovery_result.mat` snapshot written by `cs_echo_recovery/cs_save_results.m`.
- Limit: larger range or azimuth selections will grow MATLAB memory usage and output size roughly in proportion to each additional retained case.
- Scaling path: run one recovery method at a time by default, add tiling or downsampling options, and persist reduced summaries instead of full intermediate arrays.

**Dataset discovery assumes one local filesystem layout:**
- Current capacity: `config/default_config.m` only searches `config.path.dataRootCandidates = {'.', 'gotcha_BP'}` relative to the workspace parent directory assembled in `src/bp_data_pipeline.m`.
- Limit: moving the repository or dataset outside that layout breaks execution immediately because there is no explicit dataset manifest or environment override.
- Scaling path: allow absolute dataset paths, environment-variable overrides, and a bootstrap script that validates the dataset before runtime.

## Dependencies at Risk

**The external GOTCHA dataset is a hard runtime dependency with convention-only discovery:**
- Risk: the code expects files named like `data_3dsar_pass1_az%03d_VV.mat` and searches for them by filename convention rather than by an explicit manifest or setup step.
- Impact: a clean checkout is not runnable by itself, renamed data files break both entrypoints, and collaborators must infer the required directory structure from `README.md` and `config/default_config.m`.
- Migration plan: add a setup script that verifies dataset presence, store a small manifest of expected files, and support an explicit absolute dataset root in config.
- Files: `config/default_config.m`, `src/bp_data_pipeline.m`, `README.md`

## Missing Critical Features

**Automated regression tests are absent:**
- Problem: there is no `tests/` directory, no `matlab.unittest` usage, and no smoke-test entrypoint for `main_gotha_bp.m` or `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Blocks: safe refactoring of `src/point_analysis.m`, `src/bp_interruption_pipeline.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`; confidence in scientific output stability.

**A first-class headless execution mode is absent:**
- Problem: the main configuration enables GUI activity by default through `config.display.showInterruptedEcho = true`, `config.display.showProgress = true`, and `config.analysis.pointAnaCfg.showFigures = true`, while several modules call `figure`, `imagesc`, `contour`, and `exportgraphics`.
- Blocks: CI execution, remote cluster runs, and reliable unattended benchmark sweeps.
- Files: `config/default_config.m`, `main_gotha_bp.m`, `src/bp_imaging_pipeline.m`, `src/point_analysis.m`, `src/bp_output_pipeline.m`

**Portable setup and data bootstrap are absent:**
- Problem: the repository has no bootstrap script to fetch or validate the GOTCHA dataset, and `open_vscode_matlab_notebook.cmd` is machine-specific.
- Blocks: reproducible onboarding, environment setup on another workstation, and scripted environment provisioning.
- Files: `config/default_config.m`, `src/bp_data_pipeline.m`, `open_vscode_matlab_notebook.cmd`, `README.md`

## Test Coverage Gaps

**Interruption layout and seed reproducibility are untested:**
- What's not tested: deterministic `tail_gap` layout, actual `random_gap` index placement, seed replay from `bp_read_seed_from_run_dir`, and constraint validation for `gapMinMeters` and `gapMaxMeters`.
- Files: `src/bp_interruption_pipeline.m`, `src/bp_read_seed_from_run_dir.m`
- Risk: sampling layouts can change silently, making experiment comparisons non-reproducible.
- Priority: High

**Point-analysis metric scaling and tilt correction are untested:**
- What's not tested: `Br` and `Fr` derivation, PSLR and ISLR calculations, IRW scaling, FFT upsampling, and tilt-estimation edge-column heuristics.
- Files: `src/bp_run_point_analysis.m`, `src/point_analysis.m`
- Risk: scientific metrics can drift or be physically mis-scaled without any automated signal.
- Priority: High

**CS recovery branch behavior is untested:**
- What's not tested: branch combinations for `run1D`, `run2D`, `runImaging`, `runPointAnalysis`, per-case status transitions, and failure handling inside the comparison pipeline.
- Files: `cs_echo_recovery/cs_recovery_pipeline.m`, `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`, `cs_echo_recovery/cs_recover_echo_fft2_ista.m`, `cs_echo_recovery/cs_save_results.m`
- Risk: optional code paths can break independently and remain undetected until a long experiment run fails.
- Priority: High

**Output naming and artifact persistence are untested:**
- What's not tested: run-directory naming, timestamp collisions, summary text contents, image export behavior, and the coupling between save flags and display flags.
- Files: `main_gotha_bp.m`, `src/bp_output_pipeline.m`, `cs_echo_recovery/cs_save_results.m`
- Risk: runs can appear successful while expected artifacts are missing or incomplete.
- Priority: Medium

---

*Concerns audit: 2026-04-18*
