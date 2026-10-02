# MUL2_NEW – Implementation Guide

For developers. Theory: `THEORETICAL_GUIDE.md`. Usage: `USER_GUIDE.md`.
Rules followed: `SPECIFICHE_CODICE_FORTRAN.md`.

---

## 1. Coding rules (summary)

* Fixed-form Fortran, extension `.for`, **≤ 72 columns**, upper case.
  Enforced by the `CHECK_FIXED_FORM` CMake target.
* `REAL(R8)` (double), `INTEGER(I4)` for counts/ids, `INTEGER(I8)` for
  sparse indices (PARDISO ILP64 interface).
* One source of truth per formula; no global mutable state; procedures
  short with a single responsibility; errors and warnings through
  `MUL2_STATUS` (never `STOP` inside library code).
* Serial reference always available; OpenMP only where the result is
  thread-count independent (bit-identical results are tested).
* The GUI never links the solver: it only exchanges files.

## 2. Build system

CMake is the single source of truth. A Visual Studio solution is always
generated:

    CREATE_VS_SOLUTION.cmd [open|build]        -> BUILD/WINDOWS_IFX/MUL2_V3.sln

Presets (`CMakePresets.json`): `windows-ifx` (VS 2022, Intel ifx, OpenMP,
MKL ILP64 sequential; configurations Debug, Release, Release_Fast),
`linux-gfortran-*` (no MKL, not verified).

Targets

| Target | Content |
|--------|---------|
| `MUL2_CORE` | everything without MKL (model, elements, assembly, post) |
| `MUL2_ARPACK` | `SRC/ARPACK/*.f` compiled with `/4I8 /w` (64-bit INTEGER and LOGICAL) |
| `MUL2_SOLVERS` | PARDISO/modal solvers, analyses 101/103, driver |
| `MUL2_V3` | executable (`mul2_main.for`; `mul2_main_core.for` stub without MKL) |
| `MUL2_TESTS`, `MUL2_PARDISO_TESTS`, `MUL2_ANALYSIS_TESTS` | unit/integration/end-to-end tests |
| `CHECK_FIXED_FORM` | 72-column and form check |

Run tests: `ctest --test-dir BUILD/WINDOWS_IFX -C Release --output-on-failure`.
The Intel runtime DLL directories must be on `PATH` (the test scripts and
`run_interface.ps1` add `oneAPI\mkl\*\bin` and `compiler\*\bin`).

## 3. Source layout (`SRC/`)

| Directory | Modules | Role |
|-----------|---------|------|
| `BASE` | kinds, status, log, timer, strings, files, sorting, runtime | precision, error/warning list, directories, `SORT_PERMUTATION`, `BINARY_SEARCH` |
| `MODEL` | nodes, elements, kinematics, materials, laminations, expansion meshes, BC, reference systems, incidence, model, analysis_input | plain data types, no I/O |
| `IO` | `read_*` | legacy-format readers; `read_model` assembles `MODEL_TYPE` |
| `QUADRATURE`, `FEM` | quadrature rules, shape functions | |
| `GEOMETRY` | jacobians, element frames, local gradients | `EVALUATE_SHAPE_AND_GRADIENT` |
| `CUF` | cuf_bases, point_bases, fundamental_nucleus | scalar basis and gradient of the combined `Ni·Ft` |
| `KINEMATICS` | linear kinematics | B operator |
| `MATERIALS` | materials, resolution, rotations | C matrix per Gauss point |
| `GAUSS` | points, geometry, materials | contiguous Gauss-point arrays |
| `ELEMENTS` | element_matrices, mitc | K, M of one element; tying sets |
| `ASSEMBLY` | dof_layout, sparse_assembly, sparse_operations | DOF map, CSR pattern, scatter, reduction |
| `BOUNDARY` | boundary_application | D-PLANE / F-POINT |
| `ANALYSES` | model_cache, model_assembly, analysis_101/103, results, driver | orchestration |
| `SOLVERS` | pardiso_factor, pardiso_solver, modal_solver | linear and eigen solvers |
| `POST` | recovery, post_grid, post_output | point recovery, VTK/GMSH/POINT outputs |
| `APP` | main | argument handling |
| `ARPACK` | `.f` | unmodified ARPACK routines |

Dependencies are one-directional (BASE ← MODEL ← … ← ANALYSES ← APP).

## 4. Execution flow (`RUN_MUL2`, `mul2_driver.for`)

1. Determine input directory: argument → `PATH_input.dat` → `INPUT`.
2. Create `STATIC`, `DYNAMIC`, `REPORT`, `WORK`.
3. `READ_ANALYSIS_FILE`, `READ_MODEL`, `READ_POSTPROCESSING_FILE`.
   Only solutions 101 and 103 are accepted.
