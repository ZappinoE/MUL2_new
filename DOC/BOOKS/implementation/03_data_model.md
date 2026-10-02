# Data model {#sec:datamodel}

The program is data-driven: the input is read into a set of plain databases (the *model*), derived data are computed once (the *cache*) and the analysis fills a *results* container. This chapter describes these structures. The complete component lists are generated in Appendix {sec:reference}; here the *meaning* and the *relations* are explained.

![Which input file fills which database.](figures/file_map.svg){#fig:filemap}

## The model

`MODEL_TYPE` (module `MUL2_MODEL`) is the root of everything read from the input directory:

```fortran
#caption: MODEL_TYPE (MODEL/mul2_model.for)
TYPE, PUBLIC :: MODEL_TYPE
  CHARACTER(LEN=512) :: INPUT_PATH
  TYPE(ANALYSIS_TYPE)           :: ANALYSIS     ! ANALYSIS.dat
  TYPE(POST_DB_TYPE)            :: POST         ! POSTPROCESSING.dat
  TYPE(KINEMATICS_DB_TYPE)      :: KINEMATICS   ! KINEMATICS.dat or legacy NODES.dat
  TYPE(NODE_DB_TYPE)            :: NODES        ! NODES.dat
  TYPE(ELEMENT_DB_TYPE)         :: ELEMENTS     ! CONNECTIVITY.dat
  TYPE(EXPANSION_DB_TYPE)       :: EXPANSIONS   ! EXP_MESH_nn.dat / EXP_CONN_nn.dat
  TYPE(REFERENCE_VECTOR_DB_TYPE):: VECTORS      ! VERSORS.dat
  TYPE(MATERIAL_DB_TYPE)        :: MATERIALS    ! MATERIAL.dat
  TYPE(LAMINATION_DB_TYPE)      :: LAMINATIONS  ! LAMINATION.dat
  TYPE(BOUNDARY_DB_TYPE)        :: BOUNDARIES   ! BC.dat
END TYPE MODEL_TYPE
```

### Nodes, elements and incidence

- `NODE_TYPE`: `ID` (number in the file), `COORDINATE(3)` (global), `KINEMATIC_ID` (which kinematic record the node uses). `NODE_DB_TYPE` also stores `ID_LIST` and `ID_ORDER`, a sorted copy of the ids built by `BUILD_NODE_INDEX`, so that `FIND_NODE_INDEX(NODES, id)` is a binary search.
- `ELEMENT_TYPE`: `ID`, `TOPOLOGY` (integer code, see `MUL2_TOPOLOGIES`), `NODE_ID(:)` (node ids in the shape-function order), `FRAME_ID` (versor id), `EXPANSION_ID` (index of the expansion mesh).
- `NODE_INCIDENCE_TYPE`: for node $i$ the elements that contain it are `ELEMENT(FIRST(i):FIRST(i+1)-1)` (CSR-like, ascending). It is used to know which expansion mesh governs a node (the first incident element) and to detect unused nodes.

### Kinematics

A *kinematic* is the expansion specification of the nine fields:

```fortran
#caption: Kinematics (MODEL/mul2_kinematics.for)
TYPE :: EXPANSION_SPEC_TYPE
  INTEGER(I4) :: FAMILY = EXPANSION_NONE   ! NONE, TE, LE, HLE, MISC
  INTEGER(I4) :: ORDER = 0                 ! Taylor order, HLE order
  INTEGER(I4) :: FIELD_REFERENCE = 0       ! index of user functions (M<n>)
END TYPE
TYPE :: KINEMATIC_TYPE
  INTEGER(I4) :: ID
  TYPE(EXPANSION_SPEC_TYPE) :: FIELD(N_FIELDS)   ! U V W T P B SZZ SXZ SYZ
END TYPE
```

With the historical `NODES.dat` (`ID X Y Z TE|LE [order]`) the reader `READ_LEGACY_NODES_FILE` creates one kinematic for every distinct (family, order) pair, with the same expansion for the three displacement fields. With a `KINEMATICS.dat` file the table is read explicitly and `NODES.dat` carries the kinematic id.

### Expansion meshes

`EXPANSION_MESH_TYPE` holds `NODE(:)` (id and local coordinate of every expansion node) and `ELEMENT(:)` (sub-elements with topology, lamination id and node ids). The mesh index equals the number `nn` of the files `EXP_MESH_nn.dat`, `EXP_CONN_nn.dat`. The coordinates of an expansion node are $(x_s,0,z_s)$ for a beam section, $(0,0,z_s)$ for a plate thickness and $(0,0,0)$ for a solid; the program determines which axes are active from the extent of the nodes (`FIND_EXPANSION_ACTIVE_AXES`).

### Materials, laminations, boundary conditions

- `MATERIAL_TYPE`: `ID`, `MODEL`, `DENSITY`, `STIFFNESS(6,6)` in the material axes (Voigt order TT, LL, ZZ, TZ, LZ, TL).
- `LAMINATION_TYPE`: `ID`, `KIND` (constant), `MATERIAL_ID`, `ANGLE_Y_DEG`, `ANGLE_Z_DEG`.
- `BOUNDARY_CONDITION_TYPE`: `KIND` (`BC_DISPLACEMENT_PLANE` or `BC_FORCE_POINT`), `PLANE(4)`, `POINT(3)`, `ACTIVE(3)` (constrained components), `VALUE(3)` (prescribed displacements or load components).

### Analysis and post-processing requests

`ANALYSIS_TYPE` holds `SOLUTION` (101/103), `MODE_COUNT` and `SHEAR(3)` (the correction codes `SHEAR_NONE`, `SHEAR_MITC`, ... for beams, plates, solids). `POST_DB_TYPE` holds the list of field requests (`FORMAT`, `FRAME`, `CELL_NODES`, `SPLIT(9)`), the list of point requests and the dump flags.

## Topology codes

`MUL2_TOPOLOGIES` is the single registry of topologies. The integer code encodes the family in the hundreds digit: 101–103 beams, 201–205 surface elements, 301–306 solids, 401 the point element `S1`. Functions `TOPOLOGY_FROM_NAME`, `TOPOLOGY_NODE_COUNT` and `TOPOLOGY_NATURAL_DIMENSION` are used everywhere instead of hard-coded numbers.

## DOF layout

`DOF_LAYOUT_TYPE` (module `MUL2_DOF_LAYOUT`, routine `BUILD_DOF_LAYOUT`):

| Component | Meaning |
|---|---|
| `TERM_COUNT(node, field)` | number of terms of the field at the node (0 for inactive fields and unused nodes) |
| `FIRST(node, field)` | first global DOF of the block |
| `FIELD_FIRST(field)`, `FIELD_LAST(field)` | range of the global DOFs of each field |
| `TOTAL_DOF` | total number of DOFs |

`TERM_COUNT` comes from `NODE_FIELD_TERM_COUNT`: for Taylor, `TAYLOR_BASIS_TERM_COUNT(order, dim)` with `dim` the dimension of the expansion mesh (2 for beams, 1 for plates, 0 for solids); for Lagrange, the number of nodes of the mesh. `GLOBAL_DOF(layout, node, field, term)` returns `FIRST(node,field) + term - 1`. All other modules obtain global numbers only through this function.

## Sparse system

`SPARSE_SYSTEM_TYPE` stores the CSR matrices:

```fortran
#caption: SPARSE_SYSTEM_TYPE (ASSEMBLY/mul2_sparse_assembly.for)
TYPE :: SPARSE_SYSTEM_TYPE
  INTEGER(I8) :: ORDER, NONZERO_COUNT
  INTEGER(I8), ALLOCATABLE :: ROW_POINTER(:)    ! size ORDER+1, 1-based
  INTEGER(I8), ALLOCATABLE :: COLUMN_INDEX(:)   ! size NONZERO_COUNT, ascending per row
  REAL(R8),    ALLOCATABLE :: STIFFNESS(:)      ! K values
  REAL(R8),    ALLOCATABLE :: MASS(:)           ! M values (only when requested)
END TYPE
```

![CSR storage.](figures/csr.svg){#fig:csr-impl}

## The cache

`MODEL_CACHE_TYPE` collects everything that depends on the model but not on the analysis. It is built once by `BUILD_MODEL_CACHE` (Chapter {sec:preproc}):

| Component | Type | Content |
|---|---|---|
| `FRAMES` | `ELEMENT_FRAME_DB_TYPE` | `ORIGIN(3,e)`, `GLOBAL_TO_LOCAL(3,3,e)`, `LOCAL_TO_GLOBAL(3,3,e)` |
| `DOF_LAYOUT` | `DOF_LAYOUT_TYPE` | numbering |
| `RULES` | `REFERENCE_RULE_DB_TYPE` | quadrature rules with shapes/derivatives at their points |
| `GAUSS_LAYOUT` | `GAUSS_LAYOUT_TYPE` | decomposition of the global Gauss-point number |
| `STRUCTURAL_GEOMETRY` | `STRUCTURAL_GEOMETRY_CACHE_TYPE` | Jacobian, inverse, determinant, local gradients of the structural points |
| `EXPANSION_GEOMETRY` | `EXPANSION_GEOMETRY_CACHE_TYPE` | same for the expansion points |
| `GEOMETRY` | `GAUSS_GEOMETRY_TYPE` | indices into the two caches, global coordinates, integration weights |
| `MATERIAL_CACHE`, `MATERIAL_MAP` | | rotated stiffness per lamination and the material index of every Gauss point |
| `EXPANSION_ORDER` | `INTEGER(:)` | Gauss points per direction required by each expansion mesh |

## Results

`ANALYSIS_RESULTS_TYPE` holds `SYSTEM` (the sparse matrices), `CONSTRAINTS`, `FORCE`, `SOLUTION` (101) or `MODE(:,k)`, `EIGENVALUE`, `FREQUENCY`, `RESIDUAL` (103) and the solver statistics `SOLVER_BACKEND`, `SOLVER_ITERATIONS`, `SOLVER_OPERATIONS`, `SOLVER_SUBSPACE`, `ASSEMBLY_SECONDS`, `SOLVER_SECONDS`.
