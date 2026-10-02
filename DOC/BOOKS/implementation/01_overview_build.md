# Overview, rules and build system

## Purpose of this guide

The Theoretical Guide explains *what* is computed. This guide explains *where and how* each formula is coded in the Fortran sources of MUL2_NEW, so that a student can read a routine and know its mathematical meaning, its inputs and outputs, and the data structures it works on. It is organised as follows:

- Chapters 1 and 2: rules of the code, the build system, the layered architecture and the conventions (status handling, kinds, naming).
- Chapters 3 to 5: data model, input and preprocessing.
- Chapters 6 to 8: element kernels, assembly, constraints and solvers (with flowcharts).
- Chapters 9 and 10: post-processing and tests.
- Chapter 11: how to extend the program.
- Appendices: variable dictionary, file formats, and the **generated routine reference** (every module, derived type and procedure).

## Rules the code follows

The program obeys the document `SPECIFICHE_CODICE_FORTRAN.md` of the repository. The points that matter when reading the code are:

Table: Coding rules and where they show. {#tab:rules}

| Rule | Consequence in the sources |
|---|---|
| Fixed-form source, extension `.for`, 72 columns, upper case | continuation lines start with `&` in column 6; the `CHECK_FIXED_FORM` target fails the build if a line is longer |
| `REAL(R8)` for all reals, `INTEGER(I4)` for counts and ids, `INTEGER(I8)` for sparse indices | every literal carries its kind: `0.0_R8`, `1_I4`; sparse arrays (`ROW_POINTER`, `COLUMN_INDEX`) are 64-bit |
| One implementation per formula | e.g. the strain operator exists only in `MUL2_LINEAR_KINEMATICS`; the rotation of the stiffness only in `MUL2_MATERIAL_ROTATIONS` |
| No global mutable state | all data is passed as arguments; the only module variable is the debug flag of the logger |
| Errors and warnings through a status object | no `STOP` inside library routines; `STATUS_TYPE` travels upwards (Section {sec:status}) |
| Serial reference always available; OpenMP only where the result does not depend on the thread count | the assembly scatters serially; the parallel regions are listed in Section {sec:openmp} |
| Legacy input and output names are kept | `STATIC/POST_POINT.dat`, `DYNAMIC/FREQUENCIES.dat`, ... are written exactly as the baseline |
| The GUI never links the solver | `INTERFACE/` only writes input files, starts the executable and reads output files |

## Repository layout

```text
MUL2_NEW/
  CMakeLists.txt  CMakePresets.json  CREATE_VS_SOLUTION.cmd
  SRC/            fixed-form sources by layer (BASE MODEL IO ... APP) and SRC/ARPACK
  TESTS/          unit, integration and end-to-end tests; CASES (golden inputs), BENCH
  INTERFACE/      web interface (HTML/JS + PowerShell server)
  DOC/            guides (this book, the User and Theoretical guides), notes
  REFERENCES/     baseline inputs and golden outputs used by the tests
  BUILD/          generated build trees (not versioned)
```

## Toolchain

- **Compiler:** Intel oneAPI `ifx` (tested with 2025.0). OpenMP is enabled with `/Qopenmp`.
- **Libraries:** oneMKL (PARDISO, BLAS/LAPACK) with the ILP64 interface, sequential threading by default; ARPACK compiled from the sources in `SRC/ARPACK` with 64-bit `INTEGER` and `LOGICAL` (`/4I8`) so that it accepts the same ILP64 arrays.
- **Build tool:** CMake ≥ 3.25 is the single source of truth. A Visual Studio solution is always generated:

```bash
CREATE_VS_SOLUTION.cmd build        # configure + build Release
CREATE_VS_SOLUTION.cmd open         # also open BUILD\WINDOWS_IFX\MUL2_V3.sln
```

Equivalent manual commands:

```bash
cmake --preset windows-ifx
cmake --build BUILD/WINDOWS_IFX --config Release
ctest --test-dir BUILD/WINDOWS_IFX -C Release --output-on-failure
```

The preset `windows-ifx` uses the *Visual Studio 17 2022* generator with the `ifx` toolset and defines the configurations `Debug` (bounds, uninitialised-variable and traceback checks), `Release` and `Release_Fast`. The options of interest are:

Table: CMake options. {#tab:cmake}

| Option | Default | Meaning |
|---|---|---|
| `MUL2_ENABLE_OPENMP` | ON in the preset | compile with OpenMP |
| `MUL2_ENABLE_MKL` | ON in the preset | build the solvers (PARDISO, ARPACK, LAPACK); without it only the core library and a stub executable are built |
| `MUL2_MKL_ILP64` | ON | 64-bit MKL integer interface |
| `MUL2_MKL_THREADED` | OFF | link the threaded MKL (faster factorisations on some machines, not bit-reproducible across thread counts) |

## CMake targets

Table: Targets defined in `CMakeLists.txt`. {#tab:targets}

| Target | Type | Content |
|---|---|---|
| `MUL2_CORE` | static library | everything that does not need MKL: base, model, readers, geometry, caches, kernels, assembly, boundary, post-processing |
| `MUL2_ARPACK` | static library | ARPACK sources (`SRC/ARPACK/*.f`) |
| `MUL2_SOLVERS` | static library | PARDISO and modal solvers, analyses 101/103, driver |
| `MUL2_V3` | executable | `mul2_main.for` (or `mul2_main_core.for` when MKL is off) |
| `MUL2_TESTS` | executable | unit tests of the core |
| `MUL2_PARDISO_TESTS` | executable | tests of the PARDISO wrapper |
| `MUL2_ANALYSIS_TESTS` | executable | end-to-end tests against the golden cases |
| `CHECK_FIXED_FORM` | custom target | checks the 72-column rule |

## What happens when the program runs

```bash
MUL2_V3.exe [input_directory]
```

![Overall flow of the program.](figures/flow_main.svg){#fig:flow-main}

1. `mul2_main` decides the input directory: command-line argument, otherwise the first line of `PATH_input.dat`, otherwise `INPUT`; `--version` prints the version.
2. `RUN_MUL2` (module `MUL2_DRIVER`) creates `STATIC`, `DYNAMIC`, `WORK`, `REPORT`, reads the model, builds the cache, runs the analysis (101 or 103), writes the outputs and the warning report.
3. The exit code is 0 on success and 1 on any error, after printing `[ERROR] source: message`.

The environment variable `MUL2_DEBUG=1` enables debug logging; `MUL2_GENERAL_KERNEL=1` forces the point-by-point reference kernel (Chapter 6); `OMP_NUM_THREADS` sets the number of OpenMP threads.
