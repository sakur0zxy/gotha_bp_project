# Testing Patterns

**Analysis Date:** 2026-04-18

## Test Framework

**Runner:**
- Not detected. No `matlab.unittest`, `functiontests`, `runtests`, dedicated `tests/` directory, or `*.test.*` / `*.spec.*` files exist anywhere in the repository.
- Config: Not detected.

**Assertion Library:**
- MATLAB `assert(...)` inside production code is the only systematic validation mechanism. The strongest examples are `src/bp_validate_config.m`, `src/bp_data_pipeline.m`, `src/bp_interruption_pipeline.m`, `src/point_analysis.m`, and `cs_echo_recovery/cs_recovery_pipeline.m`.

**Run Commands:**
```bash
Not detected                              # Run all automated tests
Not applicable                            # Watch mode
Not detected                              # Coverage
```

## Test File Organization

**Location:**
- No automated test tree or co-located unit test files are present.
- Validation is embedded in production files and manual workflows are documented in `README.md`, `cs_echo_recovery/README.md`, and `src/point_analysis_algorithm.md`.

**Naming:**
- Not detected for automated tests.
- Manual regression entry points are `main_gotha_bp.m`, `main_gotha_bp.ipynb`, and `cs_echo_recovery/run_cs_echo_recovery_demo.m`.

**Structure:**
```text
No automated test directory detected.

Manual regression artifacts are written to:
- `img/run_*`
- `cs_echo_recovery/results/run_*`
```

## Manual Regression Entry Points

**Current execution paths:**
- The primary end-to-end run starts at `main_gotha_bp.m` and exercises config loading, data loading, interruption sampling, BP imaging, output writing, and optional point-target analysis.
- The recovery comparison run starts at `cs_echo_recovery/run_cs_echo_recovery_demo.m` and exercises compressed-sensing recovery plus imaging and point-analysis comparison across multiple cases.
- `main_gotha_bp.ipynb` and `open_vscode_matlab_notebook.cmd` provide a notebook-based exploratory path rather than a formal test harness.

## Test Structure

**Suite Organization:**
```matlab
% Core manual regression path from `README.md`
addpath('gotha_bp_project');
result = main_gotha_bp();

% Recovery comparison path from `cs_echo_recovery/README.md`
addpath('gotha_bp_project');
addpath(fullfile('gotha_bp_project', 'cs_echo_recovery'));
result = run_cs_echo_recovery_demo();
```

**Patterns:**
- Setup pattern: build defaults in `config/default_config.m` or `cs_echo_recovery/cs_default_config.m`, then merge optional user overrides through `src/bp_merge_config.m` or the local merge helper in `cs_echo_recovery/run_cs_echo_recovery_demo.m`.
- Teardown pattern: there is no suite-level teardown. Cleanup is internal and local through `onCleanup(...)` in `src/bp_interruption_pipeline.m`, `src/bp_output_pipeline.m`, `src/bp_run_point_analysis.m`, and `cs_echo_recovery/cs_save_results.m`.
- Assertion pattern: fail fast with `assert(...)` before expensive numeric work. The code treats config validation as the nearest equivalent to unit-test preconditions.

## Mocking

**Framework:** None

**Patterns:**
```matlab
% Not detected: the repository has no mock, stub, or dependency-injection layer.
% Runs operate on real arrays, real GOTCHA .mat files, and real output directories.
```

**What to Mock:**
- None in the current codebase. Files such as `src/bp_data_pipeline.m`, `src/bp_output_pipeline.m`, and `cs_echo_recovery/cs_save_results.m` directly call `load`, `save`, `imwrite`, `exportgraphics`, and filesystem APIs.

**What NOT to Mock:**
- Do not add ad hoc mocks inside production pipeline files. Current behavior assumes real data roots resolved by `config/default_config.m` and real artifact generation under `img/` or `cs_echo_recovery/results/`.
- If faster verification is needed, reduce the selected data range through `cs_echo_recovery/cs_default_config.m` and `localResolveIndexRange(...)` in `cs_echo_recovery/cs_recovery_pipeline.m` instead of faking external dependencies.

