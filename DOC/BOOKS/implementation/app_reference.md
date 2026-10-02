# Source reference {#sec:reference}

This appendix is generated from the sources by `DOC/BOOKS/tools/refgen.py`; it lists, layer by layer, every module with its purpose, the modules it uses, its public derived types and constants, and its procedures with the meaning of the dummy arguments. Procedure descriptions are the comments written above each routine in the code.

The code base has **83 modules** and **404 procedures** in 85 source files (ARPACK excluded).

## Layer BASE {#sec:ref_base}

Precision kinds, status/error handling, logging, timers, string and file utilities, sorting and searching.

### MUL2_FILES

File `SRC/BASE/mul2_files.for`.

File-system helpers (output directories).

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Procedures of `MUL2_FILES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `IS_WINDOWS` | Function → logical | public | True when the program runs on Windows (selects shell syntax). |
| `ENSURE_DIRECTORY` | Subroutine | public | Create a relative directory if it does not exist yet. |

#### `ENSURE_DIRECTORY`

Create a relative directory if it does not exist yet.

| Argument | Declaration | Meaning |
|---|---|---|
| `NAME` | `CHARACTER(LEN=*), intent(IN)` | Name. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_KINDS

File `SRC/BASE/mul2_kinds.for`.

Numeric kinds used by the whole code.

### MUL2_LOG

File `SRC/BASE/mul2_log.for`.

Central console logger.

Table: Procedures of `MUL2_LOG`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `LOG_INITIALIZE` | Subroutine | public | Select normal or debug logging. |
| `LOG_INFO` | Subroutine | public | Print an informational line on the console. |
| `LOG_WARNING` | Subroutine | public | Print a warning line. |
| `LOG_ERROR` | Subroutine | public | Print an error line on the error unit. |
| `LOG_DEBUG` | Subroutine | public | Print a line only in debug mode. |
| `IS_DEBUG_MODE` | Function → logical | public | Return the debug flag. |

#### `LOG_INITIALIZE`

Select normal or debug logging.

| Argument | Declaration | Meaning |
|---|---|---|
| `DEBUG_ENABLED` | `LOGICAL, intent(IN)` | True selects debug logging. |

#### `LOG_INFO`

Print an informational line on the console.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

#### `LOG_WARNING`

Print a warning line.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

#### `LOG_ERROR`

Print an error line on the error unit.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

#### `LOG_DEBUG`

Print a line only in debug mode.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

### MUL2_RUNTIME

File `SRC/BASE/mul2_runtime.for`.

Process-wide runtime initialization.

Uses: `MUL2_LOG`.

Table: Procedures of `MUL2_RUNTIME`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `INITIALIZE_RUNTIME` | Subroutine | public | Start the global timer and print the banner. |
| `FINALIZE_RUNTIME` | Subroutine | public | Print the CPU and wall time of the run. |

### MUL2_SORTING

File `SRC/BASE/mul2_sorting.for`.

Heap sort of 64-bit keys with a permutation, and duplicate search.

Uses: `MUL2_KINDS`.

Table: Procedures of `MUL2_SORTING`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `SORT_PERMUTATION` | Subroutine | public | Order(1:n) = permutation such that key(order(1:n)) is ascending. |
| `SIFT_DOWN` | Subroutine | private | Heap-sort helper. |
| `BINARY_SEARCH` | Function → integer(i4) | public | Position i of target in sorted_key(order(1:n)) as order(i), or 0. |
| `HAS_DUPLICATE_KEYS` | Function → logical | public | True when a key array contains a repeated value. |

#### `SORT_PERMUTATION`

Order(1:n) = permutation such that key(order(1:n)) is ascending.

| Argument | Declaration | Meaning |
|---|---|---|
| `KEY` | `INTEGER(I8), intent(IN)(:)` | Array of keys to sort. |
| `ORDER` | `INTEGER(I4), intent(OUT)(:)` | Output: permutation. |

#### `BINARY_SEARCH`

Position i of target in sorted_key(order(1:n)) as order(i), or 0.

| Argument | Declaration | Meaning |
|---|---|---|
| `SORTED_KEY` | `INTEGER(I8), intent(IN)(:)` | Keys (in the order given by ORDER). |
| `ORDER` | `INTEGER(I4), intent(IN)(:)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `TARGET` | `INTEGER(I8), intent(IN)` | Key to find. |

#### `HAS_DUPLICATE_KEYS`

True when a key array contains a repeated value.

| Argument | Declaration | Meaning |
|---|---|---|
| `KEY` | `INTEGER(I8), intent(IN)(:)` | Integer keys. |

### MUL2_STATUS

File `SRC/BASE/mul2_status.for`.

Central status and error description.

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_STATUS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `STATUS_OK` | `INTEGER(I4)` | `0_I4` | Status code. |
| `STATUS_WARNING` | `INTEGER(I4)` | `1_I4` | Status code. |
| `STATUS_ERROR` | `INTEGER(I4)` | `2_I4` | Status code. |

Table: Derived type `STATUS_TYPE` — Result of any operation: code (0 OK, 1 warning, 2 error), warning counter, last message and its source routine.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `CODE` | `INTEGER(I4)` | `` | `STATUS_OK` | Status code. |
| `WARNING_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of warnings. |
| `MESSAGE` | `CHARACTER(LEN=256)` | `` | `' '` | Last message. |
| `SOURCE` | `CHARACTER(LEN=64)` | `` | `' '` | Routine that reported it. |

Table: Procedures of `MUL2_STATUS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `CLEAR_STATUS` | Subroutine | public | Reset a status to OK. |
| `SET_WARNING` | Subroutine | public | Record a warning (an existing error is not overwritten). |
| `SET_ERROR` | Subroutine | public | Record an error with its source and message. |
| `STATUS_IS_OK` | Function → logical | public | True when the status is not an error (warnings are allowed). |
| `MERGE_STATUS` | Subroutine | public | Fold the status of one step into the status of a whole phase: the first error wins and warnings are counted, never lost. |

#### `CLEAR_STATUS`

Reset a status to OK.

| Argument | Declaration | Meaning |
|---|---|---|
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `SET_WARNING`

Record a warning (an existing error is not overwritten).

| Argument | Declaration | Meaning |
|---|---|---|
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |
| `SOURCE` | `CHARACTER(LEN=*), intent(IN)` | Name of the routine reporting the warning. |
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

#### `SET_ERROR`

Record an error with its source and message.

| Argument | Declaration | Meaning |
|---|---|---|
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |
| `SOURCE` | `CHARACTER(LEN=*), intent(IN)` | Name of the routine reporting the error. |
| `MESSAGE` | `CHARACTER(LEN=*), intent(IN)` | Message text. |

#### `STATUS_IS_OK`

True when the status is not an error (warnings are allowed).

| Argument | Declaration | Meaning |
|---|---|---|
| `STATUS` | `TYPE(STATUS_TYPE), intent(IN)` | Status of the call (OK, warning or error with message and source). |

#### `MERGE_STATUS`

Fold the status of one step into the status of a whole phase: the first error wins and warnings are counted, never lost.

| Argument | Declaration | Meaning |
|---|---|---|
| `LOCAL` | `TYPE(STATUS_TYPE), intent(IN)` | Status of one step. |
| `GLOBAL` | `TYPE(STATUS_TYPE), intent(INOUT)` | Accumulated status of the phase. |

### MUL2_STRINGS

File `SRC/BASE/mul2_strings.for`.

Basic string utilities.

Table: Procedures of `MUL2_STRINGS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `UPPERCASE` | Subroutine | public | Convert a string to upper case in place. |

#### `UPPERCASE`

Convert a string to upper case in place.

| Argument | Declaration | Meaning |
|---|---|---|
| `TEXT` | `CHARACTER(LEN=*), intent(INOUT)` | Text. |

### MUL2_TIMER

File `SRC/BASE/mul2_timer.for`.

Wall-clock and cpu timer.

Uses: `MUL2_KINDS`.

Table: Derived type `TIMER_TYPE` — CPU and wall-clock timer.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `NAME` | `CHARACTER(LEN=64)` | `` | `' '` | Timer name. |
| `CPU_BEGIN` | `REAL(R8)` | `` | `0.0_R8` | CPU time at start. |
| `CPU_END` | `REAL(R8)` | `` | `0.0_R8` | CPU time at stop. |
| `CLOCK_BEGIN` | `INTEGER(I8)` | `` | `0_I8` | Clock count at start. |
| `CLOCK_END` | `INTEGER(I8)` | `` | `0_I8` | Clock count at stop. |
| `CLOCK_RATE` | `INTEGER(I8)` | `` | `0_I8` | Clock ticks per second. |
| `CLOCK_MAX` | `INTEGER(I8)` | `` | `0_I8` | Clock wrap value. |
| `RUNNING` | `LOGICAL` | `` | `.FALSE.` | Timer running flag. |

Table: Procedures of `MUL2_TIMER`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `TIMER_START` | Subroutine | public | Start a named timer (CPU and wall clock). |
| `TIMER_STOP` | Subroutine | public | Stop a timer. |
| `TIMER_CPU_SECONDS` | Function → real(r8) | public | Elapsed CPU seconds. |
| `TIMER_WALL_SECONDS` | Function → real(r8) | public | Elapsed wall-clock seconds. |

#### `TIMER_START`

Start a named timer (CPU and wall clock).

| Argument | Declaration | Meaning |
|---|---|---|
| `TIMER` | `TYPE(TIMER_TYPE), intent(INOUT)` | Timer. |
| `NAME` | `CHARACTER(LEN=*), intent(IN)` | Name. |

#### `TIMER_STOP`

Stop a timer.

| Argument | Declaration | Meaning |
|---|---|---|
| `TIMER` | `TYPE(TIMER_TYPE), intent(INOUT)` | Timer. |

#### `TIMER_CPU_SECONDS`

Elapsed CPU seconds.

| Argument | Declaration | Meaning |
|---|---|---|
| `TIMER` | `TYPE(TIMER_TYPE), intent(IN)` | Timer. |

#### `TIMER_WALL_SECONDS`

Elapsed wall-clock seconds.

| Argument | Declaration | Meaning |
|---|---|---|
| `TIMER` | `TYPE(TIMER_TYPE), intent(IN)` | Timer. |

## Layer MODEL {#sec:ref_model}

Plain data types of the model: nodes, elements, kinematics, expansion meshes, materials, laminations, boundary conditions, analysis and post-processing requests.

### MUL2_ANALYSIS_INPUT

File `SRC/MODEL/mul2_analysis_input.for`.

Analysis configuration and post-processing requests. shear(1:3) holds the shear-locking treatment of beam, plate and solid elements: none (full integration), redi (reduced integration of the structural element), seli (selective: the terms with a shear strain are reduced, the others full) or mitc (tied shear strains).

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_ANALYSIS_INPUT`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `SOLUTION_STATIC` | `INTEGER(I4)` | `101_I4` | Analysis number. |
| `SOLUTION_MODAL` | `INTEGER(I4)` | `103_I4` | Analysis number. |
| `SOLUTION_TIME` | `INTEGER(I4)` | `104_I4` | Analysis number. |
| `SOLUTION_BUCKLING` | `INTEGER(I4)` | `105_I4` | Analysis number. |
| `SOLUTION_FREQUENCY` | `INTEGER(I4)` | `106_I4` | Analysis number. |
| `SOLUTION_NONLINEAR` | `INTEGER(I4)` | `108_I4` | Analysis number. |
| `SHEAR_NONE` | `INTEGER(I4)` | `0_I4` | Shear-correction code NONE. |
| `SHEAR_REDUCED` | `INTEGER(I4)` | `1_I4` | Shear-correction code REDUCED. |
| `SHEAR_SELECTIVE` | `INTEGER(I4)` | `2_I4` | Shear-correction code SELECTIVE. |
| `SHEAR_MITC` | `INTEGER(I4)` | `3_I4` | Shear-correction code MITC. |
| `SHEAR_BEAM` | `INTEGER(I4)` | `1_I4` | Shear-correction code BEAM. |
| `SHEAR_PLATE` | `INTEGER(I4)` | `2_I4` | Shear-correction code PLATE. |
| `SHEAR_SOLID` | `INTEGER(I4)` | `3_I4` | Shear-correction code SOLID. |
| `POST_FORMAT_PARAVIEW` | `INTEGER(I4)` | `1_I4` | Output format code. |
| `POST_FORMAT_GMSH` | `INTEGER(I4)` | `2_I4` | Output format code. |
| `POST_FRAME_LOCAL` | `INTEGER(I4)` | `1_I4` | Output frame code. |
| `POST_FRAME_GLOBAL` | `INTEGER(I4)` | `2_I4` | Output frame code. |

Table: Derived type `ANALYSIS_TYPE` — Content of ANALYSIS.dat.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `SOLUTION` | `INTEGER(I4)` | `` | `0_I4` | Displacement coefficients in field-major DOF order. |
| `MODE_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of modes (requested / converged). |
| `FIELD_RECORD` | `LOGICAL` | `` | `.FALSE.` | Optional `fields` record: the physics that are solved (the kinematics only define how each field is expanded). without the record (field_record false) every field expanded in kinematics.dat is solved, as in the historical format. |
| `FIELD_MECH` | `LOGICAL` | `` | `.TRUE.` |  |
| `FIELD_THERMO` | `LOGICAL` | `` | `.FALSE.` |  |
| `FIELD_PIEZO` | `LOGICAL` | `` | `.FALSE.` |  |
| `JOIN_COINCIDENT` | `LOGICAL` | `` | `.FALSE.` | `join coincident [tol]`: dofs of different nodes are joined when they are the same field at the same point; tol is a fraction of the diagonal of the model. |
| `JOIN_TOLERANCE` | `REAL(R8)` | `` | `1.0E-6_R8` |  |
| `SHEAR` | `INTEGER(I4)` | `(3)` | `SHEAR_NONE` | Shear correction of beams, plates, solids. |

Table: Derived type `POST_FIELD_REQUEST_TYPE` — One `para` or `gmsh` record. split holds the nine subdivision counts: beam (section x, axis, section z), plate (x, y, thickness), solid (x, y, z). cell_nodes is 8 (linear) or 20/27 (quadratic).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FORMAT` | `INTEGER(I4)` | `` | `POST_FORMAT_PARAVIEW` | Output format (VTK or GMSH). |
| `FRAME` | `INTEGER(I4)` | `` | `POST_FRAME_GLOBAL` | Output frame (local or global) or frame id. |
| `CELL_NODES` | `INTEGER(I4)` | `` | `20_I4` | Nodes per output cell. |
| `SPLIT` | `INTEGER(I4)` | `(9)` | `1_I4` | Subdivision counts. |

Table: Derived type `POST_POINT_REQUEST_TYPE` — One PNT record.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `COORDINATE` | `REAL(R8)` | `(3)` | `0.0_R8` | Coordinates. |

Table: Derived type `POST_DB_TYPE` — Content of POSTPROCESSING.dat.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FIELD` | `TYPE(POST_FIELD_REQUEST_TYPE), ALLOCATABLE` | `(:)` | `` | Field of each local DOF (or request list). |
| `POINT` | `TYPE(POST_POINT_REQUEST_TYPE), ALLOCATABLE` | `(:)` | `` | Point requests or point coordinate. |
| `WRITE_STIFFNESS` | `LOGICAL` | `` | `.FALSE.` | Dump K. |
| `WRITE_MASS` | `LOGICAL` | `` | `.FALSE.` | Dump M. |
| `WRITE_FORCE` | `LOGICAL` | `` | `.FALSE.` | Dump F. |
| `WRITE_UNKNOWN` | `LOGICAL` | `` | `.FALSE.` | Dump u. |
| `WRITE_ENERGY` | `LOGICAL` | `` | `.FALSE.` | Energy request. |

### MUL2_BOUNDARY_CONDITIONS

File `SRC/MODEL/mul2_boundary_conditions.for`.

Mechanical boundary-condition input model.

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_BOUNDARY_CONDITIONS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `BC_DISPLACEMENT_PLANE` | `INTEGER(I4)` | `1_I4` | Boundary-condition kind. |
| `BC_FORCE_POINT` | `INTEGER(I4)` | `2_I4` | Boundary-condition kind. |
| `BC_VALUE_POINT` | `INTEGER(I4)` | `3_I4` | Prescribed value of a field (e.g. the electric potential) at a point; on a plane the record is a bc_displacement_plane. |
| `BC_TIE_PLANE` | `INTEGER(I4)` | `4_I4` | Floating electrode: the potential dofs on a plane share one value. |
| `BC_SURFACE` | `INTEGER(I4)` | `5_I4` | Load on the exposed surface (heat flux, sun, convection): see mul2_surface_loads. surface = 1 flux, 2 sun, 3 convection. |

Table: Derived type `BOUNDARY_CONDITION_TYPE` — One D-PLANE or F-POINT record.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `KIND` | `INTEGER(I4)` | `` | `0_I4` | Record kind. |
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `PLANE` | `REAL(R8)` | `(4)` | `0.0_R8` | Plane A, B, C, D. |
| `POINT` | `REAL(R8)` | `(3)` | `0.0_R8` | Point requests or point coordinate. |
| `ACTIVE` | `LOGICAL` | `(9)` | `.FALSE.` | One entry per field (u v w t p b szz sxz syz). |
| `VALUE` | `REAL(R8)` | `(9)` | `0.0_R8` | Values. |
| `FIELD_ID` | `INTEGER(I4)` | `` | `0_I4` | Spatial field (fields.dat) multiplying the value, 0 = none. |
| `SURFACE` | `INTEGER(I4)` | `` | `0_I4` |  |
| `PARAM` | `REAL(R8)` | `(6)` | `0.0_R8` |  |

Table: Derived type `BOUNDARY_DB_TYPE` — Boundary-condition database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(BOUNDARY_CONDITION_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

### MUL2_ELEMENTS

File `SRC/MODEL/mul2_elements.for`.

Finite-element connectivity definitions.

Uses: `MUL2_KINDS`.

Table: Derived type `ELEMENT_TYPE` — One structural element.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I8)` | `` | `0_I8` | Identifier. |
| `TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Topology code. |
| `NODE_ID` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Node ids of the element. |
| `FRAME_ID` | `INTEGER(I4)` | `` | `0_I4` |  |
| `EXPANSION_ID` | `INTEGER(I4)` | `` | `0_I4` | Expansion mesh used. |
| `GENERAL` | `LOGICAL` | `` | `.FALSE.` | True when the name of the element forces the general (curved) geometry: s4 s9 s16 (shells), cb2 cb3 cb4 (curved beams). |

Table: Derived type `ELEMENT_DB_TYPE` — Element database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(ELEMENT_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

### MUL2_EXPANSION_MESHES

File `SRC/MODEL/mul2_expansion_meshes.for`.

Lagrange expansion meshes used on sections or thicknesses.

Uses: `MUL2_KINDS`.

Table: Derived type `EXPANSION_NODE_TYPE` — Node of an expansion mesh (section or thickness).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I8)` | `` | `0_I8` | Identifier. |
| `COORDINATE` | `REAL(R8)` | `(3)` | `0.0_R8` | Coordinates. |

Table: Derived type `EXPANSION_ELEMENT_TYPE` — Sub-element of an expansion mesh.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I8)` | `` | `0_I8` | Identifier. |
| `TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Topology code. |
| `LAMINATION_ID` | `INTEGER(I4)` | `` | `0_I4` | Lamination id. |
| `NODE_ID` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Node ids of the element. |
| `MODE_TERM` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Hle only: global term and sign of every local function (term 0 = function omitted by the order of an adjacent sub-element). |
| `MODE_SIGN` | `REAL(R8), ALLOCATABLE` | `(:)` | `` |  |
| `MID_NODE_ID` | `INTEGER(I8)` | `(4)` | `0_I8` | Hq only: third point (a mesh node, 0 = none) of each side; a side with one is the circular arc through its vertices and that point. |

Table: Derived type `EXPANSION_MESH_TYPE` — One expansion mesh (EXP_MESH_nn / EXP_CONN_nn).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `NODE` | `TYPE(EXPANSION_NODE_TYPE), ALLOCATABLE` | `(:)` | `` |  |
| `ELEMENT` | `TYPE(EXPANSION_ELEMENT_TYPE), ALLOCATABLE` | `(:)` | `` | Element index. |
| `IS_HLE` | `LOGICAL` | `` | `.FALSE.` | Hle only: number of global terms and their origin. the first terms are the vertex modes; term_node(:,t) = (node,0) for a vertex, (node_a,node_b) for a side mode, (0,0) for an internal mode; term_owner(t) is the sub-element of an internal mode. |
| `N_TERM` | `INTEGER(I4)` | `` | `0_I4` |  |
| `TERM_NODE` | `INTEGER(I4), ALLOCATABLE` | `(:,:)` | `` |  |
| `TERM_OWNER` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `NODE_TERM` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Term of the vertex mode of every node (0 = node used only to describe a curved side, it carries no degree of freedom). |

