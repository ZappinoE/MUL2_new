# Input file reference {#sec:inputref}

All files are in the input directory. For each file this chapter gives the purpose, the exact record syntax, the rules and the typical mistakes. In the syntax lines, `[ ]` marks an optional field and `…` a repetition.

## ANALYSIS.dat

Chooses the analysis and the numerical options.

```text
101  STATIC                    ← record 1: analysis number (+ optional comment)

20       Number of Modes ...   ← record 2: number of modes (analysis 103)

MITC     shear correction beam   ← record 3: NONE | REDI | SELI | MITC
MITC     shear correction plate  ← record 4
NONE     shear correction solid  ← record 5
```

The historical files have an extra record between the analysis number and the number of modes (the old solver selector, e.g. `100 !! NOT USED`). It no longer exists: the program recognises it (a second integer line) and ignores it with a warning, so old inputs still run.

Table: Records of `ANALYSIS.dat`. {#tab:in-analysis}

| Record | Content | Allowed values |
|---|---|---|
| 1 | analysis number | `101` linear static; `103` free vibration. Other numbers of the historical program (104, 105, 106, 111, …) give the error `SOLUTION n IS NOT SUPPORTED (ONLY 101 AND 103)` |
| 2 | number of modes | integer ≥ 1; if larger than the number of free DOF a warning is issued and all are returned |
| 3, 4, 5 | shear-locking treatment of beam, plate, solid elements | `NONE` full integration; `REDI` reduced integration; `SELI` selective integration (shear terms reduced, the others full); `MITC` tied shear strains; anything else is an error |
| 6 (optional) | physics that are solved | `FIELDS MECH [THERMO] [PIEZO]`; without the record every field expanded in `KINEMATICS.dat` is solved (Chapter {sec:multiphysics}) |
| 7 (optional) | joining by coincidence | `JOIN COINCIDENT [tol]`: the DOFs of different nodes that are the same field at the same point are joined (Chapter {sec:modelling}) |

> NOTE: `MITC` does nothing for topologies that have no tying table (Q16, T3, T6, T4, T10, P6): they are integrated fully and the program prints a warning. `REDI` and `SELI` reduce the Gauss rule of the *structural* element by one point per direction (B2 1, B3 2, B4 3 points; Q4 1, Q9 2, Q16 3; H8 1, H27 2); triangles stay fully integrated (warning). `REDI` leaves hourglass modes in Q4, H8 and H27 (warning): prefer `SELI` or `MITC` there. In a modal analysis `REDI` also reduces the mass.

## NODES.dat – the structural nodes

Two formats are accepted.

**Historical format (default).** Each record: node id, three global coordinates, the expansion model and, for `TE`, its order:

```text
16                                    ← number of nodes

1   0.0D0   0.0000000000000000D0   0.0D0   TE 2
2   0.0D0   0.0333333333333333D0   0.0D0   TE 2
...
```

Table: Historical `NODES.dat` records. {#tab:in-nodes}

| Field | Meaning |
|---|---|
| `ID` | positive integer, unique |
| `X Y Z` | global coordinates |
| `TE n` | Taylor expansion of order $n\ge0$ for $u$, $v$ and $w$ |
| `LE [m]` | Lagrange expansion defined by the expansion mesh; the number is read and ignored |

Nodes that belong to no element are accepted but receive no unknowns (a warning is issued).

**With `KINEMATICS.dat`.** If the file `KINEMATICS.dat` exists the nodes carry a *kinematic id* instead of the model token:

```text
KINEMATICS.dat
3

KINEMATIC 1  TE2 TE2 TE2 NONE NONE NONE NONE NONE NONE
KINEMATIC 2  LE  LE  LE  NONE NONE NONE NONE NONE NONE
KINEMATIC 3  TE4 TE2 TE2 NONE NONE NONE NONE NONE NONE
```

```text
NODES.dat   (ID  X  Y  Z  KINEMATIC_ID)
3

1  0.0  0.0  0.0  1
2  0.0  0.1  0.0  2
3  0.0  0.2  0.0  3
```

The nine columns are the fields $u,v,w,T,P,B,\sigma_{zz},\sigma_{xz},\sigma_{yz}$. For analyses 101/103 only the first three may be different from `NONE`. Tokens: `TEn` (Taylor order $n$), `LE`, `NONE`; `HLE` (no order; the order belongs to the section sub-elements, Chapter {sec:hle-user}) is supported; `Mn` is accepted syntactically but gives an explicit *not implemented* error. Different expansions for $u$, $v$ and $w$ at the same node are allowed.

> WARNING: Two elements that share a node must use compatible expansions at that node. All the elements incident to a **Lagrange node** must use the **same expansion mesh** (error `LE NODE USES INCOMPATIBLE EXPANSIONS`); for **Taylor nodes** the expansion meshes of the incident elements must have the same dimension.

## CONNECTIVITY.dat – the structural elements

```text
5                                     ← number of elements

B4  1   1  2  3  4    1   1
B4  2   4  5  6  7    1   1
```

`TYPE  id  node_1 … node_N  [versor]  section`

Table: Element records. {#tab:in-conn}

| Field | Meaning |
|---|---|
| `TYPE` | `B2 B3 B4` (beams), `Q4 Q9 Q16 T3 T6` (plates; `Q3`, `Q6` = `T3`, `T6`), `H8 H27` (solids). `H20`, `T4`, `T10`, `P6` are recognised but not implemented (error) |
| `id` | positive integer, unique |
| `node_1…node_N` | the $N$ node ids in the element node order (Figure {fig:el2d-user} and the quick reference, Appendix A) |
| `versor` | id of the versor in `VERSORS.dat` (beams and plates); for solids it may be omitted or any value |
| `section` | number $nn$ of the expansion mesh `EXP_MESH_nn.dat`/`EXP_CONN_nn.dat` used by the element |

If only one integer follows the nodes it is taken as the **section** number and the versor as 0.

Rules: node ids must exist; at most 99 expansion meshes; the section numbers used must be $1\dots n_{max}$ without gaps (every file `EXP_*_01 … nn` for $nn\le n_{max}$ must exist).

## VERSORS.dat – the reference vectors

```text
2

VERSOR 1   0 0 1
VERSOR 2   1 0 0
```

`VERSOR id vx vy vz`. The vector fixes the rotation of the **element frame**: for a beam it gives the direction of the local $z$ axis (the "up" of the section), for a plate the direction of the local $x$ axis in the plane of the element. It need not be normalised and, for a beam, may be any vector that is not parallel to the axis; for a plate any vector that is not normal to the element. Chapter {sec:refsys} gives recipes. A zero vector is an error.

## MATERIAL.dat – materials

```text
2  2                                  ← number of materials, number of records

ISO-M  1   7.0D10   0.30   2700.0
ORT-M  2   140D9 10D9 10D9   0.3 0.3 0.4   5D9 5D9 3.5D9   1600
```

The header has two integers: the number of **mechanical materials** and the number of **records** that follow (the file may contain additional, non-mechanical records of the historical program, which are accepted and ignored).

Table: Material records. {#tab:in-mat}

| Record | Fields | Notes |
|---|---|---|
| `ISO-M` | `id E nu rho` | isotropic; $E>0$, $-1<\nu<0.5$, $\rho\ge0$ |
| `ORT-M` | `id EL ET EZ nuLT nuLZ nuTZ GLT GLZ GTZ rho` | orthotropic in the axes $(T,L,Z)$: $L$ fibre, $T$ transverse in the plane, $Z$ thickness |
| `MAT-C` | `id` and 36 numbers (row by row) and `rho` | full $6\times6$ stiffness in the material axes, Voigt order $(TT,LL,ZZ,TZ,LZ,TL)$; it must be symmetric |
| `T-EXP S-EXP T-SPC VISCO T-CON Z-EXP Z-PRM M-EXP M-PRM H-EXP H-DIF PIROE PIROM PZ-MG MZ-PZ DAMP` | | accepted and ignored in 101/103 |

> NOTE: In an orthotropic material the **fibre direction is $L$**. With zero lamination angles $T\equiv x$, $L\equiv y$, $Z\equiv z$ of the element frame: for a beam, fibres run along the beam axis; for a plate, fibres run along the element's $y$ direction.

## LAMINATION.dat – material orientation

```text
3

LAM2  1   1   0.0   0.0
LAM2  2   1   0.0  90.0
LAM2  3   1   0.0   0.0
```

`LAM2 id material_id angle_y angle_z` (degrees). A lamination is a material with an orientation: the angle $\theta_y$ rotates the material axes about the element $y$ axis and $\theta_z$ about the element $z$ axis (Chapter {sec:refsys}). The same material may appear in several laminations with different angles; this is how a laminate is described: one lamination per ply (or per group of plies), each referenced by a sub-element of the expansion mesh. Only `LAM2` records are accepted in 101/103.

## EXP_MESH_nn.dat and EXP_CONN_nn.dat – the section or thickness

Each expansion mesh is a pair of files, with `nn` = 01, 02, ….

```text
EXP_MESH_01.dat                         EXP_CONN_01.dat
9                                       1

1  -0.05D0 0.0D0 -0.05D0                Q9  1   1    1 2 3 6 9 8 7 4 5
2   0.00D0 0.0D0 -0.05D0
...
9   0.05D0 0.0D0  0.05D0
```

**EXP_MESH_nn.dat:** `id x y z` — the **local** coordinates of the expansion nodes, measured in the element frame from the structural node. For a **beam** the section lies in the plane $y=0$: `x`, `z` in the section, `y = 0`. For a **plate** the thickness is along $z$: `x = y = 0`. For a **solid** a single node at the origin.

**EXP_CONN_nn.dat:** `TYPE id lamination node_1 … node_N` — the sub-elements. Allowed types: for beams `Q4 Q9 Q16 T3 T6`; for plates `B2 B3 B4`; for solids `S1`. The node ids refer to `EXP_MESH_nn.dat`. The **lamination id** says which row of `LAMINATION.dat` (material and angles) the sub-element has.

![A laminated section: one sub-element per ply.](figures/expansion_layers.svg){#fig:layers-user}

Rules:

- The mesh must be **non-degenerate**: the nodes must span the two section axes (beam) or the thickness axis (plate).
- Sub-elements must cover the section without overlapping; nodes shared by two sub-elements must be the same node.
- For a Taylor expansion the expansion mesh defines the integration domain and the points where loads and constraints can be placed.
- The node order of every sub-element follows its topology (Figure {fig:el2d-user} and the quick reference, Appendix A).

## BC.dat – constraints and loads

```text
2

D-PLANE  1   0 1 0 0    0.0 0.0 0.0
F-POINT  2   0.0 1.0 0.0    0.0 0.0 1000.0
```

**`D-PLANE id A B C D ux uy uz`** — prescribes displacements on every degree of freedom that lies on the plane

$$
A\,X+B\,Y+C\,Z+D=0 .
$$

`ux uy uz` are the prescribed values of the global displacement components; write `N` for a component that is left free. Examples:

Table: Examples of `D-PLANE`. {#tab:in-dplane}

| Record | Effect |
|---|---|
| `D-PLANE 1  0 1 0 0   0.0 0.0 0.0` | plane $Y=0$: all three components clamped to 0 |
| `D-PLANE 2  0 1 0 -1   N 0.0 N` | plane $Y=1$ ($Y-1=0$): only $u_y$ fixed |
| `D-PLANE 3  0 0 1 0   N N 0.0` | plane $Z=0$: $u_z=0$ (symmetry plane) |
| `D-PLANE 4  1 1 0 -2   0.0 0.0 0.0` | oblique plane $X+Y=2$ |

The test is done on the **physical position of every expansion node of every structural node**, within a small tolerance. For a Lagrange expansion only the section nodes that lie on the plane are constrained (a plane may cut the section: partial constraints are possible). For a **Taylor expansion the plane must contain the whole section** of the node: the whole expansion is then constrained (constant term to the value, the other terms to zero); a plane that cuts a Taylor section gives the error `PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE`.

> WARNING: The plane equation is $AX+BY+CZ+D=0$ — note the **plus** $D$. The plane $Y=1$ is `0 1 0 -1`, not `0 1 0 1`. A plane that selects no degree of freedom gives the warning `PLANE DID NOT SELECT ANY ACTIVE DOF`; two records that prescribe different values for the same DOF give an error.

**`F-POINT id x y z Fx Fy Fz`** — a point load $(F_x,F_y,F_z)$ in global components at the global point $(x,y,z)$. The point must coincide (within tolerance) with the physical position of a **section node of a structural node** (that is, $\mathbf{X}_{node}+\mathbf{R}^T\mathbf{c}_{section\ node}$); otherwise the error `POINT LOAD LOCATION WAS NOT FOUND` is given. Lagrange: the force acts on the single nodal degree of freedom. Taylor: it is distributed over the terms of the expansion.

Distributed loads are not available: replace them by equivalent nodal point loads. (For a uniform load on a Q9 edge the three nodes carry 1/6, 4/6 and 1/6 of the total force.)

In **analysis 103** loads and non-zero prescribed values are ignored (warning); only the *constraints* matter.

## POSTPROCESSING.dat – what to write

```text
7                                      ← number of records

PARA  20  GLB  1 1 1  1 1 1  1 1 1     ← field output for ParaView
GMSH  27  LOC  1 1 1  3 3 3  1 1 1     ← field output for GMSH
PNT   1   0.0025  0.02  0.000001       ← point result
KMAT                                    ← dump the stiffness matrix
...
```

Table: Records of `POSTPROCESSING.dat`. {#tab:in-post}

| Record | Meaning |
|---|---|
| `PARA n frame s1…s9` | write `RESULTS_PARA_nn.vtk` (one file per record, numbered in order). `n` = nodes per output cell: **8** (linear) or **20**, **27** (quadratic); `frame` = `GLB` (global components) or `LOC` (element frame); `s1…s9` = subdivision of each element into cells: beam $(\xi,\eta,\nu)$, plate $(\xi,\eta,\nu)$, solid $(\xi,\eta,\nu)$; use `1` for no subdivision |
| `GMSH n frame s1…s9` | the same for GMSH (`RESULTS_GMSH_nn.msh`) |
| `PNT id x y z` | write the results at the global point $(x,y,z)$ in `POST_POINT.dat` |
| `KMAT`, `MMAT` | write the stiffness / mass matrix in `WORK/K_MAT.dat`, `WORK/M_MAT.dat` |
| `FRCE`, `UNKN` | write the force vector / solution vector in `WORK/FORCES.dat`, `WORK/UNKNOWN.dat` |
| `ENRG` | accepted, no output in this release |

The subdivision numbers refine the output grid *inside every element and sub-element* (use 2 or 3 to see smooth curves along the beam axis; each sub-element of the section is a separate set of cells so that laminate layers are visible). The meaning of $(\xi,\eta,\nu)$ is: for a beam $\eta$ along the axis, $(\xi,\nu)$ over the section; for a plate $(\xi,\eta)$ in the surface and $\nu$ through the thickness; for a solid the three element coordinates.

If the declared number of records is larger than the number present, the missing ones are ignored with a warning. Unknown record words are ignored with a warning. A point outside the structure gives a row of `NaN` in `POST_POINT.dat` and a warning.

## A complete minimal checklist

Table: Checklist before running. {#tab:checklist}

| Check | Where |
|---|---|
| analysis is 101 or 103; modes requested for 103 | `ANALYSIS.dat` |
| every element refers to existing nodes, an existing versor and a section number whose files exist | `CONNECTIVITY.dat`, `VERSORS.dat`, `EXP_*` |
| node order of every element follows the figures | `CONNECTIVITY.dat`, `EXP_CONN_nn.dat` |
| the laminations used by the sub-elements exist; each lamination refers to an existing material | `EXP_CONN`, `LAMINATION.dat`, `MATERIAL.dat` |
| the structure is supported: no rigid-body motion left | `BC.dat` |
| loads are at section nodes (static only) | `BC.dat` |
| at least one `PNT` or `PARA` request | `POSTPROCESSING.dat` |