4. `BUILD_MODEL_CACHE`: incidence, DOF layout, Gauss geometry,
   material resolution, MITC preparation (`MITC_PREPARE_ELEMENT`).
5. Analysis:
   * 101 `RUN_STATIC_ANALYSIS`: assemble K and F → eliminate constraints
     → `PARDISO_FACTORIZE` / `PARDISO_SOLVE` (tolerance 1e-9) → expand.
   * 103 `RUN_MODAL_ANALYSIS`: assemble K, M → `BUILD_REDUCED_PATTERN` /
     `REDUCE_VALUES` → `SOLVE_MODAL_PROBLEM` (ARPACK or dense) →
     `SORT_MODES`, `COMPUTE_RESIDUALS`.
6. Output (`mul2_post_output`): points, VTK/GMSH, frequencies, dumps.
7. All warnings written to `REPORT/WARNING_file.dat`; console reports times.
   Errors give a non-zero exit code (1).

## 5. Key algorithms

### 5.1 DOF layout and sparse pattern
`mul2_dof_layout` builds the map (node, field, term) → global DOF,
field-major. `BUILD_ELEMENT_DOF_LIST` gives each element's global DOF list.
`BUILD_PATTERN_FROM_DOF_LISTS` produces the pairs, sorts them, removes
duplicates and returns CSR 1-based `ROW_POINTER(I8)`, `COLUMN_INDEX(I8)`
shared by K and M. `SCATTER_ELEMENT` finds the CSR slot by binary search in
the (sorted) row segment.

### 5.2 Assembly and OpenMP
`ASSEMBLE_MODEL_SYSTEM` processes elements in chunks bounded by
`CHUNK_BYTES` (2·10⁸ bytes of element matrices). Within a chunk element
matrices are evaluated in `!$OMP PARALLEL DO SCHEDULE(DYNAMIC,1)` into
private storage; the scatter into the CSR arrays is then **serial and in
element order**, so the floating-point sum order never depends on the
thread count (tested with 1 and 4 threads: bit-identical).

### 5.3 Element kernel
Two kernels produce the same matrices. The default is the *separable* CUF
kernel (`mul2_separable_kernel.for`, see `BENCHMARK.md`): structural and
expansion integrals are computed separately and combined, so the cost is
additive in the Gauss points. The *point-by-point* kernel described next is
the reference and the fallback (force it with the environment variable
`MUL2_GENERAL_KERNEL=1`).

`BUILD_LINEAR_ELEMENT_MATRICES` loops over the contiguous Gauss points of
the element. For every point, `EVALUATE_LOCAL_DOF` obtains the basis
(`EVALUATE_POINT_FACTORS`, `EVALUATE_FIELD_BASIS`), the B column of each DOF
and, when a `MITC_DATA_TYPE` is passed, replaces the shear rows via
`MITC_TIE_COLUMN` (tensor Lagrange interpolation of the columns evaluated
at the tying points). `ELEMENT_MATRIX_TYPE` stores `NODE_INDEX` and
`KINEMATIC_INDEX` of each local DOF.

### 5.4 Constraints
`mul2_boundary_application` selects constrained terms from physical
coordinates (using node incidence for the first incident element) and
`mul2_sparse_operations` applies the exact elimination: `F := F − K u_c`,
zero rows/columns, unit diagonal for 101; for 103 the reduced matrices
contain only free DOFs.

### 5.5 Solvers
* `mul2_pardiso_factor`: `PARDISO_FACTOR_TYPE` holds the handle and
  (phase 12 → 33 → −1). `PARDISO_HINT` translates negative error codes
  (e.g. −4 = numerically singular: check constraints).
* `mul2_modal_solver`: ARPACK `dsaupd`/`dseupd`, mode 3, `BMAT='G'`,
  σ = 0 with the stored factor; dense fallback (`dsygv`) when N ≤ 400 or
  nev ≥ N−2; `COMPUTE_RESIDUALS` returns ‖Kφ−λMφ‖/(λ‖Mφ‖-ish scale).
  ARPACK is compiled with 64-bit INTEGER *and* LOGICAL (`/4I8`) so the same
  ILP64 CSR arrays can be used; `second` comes from MKL.

### 5.6 Post-processing
`mul2_recovery`: `PLACE_SETUP` (element bounding boxes, cached frames),
`LOCATE_POINT` (bbox prefilter then Newton), `STATE_FROM_PLACE` (u, ε, σ at
the located natural coordinates, with MITC if active).
`mul2_post_grid`: maps element sub-cells to VTK (type 12 linear hexa, 25
quadratic hexa with 20 of 27 nodes) and GMSH cell orders; beam natural
mapping S=η, E=(ξ,ν); plate S=(ξ,η), E=ν; solid S=(ξ,η,ν).
`mul2_post_output` evaluates cells in parallel and writes the files;
points outside the mesh give a NaN row and a warning.