Table: Derived type `EXPANSION_DB_TYPE` — Expansion mesh database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(EXPANSION_MESH_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Procedures of `MUL2_EXPANSION_MESHES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `HAS_EXPANSION_NODE_ID` | Function → logical | public | True when the mesh has a node with this id. |
| `FIND_EXPANSION_INDEX` | Function → integer(i4) | public | Index of an expansion mesh by id. |
| `EXPANSION_TERM_COUNT` | Function → integer(i4) | public | Number of degrees of freedom per structural node and field of a lagrange or hle mesh. |

#### `HAS_EXPANSION_NODE_ID`

True when the mesh has a node with this id.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(IN)` | Expansion mesh. |
| `ID` | `INTEGER(I8), intent(IN)` | Identifier. |

#### `FIND_EXPANSION_INDEX`

Index of an expansion mesh by id.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

#### `EXPANSION_TERM_COUNT`

Number of degrees of freedom per structural node and field of a lagrange or hle mesh.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(IN)` | Expansion mesh. |

### MUL2_FIELDS

File `SRC/MODEL/mul2_fields.for`.

Spatial fields (fields.dat): f(x,y,z) = sum of terms. a boundary condition may end with a field number: its value is then multiplied by f at the position of every node (or integration point of a surface load). terms (same grammar as the historical code): const c1 c1 x-exp c1 c2 c1 x**c2 (also y-exp, z-exp) cos-x c1 c2 c3 c1 cos(c2 x + c3) (also cos-y, cos-z) sin-x c1 c2 c3 c1 sin(c2 x + c3) (also sin-y, sin-z) atnzx c1 c2 c3 c1 atan2(z-c2,x-c3) in degrees b-sin c1 c2 c3 c4 c5 c1 sin(c2 pi x/c3) sin(c4 pi y/c5)

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_FIELDS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `TERM_CONSTANT` | `INTEGER(I4)` | `1_I4` |  |
| `TERM_POWER_X` | `INTEGER(I4)` | `2_I4` |  |
| `TERM_POWER_Y` | `INTEGER(I4)` | `3_I4` |  |
| `TERM_POWER_Z` | `INTEGER(I4)` | `4_I4` |  |
| `TERM_ARCTAN` | `INTEGER(I4)` | `5_I4` |  |
| `TERM_COS_X` | `INTEGER(I4)` | `6_I4` |  |
| `TERM_COS_Y` | `INTEGER(I4)` | `7_I4` |  |
| `TERM_SIN_X` | `INTEGER(I4)` | `8_I4` |  |
| `TERM_SIN_Y` | `INTEGER(I4)` | `9_I4` |  |
| `TERM_BI_SINE` | `INTEGER(I4)` | `10_I4` |  |
| `TERM_COS_Z` | `INTEGER(I4)` | `11_I4` |  |
| `TERM_SIN_Z` | `INTEGER(I4)` | `12_I4` |  |

Table: Derived type `FIELD_TYPE` — component list

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `TERM` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Expansion term of each local DOF. |
| `CONSTANT` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |

Table: Derived type `FIELD_DB_TYPE` — component list

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(FIELD_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Procedures of `MUL2_FIELDS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `FIND_FIELD_INDEX` | Function → integer(i4) | public |  |
| `EVALUATE_FIELD` | Function → real(r8) | public | Value of field id at a point (1 for id = 0: no field). |

#### `FIND_FIELD_INDEX`

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(FIELD_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

#### `EVALUATE_FIELD`

Value of field id at a point (1 for id = 0: no field).

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(FIELD_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |
| `X` | `REAL(R8), intent(IN)` | Vector or coordinate. |
| `Y` | `REAL(R8), intent(IN)` | Result vector. |
| `Z` | `REAL(R8), intent(IN)` |  |

### MUL2_HLE_MODES

File `SRC/MODEL/mul2_hle_modes.for`.

Global terms of a hierarchical legendre (hle) expansion mesh. every sub-element carries its own polynomial order. the global terms (the degrees of freedom of one structural node and field) are first vertex modes, one per node that is a vertex of a sub-element (the nodal value); nodes that only describe a curved side carry no term (mesh%node_term = 0); next side modes: one group for every geometric side (pair of nodes), modes k = 2..pmin, pmin being the lowest order of the sub-elements that share the side; last internal modes, owned by one sub-element. a side mode of a sub-element of higher order than its neighbour is omitted (constrained to zero): the trace on the shared side is then a polynomial of the lower degree on both sides, so the field stays c0. the side functions have the parity (-1)**k, so a sub-element whose local side direction is opposite to the global one (from the lower to the higher node id) uses the sign (-1)**k.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TOPOLOGIES`, `MUL2_EXPANSION_MESHES`, `MUL2_HLE_SHAPE`.

Table: Procedures of `MUL2_HLE_MODES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_HLE_MESH` | Subroutine | public |  |

#### `BUILD_HLE_MESH`

| Argument | Declaration | Meaning |
|---|---|---|
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(INOUT)` | Expansion mesh. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_INCIDENCE

File `SRC/MODEL/mul2_incidence.for`.

Node-to-element incidence (csr): the elements touching each node.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`.

Table: Derived type `NODE_INCIDENCE_TYPE` — Elements of node i: element(first(i):first(i+1)-1), ascending.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FIRST` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | First global DOF of (node, field) or first element of a node. |
| `ELEMENT` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Element index. |

Table: Procedures of `MUL2_INCIDENCE`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_NODE_INCIDENCE` | Subroutine | public | Node -> incident elements table (CSR). |

#### `BUILD_NODE_INCIDENCE`

Node -> incident elements table (CSR).

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `INCIDENCE` | `TYPE(NODE_INCIDENCE_TYPE), intent(INOUT)` | Node -> element incidence table. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_KINEMATICS

File `SRC/MODEL/mul2_kinematics.for`.

Field-dependent kinematics definitions.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`.

Table: Public constants of `MUL2_KINEMATICS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `N_FIELDS` | `INTEGER(I4)` | `9_I4` | Number of fields of the unified formulation. |
| `N_SOLVED_FIELDS` | `INTEGER(I4)` | `5_I4` | Fields solved by the 101/103 analyses: u, v, w, t, p. |
| `FIELD_U` | `INTEGER(I4)` | `1_I4` | Field index of U. |
| `FIELD_V` | `INTEGER(I4)` | `2_I4` | Field index of V. |
| `FIELD_W` | `INTEGER(I4)` | `3_I4` | Field index of W. |
| `FIELD_T` | `INTEGER(I4)` | `4_I4` | Field index of T. |
| `FIELD_P` | `INTEGER(I4)` | `5_I4` | Field index of P. |
| `FIELD_B` | `INTEGER(I4)` | `6_I4` | Field index of B. |
| `FIELD_SZZ` | `INTEGER(I4)` | `7_I4` | Field index of SZZ. |
| `FIELD_SXZ` | `INTEGER(I4)` | `8_I4` | Field index of SXZ. |
| `FIELD_SYZ` | `INTEGER(I4)` | `9_I4` | Field index of SYZ. |
| `EXPANSION_NONE` | `INTEGER(I4)` | `0_I4` | Expansion family NONE. |
| `EXPANSION_TE` | `INTEGER(I4)` | `1_I4` | Expansion family TE. |
| `EXPANSION_LE` | `INTEGER(I4)` | `2_I4` | Expansion family LE. |
| `EXPANSION_HLE` | `INTEGER(I4)` | `3_I4` | Expansion family HLE. |
| `EXPANSION_MISC` | `INTEGER(I4)` | `4_I4` | Expansion family MISC. |

Table: Derived type `EXPANSION_SPEC_TYPE` — Expansion of one field: family (NONE, TE, LE, HLE, M), order and field reference.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FAMILY` | `INTEGER(I4)` | `` | `EXPANSION_NONE` | Expansion family code. |
| `ORDER` | `INTEGER(I4)` | `` | `0_I4` | Order of the matrix / expansion order / quadrature order (see type). |
| `FIELD_REFERENCE` | `INTEGER(I4)` | `` | `0_I4` | Index of a user-defined function set. |

Table: Derived type `KINEMATIC_TYPE` — Expansion specification of the nine fields.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `FIELD` | `TYPE(EXPANSION_SPEC_TYPE)` | `(N_FIELDS)` | `` | Field of each local DOF (or request list). |

Table: Derived type `KINEMATICS_DB_TYPE` — Kinematics database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(KINEMATIC_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Procedures of `MUL2_KINEMATICS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `HAS_KINEMATIC_ID` | Function → logical | public | True when the kinematic id exists. |
| `APPLY_FIELD_SELECTION` | Subroutine | public | The `fields` record of analysis.dat decides which physics are solved: the expansions of the fields that are switched off are disabled (the kinematics keep their definition), and a field that is switched on must be expanded somewhere. |
| `ANY_FIELD_ACTIVE` | Function → logical | public | True when some kinematic expands the field (1..9) at all. |
| `FIND_KINEMATIC_INDEX` | Function → integer(i4) | public | Index of a kinematic by id. |
| `PARSE_EXPANSION_TOKEN` | Subroutine | public | Parse TE<n>, LE, HLE<n>, M<n> or NONE into an expansion specification. |
| `READ_SUFFIX` | Subroutine | private | Read the integer suffix of a token. |
| `INVALID_TOKEN` | Subroutine | private | Set the error of an unknown expansion token. |

#### `HAS_KINEMATIC_ID`

True when the kinematic id exists.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

#### `APPLY_FIELD_SELECTION`

The `fields` record of analysis.dat decides which physics are solved: the expansions of the fields that are switched off are disabled (the kinematics keep their definition), and a field that is switched on must be expanded somewhere.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(KINEMATICS_DB_TYPE), intent(INOUT)` | Database being filled. |
| `THERMO` | `LOGICAL, intent(IN)` |  |
| `PIEZO` | `LOGICAL, intent(IN)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |

#### `ANY_FIELD_ACTIVE`

True when some kinematic expands the field (1..9) at all.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Database being filled. |
| `FIELD` | `INTEGER(I4), intent(IN)` | Field index (1=U, 2=V, 3=W, ...). |

#### `FIND_KINEMATIC_INDEX`

Index of a kinematic by id.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

#### `PARSE_EXPANSION_TOKEN`

Parse TE<n>, LE, HLE<n>, M<n> or NONE into an expansion specification.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOKEN` | `CHARACTER(LEN=*), intent(IN)` | Text token such as TE3, LE or NONE. |
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE), intent(OUT)` | Expansion specification (family, order, field reference). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_LAMINATIONS

File `SRC/MODEL/mul2_laminations.for`.

Material assignments and orientations.

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_LAMINATIONS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `LAMINATION_CONSTANT` | `INTEGER(I4)` | `1_I4` |  |

Table: Derived type `LAMINATION_TYPE` — One lamination: material and orientation angles.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `KIND` | `INTEGER(I4)` | `` | `0_I4` | Record kind. |
| `MATERIAL_ID` | `INTEGER(I4)` | `` | `0_I4` | Material id. |
| `ANGLE_Y_DEG` | `REAL(R8)` | `` | `0.0_R8` | Angle about y (degrees). |
| `ANGLE_Z_DEG` | `REAL(R8)` | `` | `0.0_R8` | Angle about z (degrees). |

Table: Derived type `LAMINATION_DB_TYPE` — Lamination database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(LAMINATION_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Procedures of `MUL2_LAMINATIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `FIND_LAMINATION_INDEX` | Function → integer(i4) | public | Index of a lamination by id. |

#### `FIND_LAMINATION_INDEX`

Index of a lamination by id.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(LAMINATION_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

### MUL2_MODEL

File `SRC/MODEL/mul2_model.for`.

Complete input model: one container passed to the high-level steps.

Uses: `MUL2_KINDS`, `MUL2_ANALYSIS_INPUT`, `MUL2_KINEMATICS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_MATERIALS`, `MUL2_LAMINATIONS`, `MUL2_BOUNDARY_CONDITIONS`, `MUL2_FIELDS`, `MUL2_TIME_INPUT`.

Table: Derived type `MODEL_TYPE` — Complete input model.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `INPUT_PATH` | `CHARACTER(LEN=512)` | `` | `' '` | Input directory. |
| `ANALYSIS` | `TYPE(ANALYSIS_TYPE)` | `` | `` | Analysis data. |
| `POST` | `TYPE(POST_DB_TYPE)` | `` | `` | Post-processing data. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE)` | `` | `` | Kinematics. |
| `NODES` | `TYPE(NODE_DB_TYPE)` | `` | `` | Nodes. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE)` | `` | `` | Elements. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE)` | `` | `` | Expansion meshes. |
| `VECTORS` | `TYPE(REFERENCE_VECTOR_DB_TYPE)` | `` | `` | Versors. |
| `MATERIALS` | `TYPE(MATERIAL_DB_TYPE)` | `` | `` | Materials. |
| `LAMINATIONS` | `TYPE(LAMINATION_DB_TYPE)` | `` | `` | Laminations. |
| `BOUNDARIES` | `TYPE(BOUNDARY_DB_TYPE)` | `` | `` | Boundary conditions. |
| `FIELDS` | `TYPE(FIELD_DB_TYPE)` | `` | `` |  |
| `TIME` | `TYPE(TIME_INPUT_TYPE)` | `` | `` |  |
| `FREQ` | `TYPE(FREQ_INPUT_TYPE)` | `` | `` |  |
| `NL` | `TYPE(NL_INPUT_TYPE)` | `` | `` |  |

### MUL2_NODES

File `SRC/MODEL/mul2_nodes.for`.

Geometric node definitions.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_SORTING`.

Table: Derived type `NODE_TYPE` — One structural node.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I8)` | `` | `0_I8` | Identifier. |
| `COORDINATE` | `REAL(R8)` | `(3)` | `0.0_R8` | Coordinates. |
| `KINEMATIC_ID` | `INTEGER(I4)` | `` | `0_I4` | Kinematic id of the node. |
| `HAS_DIRECTOR` | `LOGICAL` | `` | `.FALSE.` | Exact director of a shell node (directors.dat, optional). |
| `DIRECTOR` | `REAL(R8)` | `(3)` | `0.0_R8` |  |

Table: Derived type `NODE_DB_TYPE` — Id_list/id_order are the sorted-id lookup built by build_node_index.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(NODE_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |
| `ID_LIST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Sorted node ids. |
| `ID_ORDER` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Permutation of the sorted ids. |

Table: Procedures of `MUL2_NODES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `HAS_NODE_ID` | Function → logical | public | True when a node with this id exists. |
| `FIND_NODE_INDEX` | Function → integer(i4) | public | Index of a node by id (binary search). |
| `BUILD_NODE_INDEX` | Subroutine | public | Sorted-id lookup (o(log n) search); duplicate ids are an error. |

#### `HAS_NODE_ID`

True when a node with this id exists.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ID` | `INTEGER(I8), intent(IN)` | Identifier. |

#### `FIND_NODE_INDEX`

Index of a node by id (binary search).

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ID` | `INTEGER(I8), intent(IN)` | Identifier. |

#### `BUILD_NODE_INDEX`

Sorted-id lookup (o(log n) search); duplicate ids are an error.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(INOUT)` | Structural node database. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_REFERENCE_SYSTEMS

File `SRC/MODEL/mul2_reference_systems.for`.

User reference vectors and orthonormal element frames.

Uses: `MUL2_KINDS`.

Table: Derived type `REFERENCE_VECTOR_TYPE` — One versor.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `DIRECTION` | `REAL(R8)` | `(3)` | `0.0_R8` | Direction vector. |

Table: Derived type `REFERENCE_VECTOR_DB_TYPE` — Versor database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(REFERENCE_VECTOR_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Derived type `ELEMENT_FRAME_DB_TYPE` — Origin and rotation of the local frame of every element.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ORIGIN` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Frame origin (first node). |
| `GLOBAL_TO_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Rows = local axes in global components (local = R global). |
| `LOCAL_TO_GLOBAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Transpose of GLOBAL_TO_LOCAL. |
| `GENERAL_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Curved beams and shells (general geometry): index of the element in the compact arrays below (0 = ordinary straight / flat element), the triad of every node (vectors a1, a2, a3 of a section or of a surface: see mul2_general_geometry) and the reference vector. |
| `GENERAL_TRIAD` | `REAL(R8), ALLOCATABLE` | `(:,:,:,:)` | `` |  |
| `GENERAL_REFERENCE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `GENERAL_KINK` | `INTEGER(I4), ALLOCATABLE` | `(:,:)` | `` | Shell nodes shared with elements of another normal (kinks): code 1: the first-order term is the rotation of the node; code -1: the element thickness axis is opposite to the one of the node. |

### MUL2_TIME_INPUT

File `SRC/MODEL/mul2_time_input.for`.

TIME-RESPONSE INPUT (TIME_RESP.DAT, HISTORICAL FORMAT) AND THE LOAD AMPLITUDE a(t) THAT MULTIPLIES EVERY LOAD AND PRESCRIBED VALUE. TI TF NSTEP POST_EVERY (OUTPUT EVERY N STEPS) N_SPECIFIC (EXTRA OUTPUT STEPS, ONE PER LINE) N_LOADS STEP t0 A A FOR t >= t0 IMPU t0 A A AT THE FIRST STEP t >= t0 ONLY RAMP t0 t1 A LINEAR RISE FROM 0 TO A SINU PHI OMEGA A A SIN(PHI + OMEGA t) HASU t0 F PHI2 N PHI1 A HANN-WINDOWED SINE BURST HACU t0 F PHI2 N PHI1 A HANN-WINDOWED COSINE BURST WPSU t0 F PHI2 N PHI1 A SINE BURST WITH SIN**2 WINDOW OPTIONAL RECORDS AFTER THE LOADS (ANY ORDER): NEWMARK BETA GAMMA DEFAULT 0.25 0.5 RAYLEIGH ALPHA BETA C = ALPHA M + BETA K (OVERRIDES DAMP) THETA TH THERMAL THETA-METHOD, DEFAULT 1 T0 TEMPERATURE ABSOLUTE REFERENCE TEMPERATURE: SWITCHES ON THE THERMOELASTIC HEATING TERM

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_TIME_INPUT`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `LOAD_STEP` | `INTEGER(I4)` | `1_I4` |  |
| `LOAD_RAMP` | `INTEGER(I4)` | `2_I4` |  |
| `LOAD_IMPULSE` | `INTEGER(I4)` | `3_I4` |  |
| `LOAD_SINE` | `INTEGER(I4)` | `4_I4` |  |
| `LOAD_HANN_SINE` | `INTEGER(I4)` | `5_I4` |  |
| `LOAD_HANN_COSINE` | `INTEGER(I4)` | `6_I4` |  |
| `LOAD_WINDOWED_SINE` | `INTEGER(I4)` | `7_I4` |  |

Table: Derived type `TIME_LOAD_TYPE` — component list

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `KIND` | `INTEGER(I4)` | `` | `0_I4` | Record kind. |
| `ARG` | `REAL(R8)` | `(8)` | `0.0_R8` |  |

Table: Derived type `TIME_INPUT_TYPE` — component list

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `INITIAL_TIME` | `REAL(R8)` | `` | `0.0_R8` |  |
| `FINAL_TIME` | `REAL(R8)` | `` | `0.0_R8` |  |
| `STEP_COUNT` | `INTEGER(I4)` | `` | `0_I4` |  |
| `POST_EVERY` | `INTEGER(I4)` | `` | `1_I4` |  |
| `SPECIFIC_STEP` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `LOAD` | `TYPE(TIME_LOAD_TYPE), ALLOCATABLE` | `(:)` | `` |  |
| `NEWMARK_BETA` | `REAL(R8)` | `` | `0.25_R8` |  |
| `NEWMARK_GAMMA` | `REAL(R8)` | `` | `0.5_R8` |  |
| `RAYLEIGH_MASS` | `REAL(R8)` | `` | `0.0_R8` |  |
| `RAYLEIGH_STIFFNESS` | `REAL(R8)` | `` | `0.0_R8` |  |
| `HAS_RAYLEIGH` | `LOGICAL` | `` | `.FALSE.` |  |
| `THETA` | `REAL(R8)` | `` | `1.0_R8` |  |
| `REFERENCE_TEMPERATURE` | `REAL(R8)` | `` | `0.0_R8` |  |

Table: Derived type `FREQ_INPUT_TYPE` — Freq_resp.dat: fi ff / nstep / post_every, then optional rayleigh alpha beta and t0 records (frequencies in hz).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FIRST_FREQUENCY` | `REAL(R8)` | `` | `0.0_R8` |  |
| `LAST_FREQUENCY` | `REAL(R8)` | `` | `0.0_R8` |  |
| `STEP_COUNT` | `INTEGER(I4)` | `` | `0_I4` |  |
| `POST_EVERY` | `INTEGER(I4)` | `` | `1_I4` |  |
| `RAYLEIGH_MASS` | `REAL(R8)` | `` | `0.0_R8` |  |
| `RAYLEIGH_STIFFNESS` | `REAL(R8)` | `` | `0.0_R8` |  |
| `HAS_RAYLEIGH` | `LOGICAL` | `` | `.FALSE.` |  |
| `REFERENCE_TEMPERATURE` | `REAL(R8)` | `` | `0.0_R8` |  |

Table: Derived type `NL_INPUT_TYPE` — Nl_info.dat (nonlinear static): solvtec / nlstep / itmax / toll / post_every (the first five records of the historical file). solvtec 1: load control (nlstep equal steps, lambda = n/nlstep); solvtec 2: arc length (nlstep = maximum number of steps). optional sixth record (arc length only): ds0 dsmin dsmax lambda_max; a zero ds0 / dsmin / dsmax means automatic.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `TECHNIQUE` | `INTEGER(I4)` | `` | `1_I4` |  |
| `STEP_COUNT` | `INTEGER(I4)` | `` | `10_I4` |  |
| `MAX_ITERATIONS` | `INTEGER(I4)` | `` | `30_I4` |  |
| `TOLERANCE` | `REAL(R8)` | `` | `1.0E-6_R8` |  |
| `POST_EVERY` | `INTEGER(I4)` | `` | `1_I4` |  |
| `ARC_LENGTH` | `REAL(R8)` | `` | `0.0_R8` |  |
| `ARC_LENGTH_MIN` | `REAL(R8)` | `` | `0.0_R8` |  |
| `ARC_LENGTH_MAX` | `REAL(R8)` | `` | `0.0_R8` |  |
| `LAMBDA_MAX` | `REAL(R8)` | `` | `1.0_R8` |  |

Table: Procedures of `MUL2_TIME_INPUT`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `STEP_TIME` | Function → real(r8) | public |  |
| `STEP_IS_OUTPUT` | Function → logical | public |  |
| `LOAD_AMPLITUDE` | Function → real(r8) | public | Amplitude at step i (t = step_time): sum of all the load records. the impulse is a single-step value, as in the historical code. |

#### `STEP_TIME`

| Argument | Declaration | Meaning |
|---|---|---|
| `TIME` | `TYPE(TIME_INPUT_TYPE), intent(IN)` |  |
| `STEP` | `INTEGER(I4), intent(IN)` |  |

#### `STEP_IS_OUTPUT`

| Argument | Declaration | Meaning |
|---|---|---|
| `TIME` | `TYPE(TIME_INPUT_TYPE), intent(IN)` |  |
| `STEP` | `INTEGER(I4), intent(IN)` |  |

#### `LOAD_AMPLITUDE`

Amplitude at step i (t = step_time): sum of all the load records. the impulse is a single-step value, as in the historical code.

| Argument | Declaration | Meaning |
|---|---|---|
| `TIME` | `TYPE(TIME_INPUT_TYPE), intent(IN)` |  |
| `STEP` | `INTEGER(I4), intent(IN)` |  |

### MUL2_TOPOLOGIES

File `SRC/MODEL/mul2_topologies.for`.

Single registry of supported element topologies.

Uses: `MUL2_KINDS`, `MUL2_STRINGS`, `MUL2_HLE_SHAPE`.

Table: Public constants of `MUL2_TOPOLOGIES`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `TOPOLOGY_UNKNOWN` | `INTEGER(I4)` | `0_I4` | Topology code UNKNOWN. |
| `TOPOLOGY_B2` | `INTEGER(I4)` | `101_I4` | Topology code B2. |
| `TOPOLOGY_B3` | `INTEGER(I4)` | `102_I4` | Topology code B3. |
| `TOPOLOGY_B4` | `INTEGER(I4)` | `103_I4` | Topology code B4. |
| `TOPOLOGY_Q4` | `INTEGER(I4)` | `201_I4` | Topology code Q4. |
| `TOPOLOGY_Q9` | `INTEGER(I4)` | `202_I4` | Topology code Q9. |
| `TOPOLOGY_Q16` | `INTEGER(I4)` | `203_I4` | Topology code Q16. |
| `TOPOLOGY_T3` | `INTEGER(I4)` | `204_I4` | Topology code T3. |
| `TOPOLOGY_T6` | `INTEGER(I4)` | `205_I4` | Topology code T6. |
| `TOPOLOGY_H8` | `INTEGER(I4)` | `301_I4` | Topology code H8. |
| `TOPOLOGY_H20` | `INTEGER(I4)` | `302_I4` | Topology code H20. |
| `TOPOLOGY_H27` | `INTEGER(I4)` | `303_I4` | Topology code H27. |
| `TOPOLOGY_T4` | `INTEGER(I4)` | `304_I4` | Topology code T4. |
| `TOPOLOGY_T10` | `INTEGER(I4)` | `305_I4` | Topology code T10. |
| `TOPOLOGY_P6` | `INTEGER(I4)` | `306_I4` | Topology code P6. |
| `TOPOLOGY_S1` | `INTEGER(I4)` | `401_I4` | Topology code S1. |
| `TOPOLOGY_HB_BASE` | `INTEGER(I4)` | `1100_I4` | Hle sub-elements: base + polynomial order p (1..99). the base value itself is the family name before the order is known. |
| `TOPOLOGY_HQ_BASE` | `INTEGER(I4)` | `2100_I4` | Topology code HQ_BASE. |

Table: Procedures of `MUL2_TOPOLOGIES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `TOPOLOGY_FROM_NAME` | Function → integer(i4) | public | Topology code from the name in the input (B2, Q9, H27, ...). |
| `TOPOLOGY_NODE_COUNT` | Function → integer(i4) | public | Number of nodes of a topology. |
| `TOPOLOGY_NATURAL_DIMENSION` | Function → integer(i4) | public | Natural dimension 0..3 of a topology. |
| `TOPOLOGY_FUNCTION_COUNT` | Function → integer(i4) | public | Number of shape functions (nodes for lagrange elements, modes for hle sub-elements). |
| `TOPOLOGY_IS_HLE` | Function → logical | public | True for a hle sub-element of a defined order. |
| `TOPOLOGY_IS_HLE_FAMILY` | Function → logical | public | True for the family name alone (order not yet read). |
| `TOPOLOGY_HLE_ORDER` | Function → integer(i4) | public |  |

#### `TOPOLOGY_FROM_NAME`

Topology code from the name in the input (B2, Q9, H27, ...).

| Argument | Declaration | Meaning |
|---|---|---|
| `NAME` | `CHARACTER(LEN=*), intent(IN)` | Name. |

#### `TOPOLOGY_NODE_COUNT`

Number of nodes of a topology.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `TOPOLOGY_NATURAL_DIMENSION`

Natural dimension 0..3 of a topology.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `TOPOLOGY_FUNCTION_COUNT`

Number of shape functions (nodes for lagrange elements, modes for hle sub-elements).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `TOPOLOGY_IS_HLE`

True for a hle sub-element of a defined order.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `TOPOLOGY_IS_HLE_FAMILY`

True for the family name alone (order not yet read).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `TOPOLOGY_HLE_ORDER`

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

## Layer IO {#sec:ref_io}

Readers of the legacy input files and assembly of the complete model.

### MUL2_TEXT_IO

File `SRC/IO/mul2_text_io.for`.

Shared text-input utilities.

Table: Procedures of `MUL2_TEXT_IO`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `NEXT_DATA_LINE` | Subroutine | public | Next non-blank, non-comment line of a text file. |

#### `NEXT_DATA_LINE`

Next non-blank, non-comment line of a text file.

| Argument | Declaration | Meaning |
|---|---|---|
| `UNIT` | `INTEGER, intent(IN)` | Fortran unit number. |
| `LINE` | `CHARACTER(LEN=*), intent(OUT)` | Text line. |
| `IOS` | `INTEGER, intent(OUT)` | I/O status. |

### MUL2_READ_ANALYSIS

File `SRC/IO/read_analysis.for`.

Analysis.dat and postprocessing.dat readers (legacy formats).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_ANALYSIS_INPUT`.

Table: Procedures of `MUL2_READ_ANALYSIS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_ANALYSIS_FILE` | Subroutine | public | Record order: solution id, number of modes and the shear treatments (none, redi, seli, mitc) of beam, plate and solid elements. the obsolete solver record of the historical format (a second integer between the solution id and the number of modes) is recognised and ignored with a warning. |
| `READ_JOIN_RECORD` | Subroutine | private | `join coincident [tolerance]`: the dofs of different nodes that are the same field at the same point are joined (tolerance: fraction of the diagonal of the model, default 1e-6). |
| `READ_FIELD_RECORD` | Subroutine | private | `fields mech thermo piezo`: the active physics. mech (displacements) is always solved; `stress` (mixed rmvt elements) is reserved. |
| `READ_POSTPROCESSING_FILE` | Subroutine | public | First record: number of requests. then `para`/`gmsh` field outputs, `pnt` point outputs and the matrix dumps `kmat mmat frce unkn enrg`. |

#### `READ_ANALYSIS_FILE`

Record order: solution id, number of modes and the shear treatments (none, redi, seli, mitc) of beam, plate and solid elements. the obsolete solver record of the historical format (a second integer between the solution id and the number of modes) is recognised and ignored with a warning.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `ANALYSIS` | `TYPE(ANALYSIS_TYPE), intent(OUT)` | Output: content of ANALYSIS.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `READ_POSTPROCESSING_FILE`

First record: number of requests. then `para`/`gmsh` field outputs, `pnt` point outputs and the matrix dumps `kmat mmat frce unkn enrg`.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `POST` | `TYPE(POST_DB_TYPE), intent(INOUT)` | Output: content of POSTPROCESSING.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_BOUNDARY_CONDITIONS

File `SRC/IO/read_boundary_conditions.for`.

Reader for the first mechanical 101/103 boundary-condition gate.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_BOUNDARY_CONDITIONS`.

Table: Procedures of `MUL2_READ_BOUNDARY_CONDITIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_BOUNDARY_CONDITIONS_FILE` | Subroutine | public | Read BC.dat (D-PLANE and F-POINT). |
| `READ_FIELD_ID` | Subroutine | private | A record of a value may end with a field number (fields.dat): the record is read again with one more item; if it is not there nothing changes. |
| `PARSE_COMPONENTS` | Subroutine | private | Parse three displacement tokens; N means free. |

#### `READ_BOUNDARY_CONDITIONS_FILE`

Read BC.dat (D-PLANE and F-POINT).

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `DATABASE` | `TYPE(BOUNDARY_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_CONNECTIVITY

File `SRC/IO/read_connectivity.for`.

Connectivity.dat reader.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_SORTING`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_TOPOLOGIES`.

Table: Procedures of `MUL2_READ_CONNECTIVITY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_CONNECTIVITY_FILE` | Subroutine | public | Read CONNECTIVITY.dat: topology, node ids, versor and expansion mesh of every element. |
| `ALIAS_NAME` | Subroutine | private | S4 s9 s16 are the q4 q9 q16 plate topologies and cb2 cb3 cb4 the b2 b3 b4 beam topologies, with the general (curved) geometry forced. |

#### `READ_CONNECTIVITY_FILE`

Read CONNECTIVITY.dat: topology, node ids, versor and expansion mesh of every element.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(INOUT)` | Structural element database. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_DIRECTORS

File `SRC/IO/read_directors.for`.

Reader of directors.dat (optional file). exact directors (normals) of the shell nodes, when the geometry is known (cad, analytic surface). without the file, or for the nodes that are not listed, the director is the average of the normals of the elements that share the node. n_directors node_id vx vy vz (n_directors lines, not normalised)

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_NODES`.

Table: Procedures of `MUL2_READ_DIRECTORS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_DIRECTORS_FILE` | Subroutine | public |  |

#### `READ_DIRECTORS_FILE`

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(INOUT)` | Structural node database. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_EXPANSIONS

File `SRC/IO/read_expansions.for`.

Read exp_mesh_nn.dat and exp_conn_nn.dat files.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_TOPOLOGIES`, `MUL2_HLE_MODES`, `MUL2_EXPANSION_MESHES`.

Table: Procedures of `MUL2_READ_EXPANSIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_EXPANSION_FILES` | Subroutine | public | Read one EXP_MESH / EXP_CONN pair. |
| `READ_EXPANSION_SET` | Subroutine | public | Read all expansion meshes EXP_*_01 ... NN. |
| `READ_EXPANSION_NODES` | Subroutine | private | Read EXP_MESH_nn.dat. |
| `READ_EXPANSION_ELEMENTS` | Subroutine | private | Read EXP_CONN_nn.dat. |
| `DUPLICATE_NODE_ID` | Function → logical | private | True when an id appears twice. |
| `DUPLICATE_ELEMENT_ID` | Function → logical | private | True when an id appears twice. |

#### `READ_EXPANSION_FILES`

Read one EXP_MESH / EXP_CONN pair.

| Argument | Declaration | Meaning |
|---|---|---|
| `MESH_FILE` | `CHARACTER(LEN=*), intent(IN)` | Path of EXP_MESH_nn.dat. |
| `CONNECTIVITY_FILE` | `CHARACTER(LEN=*), intent(IN)` | Path of EXP_CONN_nn.dat. |
| `EXPANSION_ID` | `INTEGER(I4), intent(IN)` | Id given to the mesh (index nn of the file). |
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(INOUT)` | Expansion mesh. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `READ_EXPANSION_SET`

Read all expansion meshes EXP_*_01 ... NN.

| Argument | Declaration | Meaning |
|---|---|---|
| `PATH` | `CHARACTER(LEN=*), intent(IN)` | Input directory. |
| `COUNT` | `INTEGER(I4), intent(IN)` | Number of items. |
| `DATABASE` | `TYPE(EXPANSION_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_FIELDS

File `SRC/IO/read_fields.for`.

Reader of fields.dat (optional file). n_fields field id n_terms term c1 [c2 ...] (n_terms lines) ...

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_FIELDS`.

Table: Procedures of `MUL2_READ_FIELDS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_FIELDS_FILE` | Subroutine | public |  |

#### `READ_FIELDS_FILE`

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `DATABASE` | `TYPE(FIELD_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_KINEMATICS

File `SRC/IO/read_kinematics.for`.

Kinematics.dat reader.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_KINEMATICS`.

Table: Procedures of `MUL2_READ_KINEMATICS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_KINEMATICS_FILE` | Subroutine | public | Read KINEMATICS.dat (field-dependent expansions). |
| `DUPLICATE_ID` | Function → logical | private | True when an id appears twice. |

#### `READ_KINEMATICS_FILE`

Read KINEMATICS.dat (field-dependent expansions).

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `DATABASE` | `TYPE(KINEMATICS_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_LAMINATIONS

File `SRC/IO/read_laminations.for`.

Lamination.dat reader. first gate supports constant lam2 records.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_STRINGS`, `MUL2_MATERIALS`, `MUL2_LAMINATIONS`.

Table: Procedures of `MUL2_READ_LAMINATIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_LAMINATIONS_FILE` | Subroutine | public | Read LAMINATION.dat (LAM2 records). |

#### `READ_LAMINATIONS_FILE`

Read LAMINATION.dat (LAM2 records).

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `MATERIALS` | `TYPE(MATERIAL_DB_TYPE), intent(IN)` | Material database. |
| `DATABASE` | `TYPE(LAMINATION_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_LEGACY_NODES

File `SRC/IO/read_legacy_nodes.for`.

Adapter for the historical nodes.dat (id x y z model [order]). the historical file has no kinematics.dat. each distinct (model, order) pair becomes one kinematic with the same expansion for u, v and w and no other active field. le ignores the order column. only the models implemented by v3 (te, le) are accepted.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_KINEMATICS`, `MUL2_NODES`.

Table: Procedures of `MUL2_READ_LEGACY_NODES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_LEGACY_NODES_FILE` | Subroutine | public | Read the historical NODES.dat (TE/LE token) and create the kinematics. |
| `REGISTER_KINEMATIC` | Function → integer(i4) | private | Return the id of the (family, order) kinematic, creating it if new. |

#### `READ_LEGACY_NODES_FILE`

Read the historical NODES.dat (TE/LE token) and create the kinematics.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(INOUT)` | Field-dependent kinematics database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(INOUT)` | Structural node database. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_MATERIALS

File `SRC/IO/read_materials.for`.

Legacy-compatible material.dat reader for mechanical materials.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_STRINGS`, `MUL2_MATERIALS`.

Table: Procedures of `MUL2_READ_MATERIALS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_MATERIALS_FILE` | Subroutine | public | Read MATERIAL.dat (ISO-M, ORT-M, MAT-C; other records are accepted and ignored). |
| `STORE_MATERIAL` | Subroutine | private | Validate and store one material record. |

#### `READ_MATERIALS_FILE`

Read MATERIAL.dat (ISO-M, ORT-M, MAT-C; other records are accepted and ignored).

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `DATABASE` | `TYPE(MATERIAL_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_MODEL

File `SRC/IO/read_model.for`.

READ A COMPLETE INPUT DIRECTORY INTO ONE MODEL. THE DIRECTORY FOLLOWS THE HISTORICAL LAYOUT (ANALYSIS, NODES, CONNECTIVITY, EXP_MESH_NN, EXP_CONN_NN, MATERIAL, LAMINATION, VERSORS, BC, POSTPROCESSING). IF `KINEMATICS.dat` IS PRESENT THE V3 NODES.dat (WITH KINEMATIC_ID) IS EXPECTED, OTHERWISE THE HISTORICAL NODES.dat IS CONVERTED BY MUL2_READ_LEGACY_NODES.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_KINEMATICS`, `MUL2_MODEL`, `MUL2_READ_ANALYSIS`, `MUL2_READ_KINEMATICS`, `MUL2_READ_NODES`, `MUL2_READ_LEGACY_NODES`, `MUL2_READ_CONNECTIVITY`, `MUL2_READ_EXPANSIONS`, `MUL2_READ_REFERENCE_SYSTEMS`, `MUL2_READ_MATERIALS`, `MUL2_READ_LAMINATIONS`, `MUL2_READ_BOUNDARY_CONDITIONS`, `MUL2_READ_FIELDS`, `MUL2_READ_DIRECTORS`, `MUL2_READ_TIME`.

Table: Procedures of `MUL2_READ_MODEL`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_MODEL` | Subroutine | public | Read an input directory into one MODEL_TYPE. |
| `FILE_OF` | Function → character(len=600) | private | Full path of a file of the input directory. |

#### `READ_MODEL`

Read an input directory into one MODEL_TYPE.

| Argument | Declaration | Meaning |
|---|---|---|
| `INPUT_PATH` | `CHARACTER(LEN=*), intent(IN)` | Input directory. |
| `MODEL` | `TYPE(MODEL_TYPE), intent(INOUT)` | Complete input model (all databases). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_NODES

File `SRC/IO/read_nodes.for`.

Nodes.dat reader for the v3 format.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_KINEMATICS`, `MUL2_NODES`, `MUL2_TEXT_IO`.

Table: Procedures of `MUL2_READ_NODES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_NODES_FILE` | Subroutine | public | Read the NODES.dat that carries a kinematic id. |

#### `READ_NODES_FILE`

Read the NODES.dat that carries a kinematic id.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(INOUT)` | Structural node database. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_REFERENCE_SYSTEMS

File `SRC/IO/read_reference_systems.for`.

Versors.dat reader.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TEXT_IO`, `MUL2_STRINGS`, `MUL2_REFERENCE_SYSTEMS`.

Table: Procedures of `MUL2_READ_REFERENCE_SYSTEMS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_REFERENCE_VECTORS_FILE` | Subroutine | public | Read VERSORS.dat. |
| `DUPLICATE_ID` | Function → logical | private | True when an id appears twice. |

#### `READ_REFERENCE_VECTORS_FILE`

Read VERSORS.dat.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `DATABASE` | `TYPE(REFERENCE_VECTOR_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_READ_TIME

File `SRC/IO/read_time.for`.

Reader of time_resp.dat (see mul2_time_input for the format).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_STRINGS`, `MUL2_TEXT_IO`, `MUL2_TIME_INPUT`.

Table: Procedures of `MUL2_READ_TIME`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `READ_TIME_FILE` | Subroutine | public |  |
| `NEXT_DATA` | Subroutine | private | Next record, skipping comments and the dashed separators of the historical files. |
| `READ_FREQ_FILE` | Subroutine | public | Freq_resp.dat. |
| `READ_NL_FILE` | Subroutine | public | Nl_info.dat: five records (solvtec 1 = load control, 2 = arc length) and an optional sixth one ds0 dsmin dsmax lambda_max for the arc length. anything else of the historical file is unused. |

#### `READ_TIME_FILE`

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `TIME` | `TYPE(TIME_INPUT_TYPE), intent(OUT)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `READ_FREQ_FILE`

Freq_resp.dat.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `FREQ` | `TYPE(FREQ_INPUT_TYPE), intent(OUT)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `READ_NL_FILE`

Nl_info.dat: five records (solvtec 1 = load control, 2 = arc length) and an optional sixth one ds0 dsmin dsmax lambda_max for the arc length. anything else of the historical file is unused.

| Argument | Declaration | Meaning |
|---|---|---|
| `FILE_NAME` | `CHARACTER(LEN=*), intent(IN)` | Path of the file. |
| `NL` | `TYPE(NL_INPUT_TYPE), intent(OUT)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer QUADRATURE {#sec:ref_quadrature}

Gauss–Legendre and triangle rules.

### MUL2_QUADRATURE

File `SRC/QUADRATURE/mul2_quadrature.for`.

Reference-element gauss quadrature rules.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TOPOLOGIES`.

Table: Derived type `QUADRATURE_RULE_TYPE` — Points and weights of a quadrature rule.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `NATURAL_DIMENSION` | `INTEGER(I4)` | `` | `0_I4` | Natural dimension. |
| `COORDINATE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Coordinates. |
| `WEIGHT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Weights. |

Table: Procedures of `MUL2_QUADRATURE`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `REDUCED_POINTS_PER_DIRECTION` | Function → integer(i4) | public | Gauss points per direction of the reduced rule of a structural element (one less than the full rule, as in the baseline: redi and seli). 0 = no reduced rule (triangles and any other topology). |
| `BUILD_REDUCED_QUADRATURE` | Subroutine | public |  |
| `BUILD_DEFAULT_QUADRATURE` | Subroutine | public | Default Gauss rule of a topology. |
| `DEFAULT_POINTS_PER_DIRECTION` | Function → integer(i4) | public | Gauss points per direction of the default rule (0 = not tensor). |
| `BUILD_ORDERED_QUADRATURE` | Subroutine | public | Tensor rule with order points per direction (lines and quadrilaterals). used for high-order taylor expansions, whose integrands are polynomials of degree 2*n. |
| `BUILD_LINE_RULE` | Subroutine | private | Gauss-Legendre rule on [-1,1]. |
| `BUILD_TENSOR_RULE` | Subroutine | private | Tensor product rule on [-1,1]^d. |
| `BUILD_TRIANGLE_RULE` | Subroutine | private | Triangle rule (1 or 3 points). |
| `GAUSS_LEGENDRE_1D` | Subroutine | private | Gauss-Legendre points and weights (closed form up to 4, Newton on the Legendre polynomial above). |
| `CLEAR_RULE` | Subroutine | private | Release a quadrature rule. |

#### `REDUCED_POINTS_PER_DIRECTION`

Gauss points per direction of the reduced rule of a structural element (one less than the full rule, as in the baseline: redi and seli). 0 = no reduced rule (triangles and any other topology).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `BUILD_REDUCED_QUADRATURE`

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `RULE` | `TYPE(QUADRATURE_RULE_TYPE), intent(INOUT)` | Output: quadrature rule. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_DEFAULT_QUADRATURE`

Default Gauss rule of a topology.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `RULE` | `TYPE(QUADRATURE_RULE_TYPE), intent(INOUT)` | Output: quadrature rule. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `DEFAULT_POINTS_PER_DIRECTION`

Gauss points per direction of the default rule (0 = not tensor).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `BUILD_ORDERED_QUADRATURE`

Tensor rule with order points per direction (lines and quadrilaterals). used for high-order taylor expansions, whose integrands are polynomials of degree 2*n.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `ORDER` | `INTEGER(I4), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `RULE` | `TYPE(QUADRATURE_RULE_TYPE), intent(INOUT)` | Output: quadrature rule. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer FEM {#sec:ref_fem}

Shape functions and natural derivatives of every topology.

### MUL2_HLE_MAP

File `SRC/FEM/mul2_hle_map.for`.

Blending-function map of a hle quadrilateral with curved sides. the sides of a sub-element are straight unless a third point on the side is given: the side is then the circular arc through its two vertices and that point, parameterised by its angle (exact circle, no geometric approximation error). the map is the transfinite (gordon-hall) interpolation of the paper (eqs. 20-25): q(r,s) = sum_i n_i(r,s) x_i + sum_e beta_e(r,s) (c_e(t) - l_e(t)) n_i are the bilinear vertex functions, l_e the straight side, c_e the arc, t the natural coordinate along the side and beta_e the linear blending function (1 on side e, 0 on the opposite one). the functions of the expansion are not the map: the element is not isoparametric.

Uses: `MUL2_KINDS`, `MUL2_HLE_SHAPE`.

Table: Derived type `HLE_GEOMETRY_TYPE` — component list

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ANY_CURVED` | `LOGICAL` | `` | `.FALSE.` |  |
| `CURVED` | `LOGICAL` | `(4)` | `.FALSE.` |  |
| `VERTEX` | `REAL(R8)` | `(2,4)` | `0.0_R8` |  |
| `CENTER` | `REAL(R8)` | `(2,4)` | `0.0_R8` |  |
| `RADIUS` | `REAL(R8)` | `(4)` | `0.0_R8` |  |
| `THETA0` | `REAL(R8)` | `(4)` | `0.0_R8` |  |
| `DTHETA` | `REAL(R8)` | `(4)` | `0.0_R8` |  |

Table: Procedures of `MUL2_HLE_MAP`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `HLE_GEOMETRY_SETUP` | Subroutine | public | Vertex(2,4): vertices in the active plane; mid(2,4) and has_mid(4): third point of each side. |
| `HLE_MAP_EVALUATE` | Subroutine | public | X(2) and dx(:,1) = dx/dr, dx(:,2) = dx/ds at the natural point (r,s). |

#### `HLE_GEOMETRY_SETUP`

Vertex(2,4): vertices in the active plane; mid(2,4) and has_mid(4): third point of each side.

| Argument | Declaration | Meaning |
|---|---|---|
| `VERTEX` | `REAL(R8), intent(IN)(2,4)` |  |
| `MID` | `REAL(R8), intent(IN)(2,4)` |  |
| `HAS_MID` | `LOGICAL, intent(IN)(4)` |  |
| `GEOMETRY` | `TYPE(HLE_GEOMETRY_TYPE), intent(OUT)` | Combined Gauss geometry (coordinates, weights). |

#### `HLE_MAP_EVALUATE`

X(2) and dx(:,1) = dx/dr, dx(:,2) = dx/ds at the natural point (r,s).

| Argument | Declaration | Meaning |
|---|---|---|
| `GEOMETRY` | `TYPE(HLE_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `R` | `REAL(R8), intent(IN)` |  |
| `S` | `REAL(R8), intent(IN)` |  |
| `X` | `REAL(R8), intent(OUT)(2)` | Vector or coordinate. |
| `DX` | `REAL(R8), intent(OUT)(2,2)` |  |

### MUL2_HLE_SHAPE

File `SRC/FEM/mul2_hle_shape.for`.

Hierarchical legendre expansion (hle) functions of one sub-element. the functions are the ones of pagani, garcia de miguel, carrera (comput mech 2017) and of the p-version finite element method (szabo and babuska): the trunk space of degree p. quadrilateral (natural r,s in [-1,1], vertices 1(-1,-1) 2(1,-1) 3(1,1) 4(-1,1)): vertex 1/4 (1+rt r)(1+st s) 4 functions side k 1/2 (1-s) phi_k(r) side 1 (vertex 1 -> 2) 1/2 (1+r) phi_k(s) side 2 (vertex 2 -> 3) 1/2 (1+s) phi_k(r) side 3 (vertex 4 -> 3) 1/2 (1-r) phi_k(s) side 4 (vertex 1 -> 4) 4 (p-1) functions, k = 2..p internal phi_i(r) phi_j(s), i,j >= 2, i+j <= p (p-2)(p-3)/2 functions (p >= 4) line (natural r in [-1,1]): vertex 1/2 (1-r), 1/2 (1+r); internal phi_k(r), k = 2..p phi_k(x) = sqrt((2k-1)/2) integral(-1,x) l_(k-1) (k >= 2) local order (the numbering of the paper): the vertices; then, for each k = 2..p, the four sides of order k followed (k >= 4) by the internal pairs (i,j) with i+j = k, i descending.

Uses: `MUL2_KINDS`.

Table: Public constants of `MUL2_HLE_SHAPE`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `HLE_VERTEX` | `INTEGER(I4)` | `1_I4` |  |
| `HLE_SIDE` | `INTEGER(I4)` | `2_I4` |  |
| `HLE_INTERNAL` | `INTEGER(I4)` | `3_I4` |  |

Table: Procedures of `MUL2_HLE_SHAPE`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `HLE_FUNCTION_COUNT` | Function → integer(i4) | public |  |
| `HLE_SIDE_ENDS` | Subroutine | public | Start and end vertex of a side along its natural direction. |
| `HLE_MODE_LIST` | Subroutine | public | Kind(l), a(l), b(l) of every local function: vertex a = vertex side a = side, b = order k internal a = i, b = j (quadrilateral); a = k (line) |
| `HLE_PHI` | Subroutine | public | Phi_k and its derivative for k = 2..kmax. |
| `EVALUATE_HLE_SHAPE` | Subroutine | public |  |

#### `HLE_FUNCTION_COUNT`

| Argument | Declaration | Meaning |
|---|---|---|
| `QUAD` | `LOGICAL, intent(IN)` |  |
| `P` | `INTEGER(I4), intent(IN)` |  |

#### `HLE_SIDE_ENDS`

Start and end vertex of a side along its natural direction.

| Argument | Declaration | Meaning |
|---|---|---|
| `SIDE` | `INTEGER(I4), intent(IN)` |  |
| `START` | `INTEGER(I4), intent(OUT)` |  |
| `FINISH` | `INTEGER(I4), intent(OUT)` |  |

#### `HLE_MODE_LIST`

Kind(l), a(l), b(l) of every local function: vertex a = vertex side a = side, b = order k internal a = i, b = j (quadrilateral); a = k (line)

| Argument | Declaration | Meaning |
|---|---|---|
| `QUAD` | `LOGICAL, intent(IN)` |  |
| `P` | `INTEGER(I4), intent(IN)` |  |
| `KIND` | `INTEGER(I4), intent(OUT)(:)` |  |
| `A` | `INTEGER(I4), intent(OUT)(:)` | Matrix or operand A. |
| `B` | `INTEGER(I4), intent(OUT)(:)` | Matrix or operand B. |

#### `HLE_PHI`

Phi_k and its derivative for k = 2..kmax.

| Argument | Declaration | Meaning |
|---|---|---|
| `KMAX` | `INTEGER(I4), intent(IN)` |  |
| `X` | `REAL(R8), intent(IN)` | Vector or coordinate. |
| `PHI` | `REAL(R8), intent(OUT)(:)` |  |
| `DPHI` | `REAL(R8), intent(OUT)(:)` |  |

#### `EVALUATE_HLE_SHAPE`

| Argument | Declaration | Meaning |
|---|---|---|
| `QUAD` | `LOGICAL, intent(IN)` |  |
| `P` | `INTEGER(I4), intent(IN)` |  |
| `X` | `REAL(R8), intent(IN)(:)` | Vector or coordinate. |
| `N` | `REAL(R8), intent(OUT)(:)` | Shape function values. |
| `DN` | `REAL(R8), intent(OUT)(:,:)` | Shape derivatives. |

### MUL2_SHAPE_FUNCTIONS

File `SRC/FEM/mul2_shape_functions.for`.

Shape functions and natural derivatives.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TOPOLOGIES`, `MUL2_HLE_SHAPE`.

Table: Procedures of `MUL2_SHAPE_FUNCTIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `EVALUATE_SHAPE` | Subroutine | public | Shape functions and natural derivatives of a topology at a natural point. |
| `SHAPE_B` | Subroutine | private | Lagrange line shapes (B2, B3, B4). |
| `SHAPE_Q4` | Subroutine | private | Bilinear quadrilateral. |
| `SHAPE_Q9` | Subroutine | private | Biquadratic quadrilateral. |
| `SHAPE_Q16` | Subroutine | private | Bicubic quadrilateral. |
| `SHAPE_T3` | Subroutine | private | Linear triangle. |
| `SHAPE_T6` | Subroutine | private | Quadratic triangle. |
| `SHAPE_H8` | Subroutine | private | Trilinear hexahedron. |
| `SHAPE_H27` | Subroutine | private | Triquadratic hexahedron. |
| `TENSOR_2D` | Subroutine | private | Tensor product of 1D Lagrange functions on a quadrilateral. |
| `TENSOR_3D` | Subroutine | private | Tensor product of 1D Lagrange functions on a hexahedron. |
| `LAGRANGE_1D` | Subroutine | private | 1D Lagrange polynomial and derivative of given order and node index. |

#### `EVALUATE_SHAPE`

Shape functions and natural derivatives of a topology at a natural point.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `NATURAL` | `REAL(R8), intent(IN)(:)` | Natural coordinates (xi, eta, nu). |
| `N` | `REAL(R8), intent(OUT)(:)` | Output: shape function values. |
| `DN_DNATURAL` | `REAL(R8), intent(OUT)(:,:)` | Derivatives with respect to natural coordinates. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer GEOMETRY {#sec:ref_geometry}

Element reference frames, Jacobians and local-frame gradients.

### MUL2_ELEMENT_FRAMES

File `SRC/GEOMETRY/mul2_element_frames.for`.

Construction of right-handed element reference systems.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_TOPOLOGIES`.

Table: Procedures of `MUL2_ELEMENT_FRAMES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_ELEMENT_FRAMES` | Subroutine | public | Right-handed local frame of every element from node coordinates and the versor. |
| `BUILD_BEAM_FRAME` | Subroutine | private | Beam frame: y along the axis, z from the versor orthogonalised, x = y x z. |
| `BUILD_SURFACE_FRAME` | Subroutine | private | Plate frame: z normal to the surface, x from the projected versor, y = z x x. |
| `NORMALIZE` | Subroutine | private | Normalise a vector, error if its length is (almost) zero. |
| `CROSS_PRODUCT` | Function | private | Vector product. |
| `FIND_VECTOR_INDEX` | Function → integer(i4) | private | Index of a versor by id. |
| `SET_IDENTITY` | Subroutine | private | Identity 3x3 matrix. |
| `CLEAR_FRAMES` | Subroutine | private | Release the frame arrays. |

#### `BUILD_ELEMENT_FRAMES`

Right-handed local frame of every element from node coordinates and the versor.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `REFERENCE_VECTORS` | `TYPE(REFERENCE_VECTOR_DB_TYPE), intent(IN)` | Versor database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(INOUT)` | Element reference frames. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_GENERAL_GEOMETRY

File `SRC/GEOMETRY/mul2_general_geometry.for`.

General (curved) geometry of beams and shells. an ordinary element has one local frame: a straight beam or a flat plate. an element with the general geometry (a curved beam, a shell) carries a triad a1, a2, a3 at every node and the map from the natural coordinates to space is x(xi,c) = sum_i n_i(xi) [ x_i + c1 a1_i + c2 a2_i + c3 a3_i ] where c is the position of a point of the expansion mesh (the section of a beam, the thickness of a shell, in physical lengths). the triad beam: a1 = a2 x a3, a2 = tangent of the axis, a3 = reference vector (sor) projected on the normal plane; shell: a3 = director (normal), a1 = sor projected on the tangent plane, a2 = a3 x a1 (the frame of a flat plate). the tangents and the directors are averaged over the elements that share a node (only the ones within the feature angle, so a true edge keeps one director per side), which makes the geometry continuous. the thickness comes from the expansion mesh, as for the plates. an element is general when its name says so (s4 s9 s16 cb2 cb3 cb4) or when its nodes are not on a line (b2 b3 b4) or in a plane (q4 q9 q16).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_TOPOLOGIES`, `MUL2_SHAPE_FUNCTIONS`.

Table: Procedures of `MUL2_GENERAL_GEOMETRY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `IS_GENERAL_ELEMENT` | Function → logical | public |  |
| `GENERAL_NODE_NATURAL` | Subroutine | public | Natural coordinates of node j of a beam (1 value) or plate (2 values) topology, in the order of the shape functions. |
| `GENERAL_MAP` | Subroutine | public | Position x and jacobian rows g(a,:) = d x / d t_a of the map, with t = (structural natural coordinates, active expansion coordinates). ds number of structural coordinates (1 beam, 2 shell) coord nodal coordinates (3,n); triad nodal triads (3,3,n) n, dn shape values and derivatives (n, ds) c position in the expansion mesh (3), axis its active axes |
| `GENERAL_FRAME` | Subroutine | public | Frame rows (e1; e2; e3) = global_to_local at a point, with the same rules as the ordinary frames: a beam has e2 along the axis (tangent of the axis curve, c = 0) and e3 from the reference vector, a shell has e3 normal to the coordinate surface and e1 from the reference vector. |
| `GENERAL_OFFSET` | Subroutine | public | Offset of an expansion point c from the node, in global components (the equivalent of local_to_global * c of an ordinary element). |
| `BUILD_GENERAL_GEOMETRY` | Subroutine | public | Finds the general elements and builds the nodal triads. |
| `IS_CURVED` | Function → logical | private | True when the nodes are not on the line of a beam / in the plane of a plate. |
| `FIND_VECTOR` | Function → integer(i4) | private |  |
| `UNIT_VECTOR` | Subroutine | private |  |
| `CROSS` | Function | private |  |
| `ITOA` | Function | private |  |

#### `IS_GENERAL_ELEMENT`

| Argument | Declaration | Meaning |
|---|---|---|
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `ELEMENT` | `INTEGER(I4), intent(IN)` | Element index. |

#### `GENERAL_NODE_NATURAL`

Natural coordinates of node j of a beam (1 value) or plate (2 values) topology, in the order of the shape functions.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `J` | `INTEGER(I4), intent(IN)` |  |
| `XI` | `REAL(R8), intent(OUT)(2)` |  |

#### `GENERAL_MAP`

Position x and jacobian rows g(a,:) = d x / d t_a of the map, with t = (structural natural coordinates, active expansion coordinates). ds number of structural coordinates (1 beam, 2 shell) coord nodal coordinates (3,n); triad nodal triads (3,3,n) n, dn shape values and derivatives (n, ds) c position in the expansion mesh (3), axis its active axes

| Argument | Declaration | Meaning |
|---|---|---|
| `DS` | `INTEGER(I4), intent(IN)` |  |
| `N_NODE` | `INTEGER(I4), intent(IN)` |  |
| `COORD` | `REAL(R8), intent(IN)(:,:)` |  |
| `TRIAD` | `REAL(R8), intent(IN)(:,:,:)` |  |
| `N` | `REAL(R8), intent(IN)(:)` | Shape function values. |
| `DN` | `REAL(R8), intent(IN)(:,:)` | Shape derivatives. |
| `C` | `REAL(R8), intent(IN)(3)` |  |
| `AXIS` | `INTEGER(I4), intent(IN)(:)` | Active local axes. |
| `X` | `REAL(R8), intent(OUT)(3)` | Vector or coordinate. |
| `G` | `REAL(R8), intent(OUT)(3,3)` |  |

#### `GENERAL_FRAME`

Frame rows (e1; e2; e3) = global_to_local at a point, with the same rules as the ordinary frames: a beam has e2 along the axis (tangent of the axis curve, c = 0) and e3 from the reference vector, a shell has e3 normal to the coordinate surface and e1 from the reference vector.

| Argument | Declaration | Meaning |
|---|---|---|
| `DS` | `INTEGER(I4), intent(IN)` |  |
| `N_NODE` | `INTEGER(I4), intent(IN)` |  |
| `COORD` | `REAL(R8), intent(IN)(:,:)` |  |
| `DN` | `REAL(R8), intent(IN)(:,:)` | Shape derivatives. |
| `G` | `REAL(R8), intent(IN)(3,3)` |  |
| `REFERENCE` | `REAL(R8), intent(IN)(3)` |  |
| `R` | `REAL(R8), intent(OUT)(3,3)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `GENERAL_OFFSET`

Offset of an expansion point c from the node, in global components (the equivalent of local_to_global * c of an ordinary element).

| Argument | Declaration | Meaning |
|---|---|---|
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `ELEMENT` | `INTEGER(I4), intent(IN)` | Element index. |
| `LOCAL_NODE` | `INTEGER(I4), intent(IN)` | Local structural node index. |
| `C` | `REAL(R8), intent(IN)(3)` |  |
| `OFFSET` | `REAL(R8), intent(OUT)(3)` |  |

#### `BUILD_GENERAL_GEOMETRY`

Finds the general elements and builds the nodal triads.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `VECTORS` | `TYPE(REFERENCE_VECTOR_DB_TYPE), intent(IN)` | DOF vectors (e.g. mode shapes), one per column. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(INOUT)` | Element reference frames. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_JACOBIANS

File `SRC/GEOMETRY/mul2_jacobians.for`.

Square isoparametric jacobian and derivative transformation.

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Procedures of `MUL2_JACOBIANS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `EVALUATE_SQUARE_JACOBIAN` | Subroutine | public | Jacobian, determinant, inverse and physical derivatives for a square mapping of dimension 1, 2 or 3. |
| `INVERT_SMALL_MATRIX` | Subroutine | private | Invert a 1x1, 2x2 or 3x3 matrix. |

#### `EVALUATE_SQUARE_JACOBIAN`

Jacobian, determinant, inverse and physical derivatives for a square mapping of dimension 1, 2 or 3.

| Argument | Declaration | Meaning |
|---|---|---|
| `COORDINATE` | `REAL(R8), intent(IN)(:,:)` | Coordinates. |
| `DN_DNATURAL` | `REAL(R8), intent(IN)(:,:)` | Derivatives with respect to natural coordinates. |
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |
| `JACOBIAN` | `REAL(R8), intent(OUT)(:,:)` | Output: Jacobian matrix. |
| `DETERMINANT` | `REAL(R8), intent(OUT)` | Output: determinant of the Jacobian. |
| `INVERSE_JACOBIAN` | `REAL(R8), intent(OUT)(:,:)` | Output: inverse Jacobian. |
| `DN_DPHYSICAL` | `REAL(R8), intent(OUT)(:,:)` | Output: shape derivatives with respect to the physical coordinates. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_LOCAL_GRADIENTS

File `SRC/GEOMETRY/mul2_local_gradients.for`.

Local-frame gradients of the shape functions of one element. the element lives in its active local axes (beam: axis 2; plate: axes 1,2; solid and expansion elements: their own axes). the jacobian is square in those axes; the gradient is embedded back into the three local coordinates (inactive components are zero).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TOPOLOGIES`, `MUL2_SHAPE_FUNCTIONS`, `MUL2_JACOBIANS`.

Table: Procedures of `MUL2_LOCAL_GRADIENTS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `STRUCTURAL_ACTIVE_AXES` | Subroutine | public | Active local axes of a structural element of given dimension. |
| `LOCAL_SHAPE_GRADIENT` | Subroutine | public | Gradient(:,i) = gradient of shape i in the local frame. |
| `EVALUATE_SHAPE_AND_GRADIENT` | Subroutine | public | Shapes and local gradients of a structural element at a natural point. node_local(:,i) is the local coordinate of node i. |

#### `STRUCTURAL_ACTIVE_AXES`

Active local axes of a structural element of given dimension.

| Argument | Declaration | Meaning |
|---|---|---|
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |
| `AXIS` | `INTEGER(I4), intent(OUT)(3)` | Active local axes. |

#### `LOCAL_SHAPE_GRADIENT`

Gradient(:,i) = gradient of shape i in the local frame.

| Argument | Declaration | Meaning |
|---|---|---|
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |
| `AXIS` | `INTEGER(I4), intent(IN)(3)` | Active local axes. |
| `COORDINATE` | `REAL(R8), intent(IN)(:,:)` | Coordinates. |
| `NATURAL_DERIVATIVE` | `REAL(R8), intent(IN)(:,:)` | Derivatives of the shapes with respect to the natural coordinates. |
| `GRADIENT` | `REAL(R8), intent(OUT)(:,:)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EVALUATE_SHAPE_AND_GRADIENT`

Shapes and local gradients of a structural element at a natural point. node_local(:,i) is the local coordinate of node i.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `NODE_LOCAL` | `REAL(R8), intent(IN)(:,:)` | Local-frame coordinates of the element nodes. |
| `NATURAL` | `REAL(R8), intent(IN)(3)` | Natural coordinates (xi, eta, nu). |
| `SHAPE` | `REAL(R8), intent(OUT)(:)` | Output: shape function values. |
| `GRADIENT` | `REAL(R8), intent(OUT)(:,:)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer CUF {#sec:ref_cuf}

Expansion bases (Taylor, Lagrange), point factors and the fundamental nucleus.

### MUL2_CUF_BASES

File `SRC/CUF/mul2_cuf_bases.for`.

Cuf expansion bases. taylor order matches the authoritative code.

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Procedures of `MUL2_CUF_BASES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `TAYLOR_BASIS_TERM_COUNT` | Function → integer(i4) | public | Number of Taylor monomials of order N in 1D (N+1) or 2D ((N+1)(N+2)/2). |
| `EVALUATE_TAYLOR_BASIS` | Subroutine | public | All Taylor monomials and their gradients at a section point. |
| `EVALUATE_TAYLOR_TERM` | Subroutine | public | One Taylor monomial x^a z^b and its gradient. |
| `INTEGER_POWER` | Function → real(r8) | private | x**n by repeated multiplication (no overflow of the generic power). |

#### `TAYLOR_BASIS_TERM_COUNT`

Number of Taylor monomials of order N in 1D (N+1) or 2D ((N+1)(N+2)/2).

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I4), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |

#### `EVALUATE_TAYLOR_BASIS`

All Taylor monomials and their gradients at a section point.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I4), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |
| `ACTIVE_AXIS` | `INTEGER(I4), intent(IN)(2)` | Active local axes of the section. |
| `COORDINATE` | `REAL(R8), intent(IN)(3)` | Coordinates. |
| `VALUE` | `REAL(R8), intent(OUT)(:)` | Value(s) (see routine). |
| `GRADIENT` | `REAL(R8), intent(OUT)(:,:)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EVALUATE_TAYLOR_TERM`

One Taylor monomial x^a z^b and its gradient.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I4), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension. |
| `ACTIVE_AXIS` | `INTEGER(I4), intent(IN)(2)` | Active local axes of the section. |
| `COORDINATE` | `REAL(R8), intent(IN)(3)` | Coordinates. |
| `TERM` | `INTEGER(I4), intent(IN)` | Expansion term index. |
| `VALUE` | `REAL(R8), intent(OUT)` | Value(s) (see routine). |
| `GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_FUNDAMENTAL_NUCLEUS

File `SRC/CUF/mul2_fundamental_nucleus.for`.

Generic linear cuf fundamental nuclei at one integration point.

Uses: `MUL2_KINDS`.

Table: Procedures of `MUL2_FUNDAMENTAL_NUCLEUS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `STIFFNESS_NUCLEUS` | Function → real(r8) | public | Scalar fundamental nucleus: weight * B_i^T C B_j. |
| `STIFFNESS_BLOCK_NUCLEUS` | Subroutine | public | 3x3 stiffness nucleus of a pair of nodes/terms. |
| `MASS_NUCLEUS` | Function → real(r8) | public | Scalar mass nucleus: rho N_i N_j weight for equal components. |
| `MASS_BLOCK_NUCLEUS` | Subroutine | public | 3x3 mass nucleus (diagonal). |
| `ROTATE_BLOCK_TO_GLOBAL` | Subroutine | public | Rotate a 3x3 block from the local to the global frame. |

#### `STIFFNESS_NUCLEUS`

Scalar fundamental nucleus: weight * B_i^T C B_j.

| Argument | Declaration | Meaning |
|---|---|---|
| `TEST_COLUMN` | `REAL(R8), intent(IN)(6)` | Strain column of the test DOF. |
| `STIFFNESS` | `REAL(R8), intent(IN)(6,6)` | Stiffness matrix (or values). |
| `TRIAL_COLUMN` | `REAL(R8), intent(IN)(6)` | Strain column of the trial DOF. |
| `INTEGRATION_WEIGHT` | `REAL(R8), intent(IN)` | Weight including the Jacobians. |

#### `STIFFNESS_BLOCK_NUCLEUS`

3x3 stiffness nucleus of a pair of nodes/terms.

| Argument | Declaration | Meaning |
|---|---|---|
| `TEST_OPERATOR` | `REAL(R8), intent(IN)(6,3)` | Strain operator of the test DOF. |
| `STIFFNESS` | `REAL(R8), intent(IN)(6,6)` | Stiffness matrix (or values). |
| `TRIAL_OPERATOR` | `REAL(R8), intent(IN)(6,3)` | Strain operator of the trial DOF. |
| `INTEGRATION_WEIGHT` | `REAL(R8), intent(IN)` | Weight including the Jacobians. |
| `BLOCK` | `REAL(R8), intent(OUT)(3,3)` | Output: 3x3 nucleus block. |

#### `MASS_NUCLEUS`

Scalar mass nucleus: rho N_i N_j weight for equal components.

| Argument | Declaration | Meaning |
|---|---|---|
| `TEST_COMPONENT` | `INTEGER(I4), intent(IN)` | Displacement component of the test DOF. |
| `TRIAL_COMPONENT` | `INTEGER(I4), intent(IN)` | Displacement component of the trial DOF. |
| `TEST_VALUE` | `REAL(R8), intent(IN)` | Basis value of the test DOF. |
| `TRIAL_VALUE` | `REAL(R8), intent(IN)` | Basis value of the trial DOF. |
| `DENSITY` | `REAL(R8), intent(IN)` | Mass density rho. |
| `INTEGRATION_WEIGHT` | `REAL(R8), intent(IN)` | Weight including the Jacobians. |

#### `MASS_BLOCK_NUCLEUS`

3x3 mass nucleus (diagonal).

| Argument | Declaration | Meaning |
|---|---|---|
| `TEST_VALUE` | `REAL(R8), intent(IN)` | Basis value of the test DOF. |
| `TRIAL_VALUE` | `REAL(R8), intent(IN)` | Basis value of the trial DOF. |
| `DENSITY` | `REAL(R8), intent(IN)` | Mass density rho. |
| `INTEGRATION_WEIGHT` | `REAL(R8), intent(IN)` | Weight including the Jacobians. |
| `BLOCK` | `REAL(R8), intent(OUT)(3,3)` | Output: 3x3 nucleus block. |

#### `ROTATE_BLOCK_TO_GLOBAL`

Rotate a 3x3 block from the local to the global frame.

| Argument | Declaration | Meaning |
|---|---|---|
| `BLOCK_LOCAL` | `REAL(R8), intent(IN)(3,3)` | Block in the element frame. |
| `GLOBAL_TO_LOCAL` | `REAL(R8), intent(IN)(3,3)` | Frame rotation (rows = local axes in global components). |
| `BLOCK_GLOBAL` | `REAL(R8), intent(OUT)(3,3)` | Output: block in the global frame. |

### MUL2_POINT_BASES

File `SRC/CUF/mul2_point_bases.for`.

Evaluate one field-dependent cuf x fem basis at a point. the basis is the product phi = n_structural * f_expansion. evaluate_expansion_factor f and its gradient at an expansion point evaluate_field_basis composes phi from given n, grad n, f, grad f evaluate_point_factors n, grad n, f, grad f at a cached gauss point evaluate_point_basis phi at a cached gauss point the same composition rule serves cached gauss points, arbitrary post points and the tying points of the shear-locking corrections.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_ELEMENTS`, `MUL2_EXPANSION_MESHES`, `MUL2_KINEMATICS`, `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_CUF_BASES`, `MUL2_TOPOLOGIES`, `MUL2_LINEAR_KINEMATICS`.

Table: Procedures of `MUL2_POINT_BASES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `EVALUATE_POINT_FACTORS` | Subroutine | public | N, grad n (structural node) and f, grad f (expansion term) at a cached gauss point. |
| `EVALUATE_POINT_BASIS` | Subroutine | public | Value and gradient of the combined basis N F at a cached Gauss point. |
| `EVALUATE_FIELD_BASIS` | Subroutine | public | One scalar basis term of one field at one point. structural_value/gradient: n_i and its local-frame gradient. expansion_shape(:): shapes of the expansion element nodes. expansion_gradient(3,:): their local-frame gradients. coordinate_local: local coordinate of the expansion point. |
| `EVALUATE_EXPANSION_FACTOR` | Subroutine | public | The expansion factor f_tau and its local gradient. |

#### `EVALUATE_POINT_FACTORS`

N, grad n (structural node) and f, grad f (expansion term) at a cached gauss point.

| Argument | Declaration | Meaning |
|---|---|---|
| `POINT` | `INTEGER(I8), intent(IN)` | Global Gauss-point index (or physical point). |
| `STRUCTURAL_NODE` | `INTEGER(I4), intent(IN)` | Local structural node index. |
| `TERM` | `INTEGER(I4), intent(IN)` | Expansion term index. |
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE), intent(IN)` | Expansion specification (family, order, field reference). |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `STRUCTURAL_VALUE` | `REAL(R8), intent(OUT)` | Structural shape function N. |
| `STRUCTURAL_GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient of the structural shape function (local frame). |
| `FACTOR_VALUE` | `REAL(R8), intent(OUT)` | Expansion factor F_tau. |
| `FACTOR_GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient of the expansion factor (local frame). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EVALUATE_POINT_BASIS`

Value and gradient of the combined basis N F at a cached Gauss point.

| Argument | Declaration | Meaning |
|---|---|---|
| `POINT` | `INTEGER(I8), intent(IN)` | Global Gauss-point index (or physical point). |
| `STRUCTURAL_NODE` | `INTEGER(I4), intent(IN)` | Local structural node index. |
| `TERM` | `INTEGER(I4), intent(IN)` | Expansion term index. |
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE), intent(IN)` | Expansion specification (family, order, field reference). |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `VALUE` | `REAL(R8), intent(OUT)` | Value(s) (see routine). |
| `GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EVALUATE_FIELD_BASIS`

One scalar basis term of one field at one point. structural_value/gradient: n_i and its local-frame gradient. expansion_shape(:): shapes of the expansion element nodes. expansion_gradient(3,:): their local-frame gradients. coordinate_local: local coordinate of the expansion point.

| Argument | Declaration | Meaning |
|---|---|---|
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE), intent(IN)` | Expansion specification (family, order, field reference). |
| `TERM` | `INTEGER(I4), intent(IN)` | Expansion term index. |
| `STRUCTURAL_VALUE` | `REAL(R8), intent(IN)` | Structural shape function N. |
| `STRUCTURAL_GRADIENT` | `REAL(R8), intent(IN)(3)` | Gradient of the structural shape function (local frame). |
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(IN)` | Expansion mesh. |
| `EXPANSION_ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the active expansion sub-element. |
| `EXPANSION_DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension of the expansion element. |
| `ACTIVE_AXIS` | `INTEGER(I4), intent(IN)(2)` | Active local axes of the section. |
| `COORDINATE_LOCAL` | `REAL(R8), intent(IN)(3)` | Section point in the element local frame. |
| `EXPANSION_SHAPE` | `REAL(R8), intent(IN)(:)` | Shape functions of the expansion sub-element nodes at the point. |
| `EXPANSION_GRADIENT` | `REAL(R8), intent(IN)(:,:)` | Local gradients of the expansion shape functions (3, node). |
| `VALUE` | `REAL(R8), intent(OUT)` | Value(s) (see routine). |
| `GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient (3 components). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EVALUATE_EXPANSION_FACTOR`

The expansion factor f_tau and its local gradient.

| Argument | Declaration | Meaning |
|---|---|---|
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE), intent(IN)` | Expansion specification (family, order, field reference). |
| `TERM` | `INTEGER(I4), intent(IN)` | Expansion term index. |
| `MESH` | `TYPE(EXPANSION_MESH_TYPE), intent(IN)` | Expansion mesh. |
| `EXPANSION_ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the active expansion sub-element. |
| `EXPANSION_DIMENSION` | `INTEGER(I4), intent(IN)` | Natural dimension of the expansion element. |
| `ACTIVE_AXIS` | `INTEGER(I4), intent(IN)(2)` | Active local axes of the section. |
| `COORDINATE_LOCAL` | `REAL(R8), intent(IN)(3)` | Section point in the element local frame. |
| `EXPANSION_SHAPE` | `REAL(R8), intent(IN)(:)` | Shape functions of the expansion sub-element nodes at the point. |
| `EXPANSION_GRADIENT` | `REAL(R8), intent(IN)(:,:)` | Local gradients of the expansion shape functions (3, node). |
| `FACTOR_VALUE` | `REAL(R8), intent(OUT)` | Expansion factor F_tau. |
| `FACTOR_GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient of the expansion factor (local frame). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer KINEMATICS {#sec:ref_kinematics}

Linear strain–displacement operator.

### MUL2_LINEAR_KINEMATICS

File `SRC/KINEMATICS/mul2_linear_kinematics.for`.

Linear small-strain operators for field-dependent displacements.

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Procedures of `MUL2_LINEAR_KINEMATICS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `COMPOSE_PRODUCT_BASIS` | Subroutine | public | Value and gradient of N F: N grad F + F grad N. |
| `BUILD_DISPLACEMENT_COLUMN` | Subroutine | public | Strain column of one displacement component for a given scalar gradient. |
| `BUILD_DISPLACEMENT_OPERATOR` | Subroutine | public | 6x3 strain operator B(grad) of a scalar basis function. |

#### `COMPOSE_PRODUCT_BASIS`

Value and gradient of N F: N grad F + F grad N.

| Argument | Declaration | Meaning |
|---|---|---|
| `STRUCTURAL_VALUE` | `REAL(R8), intent(IN)` | Structural shape function N. |
| `STRUCTURAL_GRADIENT` | `REAL(R8), intent(IN)(3)` | Gradient of the structural shape function (local frame). |
| `EXPANSION_VALUE` | `REAL(R8), intent(IN)` | Expansion factor F. |
| `EXPANSION_GRADIENT` | `REAL(R8), intent(IN)(3)` | Local gradients of the expansion shape functions (3, node). |
| `VALUE` | `REAL(R8), intent(OUT)` | Value(s) (see routine). |
| `GRADIENT` | `REAL(R8), intent(OUT)(3)` | Gradient (3 components). |

#### `BUILD_DISPLACEMENT_COLUMN`

Strain column of one displacement component for a given scalar gradient.

| Argument | Declaration | Meaning |
|---|---|---|
| `COMPONENT` | `INTEGER(I4), intent(IN)` | Displacement component index (1=u, 2=v, 3=w) or the frame column of the field. |
| `GRADIENT` | `REAL(R8), intent(IN)(3)` | Gradient (3 components). |
| `COLUMN` | `REAL(R8), intent(OUT)(6)` | Output: strain column (6 values). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_DISPLACEMENT_OPERATOR`

6x3 strain operator B(grad) of a scalar basis function.

| Argument | Declaration | Meaning |
|---|---|---|
| `GRADIENT` | `REAL(R8), intent(IN)(3)` | Gradient (3 components). |
| `OPERATOR` | `REAL(R8), intent(OUT)(6,3)` | Output: 6x3 strain operator. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer MATERIALS {#sec:ref_materials}

Constitutive matrices, rotations and lamination resolution.

### MUL2_MATERIAL_RESOLUTION

File `SRC/MATERIALS/mul2_material_resolution.for`.

Resolve a lamination into constitutive data at an integration point.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_MATERIALS`, `MUL2_LAMINATIONS`, `MUL2_MATERIAL_ROTATIONS`.

Table: Procedures of `MUL2_MATERIAL_RESOLUTION`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RESOLVE_LAMINATION` | Subroutine | public | Rotated stiffness (element frame), density and rotation of a lamination. |

#### `RESOLVE_LAMINATION`

Rotated stiffness (element frame), density and rotation of a lamination.

| Argument | Declaration | Meaning |
|---|---|---|
| `LAMINATION_ID` | `INTEGER(I4), intent(IN)` | Id of the lamination to resolve. |
| `MATERIALS` | `TYPE(MATERIAL_DB_TYPE), intent(IN)` | Material database. |
| `LAMINATIONS` | `TYPE(LAMINATION_DB_TYPE), intent(IN)` | Lamination database. |
| `STIFFNESS_LOCAL` | `REAL(R8), intent(OUT)(6,6)` | Output: stiffness in the element frame. |
| `DENSITY` | `REAL(R8), intent(OUT)` | Mass density rho. |
| `MATERIAL_FROM_LOCAL` | `REAL(R8), intent(OUT)(3,3)` | Output: rotation material <- element frame. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `PIEZO_LOCAL` | `REAL(R8), intent(OUT), OPTIONAL(3,6)` |  |
| `PERMITTIVITY_LOCAL` | `REAL(R8), intent(OUT), OPTIONAL(3,3)` |  |
| `HAS_PIEZO` | `LOGICAL, intent(OUT), OPTIONAL` |  |
| `EXPANSION_LOCAL` | `REAL(R8), intent(OUT), OPTIONAL(6)` |  |
| `CONDUCTIVITY_LOCAL` | `REAL(R8), intent(OUT), OPTIONAL(3,3)` |  |
| `HAS_THERMAL` | `LOGICAL, intent(OUT), OPTIONAL` |  |
| `PYRO_LOCAL` | `REAL(R8), intent(OUT), OPTIONAL(3)` |  |
| `HAS_PYRO` | `LOGICAL, intent(OUT), OPTIONAL` |  |

### MUL2_MATERIAL_ROTATIONS

File `SRC/MATERIALS/mul2_material_rotations.for`.

Single material-orientation transformation implementation.

Uses: `MUL2_KINDS`.

Table: Procedures of `MUL2_MATERIAL_ROTATIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_MATERIAL_ROTATION` | Subroutine | public | Rotation matrix material <- element frame from the angles about y and z (degrees). |
| `BUILD_ENGINEERING_STRAIN_TRANSFORM` | Subroutine | public | 6x6 transformation of engineering strains under a 3x3 rotation. |
| `ROTATE_STIFFNESS` | Subroutine | public | Stiffness in the reference frame: T^T C T. |
| `ROTATE_PIEZO` | Subroutine | public | E_local = a^t e_material t (d = e s: d vector, s engineering strain). |
| `ROTATE_PERMITTIVITY` | Subroutine | public |  |
| `ROTATE_EXPANSION` | Subroutine | public | Expansion strains (engineering voigt): e_ref = t(a^t) e_material. |

#### `BUILD_MATERIAL_ROTATION`

Rotation matrix material <- element frame from the angles about y and z (degrees).

| Argument | Declaration | Meaning |
|---|---|---|
| `ANGLE_Y_DEG` | `REAL(R8), intent(IN)` | Rotation about the local y axis (degrees). |
| `ANGLE_Z_DEG` | `REAL(R8), intent(IN)` | Rotation about the local z axis (degrees). |
| `MATERIAL_FROM_LOCAL` | `REAL(R8), intent(OUT)(3,3)` | Output: matrix that maps element-frame components to material-frame components. |

#### `BUILD_ENGINEERING_STRAIN_TRANSFORM`

6x6 transformation of engineering strains under a 3x3 rotation.

| Argument | Declaration | Meaning |
|---|---|---|
| `A` | `REAL(R8), intent(IN)(3,3)` | Matrix or operand A. |
| `TRANSFORM` | `REAL(R8), intent(OUT)(6,6)` | Output: 6x6 engineering-strain transformation. |

#### `ROTATE_STIFFNESS`

Stiffness in the reference frame: T^T C T.

| Argument | Declaration | Meaning |
|---|---|---|
| `STIFFNESS_MATERIAL` | `REAL(R8), intent(IN)(6,6)` | Stiffness in the material axes. |
| `MATERIAL_FROM_REFERENCE` | `REAL(R8), intent(IN)(3,3)` | Rotation material <- reference frame. |
| `STIFFNESS_REFERENCE` | `REAL(R8), intent(OUT)(6,6)` | Output: stiffness in the reference frame. |

#### `ROTATE_PIEZO`

E_local = a^t e_material t (d = e s: d vector, s engineering strain).

| Argument | Declaration | Meaning |
|---|---|---|
| `PIEZO_MATERIAL` | `REAL(R8), intent(IN)(3,6)` |  |
| `MATERIAL_FROM_REFERENCE` | `REAL(R8), intent(IN)(3,3)` | Rotation material <- reference frame. |
| `PIEZO_REFERENCE` | `REAL(R8), intent(OUT)(3,6)` |  |

#### `ROTATE_PERMITTIVITY`

| Argument | Declaration | Meaning |
|---|---|---|
| `PERMITTIVITY_MATERIAL` | `REAL(R8), intent(IN)(3,3)` |  |
| `MATERIAL_FROM_REFERENCE` | `REAL(R8), intent(IN)(3,3)` | Rotation material <- reference frame. |
| `PERMITTIVITY_REFERENCE` | `REAL(R8), intent(OUT)(3,3)` |  |

#### `ROTATE_EXPANSION`

Expansion strains (engineering voigt): e_ref = t(a^t) e_material.

| Argument | Declaration | Meaning |
|---|---|---|
| `EXPANSION_MATERIAL` | `REAL(R8), intent(IN)(6)` |  |
| `MATERIAL_FROM_REFERENCE` | `REAL(R8), intent(IN)(3,3)` | Rotation material <- reference frame. |
| `EXPANSION_REFERENCE` | `REAL(R8), intent(OUT)(6)` |  |

### MUL2_MATERIALS

File `SRC/MATERIALS/mul2_materials.for`.

Linear mechanical material data and constitutive builders.

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Public constants of `MUL2_MATERIALS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `MATERIAL_ISOTROPIC` | `INTEGER(I4)` | `1_I4` | Material model code. |
| `MATERIAL_ORTHOTROPIC` | `INTEGER(I4)` | `2_I4` | Material model code. |
| `MATERIAL_ANISOTROPIC` | `INTEGER(I4)` | `3_I4` | Material model code. |

Table: Derived type `MATERIAL_TYPE` — One material: id, model, density and 6x6 stiffness in the material axes.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ID` | `INTEGER(I4)` | `` | `0_I4` | Identifier. |
| `MODEL` | `INTEGER(I4)` | `` | `0_I4` | Material model code. |
| `DENSITY` | `REAL(R8)` | `` | `0.0_R8` | Mass density. |
| `STIFFNESS` | `REAL(R8)` | `(6,6)` | `0.0_R8` | Material axes are (t,l,z); voigt is (tt,ll,zz,tz,lz,tl). |
| `HAS_PIEZO` | `LOGICAL` | `` | `.FALSE.` | Piezoelectric stress coefficients e(i,j): electric direction i = t,l,z, strain j in the voigt order of the stiffness, and dielectric permittivity (material axes), both at constant strain. |
| `PIEZO` | `REAL(R8)` | `(3,6)` | `0.0_R8` |  |
| `PERMITTIVITY` | `REAL(R8)` | `(3,3)` | `0.0_R8` |  |
| `HAS_EXPANSION` | `LOGICAL` | `` | `.FALSE.` | Thermal expansion (strain per kelvin, voigt order of the stiffness, material axes) and heat conductivity (material axes). |
| `HAS_CONDUCTION` | `LOGICAL` | `` | `.FALSE.` |  |
| `EXPANSION` | `REAL(R8)` | `(6)` | `0.0_R8` |  |
| `CONDUCTIVITY` | `REAL(R8)` | `(3,3)` | `0.0_R8` |  |
| `HAS_PYRO` | `LOGICAL` | `` | `.FALSE.` | Pyroelectric coefficient (d per kelvin, material axes) measured at zero stress: d = p t when the body expands freely at e = 0. |
| `PYRO` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `SPECIFIC_HEAT` | `REAL(R8)` | `` | `0.0_R8` | Specific heat [j/(kg k)] (thermal capacity = density * c). |

Table: Derived type `MATERIAL_DB_TYPE` — Material database.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(MATERIAL_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |
| `DAMP_MASS` | `REAL(R8)` | `` | `0.0_R8` | Global rayleigh damping of the damp record: c = m_coeff m + k_coeff k (historical order of the record: k then m). |
| `DAMP_STIFFNESS` | `REAL(R8)` | `` | `0.0_R8` |  |

Table: Procedures of `MUL2_MATERIALS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_ISOTROPIC_MATERIAL` | Subroutine | public | Isotropic stiffness from E, nu, rho (checks nu in (-1, 0.5)). |
| `BUILD_ORTHOTROPIC_MATERIAL` | Subroutine | public | Orthotropic stiffness from the nine engineering constants in the (T,L,Z) axes. |
| `BUILD_ANISOTROPIC_MATERIAL` | Subroutine | public | Store a user-supplied 6x6 stiffness. |
| `FIND_MATERIAL_INDEX` | Function → integer(i4) | public | Index of a material by id. |
| `INVERT_SYMMETRIC_3X3` | Subroutine | private | Invert a symmetric 3x3 matrix. |

#### `BUILD_ISOTROPIC_MATERIAL`

Isotropic stiffness from E, nu, rho (checks nu in (-1, 0.5)).

| Argument | Declaration | Meaning |
|---|---|---|
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |
| `YOUNG` | `REAL(R8), intent(IN)` | Young modulus E. |
| `POISSON` | `REAL(R8), intent(IN)` | Poisson ratio nu. |
| `DENSITY` | `REAL(R8), intent(IN)` | Mass density rho. |
| `MATERIAL` | `TYPE(MATERIAL_TYPE), intent(OUT)` | Output: material (id, model, density, stiffness). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_ORTHOTROPIC_MATERIAL`

Orthotropic stiffness from the nine engineering constants in the (T,L,Z) axes.

| Argument | Declaration | Meaning |
|---|---|---|
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |
| `YOUNG_T` | `REAL(R8), intent(IN)` | Young modulus along T. |
| `YOUNG_L` | `REAL(R8), intent(IN)` | Young modulus along L. |
| `YOUNG_Z` | `REAL(R8), intent(IN)` | Young modulus along Z. |
| `NU_LT` | `REAL(R8), intent(IN)` | Poisson ratio nu_LT. |
| `NU_LZ` | `REAL(R8), intent(IN)` | Poisson ratio nu_LZ. |
| `NU_TZ` | `REAL(R8), intent(IN)` | Poisson ratio nu_TZ. |
| `SHEAR_LT` | `REAL(R8), intent(IN)` | Shear modulus G_LT. |
| `SHEAR_LZ` | `REAL(R8), intent(IN)` | Shear modulus G_LZ. |
| `SHEAR_TZ` | `REAL(R8), intent(IN)` | Shear modulus G_TZ. |
| `DENSITY` | `REAL(R8), intent(IN)` | Mass density rho. |
| `MATERIAL` | `TYPE(MATERIAL_TYPE), intent(OUT)` | Output: material (id, model, density, stiffness). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_ANISOTROPIC_MATERIAL`

Store a user-supplied 6x6 stiffness.

| Argument | Declaration | Meaning |
|---|---|---|
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |
| `STIFFNESS` | `REAL(R8), intent(IN)(6,6)` | Stiffness matrix (or values). |
| `DENSITY` | `REAL(R8), intent(IN)` | Mass density rho. |
| `MATERIAL` | `TYPE(MATERIAL_TYPE), intent(OUT)` | Output: material (id, model, density, stiffness). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `FIND_MATERIAL_INDEX`

Index of a material by id.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(MATERIAL_DB_TYPE), intent(IN)` | Database being filled. |
| `ID` | `INTEGER(I4), intent(IN)` | Identifier. |

## Layer GAUSS {#sec:ref_gauss}

Reference rules, global Gauss-point layout, geometry and material caches.

### MUL2_GAUSS_GEOMETRY

File `SRC/GAUSS/mul2_gauss_geometry.for`.

Element-dependent geometry caches for combined gauss points.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_TOPOLOGIES`, `MUL2_HLE_MAP`, `MUL2_GAUSS_POINTS`, `MUL2_JACOBIANS`.

Table: Derived type `STRUCTURAL_GEOMETRY_CACHE_TYPE` — Jacobian data and local shape gradients of the structural points.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `ELEMENT_FIRST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | First point of each element. |
| `ELEMENT_LAST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Last point of each element. |
| `CENTER_GLOBAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Global coordinate of the structural point. |
| `JACOBIAN` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Jacobian matrices. |
| `INVERSE_JACOBIAN` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Inverse Jacobians. |
| `DETERMINANT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Jacobian determinants. |
| `DERIVATIVE_OFFSET` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Offset of the derivative block of each point. |
| `DERIVATIVE_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Shape gradients in the local frame. |

Table: Derived type `EXPANSION_GEOMETRY_CACHE_TYPE` — Jacobian data and local shape gradients of the expansion points.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `ACTIVE_AXIS` | `INTEGER(I4), ALLOCATABLE` | `(:,:)` | `` | Active local axes of each mesh. |
| `MESH_ELEMENT_BASE` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | First flat sub-element of each mesh. |
| `ELEMENT_FIRST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | First point of each element. |
| `ELEMENT_LAST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Last point of each element. |
| `COORDINATE_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Local coordinate of the expansion point. |
| `JACOBIAN` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Jacobian matrices. |
| `INVERSE_JACOBIAN` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Inverse Jacobians. |
| `DETERMINANT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Jacobian determinants. |
| `DERIVATIVE_OFFSET` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Offset of the derivative block of each point. |
| `DERIVATIVE_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Shape gradients in the local frame. |

Table: Derived type `GAUSS_GEOMETRY_TYPE` — Combined Gauss points: cache indices, global coordinates and integration weights.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `STRUCTURAL_CACHE_INDEX` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Structural cache index of each point. |
| `EXPANSION_CACHE_INDEX` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Expansion cache index of each point. |
| `COORDINATE_GLOBAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Global coordinates. |
| `INTEGRATION_WEIGHT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Weight including both Jacobians. |

Table: Procedures of `MUL2_GAUSS_GEOMETRY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_STRUCTURAL_GEOMETRY_CACHE` | Subroutine | public | Jacobian, determinant, inverse and local-frame shape gradients of every structural Gauss point. |
| `BUILD_EXPANSION_GEOMETRY_CACHE` | Subroutine | public | Same for every expansion sub-element and point (the same cache serves all structural points). |
| `BUILD_COMBINED_GAUSS_GEOMETRY` | Subroutine | public | Global coordinate and integration weight of every combined (structural x expansion) point. |
| `STRUCTURAL_ACTIVE_AXES` | Subroutine | private | Local axes carried by the structural element: y for beams, x-y for plates, x-y-z for solids. |
| `FIND_EXPANSION_ACTIVE_AXES` | Subroutine | private | Local axes spanned by the expansion mesh (the largest node extents). |
| `GET_EXPANSION_NODE_COORDINATE` | Subroutine | private | Coordinate of an expansion node by id. |
| `ALLOCATE_STRUCTURAL_CACHE` | Subroutine | private | Allocate the structural geometry cache. |
| `ALLOCATE_EXPANSION_CACHE` | Subroutine | private | Allocate the expansion geometry cache. |
| `CLEAR_STRUCTURAL_CACHE` | Subroutine | private | Release the structural cache. |
| `CLEAR_EXPANSION_CACHE` | Subroutine | private | Release the expansion cache. |
| `CLEAR_COMBINED_GEOMETRY` | Subroutine | private | Release the combined geometry. |

#### `BUILD_STRUCTURAL_GEOMETRY_CACHE`

Jacobian, determinant, inverse and local-frame shape gradients of every structural Gauss point.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(INOUT)` | Model cache built by BUILD_MODEL_CACHE. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `REDUCED` | `LOGICAL, intent(IN), OPTIONAL` | Vector on the free DOFs. |

#### `BUILD_EXPANSION_GEOMETRY_CACHE`

Same for every expansion sub-element and point (the same cache serves all structural points).

| Argument | Declaration | Meaning |
|---|---|---|
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(INOUT)` | Model cache built by BUILD_MODEL_CACHE. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `EXPANSION_ORDER` | `INTEGER(I4), intent(IN), OPTIONAL(:)` | Gauss points per direction needed by each expansion mesh. |

#### `BUILD_COMBINED_GAUSS_GEOMETRY`

Global coordinate and integration weight of every combined (structural x expansion) point.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(INOUT)` | Combined Gauss geometry (coordinates, weights). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_GAUSS_MATERIALS

File `SRC/GAUSS/mul2_gauss_materials.for`.

Shared constitutive cache and gauss-point material indirection.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_GAUSS_POINTS`, `MUL2_MATERIALS`, `MUL2_LAMINATIONS`, `MUL2_MATERIAL_RESOLUTION`.

Table: Public constants of `MUL2_GAUSS_MATERIALS`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `PART_FULL` | `INTEGER(I4)` | `0_I4` |  |
| `PART_NORMAL` | `INTEGER(I4)` | `1_I4` |  |
| `PART_SHEAR` | `INTEGER(I4)` | `2_I4` |  |

Table: Derived type `MATERIAL_CACHE_TYPE` — Distinct resolved constitutive matrices (one per lamination).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of items. |
| `LAMINATION_ID` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Lamination id. |
| `MATERIAL_ID` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Material id. |
| `DENSITY` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Mass density. |
| `MATERIAL_FROM_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Rotation material <- element frame. |
| `STIFFNESS_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Stiffness in the element frame. |
| `ANY_PIEZO` | `LOGICAL` | `` | `.FALSE.` | Piezoelectric coefficients and permittivity in the element frame. |
| `PIEZO_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` |  |
| `PERMITTIVITY_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` |  |
| `ANY_THERMAL` | `LOGICAL` | `` | `.FALSE.` | Thermal expansion strains and conductivity in the element frame. |
| `EXPANSION_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `CONDUCTIVITY_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` |  |
| `ANY_PYRO` | `LOGICAL` | `` | `.FALSE.` | Pyroelectric coefficient at constant strain, element frame: p_strain = p_stress - e alpha (d = e s + eps e + p_strain t). |
| `PYRO_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `SPECIFIC_HEAT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` |  |

Table: Derived type `GAUSS_MATERIAL_MAP_TYPE` — Material cache index of every Gauss point.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `CACHE_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Material cache index of each point. |

Table: Procedures of `MUL2_GAUSS_MATERIALS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_GAUSS_MATERIAL_CACHE` | Subroutine | public | Resolve every lamination into a rotated stiffness matrix and map each Gauss point to its entry. |
| `STIFFNESS_PART` | Function | public | Constitutive matrix of a lamination, or one of its two parts for the selective integration. the strains that are reduced are the transverse shears of the element (voigt order xx yy zz xz yz xy, element frame): beam (axis y): yz, xy plate (surface x-y): xz, yz solid: xz, yz, xy part_shear keeps the entries whose row or column is a reduced strain, part_normal the others: the two parts add up to the matrix. |
| `GENERALIZED_CONSTITUTIVE` | Function | public | Generalised constitutive matrix of the mechanical, electric and thermal fields: rows/columns 1-6 are the strains, 7-9 the potential gradient and 10-12 the temperature gradient (block +k: q = -k grad t). the thermal expansion only enters the load, not this matrix. [ sigma ] [ c e^t ] [ s ] [ d ] = [ e -eps ] [ grad ] (d = e s - eps grad phi) part_normal / part_shear split the entries as in stiffness_part (the electric rows are never reduced). |
| `THERMAL_STRESS_COEFFICIENT` | Function | public | Stress per kelvin of the fully restrained expansion, beta = c alpha. |
| `SPECIFIC_OF` | Function → real(r8) | private |  |
| `CLEAR_MATERIAL_CACHE` | Subroutine | private | Release the material cache. |

#### `BUILD_GAUSS_MATERIAL_CACHE`

Resolve every lamination into a rotated stiffness matrix and map each Gauss point to its entry.

| Argument | Declaration | Meaning |
|---|---|---|
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `MATERIALS` | `TYPE(MATERIAL_DB_TYPE), intent(IN)` | Material database. |
| `LAMINATIONS` | `TYPE(LAMINATION_DB_TYPE), intent(IN)` | Lamination database. |
| `CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(INOUT)` | Model cache built by BUILD_MODEL_CACHE. |
| `POINT_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE), intent(INOUT)` | Output: Gauss point -> material cache index. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `STIFFNESS_PART`

Constitutive matrix of a lamination, or one of its two parts for the selective integration. the strains that are reduced are the transverse shears of the element (voigt order xx yy zz xz yz xy, element frame): beam (axis y): yz, xy plate (surface x-y): xz, yz solid: xz, yz, xy part_shear keeps the entries whose row or column is a reduced strain, part_normal the others: the two parts add up to the matrix.

| Argument | Declaration | Meaning |
|---|---|---|
| `CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `INDEX` | `INTEGER(I4), intent(IN)` |  |
| `PART` | `INTEGER(I4), intent(IN)` |  |
| `DIM) RESULT(C` | |  |

#### `GENERALIZED_CONSTITUTIVE`

Generalised constitutive matrix of the mechanical, electric and thermal fields: rows/columns 1-6 are the strains, 7-9 the potential gradient and 10-12 the temperature gradient (block +k: q = -k grad t). the thermal expansion only enters the load, not this matrix. [ sigma ] [ c e^t ] [ s ] [ d ] = [ e -eps ] [ grad ] (d = e s - eps grad phi) part_normal / part_shear split the entries as in stiffness_part (the electric rows are never reduced).

| Argument | Declaration | Meaning |
|---|---|---|
| `CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `INDEX` | `INTEGER(I4), intent(IN)` |  |
| `PART` | `INTEGER(I4), intent(IN)` |  |
| `DIM) RESULT(M` | |  |

#### `THERMAL_STRESS_COEFFICIENT`

Stress per kelvin of the fully restrained expansion, beta = c alpha.

| Argument | Declaration | Meaning |
|---|---|---|
| `CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `INDEX) RESULT(BETA` | |  |

### MUL2_GAUSS_POINTS

File `SRC/GAUSS/mul2_gauss_points.for`.

Shared reference rules and contiguous global gauss-point layout.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_ELEMENTS`, `MUL2_EXPANSION_MESHES`, `MUL2_TOPOLOGIES`, `MUL2_QUADRATURE`, `MUL2_SHAPE_FUNCTIONS`.

Table: Derived type `REFERENCE_RULE_TYPE` — One reference quadrature rule with shapes and derivatives at its points.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Topology code. |
| `ORDER` | `INTEGER(I4)` | `` | `0_I4` | Order of the matrix / expansion order / quadrature order (see type). |
| `NATURAL_DIMENSION` | `INTEGER(I4)` | `` | `0_I4` | Natural dimension. |
| `NODE_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of nodes. |
| `COORDINATE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Coordinates. |
| `WEIGHT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Weights. |
| `SHAPE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Shape function values at the tying/rule points. |
| `DERIVATIVE` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Shape derivatives. |

Table: Derived type `REFERENCE_RULE_DB_TYPE` — Collection of reference rules.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ITEM` | `TYPE(REFERENCE_RULE_TYPE), ALLOCATABLE` | `(:)` | `` | List of items. |

Table: Derived type `GAUSS_LAYOUT_TYPE` — Global numbering of the Gauss points and its decomposition into element, sub-element, structural and expansion point.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `ELEMENT_FIRST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | First point of each element. |
| `ELEMENT_LAST` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Last point of each element. |
| `ELEMENT_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Element index. |
| `EXPANSION_ELEMENT_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Sub-element of each point. |
| `STRUCTURAL_RULE_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Structural rule of each point. |
| `STRUCTURAL_POINT_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Structural point within its rule. |
| `EXPANSION_RULE_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Expansion rule of each point. |
| `EXPANSION_POINT_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Expansion point within its rule. |
| `LAMINATION_ID` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Lamination id. |
| `REFERENCE_WEIGHT` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Product of the two reference weights. |

Table: Procedures of `MUL2_GAUSS_POINTS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_REFERENCE_RULE_DATABASE` | Subroutine | public | One reference rule (points, weights, shapes, derivatives) per (topology, points-per-direction). |
| `BUILD_REFERENCE_RULE` | Subroutine | private | Evaluate shapes and derivatives at the points of one rule. |
| `BUILD_GAUSS_LAYOUT` | Subroutine | public | Global Gauss-point numbering: element, sub-element, structural point, expansion point. |
| `ADD_TOPOLOGY` | Subroutine | private | Register a (topology, order) pair once. |
| `FIND_REFERENCE_RULE` | Function → integer(i4) | public | Index of the rule of a topology and order, 0 if missing. |
| `FIND_STRUCTURAL_RULE` | Function → integer(i4) | public | Rule of a structural element: the reduced one (order -1) when requested and available, otherwise the default rule. |
| `EXPANSION_POINTS` | Function → integer(i4) | private | Points per direction required by a mesh (0 = default rule). |
| `EXPANSION_MESH_ORDER` | Function → integer(i4) | public | Points per direction of an expansion mesh given the per-mesh need. |
| `ALLOCATE_LAYOUT` | Subroutine | private | Allocate the Gauss layout arrays. |
| `CLEAR_LAYOUT` | Subroutine | private | Release the arrays of a DOF layout. |

#### `BUILD_REFERENCE_RULE_DATABASE`

One reference rule (points, weights, shapes, derivatives) per (topology, points-per-direction).

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `DATABASE` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(INOUT)` | Database being filled. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `EXPANSION_ORDER` | `INTEGER(I4), intent(IN), OPTIONAL(:)` | Gauss points per direction needed by each expansion mesh. |
| `REDUCED_DIMENSION` | `LOGICAL, intent(IN), OPTIONAL(3)` | Reduced_dimension(d): the structural elements of dimension d also get a reduced rule (order = -1 in the database). |

#### `BUILD_GAUSS_LAYOUT`

Global Gauss-point numbering: element, sub-element, structural point, expansion point.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `REFERENCE_RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference rule database. |
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(INOUT)` | Gauss-point layout (global point numbering). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `EXPANSION_ORDER` | `INTEGER(I4), intent(IN), OPTIONAL(:)` | Gauss points per direction needed by each expansion mesh. |
| `REDUCED` | `LOGICAL, intent(IN), OPTIONAL` | Reduced: the structural points use the reduced rule where one exists. |

#### `FIND_REFERENCE_RULE`

Index of the rule of a topology and order, 0 if missing.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Database being filled. |
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `ORDER` | `INTEGER(I4), intent(IN), OPTIONAL` | Order of the matrix, or polynomial/quadrature order (see routine). |

#### `FIND_STRUCTURAL_RULE`

Rule of a structural element: the reduced one (order -1) when requested and available, otherwise the default rule.

| Argument | Declaration | Meaning |
|---|---|---|
| `DATABASE` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Database being filled. |
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `REDUCED` | `LOGICAL, intent(IN)` | Vector on the free DOFs. |

#### `EXPANSION_MESH_ORDER`

Points per direction of an expansion mesh given the per-mesh need.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `MESH` | `INTEGER(I4), intent(IN)` | Expansion mesh. |
| `EXPANSION_ORDER` | `INTEGER(I4), intent(IN), OPTIONAL(:)` | Gauss points per direction needed by each expansion mesh. |

## Layer ELEMENTS {#sec:ref_elements}

Element matrices (reference and separable kernels), MITC, dense products.

### MUL2_DENSE_PRODUCTS

File `SRC/ELEMENTS/mul2_dense_products.for`.

Dense products used by the element kernels. matrix(i,j) += sum_q a(q,i) * b(q,j) for i <= j only. the caller mirrors the upper triangle. the loops are written without array temporaries (no stack use, safe inside openmp regions) and with a 4-column register block to reuse every streamed column of a.

Uses: `MUL2_KINDS`.

Table: Procedures of `MUL2_DENSE_PRODUCTS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `ACCUMULATE_UPPER_PRODUCT` | Subroutine | public | A, b: (rows,n) with the first rows rows used. index (ascending) selects the columns of a, b and their position in matrix; without it the columns are 1..size(a,2). |
| `COLUMN` | Function → integer(i4) | private | Column of the matrix addressed by a (possibly selected) index. |
| `ADD_ENTRY` | Subroutine | private | Add a value to one matrix entry. |
| `ACCUMULATE_PRODUCT` | Subroutine | public | Matrix(i,j) += sum_q a(q,i) * b(q,j) for all i, j. |

#### `ACCUMULATE_UPPER_PRODUCT`

A, b: (rows,n) with the first rows rows used. index (ascending) selects the columns of a, b and their position in matrix; without it the columns are 1..size(a,2).

| Argument | Declaration | Meaning |
|---|---|---|
| `A` | `REAL(R8), intent(IN)(:,:)` | Left factor, rows = integration rows, columns = DOFs. |
| `B` | `REAL(R8), intent(IN)(:,:)` | Right factor (same shape as A). |
| `ROWS` | `INTEGER(I4), intent(IN)` | Number of rows actually used. |
| `MATRIX` | `REAL(R8), intent(INOUT)(:,:)` | In/out: receives the upper triangle of A^T B. |
| `INDEX` | `INTEGER(I4), intent(IN), OPTIONAL(:)` | Optional ascending list of selected columns. |

#### `ACCUMULATE_PRODUCT`

Matrix(i,j) += sum_q a(q,i) * b(q,j) for all i, j.

| Argument | Declaration | Meaning |
|---|---|---|
| `A` | `REAL(R8), intent(IN)(:,:)` | Matrix or operand A. |
| `B` | `REAL(R8), intent(IN)(:,:)` | Matrix or operand B. |
| `ROWS` | `INTEGER(I4), intent(IN)` | Number of rows actually used. |
| `MATRIX` | `REAL(R8), intent(INOUT)(:,:)` | In/out: matrix receiving A^T B. |

### MUL2_ELEMENT_MATRICES

File `SRC/ELEMENTS/mul2_element_matrices.for`.

Dense reference element matrices for linear mechanics.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_TOPOLOGIES`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_GAUSS_MATERIALS`, `MUL2_DOF_LAYOUT`, `MUL2_POINT_BASES`, `MUL2_MITC`, `MUL2_LINEAR_KINEMATICS`, `MUL2_DENSE_PRODUCTS`, `MUL2_SEPARABLE_KERNEL`.

Table: Derived type `ELEMENT_MATRIX_TYPE` — Dense K and M of one element with the description of its local DOFs.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4)` | `` | `0_I4` | Element index. |
| `LOCAL_DOF_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of local DOFs. |
| `GLOBAL_DOF` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Global DOF numbers. |
| `NODE_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Node index of each local node. |
| `KINEMATIC_INDEX` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Kinematic index of each local node. |
| `STRUCTURAL_NODE` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Local structural node of each local DOF. |
| `FIELD` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Field of each local DOF (or request list). |
| `TERM` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Expansion term of each local DOF. |
| `CSR_POSITION` | `INTEGER(I8), ALLOCATABLE` | `(:,:)` | `` | Precomputed CSR positions. |
| `STIFFNESS` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Stiffness values or matrix. |
| `MASS` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Mass values or matrix. |
| `INTERNAL_FORCE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Internal force of the nonlinear (total lagrangian) element. |

Table: Derived type `POINT_WORK_TYPE` — Workspace of the point-by-point kernels. the basis of a degree of freedom is n_node * f_term: the structural factors (one per node) and the expansion factors (one per term and per distinct expansion) are evaluated once per point and combined for every dof, instead of re-evaluating both for each of the (often hundreds of) dofs.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `N_MEMO` | `INTEGER(I4)` | `` | `0_I4` |  |
| `MEMO_OF` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `MEMO_NODE` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `MEMO_TERMS` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `MEMO_KIN` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `MEMO_FIELD` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` |  |
| `SVAL` | `REAL(R8), ALLOCATABLE` | `(:)` | `` |  |
| `SGRAD` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `FVAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `FGRAD` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` |  |
| `VALUE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Values. |
| `BCOL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |
| `GRAD` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` |  |

Table: Procedures of `MUL2_ELEMENT_MATRICES`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_LINEAR_ELEMENT_MATRICES` | Subroutine | public | K and M of one element: separable kernel when applicable, otherwise batched point-by-point reference kernel. |
| `TRY_SEPARABLE` | Subroutine | private | Call the separable kernel (internal helper). |
| `BUILD_NONLINEAR_ELEMENT_MATRICES` | Subroutine | public | Total lagrangian (st. venant-kirchhoff) element at the state u0. h = grad u (element frame), e = b u + (h^t h)/2 (green strain), sigma = m gamma (pk2 stress, electric displacement, heat flux), f_int = sum_p w b(u)^t sigma, k_t = sum_p w [ b(u)^t m b(u) + (d_i.d_j) grad n_i . s grad n_j ] with b(u) the variation of gamma (b + the term h^t grad n). the thermal and pyroelectric loads enter sigma, the coupling blocks k(u,t) and k(phi,t) are added. mitc ties only the linear part. |
| `ADD_MASS` | Subroutine | private | M = sum_p (w rho)_p n_p n_pt, with n non-zero only between dofs of the same field: one product per field. basis_value(point,dof). |
| `MIRROR_UPPER_TRIANGLE` | Subroutine | private | Copy the upper triangle of K (and M) into the lower one. |
| `SETUP_POINT_WORK` | Subroutine | private | Distinct expansions of the dofs of an element: two dofs share a table of expansion factors when their expansion (family, order, reference) is the same, e.g. the three displacement components. |
| `SAME_EXPANSION` | Function → logical | private |  |
| `EVALUATE_POINT_COLUMNS` | Subroutine | private | Basis value, gradient and generalised-strain column of every dof at one gauss point (work%value, work%grad, work%bcol). |
| `COLUMN_FROM_BASIS` | Subroutine | private | Generalised-strain column of a dof from its basis gradient: the displacement operator (with the mitc tying when active), the potential gradient (rows 7-9) or the temperature gradient (10-12). |
| `BUILD_ELEMENT_DOF_LIST` | Subroutine | public | Local DOF list of an element: global numbers, structural node, field and term of every local DOF. |
| `VALIDATE_INPUT` | Subroutine | private | Consistency checks of the databases before the element kernel runs. |
| `CLEAR_ELEMENT_MATRIX` | Subroutine | public | Release an element-matrix container. |

#### `BUILD_LINEAR_ELEMENT_MATRICES`

K and M of one element: separable kernel when applicable, otherwise batched point-by-point reference kernel.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Global DOF numbering. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `GAUSS_LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `MATERIAL_CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Resolved constitutive matrices. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE), intent(IN)` | Gauss point -> material cache index. |
| `MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)` | Element matrix container (K, M, DOF lists). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `MITC` | `TYPE(MITC_DATA_TYPE), intent(IN), OPTIONAL` | MITC tying data of the element. |
| `WITH_MASS` | `LOGICAL, intent(IN), OPTIONAL` | Also build the mass matrix. |
| `FORCE_GENERAL` | `LOGICAL, intent(IN), OPTIONAL` | Force the reference (point-by-point) kernel. |
| `PART` | `INTEGER(I4), intent(IN), OPTIONAL` | Part: part_full, part_normal or part_shear of the constitutive matrix (selective integration); with_stiffness = .false. skips k. |
| `WITH_STIFFNESS` | `LOGICAL, intent(IN), OPTIONAL` |  |
| `COUPLING` | `LOGICAL, intent(IN), OPTIONAL` | Coupling = .true.: stiffness receives only the thermoelastic coupling block k(u,t) = - sum_p w b^t (c alpha) n_t (not symmetric: the block k(t,u) is zero in the stationary problem). |
| `GEOMETRIC` | `LOGICAL, intent(IN), OPTIONAL` | Geometric = .true.: stiffness receives the geometric (initial stress) matrix of the state u0 (global dof vector): k_g(i,j) = sum_p w (d_i.d_j) grad n_i . s grad n_j, with s the stress tensor of u0 (element frame) and d the local direction of the displacement component of a dof. |
| `U0` | `REAL(R8), intent(IN), OPTIONAL(:)` |  |

#### `BUILD_NONLINEAR_ELEMENT_MATRICES`

Total lagrangian (st. venant-kirchhoff) element at the state u0. h = grad u (element frame), e = b u + (h^t h)/2 (green strain), sigma = m gamma (pk2 stress, electric displacement, heat flux), f_int = sum_p w b(u)^t sigma, k_t = sum_p w [ b(u)^t m b(u) + (d_i.d_j) grad n_i . s grad n_j ] with b(u) the variation of gamma (b + the term h^t grad n). the thermal and pyroelectric loads enter sigma, the coupling blocks k(u,t) and k(phi,t) are added. mitc ties only the linear part.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Global DOF numbering. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `GAUSS_LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `MATERIAL_CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Resolved constitutive matrices. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE), intent(IN)` | Gauss point -> material cache index. |
| `MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)` | Element matrix container (K, M, DOF lists). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `MITC` | `TYPE(MITC_DATA_TYPE), intent(IN)` | MITC tying data of the element. |
| `U0` | `REAL(R8), intent(IN)(:)` |  |

