# Testing and validation {#sec:testing}

## Test programs

Table: Test executables and what they check. {#tab:tests}

| Executable (source) | Level | Content |
|---|---|---|
| `MUL2_TESTS` (`TESTS/mul2_tests.for`) | unit and integration | base utilities, quadrature, shape functions (partition of unity, derivative consistency), Jacobians and frames, Taylor bases, materials and rotations, DOF layout, Gauss layout/geometry, element matrices (symmetry, rigid-body energy, patch), sparse assembly, boundary conditions |
| `MUL2_PARDISO_TESTS` (`TESTS/mul2_pardiso_tests.for`) | solver | factorisation and solution of small SPD systems, error paths |
| `MUL2_ANALYSIS_TESTS` (`TESTS/mul2_analysis_tests.for`, `mul2_test_support.for`) | end-to-end | runs the real executable on test inputs in isolated directories and compares point results, VTK fields and frequencies with references |
| `CHECK_FIXED_FORM` | static check | no source line longer than 72 columns |

All are registered in CTest (`ctest --test-dir BUILD/WINDOWS_IFX -C Release`). The end-to-end test passes the executable, the repository root and a run directory as arguments.

## The end-to-end suite

`mul2_test_support.for` provides the helpers: `RUN_SOLVER(exe, input, run_dir, threads, ok)` executes the program through `EXECUTE_COMMAND_LINE` (with `OMP_NUM_THREADS` when requested), `READ_POINT_ROWS`, `READ_FREQUENCIES`, `READ_VTK_BLOCK` parse the outputs, `MAX_RELATIVE_DIFFERENCE` compares arrays and `FILES_ARE_IDENTICAL` compares two files line by line.

The cases of `TESTS/mul2_analysis_tests.for`:

Table: End-to-end cases. {#tab:e2e}

| Case | Source of the reference | Checks |
|---|---|---|
| `GOLDEN_BEAM_101`, `GOLDEN_PLATE_101`, `GOLDEN_BEAM_103` | `REFERENCES/GOLDEN` (baseline outputs) | points, VTK displacement/stress/strain, frequencies and MAC of 20 modes |
| `mixed_none`, `mixed_mitc` | `TESTS/CASES/<name>` | B4 + Q9 + H27 in one model |
| `beam_b3_te2_mitc`, `beam_te8_unit` | `TESTS/CASES` | Taylor expansions; the TE8 case is the regression test of the quadrature order |
| `plate_q4_mitc`, `plate_q9x4_mitc`, `solid_h8_none` | `TESTS/CASES` | plates and solids |
| `modal_plate_q9x4_mitc`, `modal_beam_b3_te2` | `TESTS/CASES` | frequencies |
| `patch_*` | analytic (uniform strain, $\nu=0$) | exact reproduction of a uniform strain |
| thread independence | the same run with 1 and 4 threads | outputs bit-identical |

### Tolerances

Tolerances are relative to the largest value of the field. The default is $2\cdot10^{-6}$ (limited by the penalty used in the baseline); point results use $10^{-4}$ because the baseline locates points only approximately; thin plates are ill-conditioned and use $4\cdot10^{-6}$; patch tests use $10^{-9}$.

### Creating a new reference case

1. Write the input directory `TESTS/CASES/<name>/INPUT`.
2. Run the *baseline* program on it (`MUL2_OPTIMIZED/INTERFACE/MUL2.exe`) in a scratch directory with `PATH_input.dat` containing `INPUT` and the output directories created.
3. Copy `STATIC/POST_POINT.dat`, `STATIC/RESULTS_PARA_01.vtk` (static) or `DYNAMIC/FREQUENCIES.dat`, `DYNAMIC/RESULTS_DYN_PARA.vtk` (modal) into `TESTS/CASES/<name>/REFERENCE`.
4. Add a `GENERATED_STATIC('<name>', tolerance)` or `GENERATED_MODAL(...)` line to the test program and rebuild.

Features that the baseline does not have (such as hierarchical expansions) are validated against internal equivalences (for example two bases spanning the same space must give the same displacements) instead.

## Comparing the two kernels

Setting `MUL2_GENERAL_KERNEL=1` runs the reference kernel. To compare the two kernels, request `KMAT` and `MMAT` in `POSTPROCESSING.dat`, run once with and once without the variable, and compare `WORK/K_MAT.dat` and `WORK/M_MAT.dat` numerically. The comparison is made in the tests of the project at $10^{-15}$ (relative to the largest entry).

## Benchmarks

`TESTS/BENCH` contains four inputs of about 100 000 DOF (`beam_te15_100k`, `beam_le_100k` and their modal versions) and the script `bench.ps1`, which runs an executable on a case in a clean run directory and reports exit code, wall time, CPU time and the peak working set:

```bash
powershell TESTS\BENCH\bench.ps1 -Exe BUILD\WINDOWS_IFX\Release\MUL2_V3.exe ^
    -Case TESTS\BENCH\beam_te15_100k -RunDir C:\temp\run_new
```

Results are in the Theoretical Guide, chapter *Verification and performance*.

## Debugging tips

- Build the `Debug` configuration: array bounds, uninitialised variables and floating-point traps are checked and a traceback is printed on errors.
- `MUL2_DEBUG=1` enables debug lines from the logger.
- To isolate an element problem, run a model with one element and `KMAT`/`FRCE`/`UNKN` requests and inspect the dumps in `WORK`.
- Large `Gauss point` counts or odd memory use: check `PREPROCESSING: … DOF, … GAUSS POINTS` in the console and `NNZ` in the assembly line.
- A PARDISO error $-4$ is almost always a modelling error (supports) before it is a solver problem.
