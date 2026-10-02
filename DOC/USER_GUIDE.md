# MUL2_NEW – User Guide

Linear static (101) and linear free-vibration (103) analysis of beams,
plates and solids with the Carrera Unified Formulation. Theory:
`THEORETICAL_GUIDE.md`.

---

## 1. Installation and requirements

* Windows x64, Intel oneAPI (ifx compiler, MKL) for building; to *run*
  the executable the oneAPI runtime DLLs must be on `PATH`
  (`…\oneAPI\compiler\<ver>\bin`, `…\oneAPI\mkl\<ver>\bin`).
* Build:

      CREATE_VS_SOLUTION.cmd build        (Release)
      CREATE_VS_SOLUTION.cmd open         (open the Visual Studio solution)

  The executable is `BUILD\WINDOWS_IFX\Release\MUL2_V3.exe`.

## 2. Running the solver

    MUL2_V3.exe [input_directory]

* Without an argument the program reads the directory name from
  `PATH_input.dat` in the working directory; if that file is missing,
  `INPUT` is used.
* Outputs are written under the working directory:

| Directory | Content |
|-----------|---------|
| `STATIC/` | 101: `POST_POINT.dat`, `RESULTS_PARA_nn.vtk`, `RESULTS_GMSH_nn.msh` |
| `DYNAMIC/` | 103: `FREQUENCIES.dat`, `RESULTS_DYN_PARA.vtk`, `RESULTS_DYN_GMSH.msh` |
| `WORK/` | matrix/vector dumps, `ARPACK_SOLVER_INFO.dat` |
| `REPORT/` | `WARNING_file.dat` |

Exit code 0 = success, 1 = error (message on the console). Always read
`REPORT/WARNING_file.dat`.

Number of threads: `set OMP_NUM_THREADS=4` before running. Results do
not depend on the thread count.

## 3. Web interface

Start `INTERFACE\Start-MUL2-Interface.cmd` (optional `-Port 8766`,
`-Solver <path to MUL2_V3.exe>`) and open `http://localhost:8765/`.

* **Editor** – one form per input file (analysis, nodes, connectivity,
  versors, material, lamination, expansion mesh/connectivity, BC,
  post-processing) with validation of cross-references.
* **3D Model** – beams (extruded section), plates (plan mesh with
  exaggerated thickness) and solids; supports, loads and evaluation points
  are drawn; a Z-scale selector exaggerates thin plates.
* **Run & Results** – sends the current input set to the solver, shows
  console output and lets you download result files. Each run lives in
  `INTERFACE\runs\<id>`.
* Only analyses 101 and 103 are offered.

## 4. Input files

All files live in the input directory. The first data record of each file
is the **number of records**; blank lines and text after the data are
ignored. Numbers may use Fortran `D` exponents (`1.0D-3`).

### 4.1 ANALYSIS.dat

    101  STATIC                 solution: 101 or 103
    20       number of modes (used by 103)
    MITC     shear correction – beams   (NONE | REDI | SELI | MITC)
    MITC     shear correction – plates
    NONE     shear correction – solids

`REDI` (reduced) and `SELI` (selective) integration act on the structural element; the old solver record (`100 !! NOT USED`) is no longer part of the file (old files are still read).

### 4.2 NODES.dat

    number_of_nodes

    ID   X   Y   Z   TE|LE  [order]

`TE n` = Taylor expansion of order *n* at that node (`TE 2`), `LE` =
Lagrange expansion defined by the EXP_MESH. The number after `LE` is a
legacy flag. A `KINEMATICS.dat` file (if present) overrides this syntax.

* **Beam**: axis along Y; expansion over the X–Z section.
* **Plate**: mid-surface in the X–Y plane; thickness along Z from the
  expansion (EXP_MESH nodes are at x = y = 0 and z = −h/2…+h/2).
* **Solid**: nodes carry full 3D coordinates; a single constant expansion
  (`LE 1` with a one-node EXP_MESH).

### 4.3 CONNECTIVITY.dat

    number_of_elements

    TYPE  id  node1 … nodeN  versor  lamination

Types: B2 B3 B4 (beam), Q4 Q9 Q16 T3 T6 (plate), H8 H27
(solid). Node order follows the standard ring order (for example Q9:
corners/midsides counter-clockwise *1 2 3 6 9 8 7 4* then the centre).
Mixed element families in one model are allowed.

### 4.4 VERSORS.dat

    n
    VERSOR  id  vx vy vz         element frame direction

### 4.5 MATERIAL.dat

    n_materials  n_laminas_or_flag

    ISO-M  id  E  nu  rho
    ORT-M  id  E1 E2 E3 G12 G13 G23 nu12 nu13 nu23 rho
    MAT-C  id  <6x6 matrix> rho

Other records (`T-EXP`, `S-EXP`, `T-SPC`, `VISCO`, `T-CON`…) are read and
ignored for 101/103.

### 4.6 LAMINATION.dat

    n
    LAM2  id  material_id  angle_y(deg)  angle_z(deg)

Only constant `LAM2` records are active in 101/103: each lamination
refers to a material and two rotation angles (degrees) that orient the
material frame. A layered laminate is built by giving each expansion
sub-element (EXP_CONN record) its own lamination id.