#### `BUILD_ELEMENT_DOF_LIST`

Local DOF list of an element: global numbers, structural node, field and term of every local DOF.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Global DOF numbering. |
| `MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)` | Element matrix container (K, M, DOF lists). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(INOUT)` | Status of the call (OK, warning or error with message and source). |

#### `CLEAR_ELEMENT_MATRIX`

Release an element-matrix container.

| Argument | Declaration | Meaning |
|---|---|---|
| `MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)` | Element matrix container (K, M, DOF lists). |

### MUL2_GENERAL_KERNEL

File `SRC/ELEMENTS/mul2_general_kernel.for`.

Element matrices of curved beams and shells (general geometry). the basis of a degree of freedom is phi = n_i(xi) f_tau(c), with c the position in the expansion mesh (section of the beam, thickness of the shell). the displacements are global cartesian components, so the element is a solid with the map of mul2_general_geometry: g_a = d x / d t_a (rows of the jacobian), grad phi = g^-1 d phi/d t. the strains are formed in the covariant basis, e~_ab = 1/2 (g_a . u,b + g_b . u,a), where the mitc interpolation can replace the components that lock (a shell: the transverse shears and the membrane ones, beam: axial and shears) by the values at tying points of the same position in the thickness; then they are rotated to the frame of the material, e_l = t(q) e~, q = r g^-1, r = global_to_local at the point. without tying this is exactly the cartesian strain of a solid. the electric potential and the temperature use the cartesian gradient. general_context_setup geometry and tying tables of an element general_point_columns strain columns of all the dofs at a point build_general_element_matrices k, m (or the thermoelastic block) the recovery of strain and stress uses the same columns.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_ELEMENTS`, `MUL2_TOPOLOGIES`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_GAUSS_MATERIALS`, `MUL2_DOF_LAYOUT`, `MUL2_POINT_BASES`, `MUL2_DENSE_PRODUCTS`, `MUL2_ELEMENT_MATRICES`, `MUL2_GENERAL_GEOMETRY`, `MUL2_SHAPE_FUNCTIONS`.

Table: Derived type `TIE_FAMILY_TYPE` — One family of tying points: tensor product of a list in xi and one in eta; the rows of the strain that are interpolated from them.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `NX` | `INTEGER(I4)` | `` | `0_I4` |  |
| `NY` | `INTEGER(I4)` | `` | `1_I4` |  |
| `XL` | `REAL(R8)` | `(4)` | `0.0_R8` |  |
| `YL` | `REAL(R8)` | `(4)` | `0.0_R8` |  |
| `ROW` | `LOGICAL` | `(6)` | `.FALSE.` |  |
| `SHAPE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Shape function values at the tying/rule points. |
| `DSHAPE` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` |  |

Table: Derived type `GENERAL_CONTEXT_TYPE` — Geometry of one element and its tying tables.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Topology code. |
| `DS` | `INTEGER(I4)` | `` | `0_I4` |  |
| `NN` | `INTEGER(I4)` | `` | `0_I4` |  |
| `AXIS` | `INTEGER(I4)` | `(3)` | `0_I4` |  |
| `N_FAMILY` | `INTEGER(I4)` | `` | `0_I4` |  |
| `COORD` | `REAL(R8)` | `(3,16)` | `0.0_R8` |  |
| `TRIAD` | `REAL(R8)` | `(3,3,16)` | `0.0_R8` |  |
| `REFERENCE` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `KINK` | `INTEGER(I4)` | `(16)` | `0_I4` |  |
| `FAMILY` | `TYPE(TIE_FAMILY_TYPE)` | `(3)` | `` | Expansion family code. |

Table: Procedures of `MUL2_GENERAL_KERNEL`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `GENERAL_CONTEXT_SETUP` | Subroutine | public | Geometry (nodes, triads, reference vector), active expansion axes and, with tying, the tying points of the element. |
| `GENERAL_POINT_COLUMNS` | Subroutine | public | Strain columns of all the dofs at one point. n, dn structural shapes and natural derivatives (nn, ds) natural structural natural coordinates of the point c position in the expansion mesh (3) dof_node/field, fv, fg local node, field, expansion factor and its gradient (local axes) of every dof bcol(1:6) strain in the local frame (bcol(7:9) potential gradient, bcol(10:12) temperature gradient); value the basis; g, r, det geometry at the point. |
| `BUILD_GENERAL_ELEMENT_MATRICES` | Subroutine | public |  |
| `ADD_MASS` | Subroutine | private | Add the mass contribution of a batch of points, one product per displacement component. |
| `MIRROR` | Subroutine | private |  |
| `TIE_WEIGHTS` | Subroutine | private | Weights of the tying points of a family at a natural point. |
| `COVARIANT_ROWS` | Subroutine | private | Covariant strain rows (11, 22, 33, 13, 23, 12; engineering shears) of a displacement in the global direction f with scalar basis derivatives dphi = d phi / d t. |
| `BUILD_T` | Subroutine | private | 6 x 6 matrix that turns the covariant engineering strains into the ones of the local frame, q(m,a) = e_m . g^a. |
| `LAGRANGE` | Function → real(r8) | private | Lagrange polynomial i of the n points x(1:n) at xi. |
| `INVERT3` | Subroutine | private |  |

#### `GENERAL_CONTEXT_SETUP`

Geometry (nodes, triads, reference vector), active expansion axes and, with tying, the tying points of the element.

| Argument | Declaration | Meaning |
|---|---|---|
| `CTX` | `TYPE(GENERAL_CONTEXT_TYPE), intent(OUT)` |  |
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `TYING` | `LOGICAL, intent(IN)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `GENERAL_POINT_COLUMNS`