## 6. Input readers

| File | Module | Notes |
|------|--------|-------|
| `ANALYSIS.dat` | `read_analysis` | solution id, unused record, modes, 3 shear flags |
| `NODES.dat` | `read_nodes`, `read_legacy_nodes` | legacy `ID X Y Z TE\|LE [order]` or `KINEMATICS.dat` |
| `CONNECTIVITY.dat` | `read_connectivity` | duplicate check by sorting (O(n log n)) |
| `MATERIAL.dat`, `LAMINATION.dat`, `VERSORS.dat` | `read_materials`, `read_laminations`, `read_reference_systems` | |
| `EXP_MESH_nn.dat`, `EXP_CONN_nn.dat` | `read_expansions` | |
| `BC.dat` | `read_boundary_conditions` | `D-PLANE`, `F-POINT` |
| `POSTPROCESSING.dat` | `read_analysis` | `PARA/GMSH/PNT/KMAT/MMAT/FRCE/UNKN/ENRG` |

Legacy files end with optional blank/description lines; `NEXT_DATA_LINE`
skips comments and blanks. Missing trailing post-processing records give
a warning (baseline behaviour).

## 7. Testing and validation

`TESTS/`:

* `mul2_tests.for` – unit tests (quadrature, shape functions, Jacobians,
  sparse, materials…).
* `mul2_pardiso_tests.for` – factorisation and solve on small SPD systems.
* `mul2_analysis_tests.for` + `mul2_test_support.for` – run the real
  executable in isolated directories (`BUILD/.../TESTRUNS`) on
  `TESTS/CASES/<case>/INPUT` and compare with `REFERENCE`:
  golden beam/plate 101, golden 103, generated cases (mixed, B3 TE2,
  Q4, Q9×4, H8, modal plate/beam), patch tests (uniform strain, ν=0),
  thread independence.
* `TESTS/TOOLS/compare_vtk.py` – optional VTK diff (Python; outside the
  solver).

Generating new reference cases: run the frozen baseline
(`MUL2/MUL2_OPTIMIZED`) on modified inputs, copy `INPUT` and the compact
outputs (`POST_POINT.dat`, `RESULTS_PARA_01.vtk`, `FREQUENCIES.dat`,
`RESULTS_DYN_PARA.vtk`) to `TESTS/CASES/<name>/REFERENCE`.

Tolerances: point rows 3·10⁻⁵ (the baseline locates points approximately),
frequencies ~10⁻⁵ (baseline penalty), patch tests 10⁻⁹.

## 8. Web interface

`INTERFACE/` is a static page plus a PowerShell `HttpListener` server:

* `GET /api/ping` – solver name; `POST /api/run` – body `{files:{name:text}}`
  creates `INTERFACE/runs/<id>/INPUT`, writes `PATH_input.dat`, starts
  `MUL2_V3.exe` with that directory as working directory;
  `GET /api/status?id=` – status, logs, result list;
  `GET /api/file?id=&path=` – a result file.
* Solver lookup order: `-Solver` argument, `INTERFACE\MUL2_V3.exe`,
  `BIN\MUL2_V3.exe`, `BUILD\WINDOWS_IFX\{Release,RelWithDebInfo,Debug}`.
* The 3D view detects the model family from the first element in
  `CONNECTIVITY.dat` (`Beam3DRenderer.modelMode`): beam = extruded section;
  plate = plan mesh with the EXP_MESH thickness; solid = element faces.

## 9. Extending the program

* **New element**: add topology (`mul2_topologies`), shape functions,
  quadrature, and optionally a MITC tying table in `mul2_mitc`; extend
  `mul2_post_grid` if a new cell shape is needed; add a reference case.
* **New analysis**: add `mul2_analysis_nnn.for` to `MUL2_SOLVERS`, register
  it in `mul2_driver`, extend `ANALYSIS_TYPES` in the GUI.
* **New field**: extend `MOD_KINEMATICS`, the DOF layout and the B operator.
* Always re-run the complete test-suite in Debug (bounds/uninitialised
  checks) and Release before merging.

## 10. Troubleshooting

| Symptom | Cause |
|---------|-------|
| exit code −1073741515 | Intel/MKL DLLs not on `PATH` |
| PARDISO error −4 | singular K: missing constraints, disconnected bodies, or H8 with MITC |
| heap corruption (0xC0000374) | stale tying set; `MITC_CLEAR` must reset `SET` |
| forrtl 406 warnings | array temporaries; copy assumed-shape sections locally |
| post point gives NaN | point outside the mesh |
