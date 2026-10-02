# Input and output {#sec:io}

## Reading text files

All input files share the same *legacy* layout: the first data record is the number of records; comments and blank lines may appear anywhere; text after the data is ignored. This is implemented once in `NEXT_DATA_LINE(UNIT, LINE, IOS)` (module `MUL2_TEXT_IO`), which returns the next line that is neither blank nor a comment. Every reader follows the same scheme:

```fortran
#caption: Skeleton of a reader (IO/read_connectivity.for, abridged)
CALL CLEAR_STATUS(STATUS)
OPEN(NEWUNIT=UNIT, FILE=FILE_NAME, STATUS='OLD', ACTION='READ', IOSTAT=IOS)
IF (IOS .NE. 0) THEN
  CALL SET_ERROR(STATUS, 'READ_CONNECTIVITY_FILE', 'CANNOT OPEN: '//TRIM(FILE_NAME))
  RETURN
END IF
CALL NEXT_DATA_LINE(UNIT, LINE, IOS)        ! record count
READ(LINE,*,IOSTAT=IOS) COUNT               ! list-directed read of the line
...
DO I = 1, COUNT
  CALL NEXT_DATA_LINE(UNIT, LINE, IOS)      ! one record
  READ(LINE,*,IOSTAT=IOS) NAME, ID          ! header first: decides how many values follow
  ...
END DO
CALL NEXT_DATA_LINE(UNIT, LINE, IOS)        ! extra records after the declared count
IF (IOS .EQ. 0) CALL SET_WARNING(STATUS, ..., 'EXTRA RECORDS AFTER DECLARED COUNT')
```

List-directed reading accepts Fortran real formats (`1.0D-3`, `1e-3`), arbitrary blanks and tabs.

## The readers

Table: Readers. {#tab:readers}

| Reader (module) | File | Records and checks |
|---|---|---|
| `READ_ANALYSIS_FILE` (`MUL2_READ_ANALYSIS`) | `ANALYSIS.dat` | solution id, number of modes, three shear-treatment words (`NONE`, `REDI`, `SELI`, `MITC`); the obsolete solver record of the historical format is detected (second integer record) and skipped with a warning |
| `READ_POSTPROCESSING_FILE` | `POSTPROCESSING.dat` | `PARA`/`GMSH` (cell nodes 8/20/27, `LOC`/`GLB`, nine splits ≥ 1), `PNT`, `KMAT MMAT FRCE UNKN ENRG`; fewer records than declared give a warning |
| `READ_LEGACY_NODES_FILE` | `NODES.dat` (historical) | `ID X Y Z TE|LE [order]`; creates the kinematics |
| `READ_KINEMATICS_FILE`, `READ_NODES_FILE` | `KINEMATICS.dat`, `NODES.dat` (V3) | `KINEMATIC id tok1…tok9`; `ID X Y Z KINEMATIC_ID` |
| `READ_CONNECTIVITY_FILE` | `CONNECTIVITY.dat` | `TYPE id n1…nN [versor] section`; checks that all nodes exist and ids are unique |
| `READ_EXPANSION_SET` → `READ_EXPANSION_NODES`, `READ_EXPANSION_ELEMENTS` | `EXP_MESH_nn.dat`, `EXP_CONN_nn.dat` | one pair per expansion id used (1…99); duplicate ids and unknown nodes are errors |
| `READ_REFERENCE_VECTORS_FILE` | `VERSORS.dat` | `VERSOR id vx vy vz`; zero vectors rejected |
| `READ_MATERIALS_FILE` | `MATERIAL.dat` | `ISO-M`, `ORT-M`, `MAT-C` build the stiffness (`BUILD_*_MATERIAL`); thermal/electrical records are accepted and ignored |
| `READ_LAMINATIONS_FILE` | `LAMINATION.dat` | `LAM2 id material angle_y angle_z`; material must exist |
| `READ_BOUNDARY_CONDITIONS_FILE` | `BC.dat` | `D-PLANE id A B C D ux uy uz` (`N` = free component), `F-POINT id x y z Fx Fy Fz` |

`READ_MODEL(INPUT_PATH, MODEL, STATUS)` calls them in the order: analysis, kinematics/nodes, connectivity, expansions (the number of meshes is the largest `EXPANSION_ID` found in the connectivity), versors, materials, laminations, boundary conditions, post-processing, merging all statuses.

> NOTE: The readers translate **syntax**; the **semantic** checks (for example that a lamination of an expansion element exists) are made by the caches. Duplicate ids are detected in $O(n\log n)$ with `SORT_PERMUTATION` and `HAS_DUPLICATE_KEYS`.

## Output

All output routines live in `MUL2_POST_OUTPUT`; the file names and column layouts follow the baseline.

Table: Output files. {#tab:outputs}

| File | Written by | Content |
|---|---|---|
| `STATIC/POST_POINT.dat` | `WRITE_POST_POINTS` | one 46-column row per `PNT` request |
| `STATIC/RESULTS_PARA_nn.vtk` | `WRITE_STATIC_VTK` | legacy ASCII VTK with displacement, strain, stress, von Mises |
| `STATIC/RESULTS_GMSH_nn.msh` | `WRITE_STATIC_GMSH` | the same as GMSH views |
| `DYNAMIC/FREQUENCIES.dat` | `WRITE_MODAL_OUTPUT` | `Frequency  n:  value [Hz]` |
| `DYNAMIC/RESULTS_DYN_PARA.vtk`, `RESULTS_DYN_GMSH.msh` | `WRITE_MODAL_VTK`, `WRITE_MODAL_GMSH` | mode shapes |
| `WORK/K_MAT.dat`, `M_MAT.dat`, `FORCES.dat`, `UNKNOWN.dat` | `WRITE_MATRIX_DUMPS` | `row column value` lines (field-major numbering) / vector lines |
| `WORK/ARPACK_SOLVER_INFO.dat` | `WRITE_SOLVER_INFO` | eigenvalues, residuals, iterations |
| `REPORT/WARNING_file.dat` | `WRITE_WARNING_FILE` | warnings of the whole run |

`PREPARE_OUTPUT_DIRECTORIES` creates the four output directories (using a shell command through `EXECUTE_COMMAND_LINE`, with the syntax of the current operating system, `IS_WINDOWS`).

**Point rows.** `WRITE_POINT_ROW` writes the 46 numbers: point id (1), evaluated position (3), requested position (3), lamination id, element id, sub-element id (3), displacement (3), strain local (6), strain global (6), stress local (6), stress global (6), three thermal/electric placeholders (3), six placeholders for electric fields (6). The placeholders are zeros, kept for compatibility. A point that is not found gives a row of `NaN` with zero ids.

## Output grid

The grid (`BUILD_POST_GRID`) is built from the model and the request: for every element and every sub-element, cells with 8, 20 or 27 nodes are created in natural coordinates, subdivided according to `SPLIT`. `VTK_CELL_ORDER` and `GMSH_CELL_ORDER` give the node order required by each format (VTK quadratic hexahedron = type 25 with 20 nodes; the 27th node is dropped). The states at the grid nodes are computed in parallel (`EVALUATE_GRID_STATES`).