Strain columns of all the dofs at one point. n, dn structural shapes and natural derivatives (nn, ds) natural structural natural coordinates of the point c position in the expansion mesh (3) dof_node/field, fv, fg local node, field, expansion factor and its gradient (local axes) of every dof bcol(1:6) strain in the local frame (bcol(7:9) potential gradient, bcol(10:12) temperature gradient); value the basis; g, r, det geometry at the point.

| Argument | Declaration | Meaning |
|---|---|---|
| `CTX` | `TYPE(GENERAL_CONTEXT_TYPE), intent(IN)` |  |
| `N` | `REAL(R8), intent(IN)(:)` | Shape function values. |
| `DN` | `REAL(R8), intent(IN)(:,:)` | Shape derivatives. |
| `NATURAL` | `REAL(R8), intent(IN)(3)` | Natural coordinates (xi, eta, nu). |
| `C` | `REAL(R8), intent(IN)(3)` |  |
| `N_DOF` | `INTEGER(I4), intent(IN)` |  |
| `DOF_NODE` | `INTEGER(I4), intent(IN)(:)` |  |
| `DOF_FIELD` | `INTEGER(I4), intent(IN)(:)` |  |
| `FV` | `REAL(R8), intent(IN)(:)` |  |
| `FG` | `REAL(R8), intent(IN)(:,:)` |  |
| `BCOL` | `REAL(R8), intent(OUT)(:,:)` |  |
| `VALUE` | `REAL(R8), intent(OUT)(:)` | Value(s) (see routine). |
| `G` | `REAL(R8), intent(OUT)(3,3)` |  |
| `R` | `REAL(R8), intent(OUT)(3,3)` |  |
| `DET` | `REAL(R8), intent(OUT)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_GENERAL_ELEMENT_MATRICES`

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Global DOF numbering. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `GAUSS_LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `MATERIAL_CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Resolved constitutive matrices. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE), intent(IN)` | Gauss point -> material cache index. |
| `MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)` | Element matrix container (K, M, DOF lists). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `TYING` | `LOGICAL, intent(IN)` |  |
| `WITH_MASS` | `LOGICAL, intent(IN), OPTIONAL` | Also build the mass matrix. |
| `COUPLING` | `LOGICAL, intent(IN), OPTIONAL` |  |

### MUL2_MITC

File `SRC/ELEMENTS/mul2_mitc.for`.

MITC SHEAR-LOCKING CORRECTION BY ASSUMED STRAIN ROWS. A TIED STRAIN ROW OF THE B OPERATOR IS NOT EVALUATED AT THE QUADRATURE POINT BUT INTERPOLATED FROM ITS VALUES AT THE TYING POINTS OF A TYING SET (TENSOR LAGRANGE INTERPOLATION): B_R(XI) = SUM_L M_L(XI) B_R(XI_L) THE SAME EXPANSION POINT IS USED AT THE TYING POINTS, SO THE CORRECTION ACTS ON THE FEM DIRECTIONS ONLY. THE TABLE REPRODUCES THE BASELINE (PHYSICAL STRAIN COMPONENTS, A=1/SQRT(3), B=SQRT(3/5)): ELEMENT ROW(S) TYING POINTS (XI x ETA x ZETA) B2 5,6 {0} B3 5,6 {-A,A} B4 5,6 {-B,0,B} Q4 4 {0} x {1,-1} 5 {1,-1} x {0} Q9 1,4 {-A,A} x {-B,0,B} 2,5 {-B,0,B} x {-A,A} 6 {-A,A} x {-A,A} H8 4,5,6 {0} x {0} x {0} H27 4,5,6 {-A,A} x {-A,A} x {-A,A}

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_TOPOLOGIES`, `MUL2_LOCAL_GRADIENTS`, `MUL2_LINEAR_KINEMATICS`.

