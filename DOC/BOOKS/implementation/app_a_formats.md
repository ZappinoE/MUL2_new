# File formats at a glance

Table: Input files (every file starts with the number of records; blank lines and comments are ignored). {#tab:formats-in}

| File | Record | Fields |
|---|---|---|
| `ANALYSIS.dat` | 1 | solution (`101`/`103`) and a free comment |
| | 2 | number of modes (used by 103) |
| | 3–5 | treatment of beams, plates, solids: `NONE`, `REDI`, `SELI`, `MITC` (an old integer solver record before record 2 is skipped) |
| `NODES.dat` (legacy) | `ID X Y Z TE n` or `ID X Y Z LE m` | coordinates, expansion model (`TE`: order `n`; `LE`: second number ignored) |
| `NODES.dat` (with `KINEMATICS.dat`) | `ID X Y Z KID` | kinematic id |
| `KINEMATICS.dat` | `KINEMATIC id u v w t p b szz sxz syz` | nine tokens: `TEn`, `LE`, `HLEn`, `Mn`, `NONE` |
| `CONNECTIVITY.dat` | `TYPE id n1 … nN [versor] section` | topology name, element id, node ids, versor id (not needed for solids), expansion mesh number |
| `VERSORS.dat` | `VERSOR id vx vy vz` | reference vector |
| `MATERIAL.dat` | header `nmat nrec` | number of materials, number of records |
| | `ISO-M id E nu rho` | isotropic |
| | `ORT-M id EL ET EZ nuLT nuLZ nuTZ GLT GLZ GTZ rho` | orthotropic |
| | `MAT-C id c11 … c66 rho` | 36 entries of $\mathbf{C}$ (material axes) and density |
| `LAMINATION.dat` | `LAM2 id material angle_y angle_z` | degrees |
| `EXP_MESH_nn.dat` | `id x y z` | local coordinates of expansion nodes ($y=0$ for beams) |
| `EXP_CONN_nn.dat` | `TYPE id lamination n1 … nN` | sub-element: topology, id, lamination, node ids |
| `BC.dat` | `D-PLANE id A B C D ux uy uz` | plane $AX+BY+CZ+D=0$; each component a number or `N` |
| | `F-POINT id x y z Fx Fy Fz` | point load at a section node |
| `POSTPROCESSING.dat` | `PARA|GMSH cells LOC|GLB s1…s9` | output grid |
| | `PNT id x y z` | point result |
| | `KMAT`, `MMAT`, `FRCE`, `UNKN`, `ENRG` | dump requests |

Table: Output files. {#tab:formats-out}

| File | Layout |
|---|---|
| `STATIC/POST_POINT.dat` | header + one row per point, 46 columns |
| `STATIC/RESULTS_PARA_nn.vtk` | legacy VTK ASCII, point data `Displacements`, `Epsilon_*`, `Sigma_*`, von Mises |
| `DYNAMIC/FREQUENCIES.dat` | `Frequency  n:  value` |
| `WORK/K_MAT.dat` | `row column value` (1-based, field-major numbering) |
| `REPORT/WARNING_file.dat` | count + one warning per line |

# Naming of the principal variables

Table: Variable names that recur in the sources. {#tab:varnames}

| Name | Meaning |
|---|---|
| `NODE`, `NODE_INDEX`, `NODE_ID` | node (position in the database / number in the input) |
| `ELEMENT`, `ELEMENT_INDEX` | structural element |
| `SUB_ELEMENT`, `EXPANSION_ELEMENT_INDEX` | element of the expansion mesh |
| `MESH`, `MESH_INDEX` | expansion mesh |
| `POINT` | combined Gauss point (global number) |
| `STRUCTURAL_POINT_INDEX`, `EXPANSION_POINT_INDEX` | point in the structural / expansion rule |
| `TERM` | expansion term index $\tau$ |
| `FIELD` | 1 = U, 2 = V, 3 = W |
| `LOCAL_DOF`, `I`, `J` | DOF index inside an element |
| `GLOBAL_DOF` | global DOF number |
| `N`, `DN` | shape functions and derivatives |
| `F`, `FACTOR_VALUE`, `FACTOR_GRADIENT` | expansion function and gradient |
| `B_COLUMN` | 6-vector strain column of a DOF |
| `STIFFNESS_LOCAL` | rotated $6\times6$ constitutive matrix |
| `WEIGHT`, `INTEGRATION_WEIGHT` | quadrature weight, with Jacobians |
| `GLOBAL_TO_LOCAL` | rotation $\mathbf{R}$ (rows = local axes) |
| `ACTIVE_AXIS`, `AXIS` | local axes spanned by an element or expansion mesh |
| `SIGMA`, `EPS`, `SM`, `EM`, `GAMMA`, `LAMBDA` | separable-kernel quantities of Chapter {sec:kernels} |
