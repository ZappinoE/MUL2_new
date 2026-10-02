# Output reference {#sec:outputs}

## Where the results go

After a run the following folders exist in the run directory:

Table: Output files. {#tab:out-files}

| File | When | Content |
|---|---|---|
| `STATIC/POST_POINT.dat` | 101, if `PNT` requested | values at the requested points |
| `STATIC/RESULTS_PARA_nn.vtk` | 101, one per `PARA` record | fields on a grid, for ParaView |
| `STATIC/RESULTS_GMSH_nn.msh` | 101, one per `GMSH` record | the same for GMSH |
| `DYNAMIC/FREQUENCIES.dat` | 103 | natural frequencies in Hz |
| `DYNAMIC/RESULTS_DYN_PARA.vtk`, `RESULTS_DYN_GMSH.msh` | 103 | mode shapes |
| `WORK/K_MAT.dat`, `M_MAT.dat`, `FORCES.dat`, `UNKNOWN.dat` | if `KMAT` `MMAT` `FRCE` `UNKN` requested | matrices and vectors |
| `WORK/ARPACK_SOLVER_INFO.dat` | 103 | eigenvalues, residuals, solver statistics |
| `REPORT/WARNING_file.dat` | always | warnings of the run |

## POST_POINT.dat

A header line and one row per `PNT` request. Each row has 46 numbers. The columns are, in order:

Table: Columns of `POST_POINT.dat`. {#tab:pp-columns}

| Columns | Name | Meaning |
|---|---|---|
| 1 | `ID` | point id of the request |
| 2–4 | `X_EVAL, Y_EVAL, Z_EVAL` | position where the field was **actually evaluated** (inside the model) |
| 5–7 | `X_REQ, Y_REQ, Z_REQ` | position requested |
| 8 | `LAM` | id of the lamination at the point |
| 9 | `ELE` | element id that contains the point |
| 10 | `S_ELE` | id of the sub-element (expansion element) |
| 11–13 | `U_X, U_Y, U_Z` | displacement, **global** components |
| 14–19 | `EPS_XX … EPS_XY (LOC)` | strain in the element frame, order $xx,yy,zz,xz,yz,xy$ |
| 20–25 | `EPS_… (GLB)` | strain in the global frame |
| 26–31 | `SIG_XX … SIG_XY (LOC)` | stress in the element frame |
| 32–37 | `SIG_… (GLB)` | stress in the global frame |
| 38–40 | `DT, VOLT, %H` | zeros (kept for compatibility) |
| 41–46 | `E11 … D33` | zeros (kept for compatibility) |

The shear strains are **engineering** shears: $\gamma_{xz}=2\varepsilon_{xz}$. The shear stresses are the usual $\sigma_{xz}$ etc.

If a point lies outside the model, its row has `NaN` in all result columns and a warning is added to `REPORT/WARNING_file.dat`.

> NOTE: Reading a row in a script: skip the header, split the line on blanks and take the column numbers above. Fortran writes `E` exponents like `0.12E-04` and `6.1E-024`; most scripting languages read them correctly.

## VTK files (ParaView)

`RESULTS_PARA_nn.vtk` is a legacy ASCII `UNSTRUCTURED_GRID` file. Each element and each sub-element of the section/thickness is divided into cells according to the subdivision numbers of the request. The point data are:

Table: Fields in the VTK file (names exactly as written). {#tab:vtk-fields}

| Name | Type | Meaning |
|---|---|---|
| `Displacements` | vector | displacement in the frame of the request |
| `Sigma_XX`, `Sigma_YY`, `Sigma_ZZ`, `Sigma_XZ`, `Sigma_YZ`, `Sigma_XY` | scalars | stress components |
| `VonMises` | scalar | equivalent (von Mises) stress |
| `Epsilon_XX`, `Epsilon_YY`, `Epsilon_ZZ`, `Epsilon_XZ`, `Epsilon_YZ`, `Epsilon_XY` | scalars | strain components (engineering shear) |
| `ID_LAM`, `ID_MAT` | scalars | lamination id and material id of the sub-element the node belongs to (useful to colour the plies) |
| `Elem.Dimension` | scalar | 1, 2 or 3: beam, plate or solid element |
| `SHEAR` | vector | the coordinates of the node (a quirk of the legacy layout) |
| `ElectricDisplacements`, `TEMPERATURE_[C]`, `VOLTAGE[V]`, `EX`, `EY`, `EZ`, `DOF_SET`, `HYGRO` | | zeros: placeholders for the fields of the full program, kept so that existing ParaView state files still load |

**In ParaView:** open the file, press *Apply*, choose a field from the colour list (for instance `Sigma_YY`), and apply the filter *Warp By Vector* with `Displacements` (use a *scale factor* so that the deformation is visible) to see the deformed shape. Use the *Cell data → point data* default; nodes shared between cells have one value per cell node, so there are visible jumps at element interfaces (the stress field is discontinuous).

> NOTE: Cells that sample different sub-elements (plies) do not share nodes, so the jump of stress between plies is visible in the plot.

## GMSH files

`RESULTS_GMSH_nn.msh` contains the same grid and fields as GMSH 2 views (open it with GMSH; the views appear in the *Modules → Post-processing* menu).

## Frequencies and modes

`DYNAMIC/FREQUENCIES.dat`:

```text
  Frequency  1:   8.242627792E+001
  Frequency  2:   8.242627792E+001
  Frequency  3:   4.963753952E+002
  Frequency  4:   4.963753952E+002
```

Frequencies are in **hertz**, ascending. Repeated values mean repeated modes (for example the two bending directions of a square section).

`RESULTS_DYN_PARA.vtk` has one displacement vector field per mode, named like `Mode:001-Freq:0.8243E+02Hz` (mode number and frequency); each mode is normalised with respect to the mass matrix (modal mass 1) and its absolute amplitude is arbitrary: choose a visual scale in ParaView.

`WORK/ARPACK_SOLVER_INFO.dat` lists the Ritz values and the relative residuals of the modes and says which solver was used (`ARPACK` for large problems, `DENSE` for small ones).

## Matrix dumps

If `KMAT` is requested, `WORK/K_MAT.dat` contains one line per stored entry: `row column value`, with the **global DOF numbering of the program: field by field, then node by node, then term** (all `u` DOFs first, then all `v`, then all `w`). For a static analysis the dumped matrix is the matrix **after** the elimination of the constraints (constrained rows and columns are zero with unit diagonal); for the modal analysis it is the full stiffness matrix. `FORCES.dat` and `UNKNOWN.dat` have one value per DOF in the same order.

## The warning file

`REPORT/WARNING_file.dat` lists the warnings in order. Typical messages are described in Chapter 10.

## Console summary

The lines starting with `[INFO]` summarise the run: the size of the model, the number of Gauss points, the number of non-zeros of $\mathbf{K}$ and the assembly time, the solver time, and the times of input, preprocessing, analysis and output. The line `[ERROR]` (printed on the error stream) explains why a run failed.