Table: Derived type `TYING_SET_TYPE` — Points of one tying set: the tensor product of one list per direction.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT_1D` | `INTEGER(I4)` | `(3)` | `1_I4` | Tying points per direction. |
| `COORDINATE_1D` | `REAL(R8)` | `(3,3)` | `0.0_R8` | Tying coordinates per direction. |

Table: Derived type `MITC_DATA_TYPE` — MITC data of one element: tied rows, tying sets, shapes and gradients at the tying points.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ACTIVE` | `LOGICAL` | `` | `.FALSE.` | Flags. |
| `SET_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of tying sets. |
| `ROW_SET` | `INTEGER(I4)` | `(6)` | `0_I4` | Tying set of each strain row (0 = not tied). |
| `SET` | `TYPE(TYING_SET_TYPE)` | `(MAX_SET)` | `` | Tying sets. |
| `SHAPE` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Shape function values at the tying/rule points. |
| `GRADIENT` | `REAL(R8), ALLOCATABLE` | `(:,:,:,:)` | `` | Local-frame gradients. |

Table: Procedures of `MUL2_MITC`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `MITC_IS_AVAILABLE` | Function → logical | public | True for topologies with a tying table (B2 B3 B4 Q4 Q9 H8 H20 H27). |
| `MITC_PREPARE_ELEMENT` | Subroutine | public | Tying table of a topology and the shapes/gradients at its points. node_local(:,i) is the local coordinate of element node i. |
| `MITC_CLEAR` | Subroutine | private | Reset MITC data (including the tying sets). |
| `DEFINE_TYING` | Subroutine | private | Table of tied rows and tying points of a topology. |
| `SET_LIST` | Subroutine | private | Set the tying coordinates of one direction. |
| `POINT_OF_SET` | Subroutine | private | Natural coordinates of tying point l (first direction fastest). |
| `INTERPOLATION_WEIGHT` | Subroutine | public | M_l(natural): lagrange weight of every tying point of the set. |
| `MITC_TIE_COLUMN` | Subroutine | public | Replace the tied rows of the strain column of one dof. natural: structural natural coordinates of the point local_node: structural node of the dof factor, factor_gradient: expansion factor and its gradient at the expansion point (unchanged at the tying points) component: column of the frame rotation for the dof field b_column: in: regular column; out: column with tied rows |

#### `MITC_IS_AVAILABLE`

True for topologies with a tying table (B2 B3 B4 Q4 Q9 H8 H20 H27).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |

#### `MITC_PREPARE_ELEMENT`

Tying table of a topology and the shapes/gradients at its points. node_local(:,i) is the local coordinate of element node i.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOPOLOGY` | `INTEGER(I4), intent(IN)` | Topology code (B2..S1). |
| `NODE_LOCAL` | `REAL(R8), intent(IN)(:,:)` | Local-frame coordinates of the element nodes. |
| `DATA` | `TYPE(MITC_DATA_TYPE), intent(INOUT)` | MITC data of the element. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `INTERPOLATION_WEIGHT`

M_l(natural): lagrange weight of every tying point of the set.

| Argument | Declaration | Meaning |
|---|---|---|
| `SET` | `TYPE(TYING_SET_TYPE), intent(IN)` | Tying set. |
| `NATURAL` | `REAL(R8), intent(IN)(3)` | Natural coordinates (xi, eta, nu). |
| `WEIGHT` | `REAL(R8), intent(OUT)(:)` | Output: interpolation weights of the tying points. |

#### `MITC_TIE_COLUMN`

Replace the tied rows of the strain column of one dof. natural: structural natural coordinates of the point local_node: structural node of the dof factor, factor_gradient: expansion factor and its gradient at the expansion point (unchanged at the tying points) component: column of the frame rotation for the dof field b_column: in: regular column; out: column with tied rows

| Argument | Declaration | Meaning |
|---|---|---|
| `DATA` | `TYPE(MITC_DATA_TYPE), intent(IN)` | MITC data of the element. |
| `NATURAL` | `REAL(R8), intent(IN)(3)` | Natural coordinates (xi, eta, nu). |
| `LOCAL_NODE` | `INTEGER(I4), intent(IN)` | Local structural node index. |
| `FACTOR` | `REAL(R8), intent(IN)` | PARDISO handle with factors and stored matrix. |
| `FACTOR_GRADIENT` | `REAL(R8), intent(IN)(3)` | Gradient of the expansion factor (local frame). |
| `COMPONENT` | `REAL(R8), intent(IN)(3)` | Displacement component index (1=u, 2=v, 3=w) or the frame column of the field. |
| `B_COLUMN` | `REAL(R8), intent(INOUT)(6)` | Strain column (6 values) of the DOF; tied rows are replaced on output. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_SEPARABLE_KERNEL

File `SRC/ELEMENTS/mul2_separable_kernel.for`.