### 4.7 EXP_MESH_nn.dat / EXP_CONN_nn.dat

The expansion mesh *nn* (`nn` is the `section` column of the element
record):

    EXP_MESH:  ID  X  Y  Z              nodes of the expansion
    EXP_CONN:  B2|B3|B4|Q4|Q9|Q16 id  lamination  node1 … nodeN

Plate example (two layers through the thickness):

    EXP_MESH_01.dat          EXP_CONN_01.dat
    3                        2
    1 0 0 -1.0D-4            B2 1 1 1 2
    2 0 0  0.0               B2 2 1 2 3
    3 0 0  1.0D-4

### 4.8 BC.dat

    n

    D-PLANE id  A B C D  ux uy uz          clamp the plane A x+B y+C z=D
    F-POINT id  x y z  Fx Fy Fz            point load at coordinate (x,y,z)

`D-PLANE`: the listed displacement values are the *imposed* values (0 =
clamped). All nodal terms lying on the plane are constrained; for TE
nodes the plane must contain the whole node expansion.
Static solution: constraints are eliminated exactly. Modal solution:
loads and non-zero imposed values are ignored (warning).

### 4.9 POSTPROCESSING.dat

    n_records

    PARA  cells  GLB|LOC  s1 … s9      VTK grid
    GMSH  cells  GLB|LOC  s1 … s9      GMSH grid
    PNT   id  x y z                    results at a point
    KMAT  MMAT  FRCE  UNKN  ENRG        dump matrices / vectors

* `cells` = 8, 20 or 27 nodes per output cell (20/27 → quadratic hexa).
* `GLB` global, `LOC` element frame.
* The nine integers `s1…s9` are the subdivisions of each element into
  output cells, three per family: beam (ξ,η,ν), plate (ξ,η,ν), solid
  (ξ,η,ν); only the directions that exist for the family are used
  (beam: η along the axis and ξ,ν over the section; plate: ξ,η in the
  plane and ν through the thickness; solid: ξ,η,ν). `1` = no split.
* Points outside the mesh produce a row of NaN and a warning.

## 5. Output files

### POST_POINT.dat
One row per `PNT`; 46 columns: point id, coordinates, displacements
(u,v,w), strains (6) and stresses (6) in the requested frame, plus the
per-layer results of the legacy layout.

### RESULTS_PARA_nn.vtk / RESULTS_GMSH_nn.msh
Legacy ASCII VTK (`UNSTRUCTURED_GRID`, cell types 12 and 25) and GMSH 2.2
views with displacements, strains and stresses as point data. Open with
ParaView or GMSH.

### FREQUENCIES.dat

    Frequency  1:   1.234567890E+001
    …

Frequencies in Hz, ascending. `RESULTS_DYN_PARA.vtk` contains the mode
shapes (M-normalised displacement fields, one per mode).

### WORK/
`K_MAT`, `M_MAT`, `FORCES`, `UNKNOWN` dumps when requested (field-major DOF
order), and `ARPACK_SOLVER_INFO.dat` (iterations, residuals).

## 6. Modelling advice

1. **Constrain** the model: every body must be fixed in all six rigid-body
   motions for 101. For 103 an unconstrained body has zero-frequency modes
   which stop the solver (singular factorisation).
2. **Thin structures**: use `MITC` for the matching family. Do not use MITC
   with H8 elements (singular).
3. **Expansion order**: TE1 is classical-beam-like; raise the order (TE2,
   TE3…) for local effects; use LE for layer-wise laminates.
4. **Post-processing points** must lie inside the mesh; place plate points
   strictly inside an element rather than exactly on an element boundary.
5. **Units** are free but must be consistent (SI in the examples).
6. Start with a small mesh: a wrong input is reported with the file and
   record that failed.

## 7. Error messages

| Message | Meaning / action |
|---------|------------------|
| `CANNOT OPEN: <file>` | missing input file |
| `UNKNOWN SHEAR-LOCKING CORRECTION` | use NONE, REDI, SELI or MITC |
| `SOLUTION n NOT SUPPORTED` | only 101 and 103 |
| `PARDISO ERROR -4` | singular matrix – check constraints / MITC on H8 |
| `MITC NOT AVAILABLE FOR Q16…` (warning) | full integration is used |
| `PNT outside the mesh` (warning) | coordinate not inside any element |
| `LOADS … IGNORED` (warning, 103) | normal, loads are meaningless for modes |

## 8. Examples

Ready-made inputs with the expected results are in `TESTS/CASES/`:
`beam_b3_te2_mitc`, `plate_q4_mitc`, `plate_q9x4_mitc`, `solid_h8_none`,
`mixed_mitc` (beam + plate + solid), `modal_beam_b3_te2`,
`modal_plate_q9x4_mitc`, and the patch tests. Reference inputs from the
baseline program are in `REFERENCES/BASELINE_INPUTS/`.

Quick check:

    cd TESTS\CASES\plate_q9x4_mitc
    mkdir RUN & cd RUN
    "..\..\..\..\BUILD\WINDOWS_IFX\Release\MUL2_V3.exe" "..\INPUT"
    type STATIC\POST_POINT.dat

Compare with `..\REFERENCE\POST_POINT.dat`.

