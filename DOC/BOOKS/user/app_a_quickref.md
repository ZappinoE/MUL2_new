# Quick reference

## Files and records

Table: One-page summary of the input files. {#tab:quickref}

| File | Record | Syntax |
|---|---|---|
| `ANALYSIS.dat` | analysis | `101` or `103`; line 2 number of modes; lines 3–5 `NONE`/`REDI`/`SELI`/`MITC` for beam, plate, solid; optional last line `FIELDS MECH [THERMO] [PIEZO]` (physics solved) |
| `NODES.dat` | node | `id X Y Z TE n` or `id X Y Z LE` |
| `CONNECTIVITY.dat` | element | `TYPE id n1…nN versor section` |
| `VERSORS.dat` | versor | `VERSOR id vx vy vz` |
| `MATERIAL.dat` | header | `n_materials n_records` |
| | isotropic | `ISO-M id E nu rho` |
| | orthotropic | `ORT-M id EL ET EZ nuLT nuLZ nuTZ GLT GLZ GTZ rho` |
| | anisotropic | `MAT-C id c11…c66 rho` |
| `LAMINATION.dat` | lamination | `LAM2 id material angle_y angle_z` (degrees) |
| `EXP_MESH_nn.dat` | section node | `id x y z` (local coordinates) |
| `EXP_CONN_nn.dat` | sub-element | `TYPE id lamination n1…nN` |
| `BC.dat` | constraint | `D-PLANE id A B C D ux uy uz` (plane $AX+BY+CZ+D=0$; `N` = free) |
| | load | `F-POINT id x y z Fx Fy Fz` |
| `POSTPROCESSING.dat` | field output | `PARA` or `GMSH`, `cell_nodes`, `GLB` or `LOC`, `s1…s9` (cell nodes 8, 20, 27) |
| | point | `PNT id x y z` |
| | dumps | `KMAT MMAT FRCE UNKN ENRG` |

## Element node order

Table: Node order of the elements. {#tab:nodeorder}

| Element | Order |
|---|---|
| B2, B3, B4 | along the axis, 1 … N, equally spaced |
| Q4 | counter-clockwise from the corner $(-1,-1)$: 1 2 3 4 |
| Q9 | corners and mid-sides alternate counter-clockwise from $(-1,-1)$: 1 (corner) 2 (mid) 3 (corner) 4 5 6 7 8, **9 = centre** |
| Q16 | 12 boundary nodes counter-clockwise from the corner $(-1,-1)$ (4 per side, corners 1, 4, 7, 10), then interior 13–16 |
| T3 / T6 | corners 1 2 3; T6: 4 = mid 1–2, 5 = mid 2–3, 6 = mid 3–1 |
| H8 | bottom face 1–4 counter-clockwise, top face 5–8 above them |
| H27 | corners 1–8 as H8, then edges 9–20, faces 21–26, centre 27 |

![Beam elements.](figures/elements_1d.svg){#fig:el1d-user}

![Triangles.](figures/elements_tri.svg){#fig:eltri-user}

![Hexahedra.](figures/elements_3d.svg){#fig:el3d-user}

## Frames

Table: Frames at a glance. {#tab:frames-glance}

| Element | Local $y$ | Local $z$ | Local $x$ |
|---|---|---|---|
| beam | the axis (first → last node) | $\mathbf{v}$ made orthogonal to the axis | $y\times z$ |
| plate | $z\times x$ | normal (node 1→2 × node 1→3) | $\mathbf{v}$ projected on the plate |
| solid | $Y$ | $Z$ | $X$ |

Material axes: with zero angles $(T,L,Z)=(x,y,z)$; fibre direction is $L$.

## Typical numbers

Table: Number of unknowns per structural node. {#tab:dofpernode}

| Expansion | Terms | DOF per node |
|---|---|---|
| beam `TE 1`, `TE 2`, `TE 3`, `TE 4` | 3, 6, 10, 15 | 9, 18, 30, 45 |
| beam `LE` with $m$ section nodes | $m$ | $3m$ |
| plate `TE n` | $n+1$ | $3(n+1)$ |
| plate `LE` with $m$ thickness nodes | $m$ | $3m$ |
| solid | 1 | 3 |

## Command line

```bash
MUL2_V3.exe [input_directory]       # default: PATH_input.dat, then INPUT
set OMP_NUM_THREADS=8               # threads
set MUL2_DEBUG=1                    # debug messages
```

## Order of the strain and stress components

$(xx,\ yy,\ zz,\ xz,\ yz,\ xy)$, engineering shear strains. Displacements in `POST_POINT.dat` are global.