Separable cuf element matrices. the combined basis of a dof is n_i(p) f_t(q): a structural factor (structural point p) times an expansion factor (expansion point q of a sub-element e). in the element frame, with s the structural axes, dphi/dd = sigma_d(p,i) * eps_d(q,t) sigma_d = dn/dd (d in s), n (d not in s) eps_d = f (d in s), df/dd (d not in s) and the strain column is b(:,r) = sum_d w_d,f(r) sigma_d eps_d, with w_d,f = b_operator(e_d) * frame(:,f). tied (mitc) rows replace sigma by its tensor-lagrange interpolation from the tying points. with a constitutive matrix c_e constant inside each sub-element e, k((i,t,f),(j,s,h)) = sum_e sum_d,d' lambda_e,dd'(i,j,f,h) * em_e,dd'(t,s) lambda = sum_r,r' c_e(r,r') w_d,f(r) w_d',h(r') sm_dd'^cc'(i,j) sm_dd'^cc'(i,j) = sum_p w_p sigma_d^c(p,i) sigma_d'^c'(p,j) em_e,dd'(t,s) = sum_q w_q eps_d(q,t) eps_d'(q,s) so the cost is additive in the structural and expansion points instead of their product. the result is algebraically the same as the point-by-point kernel (round-off only).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_ELEMENTS`, `MUL2_TOPOLOGIES`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_GAUSS_MATERIALS`, `MUL2_POINT_BASES`, `MUL2_MITC`, `MUL2_LINEAR_KINEMATICS`, `MUL2_DENSE_PRODUCTS`.

Table: Derived type `SPEC_BASIS_TYPE` — Expansion functions of one distinct kinematic specification at all expansion points of the element: eps(point,term,0:3), 0 = value.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `SPEC` | `TYPE(EXPANSION_SPEC_TYPE)` | `` | `` | Expansion specification. |
| `TERMS` | `INTEGER(I4)` | `` | `0_I4` | Number of terms. |
| `EPS` | `REAL(R8), ALLOCATABLE` | `(:,:,:)` | `` | Expansion functions EPS(point, term, 0:3). |

Table: Derived type `EXPANSION_PRODUCT_TYPE` — Em(t,s,k,e): k = 3*(d-1)+d' for d,d' = 1..3 and k = 10 for f f.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `READY` | `LOGICAL` | `` | `.FALSE.` | Computed flag. |
| `EM` | `REAL(R8), ALLOCATABLE` | `(:,:,:,:)` | `` | Expansion integrals EM(t,s,k,e). |

Table: Procedures of `MUL2_SEPARABLE_KERNEL`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_SEPARABLE_MATRICES` | Subroutine | public | Applicable = .false. leaves the matrices untouched (the caller then uses the point-by-point kernel). field/structural_node/term are the local dof lists (node-major, then field, then term). |
| `PRODUCT_OF` | Function → integer(i4) | private | Product of the three counts of a tying set. |
| `SAME_SPEC` | Function → logical | private | True when two kinematic specifications are identical (family, order, field reference). |
| `PREPARE_PRODUCT` | Subroutine | private | Em_e,k(t,s) = sum_q w_q eps_a,d(q,t) eps_b,d'(q,s), once per pair. |

#### `BUILD_SEPARABLE_MATRICES`

Applicable = .false. leaves the matrices untouched (the caller then uses the point-by-point kernel). field/structural_node/term are the local dof lists (node-major, then field, then term).

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE), intent(IN)` | Reference quadrature rule database. |
| `LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `STRUCTURAL_CACHE` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the structural points. |
| `EXPANSION_CACHE` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE), intent(IN)` | Geometry cache of the expansion points. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE), intent(IN)` | Combined Gauss geometry (coordinates, weights). |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `MATERIAL_CACHE` | `TYPE(MATERIAL_CACHE_TYPE), intent(IN)` | Resolved constitutive matrices. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE), intent(IN)` | Gauss point -> material cache index. |
| `MITC_DATA` | `TYPE(MITC_DATA_TYPE), intent(IN)` | MITC tying data of the element. |
| `FIELD` | `INTEGER(I4), intent(IN)(:)` | Field index (1=U, 2=V, 3=W, ...). |
| `STRUCTURAL_NODE` | `INTEGER(I4), intent(IN)(:)` | Local structural node index. |
| `TERM` | `INTEGER(I4), intent(IN)(:)` | Expansion term index. |
| `KINEMATIC_INDEX` | `INTEGER(I4), intent(IN)(:)` | Kinematic index of every structural node. |
| `WITH_MASS` | `LOGICAL, intent(IN)` | Also build the mass matrix. |
| `STIFFNESS` | `REAL(R8), intent(INOUT)(:,:)` | Stiffness matrix (or values). |
| `MASS` | `REAL(R8), intent(INOUT)(:,:)` | Mass matrix (or values). |
| `APPLICABLE` | `LOGICAL, intent(OUT)` | Set to .FALSE. when the separable path cannot be used. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `PART` | `INTEGER(I4), intent(IN), OPTIONAL` |  |
| `WITH_STIFFNESS` | `LOGICAL, intent(IN), OPTIONAL` |  |

## Layer ASSEMBLY {#sec:ref_assembly}

DOF numbering, CSR pattern and assembly, sparse operations.

### MUL2_DOF_LAYOUT

File `SRC/ASSEMBLY/mul2_dof_layout.for`.

Field-major global degree-of-freedom numbering.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_INCIDENCE`, `MUL2_ELEMENTS`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_TOPOLOGIES`, `MUL2_CUF_BASES`.

Table: Derived type `DOF_LAYOUT_TYPE` — Field-major global DOF numbering: terms per (node, field), first DOF, range of every field.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `TERM_COUNT` | `INTEGER(I4), ALLOCATABLE` | `(:,:)` | `` | Number of terms of (node, field). |
| `FIRST` | `INTEGER(I8), ALLOCATABLE` | `(:,:)` | `` | First global DOF of (node, field) or first element of a node. |
| `FIELD_FIRST` | `INTEGER(I8)` | `(N_FIELDS)` | `0_I8` | First DOF of each field. |
| `FIELD_LAST` | `INTEGER(I8)` | `(N_FIELDS)` | `0_I8` | Last DOF of each field. |
| `TOTAL_DOF` | `INTEGER(I8)` | `` | `0_I8` | Total number of DOFs. |
| `ALIAS` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Dofs joined by coincidence (join coincident): provisional number -> final number. not allocated when nothing is joined. |

Table: Procedures of `MUL2_DOF_LAYOUT`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_DOF_LAYOUT` | Subroutine | public | Compute the number of terms of every (node, field) and the field-major global numbering. |
| `NODE_FIELD_TERM_COUNT` | Subroutine | private | Terms of one field at one node from its expansion family and the expansion meshes of the incident elements. |
| `LAGRANGE_TERM_COUNT` | Function → integer(i4) | private | Number of nodes of an expansion mesh (terms of a Lagrange expansion). |
| `MESH_IS_HLE` | Function → logical | private |  |
| `EXPANSION_DIMENSION_FOR_ELEMENT` | Function → integer(i4) | private | Natural dimension of the sub-elements of an expansion mesh (-1 unknown, -2 mixed). |
| `GLOBAL_DOF` | Function → integer(i8) | public | Global DOF number of (node index, field, term). |
| `CLEAR_LAYOUT` | Subroutine | private | Release the arrays of a DOF layout. |

#### `BUILD_DOF_LAYOUT`

Compute the number of terms of every (node, field) and the field-major global numbering.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(INOUT)` | Gauss-point layout (global point numbering). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `GLOBAL_DOF`

Global DOF number of (node index, field, term).

| Argument | Declaration | Meaning |
|---|---|---|
| `LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `NODE_INDEX` | `INTEGER(I4), intent(IN)` | Index of the node in the node database. |
| `FIELD` | `INTEGER(I4), intent(IN)` | Field index (1=U, 2=V, 3=W, ...). |
| `TERM` | `INTEGER(I4), intent(IN)` | Term index (1-based) within the (node, field) block. |

### MUL2_SPARSE_ASSEMBLY

File `SRC/ASSEMBLY/mul2_sparse_assembly.for`.

One-based ilp64 csr pattern and global matrix assembly.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_ELEMENT_MATRICES`.

Table: Derived type `SPARSE_SYSTEM_TYPE` — CSR (1-based, 64-bit) pattern shared by K and M with their value arrays.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ORDER` | `INTEGER(I8)` | `` | `0_I8` | Order of the matrix / expansion order / quadrature order (see type). |
| `NONZERO_COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of stored entries. |
| `ROW_POINTER` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR row pointer. |
| `COLUMN_INDEX` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR column indices. |
| `STIFFNESS` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Stiffness values or matrix. |
| `MASS` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Mass values or matrix. |

Table: Derived type `DOF_LIST_TYPE` — Table(k) > 0 marks a lagrange-expansion dof and term(k) its term: two such dofs of the same table are coupled only if coupled(term,term).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `GLOBAL_DOF` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Global DOF numbers. |
| `TABLE` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Lagrange coupling table id (0 = fully coupled). |
| `TERM` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Expansion term of each local DOF. |

Table: Derived type `COUPLING_TABLE_TYPE` — COUPLED(t,s): the expansion nodes t and s share a sub-element.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUPLED` | `LOGICAL, ALLOCATABLE` | `(:,:)` | `` | Coupling flags of expansion terms. |

Table: Procedures of `MUL2_SPARSE_ASSEMBLY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_AND_ASSEMBLE_SPARSE_SYSTEM` | Subroutine | public | Pattern + assembly from dense element matrices (reference path used by the unit tests). |
| `BUILD_SPARSE_PATTERN` | Subroutine | public | CSR pattern from the DOF lists of dense element matrices. |
| `BUILD_PATTERN_FROM_DOF_LISTS` | Subroutine | public | Csr pattern from the dof lists alone (no element matrices needed). row r collects the dofs of every element touching r, without duplicates, sorted. memory is proportional to the final nnz. |
| `ARE_COUPLED` | Function → logical | private | False only for two lagrange-expansion dofs of the same table whose terms do not share a sub-element (their entry is exactly zero). |
| `SORT_SEGMENT` | Subroutine | private | Ascending sort of column(first:last) (insertion, heap for long rows). |
| `SIFT_COLUMN` | Subroutine | private | Heap-sort helper for SORT_SEGMENT. |
| `SCATTER_ELEMENT` | Subroutine | public | Add one element matrix pair into the shared pattern (binary search in every row; no allocation, no pattern change). |
| `BUILD_SCATTER_MAPS` | Subroutine | private | Precompute CSR_POSITION of every element entry. |
| `ASSEMBLE_ELEMENT_MATRICES` | Subroutine | public | Add dense element matrices through precomputed scatter maps. |
| `FIND_CSR_POSITION` | Function → integer(i8) | private | Position of (row, column) in the CSR arrays, 0 when absent. |
| `SORT_COORDINATES` | Subroutine | private | Sort (row, column) pairs lexicographically. |
| `SIFT_DOWN` | Subroutine | private | Heap-sort helper. |
| `PAIR_LESS` | Function → logical | private | Lexicographic comparison of two (row, column) pairs. |
| `SWAP_PAIR` | Subroutine | private | Swap two (row, column) pairs. |
| `CLEAR_SPARSE_SYSTEM` | Subroutine | public | Release a CSR system. |

#### `BUILD_AND_ASSEMBLE_SPARSE_SYSTEM`

Pattern + assembly from dense element matrices (reference path used by the unit tests).

| Argument | Declaration | Meaning |
|---|---|---|
| `TOTAL_DOF` | `INTEGER(I8), intent(IN)` | Total number of DOFs. |
| `ELEMENT_MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)(:)` | Dense element matrices with their DOF lists. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_SPARSE_PATTERN`

CSR pattern from the DOF lists of dense element matrices.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOTAL_DOF` | `INTEGER(I8), intent(IN)` | Total number of DOFs. |
| `ELEMENT_MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(INOUT)(:)` | Dense element matrices with their DOF lists. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_PATTERN_FROM_DOF_LISTS`

Csr pattern from the dof lists alone (no element matrices needed). row r collects the dofs of every element touching r, without duplicates, sorted. memory is proportional to the final nnz.

| Argument | Declaration | Meaning |
|---|---|---|
| `TOTAL_DOF` | `INTEGER(I8), intent(IN)` | Total number of DOFs. |
| `LISTS` | `TYPE(DOF_LIST_TYPE), intent(IN)(:)` | DOF lists of all elements. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `WITH_MASS` | `LOGICAL, intent(IN), OPTIONAL` | Also build the mass matrix. |
| `TABLES` | `TYPE(COUPLING_TABLE_TYPE), intent(IN), OPTIONAL(:)` | Lagrange coupling tables (one per expansion mesh). |

#### `SCATTER_ELEMENT`

Add one element matrix pair into the shared pattern (binary search in every row; no allocation, no pattern change).

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `GLOBAL_DOF` | `INTEGER(I8), intent(IN)(:)` | Global DOF numbers of the local DOFs. |
| `STIFFNESS` | `REAL(R8), intent(IN)(:,:)` | Dense element stiffness. |
| `MASS` | `REAL(R8), intent(IN)(:,:)` | Dense element mass (may be empty). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `ASSEMBLE_ELEMENT_MATRICES`

Add dense element matrices through precomputed scatter maps.

| Argument | Declaration | Meaning |
|---|---|---|
| `ELEMENT_MATRICES` | `TYPE(ELEMENT_MATRIX_TYPE), intent(IN)(:)` | Dense element matrices with their DOF lists. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `CLEAR_SPARSE_SYSTEM`

Release a CSR system.

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |

### MUL2_SPARSE_OPERATIONS

File `SRC/ASSEMBLY/mul2_sparse_operations.for`.

Basic operations on the shared csr pattern. reduction to the free dofs keeps a map from every reduced entry to its position in the full pattern, so that any value array (k, m or a combination) is reduced without re-building the pattern.

Uses: `MUL2_KINDS`.

Table: Derived type `REDUCED_PATTERN_TYPE` — CSR pattern of the free-DOF sub-matrix and the maps to the full numbering.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ORDER` | `INTEGER(I8)` | `` | `0_I8` | Order of the matrix / expansion order / quadrature order (see type). |
| `NONZERO_COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of stored entries. |
| `FREE_TO_GLOBAL` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Free DOF -> global DOF. |
| `ROW_POINTER` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR row pointer. |
| `COLUMN_INDEX` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR column indices. |
| `SOURCE_POSITION` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | Position in the full CSR of every reduced entry. |

Table: Procedures of `MUL2_SPARSE_OPERATIONS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `SPARSE_MULTIPLY` | Subroutine | public | Y = a x for a full (non-triangular) csr matrix. |
| `BUILD_REDUCED_PATTERN` | Subroutine | public | Pattern of the submatrix on the dofs with constrained(dof) = false. |
| `REDUCE_VALUES` | Subroutine | public | Copy the values of a full matrix into the reduced pattern. |
| `EXPAND_VECTOR` | Subroutine | public | Scatter a reduced vector back to the full dof numbering. |

#### `SPARSE_MULTIPLY`

Y = a x for a full (non-triangular) csr matrix.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer (1-based, size N+1). |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `VALUE` | `REAL(R8), intent(IN)(:)` | Value(s) (see routine). |
| `X` | `REAL(R8), intent(IN)(:)` | Vector or coordinate. |
| `Y` | `REAL(R8), intent(OUT)(:)` | Result vector. |

#### `BUILD_REDUCED_PATTERN`

Pattern of the submatrix on the dofs with constrained(dof) = false.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer (1-based, size N+1). |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `CONSTRAINED` | `LOGICAL, intent(IN)(:)` | Flags of constrained DOFs. |
| `PATTERN` | `TYPE(REDUCED_PATTERN_TYPE), intent(INOUT)` | Reduced CSR pattern with maps. |

#### `REDUCE_VALUES`

Copy the values of a full matrix into the reduced pattern.

| Argument | Declaration | Meaning |
|---|---|---|
| `PATTERN` | `TYPE(REDUCED_PATTERN_TYPE), intent(IN)` | Reduced CSR pattern with maps. |
| `FULL_VALUE` | `REAL(R8), intent(IN)(:)` | Values of the full CSR matrix. |
| `REDUCED_VALUE` | `REAL(R8), intent(OUT)(:)` | Output: values on the reduced pattern. |

#### `EXPAND_VECTOR`

Scatter a reduced vector back to the full dof numbering.

| Argument | Declaration | Meaning |
|---|---|---|
| `PATTERN` | `TYPE(REDUCED_PATTERN_TYPE), intent(IN)` | Reduced CSR pattern with maps. |
| `REDUCED` | `REAL(R8), intent(IN)(:)` | Vector on the free DOFs. |
| `FULL` | `REAL(R8), intent(INOUT)(:)` | Output: vector in the full DOF numbering. |

## Layer BOUNDARY {#sec:ref_boundary}

Constraints and loads.

### MUL2_BOUNDARY_APPLICATION

File `SRC/BOUNDARY/mul2_boundary_application.for`.

Geometric mechanical bc resolution and exact static elimination.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_BOUNDARY_CONDITIONS`, `MUL2_NODES`, `MUL2_INCIDENCE`, `MUL2_ELEMENTS`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_GENERAL_GEOMETRY`, `MUL2_DOF_LAYOUT`, `MUL2_CUF_BASES`, `MUL2_TOPOLOGIES`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_FIELDS`.

Table: Derived type `CONSTRAINT_SET_TYPE` — Constrained-DOF flags and prescribed values.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I8)` | `` | `0_I8` | Number of items. |
| `ACTIVE` | `LOGICAL, ALLOCATABLE` | `(:)` | `` | Flags. |
| `VALUE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Values. |
| `HAS_TIES` | `LOGICAL` | `` | `.FALSE.` | Ties (floating electrodes): master(i) = i, or the dof that holds the value of the dof i (a slave, also marked active). |
| `MASTER` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` |  |

Table: Procedures of `MUL2_BOUNDARY_APPLICATION`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_MECHANICAL_BOUNDARY_DATA` | Subroutine | public | Constraints and loads of bc.dat; fields (fields.dat) are optional. |
| `BUILD_BOUNDARY_WITH_FIELDS` | Subroutine | private |  |
| `ADD_PLANE_TIE` | Subroutine | private | Floating electrode: the electric-potential dofs of the lagrange (or hierarchical vertex) section nodes on the plane are tied to the first one; the others become inactive slaves (value 0). |
| `APPLY_DOF_TIES` | Subroutine | public | K = t^t k t and f = t^t f for the ties: the rows and columns of the slaves are added to those of their master; a slave keeps a unit diagonal (it is constrained to zero and copied from the master after the solution). k and, when allocated, m share the pattern. |
| `SHIFT_ENTRY` | Subroutine | private | Move entry i to position target (<= i), shifting the others up. |
| `EXPAND_TIES` | Subroutine | public | Copy the value of every master to its slaves. |
| `ADD_PLANE_CONSTRAINT` | Subroutine | private | Constrain the DOFs of every node/term whose physical position lies on the plane A x + B y + C z + D = 0. |
| `HLE_TERM_ON_PLANE` | Function → logical | private | A hle term is on the plane when its vertex, both ends of its side or all the vertices of its sub-element are. |
| `ADD_POINT_FORCE` | Subroutine | private | Add a point load at a physical position: nodal term for Lagrange, projection on all monomials for Taylor. |
| `ADD_POINT_VALUE` | Subroutine | private | Prescribed field value (e.g. electric potential) at a section node of a lagrange or hierarchical expansion. |
| `APPLY_STATIC_CONSTRAINTS` | Subroutine | public | Exact symmetric elimination: F = F - K u_c, zero rows/columns of constrained DOFs, unit diagonal. |
| `SET_DOF_CONSTRAINT` | Subroutine | private | Mark one DOF as constrained; conflicting values are an error. |
| `FIRST_ELEMENT` | Function → integer(i4) | private | First element incident to a node (0 if none). |
| `EXPANDED_POINT` | Subroutine | private | Physical position of a section point: node + frame * local section coordinate. |
| `PLACED_POINT` | Subroutine | public | Global position of a point of the expansion mesh at a node, seen by the element: the frame of an ordinary element, the triad of the node of a curved beam / shell. |
| `POINT_ON_PLANE` | Function → logical | private | Plane test with a scaled tolerance. |
| `FIND_EXPANSION_AXES` | Subroutine | private | Active local axes and dimension of an expansion mesh from its node extent. |
| `CLEAR_BOUNDARY_DATA` | Subroutine | private | Release the constraint set and force vector. |

#### `BUILD_MECHANICAL_BOUNDARY_DATA`

Constraints and loads of bc.dat; fields (fields.dat) are optional.

| Argument | Declaration | Meaning |
|---|---|---|
| `BOUNDARIES` | `TYPE(BOUNDARY_DB_TYPE), intent(IN)` | Boundary-condition database. |
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Global DOF numbering. |
| `TOLERANCE` | `REAL(R8), intent(IN)` | Geometric tolerance. |
| `CONSTRAINTS` | `TYPE(CONSTRAINT_SET_TYPE), intent(INOUT)` | Constrained-DOF set (flags and prescribed values). |
| `FORCE` | `REAL(R8), ALLOCATABLE, intent(INOUT)(:)` | Global force vector. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `FIELDS` | `TYPE(FIELD_DB_TYPE), intent(IN), OPTIONAL` |  |

#### `APPLY_DOF_TIES`

K = t^t k t and f = t^t f for the ties: the rows and columns of the slaves are added to those of their master; a slave keeps a unit diagonal (it is constrained to zero and copied from the master after the solution). k and, when allocated, m share the pattern.

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `FORCE` | `REAL(R8), intent(INOUT), OPTIONAL(:)` | Global force vector. |
| `CONSTRAINTS` | `TYPE(CONSTRAINT_SET_TYPE), intent(IN)` | Constrained-DOF set (flags and prescribed values). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `EXPAND_TIES`

Copy the value of every master to its slaves.

| Argument | Declaration | Meaning |
|---|---|---|
| `CONSTRAINTS` | `TYPE(CONSTRAINT_SET_TYPE), intent(IN)` | Constrained-DOF set (flags and prescribed values). |
| `VECTOR` | `REAL(R8), intent(INOUT)(:)` | Vector(s) / eigenvectors. |

#### `APPLY_STATIC_CONSTRAINTS`

Exact symmetric elimination: F = F - K u_c, zero rows/columns of constrained DOFs, unit diagonal.

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `FORCE` | `REAL(R8), intent(INOUT)(:)` | Global force vector. |
| `CONSTRAINTS` | `TYPE(CONSTRAINT_SET_TYPE), intent(IN)` | Constrained-DOF set (flags and prescribed values). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `PLACED_POINT`

Global position of a point of the expansion mesh at a node, seen by the element: the frame of an ordinary element, the triad of the node of a curved beam / shell.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `ELEMENT_INDEX` | `INTEGER(I4), intent(IN)` | Index of the element in the element database. |
| `NODE_INDEX` | `INTEGER(I4), intent(IN)` |  |
| `LOCAL_POINT` | `REAL(R8), intent(IN)(3)` |  |
| `PHYSICAL_POINT` | `REAL(R8), intent(OUT)(3)` |  |
| `MID_SURFACE` | `LOGICAL, intent(IN), OPTIONAL` | Mid_surface: a plane selects the nodes of a shell by their mid-surface point (the director is not exactly the normal of a symmetry plane), and constrains the whole thickness. |

### MUL2_COINCIDENT_JOIN

File `SRC/BOUNDARY/mul2_coincident_join.for`.

Joining of degrees of freedom by coincidence of their positions. the ordinary joint is the shared node (same node number in the elements). with `join coincident` in analysis.dat the degrees of freedom of different nodes are also identified when they are the same field at the same point of space, as in the historical code: a beam whose section node lies on a plate joins the plate even if the structural nodes of the two elements are different. le the dof of a node of the expansion mesh is the field at the point x(node) + offset(expansion node). te the term 1 (the field at the node) is joined at the same point; the higher terms only when the two elements have the same orientation (they are derivatives along the element axes). hle not joined (side and internal modes are not values). the dof are renumbered: the alias table of the layout maps every provisional dof to its final number (global_dof applies it).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_NODES`, `MUL2_INCIDENCE`, `MUL2_ELEMENTS`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_GENERAL_GEOMETRY`, `MUL2_DOF_LAYOUT`, `MUL2_BOUNDARY_APPLICATION`.

Table: Procedures of `MUL2_COINCIDENT_JOIN`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `JOIN_COINCIDENT_DOFS` | Subroutine | public | Relative_tolerance is a fraction of the diagonal of the model. |
| `ADD_ENTRY` | Subroutine | private | Add a value to one matrix entry. |
| `GLOBAL_DOF_RAW` | Function → integer(i8) | private | Dof number before any alias (the layout has none yet). |
| `CELL_OF` | Subroutine | private |  |
| `BUCKET_INDEX` | Function → integer(i4) | private |  |
| `FIND_ROOT` | Function → integer(i8) | private |  |
| `JOINABLE` | Function → logical | private |  |

#### `JOIN_COINCIDENT_DOFS`

Relative_tolerance is a fraction of the diagonal of the model.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES` | `TYPE(NODE_DB_TYPE), intent(IN)` | Structural node database. |
| `ELEMENTS` | `TYPE(ELEMENT_DB_TYPE), intent(IN)` | Structural element database. |
| `KINEMATICS` | `TYPE(KINEMATICS_DB_TYPE), intent(IN)` | Field-dependent kinematics database. |
| `EXPANSIONS` | `TYPE(EXPANSION_DB_TYPE), intent(IN)` | Expansion (section/thickness) mesh database. |
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE), intent(IN)` | Element reference frames. |
| `RELATIVE_TOLERANCE` | `REAL(R8), intent(IN)` |  |
| `LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(INOUT)` | Gauss-point layout (global point numbering). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_SURFACE_LOADS

File `SRC/BOUNDARY/mul2_surface_loads.for`.

Surface heat loads on the exposed skin of the model. a surface piece is the product of a part of the structural element and a part of the expansion sub-element, with two parameters in all: beam (1d x 2d): axis x edge of the section (lateral skin) end node x whole section (end faces) plate (2d x 1d): surface x end of the thickness (top, bottom) edge x whole thickness (sides) solid (3d x 0d): face of the element a piece is exposed when no other piece has the same centre (shared faces are interior). the outward normal points away from the centre of the element. loads (q > 0 heats the body), all on the temperature field (4): 1 flux q = q0 on the pieces of a plane 2 sun q = absorptivity g max(0, n.s) (s: towards the sun) 3 convection q = h (t_inf - t) on the pieces of a plane the convection adds h int n n^t to the conduction matrix.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_BOUNDARY_CONDITIONS`, `MUL2_RECOVERY`, `MUL2_TOPOLOGIES`, `MUL2_SHAPE_FUNCTIONS`, `MUL2_QUADRATURE`, `MUL2_NODES`, `MUL2_KINEMATICS`, `MUL2_DOF_LAYOUT`, `MUL2_POINT_BASES`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_SORTING`, `MUL2_FIELDS`.

Table: Derived type `PART_TYPE` — Part of a natural domain: natural = a + m (u, v). kind: 0 point, 1 line, 2 square, 3 triangle (the parameters are the first columns).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `KIND` | `INTEGER(I4)` | `` | `0_I4` | Record kind. |
| `WHOLE` | `LOGICAL` | `` | `.FALSE.` |  |
| `A` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `M` | `REAL(R8)` | `(3,2)` | `0.0_R8` |  |

Table: Procedures of `MUL2_SURFACE_LOADS`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `APPLY_SURFACE_LOADS` | Subroutine | public |  |
| `MESH_OF` | Function → integer(i4) | private |  |
| `STRUCTURAL_PARTS` | Subroutine | private | Parts of the natural domain of a topology that can build a surface. |
| `PART_DIMENSION` | Function → integer(i4) | private |  |
| `PIECE_IS_SURFACE` | Function → logical | private | A piece is a surface when the two parts have two parameters in all and are not both the whole domain. |
| `PART_CENTRE` | Subroutine | private | Natural coordinates of the centre of a part. |
| `PIECE_CENTRE` | Subroutine | private | Physical position of the centre of a piece. |
| `ELEMENT_REFERENCE` | Subroutine | private | Centre of the element (sub-element): the normals point away from it. |
| `FIND_EXPOSED` | Subroutine | private | Exposed = no other piece has the same centre. |
| `PART_RULE` | Subroutine | private |  |
| `INTEGRATE_PIECE` | Subroutine | private | Integral of all the surface loads over one exposed piece. |
| `ON_PLANE` | Function → logical | private | The zero plane selects everything. |