## Fixtures and Factories

**Test Data:**
```matlab
% Manual override pattern from `README.md`
userCfg = struct();
userCfg.interruption = struct( ...
    'mode', 'random_gap', ...
    'numSegments', 4, ...
    'missingRatio', 0.2, ...
    'gapMinMeters', 2, ...
    'gapMaxMeters', 50, ...
    'randomSeed', 42);

result = main_gotha_bp(userCfg);
```

**Location:**
- Default fixture factories are `config/default_config.m` and `cs_echo_recovery/cs_default_config.m`.
- Real source data is external to the repository and is discovered through `config.path.dataRootCandidates` in `config/default_config.m`, then loaded by `src/bp_data_pipeline.m`.
- Reproducible random-gap reruns use the stored seed via `src/bp_read_seed_from_run_dir.m`.
- Smaller manual regression slices are supported through `csCfg.data.rangeIndexRange` and `csCfg.data.azimuthIndexRange` in `cs_echo_recovery/cs_default_config.m` and `cs_echo_recovery/cs_recovery_pipeline.m`.

## Coverage

**Requirements:** None enforced

**View Coverage:**
```bash
Not detected
```

## Test Types

**Unit Tests:**
- Not used. There are no standalone unit-test files for helpers under `src/` or `cs_echo_recovery/`.
- The closest unit-like checks are contract-heavy files such as `src/bp_validate_config.m` and `src/point_analysis.m`, which validate dimensions, scalar ranges, and option constraints internally.

**Integration Tests:**
- Manual full-pipeline runs are the primary integration strategy.
- `main_gotha_bp.m` validates the core imaging flow end to end: config merge, path discovery, GOTCHA data loading, interruption layout generation, BP imaging, artifact writing, and optional point-target analysis.
- `cs_echo_recovery/run_cs_echo_recovery_demo.m` validates the recovery module end to end against the same core pipeline and compares `original`, `interrupted`, `recovered_1d`, and `recovered_2d` cases.

**E2E Tests:**
- No separate E2E framework is present.
- Generated artifacts are the de facto E2E evidence:
  - `img/run_*/interruption_summary.txt`
  - `img/run_*/point_analysis_summary.txt`
  - `img/run_*/point_analysis_result.mat`
  - `img/run_*/interruption_layout.jpg`
  - `cs_echo_recovery/results/run_*/summary/recovery_metrics.txt`
  - `cs_echo_recovery/results/run_*/summary/echo_comparison.jpg`
  - `cs_echo_recovery/results/run_*/summary/image_comparison.jpg`

## Manual Pass Criteria

**Current review signals:**
- A core run is treated as successful when `main_gotha_bp.m` returns a populated `result` struct and `src/bp_output_pipeline.m` writes the expected interruption, image, and point-analysis artifacts into `img/run_*`.
- A recovery run is treated as successful when `cs_echo_recovery/cs_recovery_pipeline.m` produces `recovery_result.mat`, `recovery_metrics.txt`, and per-case image or point-analysis outputs under `cs_echo_recovery/results/run_*`.
- Numeric comparison is summary-driven rather than assertion-driven. Metrics are written to text files by `src/bp_output_pipeline.m` and `cs_echo_recovery/cs_save_results.m`, then inspected manually alongside exported figures.

## Common Patterns

**Async Testing:**
```matlab
% Not applicable: the repository does not use asynchronous execution
% in tests or in the production MATLAB pipeline.
```

**Error Testing:**
```matlab
try
    [pointResult, pointMeta] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo);
catch err
    pointMeta.enabled = false;
    pointMeta.errorMessage = err.message;
    warning('main_gotha_bp:PointAnalysisFailed', '点目标分析失败：%s', err.message);
    if config.analysis.failOnPointAnalysisError
        rethrow(err);
    end
end
```
- This pattern from `main_gotha_bp.m` is the closest thing to controlled failure testing in the current codebase.
- Hard failures are usually exercised by deliberately invalid config values and letting `src/bp_validate_config.m` or other `assert(...)` guards abort the run.

---

*Testing analysis: 2026-04-18*
