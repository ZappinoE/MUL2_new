# Architecture {#sec:arch}

## Layers

The source tree is divided into **layers**, one directory per layer. A module of a layer may use only modules of the same layer or of the layers below it. The diagram below is computed automatically from the `USE` statements: every line is a real dependency.

![Layers of the code and the dependencies actually present.](figures/layers.svg){#fig:layers-arch}

Table: Layers, their purpose and their modules. {#tab:layers}

| Layer | Purpose | Modules |
|---|---|---|
| BASE | precision kinds, status, log, timers, strings, files, sorting | `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_RUNTIME`, `MUL2_STRINGS`, `MUL2_FILES`, `MUL2_SORTING` |
| MODEL | plain data types: nodes, elements, kinematics, expansion meshes, materials, laminations, boundary conditions, analysis and post requests, topologies | `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_LAMINATIONS`, `MUL2_BOUNDARY_CONDITIONS`, `MUL2_ANALYSIS_INPUT`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_INCIDENCE`, `MUL2_TOPOLOGIES`, `MUL2_MODEL` |
| IO | text readers; `READ_MODEL` builds a `MODEL_TYPE` from a directory | `READ_*` modules, `MUL2_TEXT_IO` |
| QUADRATURE, FEM | Gauss rules, shape functions | `MUL2_QUADRATURE`, `MUL2_SHAPE_FUNCTIONS` |
| GEOMETRY | element frames, Jacobians, local gradients | `MUL2_ELEMENT_FRAMES`, `MUL2_JACOBIANS`, `MUL2_LOCAL_GRADIENTS` |
| CUF, KINEMATICS | expansion bases, point factors, nucleus; strain operator | `MUL2_CUF_BASES`, `MUL2_POINT_BASES`, `MUL2_FUNDAMENTAL_NUCLEUS`, `MUL2_LINEAR_KINEMATICS` |
| MATERIALS | stiffness matrices, rotations | `MUL2_MATERIALS`, `MUL2_MATERIAL_ROTATIONS`, `MUL2_MATERIAL_RESOLUTION` |
| GAUSS | reference rules, global Gauss layout, geometry and material caches | `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_GAUSS_MATERIALS` |
| ELEMENTS | element matrices (reference and separable kernels), MITC, dense products | `MUL2_ELEMENT_MATRICES`, `MUL2_SEPARABLE_KERNEL`, `MUL2_MITC`, `MUL2_DENSE_PRODUCTS` |
| ASSEMBLY | DOF layout, CSR pattern and assembly, sparse operations | `MUL2_DOF_LAYOUT`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_SPARSE_OPERATIONS` |
| BOUNDARY | constraints and loads | `MUL2_BOUNDARY_APPLICATION` |
| SOLVERS | PARDISO and ARPACK/LAPACK wrappers | `MUL2_PARDISO_FACTOR`, `MUL2_PARDISO_SOLVER`, `MUL2_MODAL_SOLVER` |
| ANALYSES | model cache, parallel assembly, analyses 101 and 103, driver | `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_ANALYSIS_101`, `MUL2_ANALYSIS_103`, `MUL2_DRIVER` |
| POST | point location and recovery, grids, output files | `MUL2_RECOVERY`, `MUL2_POST_GRID`, `MUL2_POST_OUTPUT` |
| APP | program entry | `MUL2_V3` |

## Naming conventions

- **Modules** are named `MUL2_<NAME>`; the file has the same name in lower case.
- **Procedures** have verb-first names: `BUILD_…` creates or fills a structure, `EVALUATE_…` computes numbers at a point, `READ_…`/`WRITE_…` do I/O, `FIND_…` searches, `CLEAR_…` releases memory, `RUN_…` executes an analysis.
- **Derived types** end with `_TYPE`; collections end with `_DB_TYPE` and contain an allocatable component `ITEM(:)`.
- **Dummy arguments** are declared with `INTENT`; output arguments are `INTENT(OUT)` or `INTENT(INOUT)`; the last argument of fallible routines is `STATUS`.
- **Indices**: `…_INDEX` is a position in an array (1-based) while `…_ID` is the number given in the input; the readers build sorted lookup tables so that `FIND_…_INDEX` is a binary search.
- **Frame vocabulary**: `GLOBAL_TO_LOCAL(:,:,e)` is the matrix $\mathbf{R}$ of element $e$ (rows = local axes); `LOCAL_TO_GLOBAL` is its transpose.

## Status and error handling {#sec:status}

Every routine that can fail returns a `STATUS_TYPE`:

```fortran
#caption: STATUS_TYPE (BASE/mul2_status.for)
TYPE, PUBLIC :: STATUS_TYPE
  INTEGER(I4) :: CODE = STATUS_OK            ! 0 OK, 1 warning, 2 error
  INTEGER(I4) :: WARNING_COUNT = 0_I4
  CHARACTER(LEN=256) :: MESSAGE = ' '
  CHARACTER(LEN=64)  :: SOURCE  = ' '        ! routine that raised it
END TYPE STATUS_TYPE
```

Rules:

1. A routine starts with `CALL CLEAR_STATUS(STATUS)`.
2. It reports with `SET_WARNING(STATUS, 'ROUTINE', 'text')` (the run continues) or `SET_ERROR(...)` (the routine returns). An error is never overwritten by a later message; warnings are counted.
3. A caller merges the status of a step into the status of the phase with `MERGE_STATUS(LOCAL, GLOBAL)` (the first error wins), tests it with `STATUS_IS_OK` and returns on error.
4. `RUN_MUL2` collects the warning texts in a `WARNING_LIST_TYPE` that is written to `REPORT/WARNING_file.dat`.

This convention replaces exceptions: reading any routine, the error paths are the `IF (.NOT. STATUS_IS_OK(...)) RETURN` lines.

## Memory management

All large arrays are `ALLOCATABLE` and owned by the structure that contains them. Memory is released explicitly where it matters:

- `PARDISO_SET_SYSTEM` copies the upper triangle into the solver handle; the static analysis then frees the full matrix before the (memory-hungry) factorisation if no dump is requested.
- The modal analysis frees the full $\mathbf{K}$, $\mathbf{M}$ and the reduction map once the reduced matrices are built.
- Element matrices exist only for the elements of the chunk being assembled and are released after the scatter.

## OpenMP and determinism {#sec:openmp}

Parallel regions (all marked with `!$OMP`):

Table: Parallel regions. {#tab:omp}

| Where | What is parallel | Why it is thread-count independent |
|---|---|---|
| `ASSEMBLE_MODEL_SYSTEM` | the evaluation of the element matrices of a chunk | each element writes only its private matrices; the scatter into the CSR arrays is serial and in element order |
| `SPARSE_MULTIPLY` | rows of a matrix–vector product | rows are independent |
| `EVALUATE_GRID_STATES`, `EVALUATE_GRID_MODES` | cells of the output grid | each cell writes its own entries |

Because the order of every floating-point addition is fixed, runs with different `OMP_NUM_THREADS` give **bit-identical** results (tested with 1 and 4 threads). Chunk size is a multiple of the thread count (so that no thread idles) and bounded by a memory budget of $10^9$ bytes of element matrices.