#### `APPLY_SURFACE_LOADS`

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `FORCE` | `REAL(R8), intent(INOUT)(:)` | Global force vector. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer SOLVERS {#sec:ref_solvers}

PARDISO wrappers and the modal eigensolver (ARPACK / dense).

### MUL2_MODAL_SOLVER

File `SRC/SOLVERS/mul2_modal_solver.for`.

Generalized symmetric eigenproblem k x = lambda m x. arpack (dsaupd/dseupd, mode 3, bmat = g) with spectral transformation op = inv(k - sigma*m)*m; the linear systems are solved with one pardiso factorization. small problems (or nev near n) use dense lapack dsygv. the k-shift residual is re-computed from the matrices. arpack is built with 64-bit integers and logicals (ilp64 mkl). eigenvalues are returned in ascending order, eigenvectors are m-orthonormal: x(i)**t m x(j) = delta(i,j).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_SPARSE_OPERATIONS`, `MUL2_PARDISO_FACTOR`.

Table: Derived type `MODAL_INFO_TYPE` — Statistics of the eigensolver run.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `BACKEND` | `CHARACTER(LEN=8)` | `` | `' '` | Solver used. |
| `ORDER` | `INTEGER(I8)` | `` | `0_I8` | Order of the matrix / expansion order / quadrature order (see type). |
| `REQUESTED` | `INTEGER(I8)` | `` | `0_I8` | Requested modes. |
| `CONVERGED` | `INTEGER(I8)` | `` | `0_I8` | Converged modes. |
| `SUBSPACE` | `INTEGER(I8)` | `` | `0_I8` | Krylov subspace. |
| `ITERATIONS` | `INTEGER(I8)` | `` | `0_I8` | Iterations. |
| `OPERATIONS` | `INTEGER(I8)` | `` | `0_I8` | Operator applications. |
| `SIGMA` | `REAL(R8)` | `` | `0.0_R8` | Shift. |

Table: Procedures of `MUL2_MODAL_SOLVER`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `DSAUPD` | Subroutine | external (MKL/ARPACK/LAPACK) | ARPACK reverse-communication driver (external). |
| `DSEUPD` | Subroutine | external (MKL/ARPACK/LAPACK) | ARPACK eigenvalue/eigenvector extraction (external). |
| `DSYGV` | Subroutine | external (MKL/ARPACK/LAPACK) | LAPACK dense generalised symmetric eigenproblem (external). |
| `DSYSV` | Subroutine | external (MKL/ARPACK/LAPACK) |  |
| `SOLVE_MODAL_PROBLEM` | Subroutine | public | Solve for the nev eigenvalues closest to sigma. row_pointer/column_index: full symmetric csr shared by k and m. eigenvalue(1:nev) ascending; vector(:,i) m-orthonormal; residual(i) = \|\|k x - lambda m x\|\| / \|\|k x\|\|. |
| `SOLVE_ARPACK` | Subroutine | private | Arpack, shift-invert, pardiso |
| `HAS_MASSLESS_ROW` | Function → logical | private | Dense lapack fallback a row of m without any non-zero value (a dof that carries no mass, e.g. an electric potential). |
| `SOLVE_DENSE` | Subroutine | private | Dense fallback with dsygv for N <= 400 or almost all modes requested. |
| `DENSE_GENERALIZED` | Subroutine | private | A x = lambda b x for symmetric a and b. b singular: m x = mu k x with k positive definite. returns the lambda in ascending order and the b-orthonormal vectors (a and b are destroyed). |
| `SORT_MODES` | Subroutine | private | Ascending order of the eigenvalues (selection sort, vectors follow). |
| `COMPUTE_RESIDUALS` | Subroutine | private | Relative residual \|\|K x - lambda M x\|\| of every mode. |
| `SOLVE_BUCKLING_DENSE` | Subroutine | public | Linear buckling (k + lambda g) x = 0 on a full symmetric csr pattern, by lapack. rows without geometric stiffness (electric potential) are condensed out. with k positive definite the pencil g x = mu k x has mu = -1/lambda: the negative mu give the positive load factors, returned in ascending order (the modes are k-orthonormal). |

#### `SOLVE_MODAL_PROBLEM`

Solve for the nev eigenvalues closest to sigma. row_pointer/column_index: full symmetric csr shared by k and m. eigenvalue(1:nev) ascending; vector(:,i) m-orthonormal; residual(i) = ||k x - lambda m x|| / ||k x||.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer of the reduced (free-DOF) matrices. |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `STIFFNESS` | `REAL(R8), intent(IN)(:)` | Stiffness matrix (or values). |
| `MASS` | `REAL(R8), intent(IN)(:)` | Mass matrix (or values). |
| `NEV` | `INTEGER(I4), intent(IN)` | Number of requested modes. |
| `SIGMA` | `REAL(R8), intent(IN)` | Spectral shift. |
| `EIGENVALUE` | `REAL(R8), intent(OUT)(:)` | Eigenvalues (omega^2). |
| `VECTOR` | `REAL(R8), intent(OUT)(:,:)` | Vector(s) / eigenvectors. |
| `RESIDUAL` | `REAL(R8), intent(OUT)(:)` | Relative residuals. |
| `INFO` | `TYPE(MODAL_INFO_TYPE), intent(OUT)` | Solver information (backend, iterations, subspace). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `SOLVE_BUCKLING_DENSE`

Linear buckling (k + lambda g) x = 0 on a full symmetric csr pattern, by lapack. rows without geometric stiffness (electric potential) are condensed out. with k positive definite the pencil g x = mu k x has mu = -1/lambda: the negative mu give the positive load factors, returned in ascending order (the modes are k-orthonormal).

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer (1-based, size N+1). |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `STIFFNESS` | `REAL(R8), intent(IN)(:)` | Stiffness matrix (or values). |
| `GEOMETRIC` | `REAL(R8), intent(IN)(:)` |  |
| `NEV` | `INTEGER(I4), intent(IN)` | Number of requested modes. |
| `FACTOR` | `REAL(R8), intent(OUT)(:)` | PARDISO handle with factors and stored matrix. |
| `VECTOR` | `REAL(R8), intent(OUT)(:,:)` | Vector(s) / eigenvectors. |
| `COUNT` | `INTEGER(I4), intent(OUT)` | Number of items. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_PARDISO_FACTOR

File `SRC/SOLVERS/mul2_pardiso_factor.for`.

Mkl pardiso ilp64 factorization of real symmetric csr matrices. the caller passes the full symmetric csr (1-based, ilp64). the upper triangle required by mtype 2/-2 is extracted here and kept inside the factor handle. the factors are released with pardiso_release.

Uses: `MUL2_KINDS`, `MUL2_STATUS`.

Table: Public constants of `MUL2_PARDISO_FACTOR`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `MTYPE_SYMMETRIC_POSITIVE` | `INTEGER(I8)` | `2_I8` | PARDISO matrix type. |
| `MTYPE_SYMMETRIC_INDEFINITE` | `INTEGER(I8)` | `-2_I8` | PARDISO matrix type. |
| `MTYPE_NONSYMMETRIC` | `INTEGER(I8)` | `11_I8` | Real non-symmetric (structurally symmetric) matrix: the full csr is kept in the handle. |

Table: Derived type `PARDISO_FACTOR_TYPE` — PARDISO handle: internal pointers, parameters and the stored upper triangle.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ACTIVE` | `LOGICAL` | `` | `.FALSE.` | Flags. |
| `ORDER` | `INTEGER(I8)` | `` | `0_I8` | Order of the matrix / expansion order / quadrature order (see type). |
| `MTYPE` | `INTEGER(I8)` | `` | `0_I8` | Matrix type. |
| `PT` | `INTEGER(I8)` | `(64)` | `0_I8` | PARDISO internal pointers. |
| `IPARM` | `INTEGER(I8)` | `(64)` | `0_I8` | PARDISO parameters. |
| `ROW_POINTER` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR row pointer. |
| `COLUMN_INDEX` | `INTEGER(I8), ALLOCATABLE` | `(:)` | `` | CSR column indices. |
| `VALUE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Values. |

Table: Procedures of `MUL2_PARDISO_FACTOR`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `PARDISO` | Subroutine | external (MKL/ARPACK/LAPACK) | MKL PARDISO entry point (external, ILP64). |
| `PARDISO_FACTORIZE` | Subroutine | public | Reorder and factorize (phase 12) a full symmetric csr system. |
| `PARDISO_SET_SYSTEM` | Subroutine | public | Copy the upper triangle into the handle. afterwards the caller may free its own copy of the system before the factorization. |
| `PARDISO_FACTOR_LOADED` | Subroutine | public | Phase 12 on the matrix stored in the handle. a cholesky breakdown (round-off in a very ill-conditioned spd matrix, e.g. high-order taylor expansions) is retried with the symmetric indefinite factorization and pivot perturbation. |
| `PARDISO_FREE_INTERNAL` | Subroutine | private | Free the internal memory of pardiso but keep the matrix. |
| `PARDISO_SOLVE` | Subroutine | public | Solve a x = b with the factors of the handle (phase 33). |
| `PARDISO_RELEASE` | Subroutine | public | Free the internal memory of pardiso (phase -1). safe to repeat. |
| `EXTRACT_UPPER_TRIANGLE` | Subroutine | private | Upper triangle of a symmetric CSR matrix. |
| `PARDISO_HINT` | Function → character(len=64) | private | Meaning of the most common pardiso error codes. |

#### `PARDISO_FACTORIZE`

Reorder and factorize (phase 12) a full symmetric csr system.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer (1-based, size N+1). |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `VALUE` | `REAL(R8), intent(IN)(:)` | Value(s) (see routine). |
| `MTYPE` | `INTEGER(I8), intent(IN)` | PARDISO matrix type (2 SPD, -2 symmetric indefinite). |
| `FACTOR` | `TYPE(PARDISO_FACTOR_TYPE), intent(INOUT)` | PARDISO handle with factors and stored matrix. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `PARDISO_SET_SYSTEM`

Copy the upper triangle into the handle. afterwards the caller may free its own copy of the system before the factorization.

| Argument | Declaration | Meaning |
|---|---|---|
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `ROW_POINTER` | `INTEGER(I8), intent(IN)(:)` | CSR row pointer (1-based, size N+1). |
| `COLUMN_INDEX` | `INTEGER(I8), intent(IN)(:)` | CSR column indices (1-based). |
| `VALUE` | `REAL(R8), intent(IN)(:)` | Value(s) (see routine). |
| `FACTOR` | `TYPE(PARDISO_FACTOR_TYPE), intent(INOUT)` | PARDISO handle with factors and stored matrix. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `FULL` | `LOGICAL, intent(IN), OPTIONAL` | Full = .true.: keep the whole (non-symmetric) matrix. |

#### `PARDISO_FACTOR_LOADED`

Phase 12 on the matrix stored in the handle. a cholesky breakdown (round-off in a very ill-conditioned spd matrix, e.g. high-order taylor expansions) is retried with the symmetric indefinite factorization and pivot perturbation.

| Argument | Declaration | Meaning |
|---|---|---|
| `MTYPE` | `INTEGER(I8), intent(IN)` | PARDISO matrix type (2 SPD, -2 symmetric indefinite). |
| `FACTOR` | `TYPE(PARDISO_FACTOR_TYPE), intent(INOUT)` | PARDISO handle with factors and stored matrix. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `PARDISO_SOLVE`

Solve a x = b with the factors of the handle (phase 33).

| Argument | Declaration | Meaning |
|---|---|---|
| `FACTOR` | `TYPE(PARDISO_FACTOR_TYPE), intent(INOUT)` | PARDISO handle with factors and stored matrix. |
| `RIGHT_HAND_SIDE` | `REAL(R8), intent(IN)(:)` | Right-hand side vector. |
| `SOLUTION` | `REAL(R8), intent(OUT)(:)` | Output: solution vector. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `PARDISO_RELEASE`

Free the internal memory of pardiso (phase -1). safe to repeat.

| Argument | Declaration | Meaning |
|---|---|---|
| `FACTOR` | `TYPE(PARDISO_FACTOR_TYPE), intent(INOUT)` | PARDISO handle with factors and stored matrix. |

### MUL2_PARDISO_SOLVER

File `SRC/SOLVERS/mul2_pardiso_solver.for`.

One-shot linear solve for real symmetric positive-definite csr systems (static analysis) on top of mul2_pardiso_factor.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_PARDISO_FACTOR`.

Table: Procedures of `MUL2_PARDISO_SOLVER`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `SOLVE_SYMMETRIC_POSITIVE_DEFINITE` | Subroutine | public | Static solver: set, optionally release the caller matrix, factorize, solve. |

#### `SOLVE_SYMMETRIC_POSITIVE_DEFINITE`

Static solver: set, optionally release the caller matrix, factorize, solve.

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Sparse system (CSR pattern, K, M). |
| `RIGHT_HAND_SIDE` | `REAL(R8), intent(IN)(:)` | Right-hand side vector. |
| `SOLUTION` | `REAL(R8), ALLOCATABLE, intent(INOUT)(:)` | Global displacement vector. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `RELEASE_SYSTEM` | `LOGICAL, intent(IN), OPTIONAL` | True frees the caller matrix right after PARDISO has copied it. |

## Layer ANALYSES {#sec:ref_analyses}

Model cache, parallel assembly, analyses 101 and 103, driver.

### MUL2_ANALYSIS_101

File `SRC/ANALYSES/mul2_analysis_101.for`.

Solution 101: linear static mechanical analysis. assemble k -> loads and boundary conditions -> exact symmetric elimination -> pardiso -> displacement coefficients

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_KINEMATICS`, `MUL2_SURFACE_LOADS`, `MUL2_PARDISO_FACTOR`, `MUL2_BOUNDARY_APPLICATION`, `MUL2_PARDISO_SOLVER`, `MUL2_ANALYSIS_RESULTS`.

Table: Procedures of `MUL2_ANALYSIS_101`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_STATIC_ANALYSIS` | Subroutine | public | Analysis 101: assemble K, build loads and constraints, eliminate constraints exactly, factorize with PARDISO and solve K u = F. |
| `SOLVE_THERMOELASTIC` | Subroutine | private | Monolithic thermoelasticity: the system [ k_uu k_ut ] [u] [f] [ 0 k_tt ] [t] = [q] is non-symmetric and solved in one pardiso factorization (mtype 11). |

#### `RUN_STATIC_ANALYSIS`

Analysis 101: assemble K, build loads and constraints, eliminate constraints exactly, factorize with PARDISO and solve K u = F.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_103

File `SRC/ANALYSES/mul2_analysis_103.for`.

Solution 103: linear free vibrations. assemble k, m -> eliminate constrained dofs -> arpack/pardiso -> expand modes -> frequencies f = sqrt(lambda) / (2 pi) constrained dofs are removed from the problem (the baseline adds a large penalty to k instead). prescribed non-zero displacements and forces have no meaning here and are ignored with a warning.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_MODEL`, `MUL2_KINEMATICS`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_BOUNDARY_APPLICATION`, `MUL2_SPARSE_OPERATIONS`, `MUL2_MODAL_SOLVER`, `MUL2_ANALYSIS_RESULTS`.

Table: Procedures of `MUL2_ANALYSIS_103`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_MODAL_ANALYSIS` | Subroutine | public | Analysis 103: assemble K and M, reduce to the free DOF, solve K x = lambda M x with shift-invert ARPACK (or dense LAPACK) and sort the modes. |

#### `RUN_MODAL_ANALYSIS`

Analysis 103: assemble K and M, reduce to the free DOF, solve K x = lambda M x with shift-invert ARPACK (or dense LAPACK) and sort the modes.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_104

File `SRC/ANALYSES/mul2_analysis_104.for`.

SOLUTION 104: LINEAR TIME RESPONSE (NEWMARK). MONOLITHIC SYSTEM FOR ALL THE PHYSICS IN ONE EFFECTIVE MATRIX, U (FIELDS 1-3) SECOND ORDER: M A + C V + K X = F (NEWMARK) T (FIELD 4) FIRST ORDER: CAP TDOT + K_T T + ... = Q (THETA) P (FIELD 5) ALGEBRAIC: NO INERTIA WITH C = ALPHA M + BETA K ON THE MECHANICAL DOFS (RAYLEIGH). WHEN THE ABSOLUTE REFERENCE TEMPERATURE T0 IS GIVEN THE THERMOELASTIC HEATING TERM T0 (-K_UT)^T V IS ADDED TO THE TEMPERATURE ROWS (TWO-WAY COUPLING, THERMOELASTIC DAMPING). EVERY LOAD AND EVERY PRESCRIBED VALUE IS MULTIPLIED BY THE AMPLITUDE a(t) OF TIME_RESP.DAT. THE INITIAL STATE IS A(0) TIMES THE PRESCRIBED VALUES, ZERO VELOCITY, TEMPERATURE ZERO. THE EFFECTIVE MATRIX IS FACTORED ONCE (CONSTANT STEP).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_BOUNDARY_APPLICATION`, `MUL2_SURFACE_LOADS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_SPARSE_OPERATIONS`, `MUL2_PARDISO_FACTOR`, `MUL2_KINEMATICS`, `MUL2_DYNAMIC_COMMON`, `MUL2_TIME_INPUT`, `MUL2_POST_OUTPUT`, `MUL2_ANALYSIS_RESULTS`.

Table: Procedures of `MUL2_ANALYSIS_104`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_TIME_ANALYSIS` | Subroutine | public |  |
| `INITIAL_ACCELERATION` | Subroutine | private | A(0) from m a = f - k x (free mechanical dofs only). |

#### `RUN_TIME_ANALYSIS`

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_105

File `SRC/ANALYSES/mul2_analysis_105.for`.

SOLUTION 105: LINEAR BUCKLING. STATIC SOLUTION UNDER THE REFERENCE LOADS (101, THERMAL LOADS INCLUDED) -> GEOMETRIC MATRIX K_G OF ITS STRESS FIELD -> (K + LAMBDA K_G) X = 0 ON THE FREE MECHANICAL DOFS. THE TEMPERATURE IS A GIVEN FIELD OF THE PRE-STRESS (ITS DOFS ARE NOT PART OF THE EIGENPROBLEM); THE ELECTRIC POTENTIAL IS CONDENSED OUT (CLOSED-CIRCUIT STIFFNESS WITH THE PRESCRIBED ELECTRODES). LAMBDA IS THE FACTOR THAT MULTIPLIES THE REFERENCE LOAD, THE CRITICAL LOAD IS LAMBDA TIMES THE APPLIED ONE. RESULTS: DYNAMIC/ BUCKLING_FACTORS.dat AND THE BUCKLING MODES (RESULTS_DYN_*.vtk/msh).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_SPARSE_OPERATIONS`, `MUL2_MODAL_SOLVER`, `MUL2_DOF_LAYOUT`, `MUL2_ANALYSIS_RESULTS`, `MUL2_ANALYSIS_101`.

Table: Procedures of `MUL2_ANALYSIS_105`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_BUCKLING_ANALYSIS` | Subroutine | public |  |

#### `RUN_BUCKLING_ANALYSIS`

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_106

File `SRC/ANALYSES/mul2_analysis_106.for`.

SOLUTION 106: HARMONIC (FREQUENCY) RESPONSE. ( K - W**2 M + I W C ) X = F F: THE LOADS OF BC.dat, PRESCRIBED VALUES AT PHASE 0 ON EVERY FREQUENCY OF FREQ_RESP.dat. THE COMPLEX SYSTEM IS SOLVED AS THE REAL BLOCK SYSTEM [ AR -AI ] [XR] [FR] [ AI AR ] [XI] = [FI] (PARDISO, ONE FACTORIZATION PER FREQUENCY). ALL THE PHYSICS OF THE TIME ANALYSIS ARE INCLUDED: THE MECHANICAL DOFS HAVE INERTIA AND THE RAYLEIGH DAMPING C = ALPHA M + BETA K, THE ELECTRIC POTENTIAL IS ALGEBRAIC, THE TEMPERATURE ROWS GET I W CAPACITY AND, WITH T0, THE THERMOELASTIC HEATING I W T0 (-K_UT)^T. RESULT: DYNAMIC/FREQ_HISTORY.dat (REAL AND IMAGINARY PARTS).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_BOUNDARY_APPLICATION`, `MUL2_SURFACE_LOADS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_PARDISO_FACTOR`, `MUL2_KINEMATICS`, `MUL2_DYNAMIC_COMMON`, `MUL2_POST_OUTPUT`, `MUL2_ANALYSIS_RESULTS`.

Table: Procedures of `MUL2_ANALYSIS_106`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_FREQUENCY_ANALYSIS` | Subroutine | public |  |

#### `RUN_FREQUENCY_ANALYSIS`

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_108

File `SRC/ANALYSES/mul2_analysis_108.for`.

SOLUTION 108: GEOMETRICALLY NONLINEAR STATIC (TOTAL LAGRANGIAN). NEWTON-RAPHSON WITH LOAD / DISPLACEMENT INCREMENTS. EVERY LOAD AND PRESCRIBED VALUE IS SCALED BY THE FACTOR LAMBDA = N / NLSTEP OF STEP N; THE PHYSICS ARE THOSE OF 101 (MECHANICAL, ELECTRIC POTENTIAL, TEMPERATURE, SURFACE HEAT LOADS) IN THE ONE MONOLITHIC SYSTEM R = LAMBDA F - F_INT(X) - KS X = 0, K_T DX = R WITH F_INT FROM THE GREEN STRAIN AND THE PK2 STRESS OF THE MATERIAL (ST. VENANT-KIRCHHOFF). THE TANGENT IS RE-FACTORED AT EVERY ITERATION. KS IS THE (LINEAR) CONVECTION OF THE SURFACE LOADS. SOLVTEC 2 OF NL_INFO.DAT SELECTS THE ARC-LENGTH METHOD (CRISFIELD, CYLINDRICAL CONSTRAINT ON THE DISPLACEMENTS, ADAPTIVE STEP): LAMBDA BECOMES AN UNKNOWN AND THE PATH CAN PASS LIMIT POINTS (SNAP-THROUGH, SNAP-BACK). IT NEEDS ZERO PRESCRIBED VALUES (THE LOAD IS THE PARAMETER). OUTPUT PER POST STEP: DYNAMIC/TIME_HISTORY.dat (THE TIME COLUMN IS LAMBDA) AND, AT THE END, THE STATIC FILES. STRESSES AND STRAINS OF THE OUTPUT ARE THE LINEARISED MEASURES OF THE FINAL DISPLACEMENTS.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_MODEL_ASSEMBLY`, `MUL2_BOUNDARY_APPLICATION`, `MUL2_SURFACE_LOADS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_SPARSE_OPERATIONS`, `MUL2_PARDISO_FACTOR`, `MUL2_KINEMATICS`, `MUL2_DYNAMIC_COMMON`, `MUL2_POST_OUTPUT`, `MUL2_ANALYSIS_RESULTS`.

Table: Procedures of `MUL2_ANALYSIS_108`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_NONLINEAR_ANALYSIS` | Subroutine | public |  |
| `SOLVE_TWO` | Subroutine | private | Factorises the tangent once and solves for two right-hand sides (the residual and the reference load). the prescribed increments are zero, so the constrained entries of both solutions are zero. |
| `ARC_LENGTH_STEPS` | Subroutine | private | Arc-length path following (crisfield, cylindrical constraint \|du\|^2 = ds^2 on the displacement degrees of freedom). the reference load is the force of the model (lambda = 1); the path ends when lambda reaches lambda_max or after nlstep steps (lambda may become negative on the way: snap-back, inverted snap-through). a step that does not converge is repeated with half the arc length; after a converged step ds is rescaled by sqrt(5/iterations). |

#### `RUN_NONLINEAR_ANALYSIS`

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(INOUT)` | Analysis results container. |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_ANALYSIS_RESULTS

File `SRC/ANALYSES/mul2_analysis_results.for`.

Results shared by the analysis drivers and the post-processing.

Uses: `MUL2_KINDS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_BOUNDARY_APPLICATION`.

Table: Derived type `ANALYSIS_RESULTS_TYPE` — System: k (after the static boundary conditions for 101, full and unconstrained for 103) and, for 103, m on the same pattern. solution: displacement coefficients in field-major dof order. mode(:,k): k-th mode, m-orthonormal, in the same order (dofs on constraints are zero). frequency is in hz, eigenvalue in (rad/s)**2.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `SOLUTION_ID` | `INTEGER(I4)` | `` | `0_I4` | Analysis number (101 or 103). |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE)` | `` | `` | Sparse K and M. |
| `CONSTRAINTS` | `TYPE(CONSTRAINT_SET_TYPE)` | `` | `` | Constrained DOFs. |
| `FORCE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Global force vector. |
| `SOLUTION` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Displacement coefficients in field-major DOF order. |
| `MODE_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of modes (requested / converged). |
| `EIGENVALUE` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Eigenvalues omega^2. |
| `FREQUENCY` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Natural frequencies in Hz. |
| `MODE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | M-orthonormal mode shapes (constrained DOFs = 0). |
| `RESIDUAL` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Relative residual of every mode. |
| `SOLVER_BACKEND` | `CHARACTER(LEN=8)` | `` | `' '` | ARPACK or DENSE. |
| `SOLVER_ITERATIONS` | `INTEGER(I8)` | `` | `0_I8` | Arnoldi update iterations. |
| `SOLVER_OPERATIONS` | `INTEGER(I8)` | `` | `0_I8` | Operator applications. |
| `SOLVER_SUBSPACE` | `INTEGER(I8)` | `` | `0_I8` | Dimension of the Krylov subspace. |
| `ASSEMBLY_SECONDS` | `REAL(R8)` | `` | `0.0_R8` | Wall time of the assembly. |
| `SOLVER_SECONDS` | `REAL(R8)` | `` | `0.0_R8` | Wall time of the solver. |

### MUL2_DRIVER

File `SRC/ANALYSES/mul2_driver.for`.

Top-level flow of one run: read_model -> preprocess -> run_analysis -> write_results

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_TIMER`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_READ_MODEL`, `MUL2_ANALYSIS_INPUT`, `MUL2_ANALYSIS_RESULTS`, `MUL2_ANALYSIS_101`, `MUL2_ANALYSIS_103`, `MUL2_ANALYSIS_104`, `MUL2_ANALYSIS_105`, `MUL2_ANALYSIS_106`, `MUL2_ANALYSIS_108`, `MUL2_POST_OUTPUT`.

Table: Procedures of `MUL2_DRIVER`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `RUN_MUL2` | Subroutine | public | Program driver: create the output directories, read the model, build the cache, run 101 or 103, write all outputs and the warning report. |
| `REMEMBER_WARNING` | Subroutine | private | WARNINGS OF A STEP GO INTO REPORT/WARNING_file.dat. |

#### `RUN_MUL2`

Program driver: create the output directories, read the model, build the cache, run 101 or 103, write all outputs and the warning report.

| Argument | Declaration | Meaning |
|---|---|---|
| `INPUT_PATH` | `CHARACTER(LEN=*), intent(IN)` | Input directory. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_DYNAMIC_COMMON

File `SRC/ANALYSES/mul2_dynamic_common.for`.

Pieces shared by the time and frequency analyses (104, 106). a degree of freedom belongs to one of three classes that decide how it enters the dynamic equations: 1 displacement (fields 1-3): inertia and viscous damping 2 temperature (field 4): heat capacity (first order in time) 3 potential (field 5): no inertia (algebraic) the damping matrix lives on the csr pattern of k.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_DOF_LAYOUT`.

Table: Public constants of `MUL2_DYNAMIC_COMMON`.

| Name | Type | Value | Meaning |
|---|---|---|---|
| `CLASS_DISPLACEMENT` | `INTEGER(I4)` | `1_I4` |  |
| `CLASS_TEMPERATURE` | `INTEGER(I4)` | `2_I4` |  |
| `CLASS_POTENTIAL` | `INTEGER(I4)` | `3_I4` |  |

Table: Procedures of `MUL2_DYNAMIC_COMMON`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_DOF_CLASSES` | Subroutine | public | Class(dof) for every degree of freedom of the layout. |
| `BUILD_DAMPING_VALUES` | Subroutine | public | Damping values on the pattern of the system: displacement rows and columns: rayleigh c = alpha m + beta k; temperature row, displacement column (only with t0 > 0): the thermoelastic heating -t0 k_ut^t (k_ut is the transposed entry). |
| `CSR_POSITION` | Function → integer(i8) | public | Position of (row, column) in the csr pattern (binary search in the sorted columns of the row), 0 when the entry is not in the pattern. |

#### `BUILD_DOF_CLASSES`

Class(dof) for every degree of freedom of the layout.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODE_COUNT` | `INTEGER(I4), intent(IN)` |  |
| `LAYOUT` | `TYPE(DOF_LAYOUT_TYPE), intent(IN)` | Gauss-point layout (global point numbering). |
| `ORDER` | `INTEGER(I8), intent(IN)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `CLASS` | `INTEGER(I4), ALLOCATABLE, intent(OUT)(:)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_DAMPING_VALUES`

Damping values on the pattern of the system: displacement rows and columns: rayleigh c = alpha m + beta k; temperature row, displacement column (only with t0 > 0): the thermoelastic heating -t0 k_ut^t (k_ut is the transposed entry).

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(IN)` | Sparse system (CSR pattern, K, M). |
| `CLASS` | `INTEGER(I4), intent(IN)(:)` |  |
| `ALPHA_M` | `REAL(R8), intent(IN)` |  |
| `BETA_K` | `REAL(R8), intent(IN)` |  |
| `T0` | `REAL(R8), intent(IN)` |  |
| `CDAMP` | `REAL(R8), ALLOCATABLE, intent(OUT)(:)` |  |

#### `CSR_POSITION`

Position of (row, column) in the csr pattern (binary search in the sorted columns of the row), 0 when the entry is not in the pattern.

| Argument | Declaration | Meaning |
|---|---|---|
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(IN)` | Sparse system (CSR pattern, K, M). |
| `ROW` | `INTEGER(I8), intent(IN)` |  |
| `COLUMN` | `INTEGER(I8), intent(IN)` | Output: strain column (6 values). |

### MUL2_MODEL_ASSEMBLY

File `SRC/ANALYSES/mul2_model_assembly.for`.

Global k and m of a preprocessed model on one shared csr pattern. 1. the dof list of every element gives the csr pattern (once); 2. elements are evaluated in chunks, in parallel (openmp, elements are independent and write only their own matrices); 3. every chunk is scattered into the csr arrays serially and in element order, so the result does not depend on the number of threads (deterministic round-off). the memory of the element matrices is bounded by the chunk size.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_MITC`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_ANALYSIS_INPUT`, `MUL2_TOPOLOGIES`, `MUL2_GAUSS_MATERIALS`, `MUL2_ELEMENT_MATRICES`, `MUL2_GENERAL_KERNEL`, `MUL2_GENERAL_GEOMETRY`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_KINEMATICS`, `MUL2_NODES`, `MUL2_EXPANSION_MESHES`.

Table: Procedures of `MUL2_MODEL_ASSEMBLY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `ASSEMBLE_MODEL_SYSTEM` | Subroutine | public | Assemble global K (and M) in CSR: DOF lists, pattern, parallel element evaluation in chunks, serial deterministic scatter. |
| `ASSEMBLE_NONLINEAR_VALUES` | Subroutine | public | Tangent matrix and internal force of the nonlinear (total lagrangian) model at the state u0. tangent(:) is aligned with system%column_index. elements are evaluated in parallel in chunks and scattered in element order (the result does not depend on the number of threads). |
| `NONLINEAR_ELEMENT` | Subroutine | private |  |
| `ASSEMBLE_GEOMETRIC_VALUES` | Subroutine | public | Geometric (initial-stress) matrix of the state u0 on the pattern of the system: values(:) is aligned with system%column_index. |
| `GEOMETRIC_ELEMENT` | Subroutine | private | Geometric matrix of one element (thread-safe: only reads shared data). |
| `MARK_LAGRANGE_DOFS` | Subroutine | private | Lagrange-expansion dofs of an element: table = expansion mesh and term = mesh node. (taylor dofs keep table = 0: fully coupled.) |
| `BUILD_COUPLING_TABLES` | Subroutine | private | Coupled(t,s) = terms t and s (nodes of the mesh) share a sub-element. |
| `EVALUATE_ELEMENT` | Subroutine | private | K and m of one element; with coupled the thermoelastic block k(u,t) (full integration) is added when the element has a temperature field. |
| `EVALUATE_ELEMENT_BASE` | Subroutine | private | K and m of one element (thread-safe: only reads the shared data). |
| `GENERAL_ELEMENT` | Subroutine | private | K and m (or the thermoelastic block) of a curved beam / shell. none: compatible strains; mitc: tied strains; redi / seli are not defined for the general geometry. |

#### `ASSEMBLE_MODEL_SYSTEM`

Assemble global K (and M) in CSR: DOF lists, pattern, parallel element evaluation in chunks, serial deterministic scatter.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(INOUT)` | Output: K and optionally M in CSR. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |
| `WITH_MASS` | `LOGICAL, intent(IN), OPTIONAL` | Also build the mass matrix. |
| `THERMOELASTIC` | `LOGICAL, intent(IN), OPTIONAL` | Thermoelastic: add the non-symmetric coupling block k(u,t). |

#### `ASSEMBLE_NONLINEAR_VALUES`

Tangent matrix and internal force of the nonlinear (total lagrangian) model at the state u0. tangent(:) is aligned with system%column_index. elements are evaluated in parallel in chunks and scattered in element order (the result does not depend on the number of threads).

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `U0` | `REAL(R8), intent(IN)(:)` |  |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(IN)` | Sparse system (CSR pattern, K, M). |
| `TANGENT` | `REAL(R8), ALLOCATABLE, intent(INOUT)(:)` |  |
| `INTERNAL` | `REAL(R8), intent(OUT)(:)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `ASSEMBLE_GEOMETRIC_VALUES`

Geometric (initial-stress) matrix of the state u0 on the pattern of the system: values(:) is aligned with system%column_index.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `U0` | `REAL(R8), intent(IN)(:)` |  |
| `SYSTEM` | `TYPE(SPARSE_SYSTEM_TYPE), intent(IN)` | Sparse system (CSR pattern, K, M). |
| `VALUES` | `REAL(R8), ALLOCATABLE, intent(OUT)(:)` |  |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_MODEL_CACHE

File `SRC/ANALYSES/mul2_model_cache.for`.

Preprocessing of a validated model: frames, dofs, gauss databases and material cache. nothing here depends on the analysis type.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_MODEL`, `MUL2_ANALYSIS_INPUT`, `MUL2_NODES`, `MUL2_TOPOLOGIES`, `MUL2_MITC`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_REFERENCE_SYSTEMS`, `MUL2_ELEMENT_FRAMES`, `MUL2_GENERAL_GEOMETRY`, `MUL2_DOF_LAYOUT`, `MUL2_COINCIDENT_JOIN`, `MUL2_GAUSS_POINTS`, `MUL2_GAUSS_GEOMETRY`, `MUL2_GAUSS_MATERIALS`, `MUL2_QUADRATURE`, `MUL2_LAMINATIONS`.

Table: Derived type `REDUCED_SET_TYPE` — Second integration set of the reduced and selective integration: the structural points use the reduced rule (the expansion points are the same as in the full set).

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `GAUSS_LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE)` | `` | `` | Gauss layout. |
| `STRUCTURAL_GEOMETRY` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE)` | `` | `` | Structural geometry cache. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE)` | `` | `` | Combined geometry. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE)` | `` | `` | Gauss point to material map. |

Table: Derived type `MODEL_CACHE_TYPE` — Everything derived from the model that does not depend on the analysis: frames, DOF layout, rules, Gauss layout and geometry, material cache.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `FRAMES` | `TYPE(ELEMENT_FRAME_DB_TYPE)` | `` | `` | Element frames. |
| `DOF_LAYOUT` | `TYPE(DOF_LAYOUT_TYPE)` | `` | `` | DOF numbering. |
| `RULES` | `TYPE(REFERENCE_RULE_DB_TYPE)` | `` | `` | Reference rules. |
| `GAUSS_LAYOUT` | `TYPE(GAUSS_LAYOUT_TYPE)` | `` | `` | Gauss layout. |
| `STRUCTURAL_GEOMETRY` | `TYPE(STRUCTURAL_GEOMETRY_CACHE_TYPE)` | `` | `` | Structural geometry cache. |
| `EXPANSION_GEOMETRY` | `TYPE(EXPANSION_GEOMETRY_CACHE_TYPE)` | `` | `` | Expansion geometry cache. |
| `GEOMETRY` | `TYPE(GAUSS_GEOMETRY_TYPE)` | `` | `` | Combined geometry. |
| `MATERIAL_CACHE` | `TYPE(MATERIAL_CACHE_TYPE)` | `` | `` | Material cache. |
| `EXPANSION_ORDER` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Gauss points per direction of each expansion mesh. |
| `MATERIAL_MAP` | `TYPE(GAUSS_MATERIAL_MAP_TYPE)` | `` | `` | Gauss point to material map. |
| `REDUCED_DIMENSION` | `LOGICAL` | `(3)` | `.FALSE.` | Reduced_dimension(d): elements of dimension d use the reduced set (redi or seli with an available reduced rule). |
| `HAS_REDUCED` | `LOGICAL` | `` | `.FALSE.` |  |
| `REDUCED` | `TYPE(REDUCED_SET_TYPE)` | `` | `` |  |

Table: Procedures of `MUL2_MODEL_CACHE`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `CHECK_MECHANICAL_MODEL` | Subroutine | public | V3 101/103 are purely mechanical: only u, v and w may be active. |
| `BUILD_MODEL_CACHE` | Subroutine | public | Preprocessing pipeline: DOF layout, element frames, Gauss rules and layout, structural/expansion/combined geometry and material cache. |
| `CHECK_PHYSICS_DATA` | Subroutine | private | Every lamination of an element whose nodes solve the temperature (the electric potential) needs its conductivity (permittivity): without them the matrix is singular and the solver only reports not-a-number. |
| `FIND_REDUCED_DIMENSIONS` | Subroutine | private | Dimensions (1 beam, 2 plate, 3 solid) whose elements use the reduced structural rule. a dimension requesting redi/seli with no element that has a reduced rule (triangles) stays fully integrated: warning. |
| `ELEMENT_SHEAR_MODE` | Function → integer(i4) | public | Shear treatment requested for the dimension of an element. |
| `BUILD_EXPANSION_POINT_ORDERS` | Subroutine | private | Gauss points per direction needed by each expansion mesh. a taylor expansion of order n gives integrands of degree 2n: n+1 points are required (the baseline uses the same count). le nodes need nothing beyond the default rule of the expansion element. |
| `PREPARE_ELEMENT_MITC` | Subroutine | public | Mitc tying data of one element when the analysis requests mitc for its dimension. a topology without a mitc table is integrated fully and a warning is raised (the baseline silently produces no matrix). |

#### `CHECK_MECHANICAL_MODEL`

V3 101/103 are purely mechanical: only u, v and w may be active.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `BUILD_MODEL_CACHE`

Preprocessing pipeline: DOF layout, element frames, Gauss rules and layout, structural/expansion/combined geometry and material cache.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(INOUT)` | Model cache built by BUILD_MODEL_CACHE. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `ELEMENT_SHEAR_MODE`

Shear treatment requested for the dimension of an element.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `ELEMENT` | `INTEGER(I4), intent(IN)` | Element index. |

#### `PREPARE_ELEMENT_MITC`

Mitc tying data of one element when the analysis requests mitc for its dimension. a topology without a mitc table is integrated fully and a warning is raised (the baseline silently produces no matrix).

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `ELEMENT` | `INTEGER(I4), intent(IN)` | Element index. |
| `MITC` | `TYPE(MITC_DATA_TYPE), intent(INOUT)` | MITC tying data of the element. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer POST {#sec:ref_post}

Point location and recovery, output grids, output files.

### MUL2_POST_GRID

File `SRC/POST/mul2_post_grid.for`.

Visualization grid: hexahedral cells sampling every element. each element / expansion sub-element is divided into r x s x l cells. a cell has 3 x 3 x 3 (quadratic) or 2 x 2 x 2 (linear) nodes at natural coordinates (xi, eta, nu) in [-1,1], ordered with xi outermost and nu innermost. the natural triple is split between the structural element and the expansion element by element dimension: beam (1d): structural = (eta) expansion = (xi, nu) plate (2d): structural = (xi, eta) expansion = (nu) solid (3d): structural = (xi, eta, nu) triangular parents are reached with the collapsed map a = (1+x)/2, b = (1+y)/2 (1-a).

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_MODEL`, `MUL2_EXPANSION_MESHES`, `MUL2_TOPOLOGIES`.

Table: Derived type `POST_GRID_TYPE` — Output grid: cells with their element, sub-element and the natural coordinates of every grid node.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `NODES_PER_CELL` | `INTEGER(I4)` | `` | `27_I4` | Nodes per cell. |
| `CELL_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of cells. |
| `NODE_COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of nodes. |
| `CELL_ELEMENT` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Element of each cell. |
| `CELL_SUB_ELEMENT` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Sub-element of each cell. |
| `CELL_DIMENSION` | `INTEGER(I4), ALLOCATABLE` | `(:)` | `` | Dimension of each cell. |
| `NATURAL_STRUCTURAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Structural natural coordinates of grid nodes. |
| `NATURAL_EXPANSION` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Expansion natural coordinates of grid nodes. |

Table: Procedures of `MUL2_POST_GRID`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `BUILD_POST_GRID` | Subroutine | public | Split(1:9) = beam (xi, eta, nu), plate (xi, eta, nu), solid (xi, eta, nu) subdivisions (the postprocessing.dat layout). |
| `ELEMENT_SPLITS` | Subroutine | private | Subdivisions (x, y, z) of the cells of an element of given dimension. |
| `CELL_LIMITS` | Subroutine | private | Natural coordinates of the nodes of cell number i of n along one direction: points = 3 (end, middle, end) or 2 (ends). |
| `SPLIT_NATURAL` | Subroutine | private | Split a 3-component natural point into structural and expansion natural coordinates. |
| `COLLAPSE_TRIANGLE` | Subroutine | private | Map a square point to a triangle point (collapsed map). |
| `VTK_CELL_ORDER` | Subroutine | public | Node order of one cell in the output formats (1-based positions in the 3x3x3 or 2x2x2 node block). |
| `GMSH_CELL_ORDER` | Subroutine | public | Node order of a cell in GMSH output. |
| `CLEAR_POST_GRID` | Subroutine | public | Release a post grid. |

#### `BUILD_POST_GRID`

Split(1:9) = beam (xi, eta, nu), plate (xi, eta, nu), solid (xi, eta, nu) subdivisions (the postprocessing.dat layout).

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `NODES_PER_CELL` | `INTEGER(I4), intent(IN)` | Nodes per output cell: 8, 20 or 27. |
| `SPLIT` | `INTEGER(I4), intent(IN)(9)` | Nine subdivision counts of the record. |
| `GRID` | `TYPE(POST_GRID_TYPE), intent(INOUT)` | Output grid. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `VTK_CELL_ORDER`

Node order of one cell in the output formats (1-based positions in the 3x3x3 or 2x2x2 node block).

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES_PER_CELL` | `INTEGER(I4), intent(IN)` | Nodes per output cell: 8, 20 or 27. |
| `ORDER` | `INTEGER(I4), intent(OUT)(20)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `COUNT` | `INTEGER(I4), intent(OUT)` | Number of items. |

#### `GMSH_CELL_ORDER`

Node order of a cell in GMSH output.

| Argument | Declaration | Meaning |
|---|---|---|
| `NODES_PER_CELL` | `INTEGER(I4), intent(IN)` | Nodes per output cell: 8, 20 or 27. |
| `ORDER` | `INTEGER(I4), intent(OUT)(27)` | Order of the matrix, or polynomial/quadrature order (see routine). |
| `COUNT` | `INTEGER(I4), intent(OUT)` | Number of items. |

#### `CLEAR_POST_GRID`

Release a post grid.

| Argument | Declaration | Meaning |
|---|---|---|
| `GRID` | `TYPE(POST_GRID_TYPE), intent(INOUT)` | Output grid. |

### MUL2_POST_OUTPUT

File `SRC/POST/mul2_post_output.for`.

SCIENTIFIC OUTPUT FILES OF THE STATIC AND MODAL ANALYSES. STATIC/POST_POINT.dat POINT RESULTS (PNT RECORDS) STATIC/RESULTS_PARA_NN.vtk PARAVIEW FIELDS (PARA RECORDS) STATIC/RESULTS_GMSH_NN.msh GMSH FIELDS (GMSH RECORDS) DYNAMIC/FREQUENCIES.dat NATURAL FREQUENCIES [HZ] DYNAMIC/RESULTS_DYN_PARA.vtk MODE SHAPES (PARAVIEW) DYNAMIC/RESULTS_DYN_GMSH.msh MODE SHAPES (GMSH) WORK/K_MAT.dat M_MAT.dat FORCES.dat UNKNOWN.dat MATRIX DUMPS FILE NAMES AND COLUMN LAYOUTS FOLLOW THE BASELINE. THE DOF NUMBERING OF THE DUMPS IS THE V3 FIELD-MAJOR ONE.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_FILES`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_ANALYSIS_INPUT`, `MUL2_ANALYSIS_RESULTS`, `MUL2_SPARSE_ASSEMBLY`, `MUL2_POST_GRID`, `MUL2_RECOVERY`.

Table: Derived type `WARNING_LIST_TYPE` — Warnings collected for REPORT/WARNING_file.dat.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `COUNT` | `INTEGER(I4)` | `` | `0_I4` | Number of items. |
| `TEXT` | `CHARACTER(LEN=200)` | `(64)` | `' '` | Warning texts. |

Table: Procedures of `MUL2_POST_OUTPUT`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `PREPARE_OUTPUT_DIRECTORIES` | Subroutine | public | Create STATIC, DYNAMIC, WORK and REPORT. |
| `WRITE_STATIC_OUTPUT` | Subroutine | public | Static analysis output |
| `EVALUATE_GRID_STATES` | Subroutine | private | Values of displacement, strain and stress at every grid node. cells are independent and evaluated in parallel. |
| `EVALUATE_CELL_STATES` | Subroutine | private | Same for one cell. |
| `LOCATE_ALL_POINTS` | Subroutine | private | Locate every point request once and keep the result (see located). |
| `WRITE_TIME_STEP_OUTPUT` | Subroutine | public | OUTPUT OF ONE STEP OF A TIME ANALYSIS: DYNAMIC/TIME_HISTORY.dat GETS ONE ROW PER POINT (THE POST_POINT COLUMNS AFTER THE TIME) AND EVERY FIELD REQUEST WRITES DYNAMIC/RESULTS_PARA_NN_SSSSSS.vtk. |
| `WRITE_FREQUENCY_OUTPUT` | Subroutine | public | OUTPUT OF ONE FREQUENCY OF A HARMONIC RESPONSE: DYNAMIC/ FREQ_HISTORY.dat HAS ONE ROW PER POINT AND FREQUENCY: F[HZ] ID RE/IM OF UX UY UZ TEMPERATURE VOLTAGE |
| `WRITE_POST_POINTS` | Subroutine | private | Point results |
| `WRITE_POINT_HEADER` | Subroutine | private | Header line of POST_POINT.dat. |
| `WRITE_POINT_ROW` | Subroutine | private | One result row (46 columns). |
| `WRITE_MISSING_POINT_ROW` | Subroutine | private | Row of NaN for a point outside the model. |
| `FIND_MESH` | Function → integer(i4) | private | Expansion mesh index of an element. |
| `WRITE_VTK_GEOMETRY` | Subroutine | private | Paraview / gmsh writers (shared by static and modal output) |
| `WRITE_VTK_VECTOR` | Subroutine | private | Write a VTK vector field. |
| `WRITE_VTK_SCALAR` | Subroutine | private | Write a VTK scalar field. |
| `SELECT_FRAME` | Subroutine | private | Nodal data in the frame requested by the post-processing record. |
| `VON_MISES` | Function → real(r8) | private | Von Mises equivalent stress. |
| `WRITE_STATIC_VTK` | Subroutine | private | RESULTS_PARA_nn.vtk. |
| `WRITE_GMSH_GEOMETRY` | Subroutine | private | Write nodes and elements of a GMSH file. |
| `WRITE_GMSH_DATA` | Subroutine | private | Write one GMSH view. |
| `WRITE_STATIC_GMSH` | Subroutine | private | RESULTS_GMSH_nn.msh. |
| `WRITE_MODAL_OUTPUT` | Subroutine | public | Modal analysis output |
| `WRITE_SOLVER_INFO` | Subroutine | private | WORK/ARPACK_SOLVER_INFO.dat: EIGENVALUES, RESIDUALS, ITERATIONS. |
| `EVALUATE_GRID_MODES` | Subroutine | private | Mode displacements at the grid nodes: displacement(3,node,mode). |
| `EVALUATE_CELL_MODES` | Subroutine | private | Same for one cell. |
| `WRITE_MODAL_VTK` | Subroutine | private | RESULTS_DYN_PARA.vtk. |
| `WRITE_MODAL_GMSH` | Subroutine | private | RESULTS_DYN_GMSH.msh. |
| `WRITE_MATRIX_DUMPS` | Subroutine | private | Matrix and vector dumps (work directory) |
| `WRITE_CSR` | Subroutine | private | Dump a CSR matrix as row, column, value lines. |
| `WRITE_VECTOR` | Subroutine | private | Dump a vector. |
| `ADD_WARNING` | Subroutine | private | Report files |
| `WRITE_WARNING_FILE` | Subroutine | public | REPORT/WARNING_file.dat IN THE BASELINE LAYOUT. |
| `INTEGER_TEXT` | Function → character(len=16) | private | Integer to text without blanks. |

#### `PREPARE_OUTPUT_DIRECTORIES`

Create STATIC, DYNAMIC, WORK and REPORT.

| Argument | Declaration | Meaning |
|---|---|---|
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `WRITE_STATIC_OUTPUT`

Static analysis output

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(IN)` | Analysis results container. |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `WRITE_TIME_STEP_OUTPUT`

OUTPUT OF ONE STEP OF A TIME ANALYSIS: DYNAMIC/TIME_HISTORY.dat GETS ONE ROW PER POINT (THE POST_POINT COLUMNS AFTER THE TIME) AND EVERY FIELD REQUEST WRITES DYNAMIC/RESULTS_PARA_NN_SSSSSS.vtk.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `SOLUTION` | `REAL(R8), intent(IN)(:)` | Global displacement vector. |
| `STEP` | `INTEGER(I4), intent(IN)` |  |
| `TIME_VALUE` | `REAL(R8), intent(IN)` |  |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `WRITE_FREQUENCY_OUTPUT`

OUTPUT OF ONE FREQUENCY OF A HARMONIC RESPONSE: DYNAMIC/ FREQ_HISTORY.dat HAS ONE ROW PER POINT AND FREQUENCY: F[HZ] ID RE/IM OF UX UY UZ TEMPERATURE VOLTAGE

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `REAL_PART` | `REAL(R8), intent(IN)(:)` |  |
| `IMAGINARY_PART` | `REAL(R8), intent(IN)(:)` |  |
| `STEP` | `INTEGER(I4), intent(IN)` |  |
| `FREQUENCY` | `REAL(R8), intent(IN)` | Natural frequencies in Hz. |
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(INOUT)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `WRITE_MODAL_OUTPUT`

Modal analysis output

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `RESULTS` | `TYPE(ANALYSIS_RESULTS_TYPE), intent(IN)` | Analysis results container. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `WRITE_WARNING_FILE`

REPORT/WARNING_file.dat IN THE BASELINE LAYOUT.

| Argument | Declaration | Meaning |
|---|---|---|
| `WARNINGS` | `TYPE(WARNING_LIST_TYPE), intent(IN)` | List of warnings for REPORT/WARNING_file.dat. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

### MUL2_RECOVERY

File `SRC/POST/mul2_recovery.for`.

Recovery of displacement, strain and stress at arbitrary points. a point is given by an element, one sub-element of its expansion mesh and the natural coordinates of both (structural, expansion). the field is composed with the same basis rule used by the element matrices (mul2_point_bases), so recovery and stiffness share one implementation of the kinematics. conventions strain = [exx, eyy, ezz, gxz, gyz, gxy] (engineering shear) stress = [sxx, syy, szz, sxz, syz, sxy] local = element frame, global = model frame

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_MODEL`, `MUL2_MODEL_CACHE`, `MUL2_ANALYSIS_INPUT`, `MUL2_GENERAL_GEOMETRY`, `MUL2_GENERAL_KERNEL`, `MUL2_MITC`, `MUL2_LOCAL_GRADIENTS`, `MUL2_LINEAR_KINEMATICS`, `MUL2_NODES`, `MUL2_KINEMATICS`, `MUL2_EXPANSION_MESHES`, `MUL2_LAMINATIONS`, `MUL2_TOPOLOGIES`, `MUL2_SHAPE_FUNCTIONS`, `MUL2_HLE_MAP`, `MUL2_JACOBIANS`, `MUL2_DOF_LAYOUT`, `MUL2_POINT_BASES`, `MUL2_MATERIAL_ROTATIONS`.

Table: Derived type `PLACE_TYPE` — Geometry and shape data of one (element, sub-element) pair.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ELEMENT` | `INTEGER(I4)` | `` | `0_I4` | Element index. |
| `MESH` | `INTEGER(I4)` | `` | `0_I4` | Expansion mesh index. |
| `SUB_ELEMENT` | `INTEGER(I4)` | `` | `0_I4` | Sub-element index. |
| `STRUCTURAL_DIMENSION` | `INTEGER(I4)` | `` | `0_I4` | Structural dimension. |
| `EXPANSION_DIMENSION` | `INTEGER(I4)` | `` | `0_I4` | Expansion dimension. |
| `STRUCTURAL_TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Structural topology. |
| `EXPANSION_TOPOLOGY` | `INTEGER(I4)` | `` | `0_I4` | Expansion topology. |
| `STRUCTURAL_AXIS` | `INTEGER(I4)` | `(3)` | `[1_I4,2_I4,3_I4]` | Structural axes. |
| `EXPANSION_AXIS` | `INTEGER(I4)` | `(3)` | `[1_I4,2_I4,3_I4]` | Expansion axes. |
| `NODE_GLOBAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Global node coordinates. |
| `NODE_LOCAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Local node coordinates. |
| `EXPANSION_NODE` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Expansion node coordinates. |
| `SHAPE_STRUCTURAL` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Structural shapes. |
| `NATURAL_DERIVATIVE_S` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Structural natural derivatives. |
| `GRADIENT_STRUCTURAL` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Structural local gradients. |
| `SHAPE_EXPANSION` | `REAL(R8), ALLOCATABLE` | `(:)` | `` | Expansion shapes. |
| `NATURAL_DERIVATIVE_E` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Expansion natural derivatives. |
| `GRADIENT_EXPANSION` | `REAL(R8), ALLOCATABLE` | `(:,:)` | `` | Expansion local gradients. |
| `EXPANSION_POINT_LOCAL` | `REAL(R8)` | `(3)` | `0.0_R8` | Expansion point in the local frame. |
| `CURVED` | `LOGICAL` | `` | `.FALSE.` | Hq sub-element with curved sides: blending-function map. |
| `HLE_MAP` | `TYPE(HLE_GEOMETRY_TYPE)` | `` | `` |  |
| `MAP_DX` | `REAL(R8)` | `(2,2)` | `0.0_R8` |  |
| `POINT_GLOBAL` | `REAL(R8)` | `(3)` | `0.0_R8` | Physical point. |
| `NATURAL_S` | `REAL(R8)` | `(3)` | `0.0_R8` | Structural natural coordinates. |
| `MITC` | `TYPE(MITC_DATA_TYPE)` | `` | `` | MITC tying data. |
| `GENERAL` | `LOGICAL` | `` | `.FALSE.` | Curved beam / shell (mul2_general_kernel): geometry and tying. |
| `GCTX` | `TYPE(GENERAL_CONTEXT_TYPE)` | `` | `` |  |

Table: Derived type `POINT_STATE_TYPE` — Displacement, strain and stress at one point.

| Component | Type | Shape | Default | Meaning |
|---|---|---|---|---|
| `ELEMENT` | `INTEGER(I4)` | `` | `0_I4` | Element index. |
| `SUB_ELEMENT` | `INTEGER(I4)` | `` | `0_I4` | Sub-element index. |
| `ELEMENT_DIMENSION` | `INTEGER(I4)` | `` | `0_I4` | Element dimension. |
| `LAMINATION_ID` | `INTEGER(I4)` | `` | `0_I4` | Lamination id. |
| `MATERIAL_ID` | `INTEGER(I4)` | `` | `0_I4` | Material id. |
| `COORDINATE` | `REAL(R8)` | `(3)` | `0.0_R8` | Coordinates. |
| `DISPLACEMENT` | `REAL(R8)` | `(3)` | `0.0_R8` | Displacement (global). |
| `STRAIN_LOCAL` | `REAL(R8)` | `(6)` | `0.0_R8` | Strain in the element frame (xx,yy,zz,xz,yz,xy). |
| `STRAIN_GLOBAL` | `REAL(R8)` | `(6)` | `0.0_R8` | Strain in the global frame. |
| `STRESS_LOCAL` | `REAL(R8)` | `(6)` | `0.0_R8` | Stress in the element frame. |
| `STRESS_GLOBAL` | `REAL(R8)` | `(6)` | `0.0_R8` | Stress in the global frame. |
| `POTENTIAL` | `REAL(R8)` | `` | `0.0_R8` | Electric fields (piezoelectric models): potential, field e = -grad phi and displacement d = e_pz s - eps grad phi. |
| `ELECTRIC_FIELD_LOCAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `ELECTRIC_FIELD_GLOBAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `ELECTRIC_DISPLACEMENT_LOCAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `ELECTRIC_DISPLACEMENT_GLOBAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `TEMPERATURE` | `REAL(R8)` | `` | `0.0_R8` | Thermal fields: temperature and heat flux q = -k grad t. |
| `HEAT_FLUX_LOCAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `HEAT_FLUX_GLOBAL` | `REAL(R8)` | `(3)` | `0.0_R8` |  |
| `FRAME` | `REAL(R8)` | `(3,3)` | `RESHAPE([1.0_R8,0.0_R8,0.0_R8, 0.0_R8,1.0_R8,0.0_R8,0.0_R8,0.0_R8,1.0_R8], [3,3])` | Frame of the point (global_to_local): the one of the element, or the one of the point for a curved beam / shell. |

Table: Procedures of `MUL2_RECOVERY`.

| Procedure | Kind | Visibility | Purpose |
|---|---|---|---|
| `PLACE_SETUP` | Subroutine | public | Load the coordinates of the nodes of one element and of one expansion sub-element. |
| `SETUP_CURVED_PLACE` | Subroutine | private | Geometry of a hq sub-element with curved sides. |
| `FREE_PLACE` | Subroutine | private | Release a PLACE_TYPE. |
| `PLACE_EVALUATE` | Subroutine | public | Shapes, local gradients and physical position at a natural point. with_gradient = .false. skips the jacobian inversions (newton). |
| `CURVED_GRADIENT` | Subroutine | private | Physical gradients of the expansion functions with the blending map. |
| `STATE_FROM_PLACE` | Subroutine | public | Displacement, strain and stress at the point last evaluated by place_evaluate(..., with_gradient = .true.). |
| `GENERAL_STATE_PART` | Subroutine | private | Displacement, potential, temperature and the strain / gradients of the local frame at a point of a curved beam / shell. |
| `DISPLACEMENT_FROM_PLACE` | Subroutine | public | Global displacement of several dof vectors (e.g. mode shapes) at the point last evaluated by place_evaluate. no gradient is needed. vectors(dof,k) -> displacement(1:3,k) |
| `TRANSFORM_INVERSE` | Function | private | Inverse of the strain transform of an orthogonal rotation. |
| `LOCATE_POINT` | Subroutine | public | Find the (element, sub-element, natural coordinates) containing the target point. newton iteration on x_s(xi_s) + r**t x_e(xi_e) = target whose unknowns are all the natural coordinates of the point. |
| `POINT_NEAR_ELEMENT` | Function → logical | private | Cheap rejection: the point lies within the bounding box of the structural nodes expanded by the largest expansion extent. |
| `NEWTON_LOCATE` | Subroutine | private | Newton iteration on the isoparametric map to find the natural coordinates. |
| `NATURAL_INSIDE` | Function → logical | private | True when natural coordinates lie inside the reference element. |
| `INVERT_3X3` | Subroutine | private | Invert a 3x3 matrix with its determinant. |

#### `PLACE_SETUP`

Load the coordinates of the nodes of one element and of one expansion sub-element.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `ELEMENT` | `INTEGER(I4), intent(IN)` | Element index. |
| `SUB_ELEMENT` | `INTEGER(I4), intent(IN)` | Index of the expansion sub-element. |
| `PLACE` | `TYPE(PLACE_TYPE), intent(INOUT)` | Evaluation context: node coordinates, shapes and frames of one element/sub-element. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `PLACE_EVALUATE`

Shapes, local gradients and physical position at a natural point. with_gradient = .false. skips the jacobian inversions (newton).

| Argument | Declaration | Meaning |
|---|---|---|
| `PLACE` | `TYPE(PLACE_TYPE), intent(INOUT)` | Evaluation context: node coordinates, shapes and frames of one element/sub-element. |
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `NATURAL_S` | `REAL(R8), intent(IN)(3)` | Structural natural coordinates. |
| `NATURAL_E` | `REAL(R8), intent(IN)(3)` | Expansion natural coordinates. |
| `WITH_GRADIENT` | `LOGICAL, intent(IN)` | Also compute local gradients. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `STATE_FROM_PLACE`

Displacement, strain and stress at the point last evaluated by place_evaluate(..., with_gradient = .true.).

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `PLACE` | `TYPE(PLACE_TYPE), intent(IN)` | Evaluation context: node coordinates, shapes and frames of one element/sub-element. |
| `SOLUTION` | `REAL(R8), intent(IN)(:)` | Global displacement vector. |
| `STATE` | `TYPE(POINT_STATE_TYPE), intent(OUT)` | Displacement, strain, stress at output points. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `DISPLACEMENT_FROM_PLACE`

Global displacement of several dof vectors (e.g. mode shapes) at the point last evaluated by place_evaluate. no gradient is needed. vectors(dof,k) -> displacement(1:3,k)

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `PLACE` | `TYPE(PLACE_TYPE), intent(IN)` | Evaluation context: node coordinates, shapes and frames of one element/sub-element. |
| `VECTORS` | `REAL(R8), intent(IN)(:,:)` | DOF vectors (e.g. mode shapes), one per column. |
| `DISPLACEMENT` | `REAL(R8), intent(OUT)(:,:)` | Output: global displacement components (one column per vector). |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

#### `LOCATE_POINT`

Find the (element, sub-element, natural coordinates) containing the target point. newton iteration on x_s(xi_s) + r**t x_e(xi_e) = target whose unknowns are all the natural coordinates of the point.

| Argument | Declaration | Meaning |
|---|---|---|
| `MODEL` | `TYPE(MODEL_TYPE), intent(IN)` | Complete input model (all databases). |
| `CACHE` | `TYPE(MODEL_CACHE_TYPE), intent(IN)` | Model cache built by BUILD_MODEL_CACHE. |
| `TARGET` | `REAL(R8), intent(IN)(3)` | Physical point to locate. |
| `TOLERANCE` | `REAL(R8), intent(IN)` | Geometric tolerance. |
| `ELEMENT` | `INTEGER(I4), intent(OUT)` | Element index. |
| `SUB_ELEMENT` | `INTEGER(I4), intent(OUT)` | Index of the expansion sub-element. |
| `NATURAL_S` | `REAL(R8), intent(OUT)(3)` | Structural natural coordinates. |
| `NATURAL_E` | `REAL(R8), intent(OUT)(3)` | Expansion natural coordinates. |
| `FOUND` | `LOGICAL, intent(OUT)` | True when the point lies inside an element. |
| `STATUS` | `TYPE(STATUS_TYPE), intent(OUT)` | Status of the call (OK, warning or error with message and source). |

## Layer APP {#sec:ref_app}

Program entry points.

### None

File `SRC/APP/mul2_main.for`.

MUL2_V3 EXECUTABLE ENTRY POINT. MUL2_V3 [INPUT_DIRECTORY] (DEFAULT: FIRST LINE OF PATH_input.dat, THEN `INPUT`) MUL2_V3 --version RESULTS ARE WRITTEN TO THE REPORT, STATIC, DYNAMIC AND WORK DIRECTORIES OF THE WORKING DIRECTORY. THE EXIT CODE IS 0 ON SUCCESS.

Uses: `MUL2_KINDS`, `MUL2_STATUS`, `MUL2_LOG`, `MUL2_RUNTIME`, `MUL2_TIMER`, `MUL2_DRIVER`.

### None

File `SRC/APP/mul2_main_core.for`.

Entry point of the build without mkl: only the core library is available, there is no linear or eigenvalue solver.

Uses: `MUL2_LOG`, `MUL2_RUNTIME`.
