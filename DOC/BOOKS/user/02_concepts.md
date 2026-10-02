# How to describe a structure {#sec:concepts}

## Two meshes, not one

The unusual thing about a CUF model is that **a structure is described by two meshes**:

1. the **structural mesh** (`NODES.dat`, `CONNECTIVITY.dat`): what an ordinary finite element model has — nodes in space and elements joining them. A *beam* is a chain of line elements (B2, B3, B4) along its axis; a *plate* is a surface mesh (Q4, Q9, …); a *solid* is a volume mesh (H8, H27, …);
2. the **expansion mesh** (`EXP_MESH_nn.dat`, `EXP_CONN_nn.dat`): a small mesh of **what the structural element does not describe** — the cross-section of a beam, the thickness of a plate. Its nodes are local coordinates measured in the element frame, and each of its elements carries a *lamination* (a material and an orientation).

Each structural node also has an **expansion model** (`TE n` or `LE`): it decides how the displacement varies over the expansion mesh. With `TE n` the displacement of the section is a polynomial of degree $n$; with `LE` it is interpolated from the displacements of the nodes of the expansion mesh.

![A beam: structural nodes (left, red) and the section expansion mesh (right).](figures/cuf_concept.svg){#fig:concept-user}

## What the three families look like

Table: How the three families are modelled. {#tab:families}

| Family | Structural elements | Expansion mesh | Expansion nodes are at | Typical unknowns per node |
|---|---|---|---|---|
| Beam | B2, B3, B4 | the cross-section: Q4, Q9, Q16, T3, T6 elements | $(x_s, 0, z_s)$ | $3T$, $T$ = terms (`TE n`: $(n+1)(n+2)/2$; `LE`: nodes of the section mesh) |
| Plate | Q4, Q9, Q16, T3, T6 | the thickness: B2, B3, B4 elements | $(0, 0, z_s)$ | $3T$, $T$ = terms (`TE n`: $n+1$; `LE`: nodes of the thickness mesh) |
| Solid | H8, H27, … | one point (`S1`) | $(0,0,0)$ | 3 |

For a **solid** the section mesh is trivial: a single node and the element `S1`:

```text
EXP_MESH_01.dat          EXP_CONN_01.dat
1                        1

1  0.0D0  0.0D0  0.0D0   S1  1  1  1
```

The expansion mesh is *shared* by all the structural elements that refer to it through their last integer in `CONNECTIVITY.dat` (the "section" number). A model can use several expansion meshes (`EXP_MESH_01`, `EXP_MESH_02`, …); this is how a model can contain, for example, a thick-walled and a thin-walled part.

## Units and coordinates

The program is **unit-free**: use any consistent set. The examples of this guide use SI units (metres, newtons, pascals, kilograms; frequencies in hertz).

Three coordinate systems appear in the files (Chapter 5 explains them in detail):

- the **global system** $(X,Y,Z)$: node coordinates, point coordinates of loads and results, constraint planes;
- the **element system** $(x,y,z)$: used for the *section/thickness coordinates* in `EXP_MESH_nn.dat` and for strains and stresses in the `LOC` output; it is built automatically from the nodes and the *versor* of the element;
- the **material system** $(T,L,Z)$: the principal axes of a material, related to the element system by the angles of `LAMINATION.dat`.

## Which element for which structure?

- **Beams**: the axis of the beam is the line through the nodes. Use B3 or B4 elements for curved or highly loaded beams and B2 for simple cases (use `MITC` for B2/B3 to avoid shear locking).
- **Plates and shells**: use Q4 (simple) or Q9 (more accurate, recommended with `MITC`). A plate may be oriented anywhere in space (the element frame follows its plane), but each element should be **flat or nearly flat**: the frame is built from three corners and out-of-plane warping of the nodes is neglected.
- **Solids**: H8 for simple blocks (without MITC), H27 for accuracy.
- **Mixed models**: a model may contain beams, plates and solids at the same time; they must be connected through *shared nodes* with compatible expansions (Chapter 6).

## The files of a model

![Which file controls what.](figures/file_map.svg){#fig:filemap-user}

A minimal model needs: `ANALYSIS.dat`, `NODES.dat`, `CONNECTIVITY.dat`, `VERSORS.dat`, `MATERIAL.dat`, `LAMINATION.dat`, at least one `EXP_MESH_01.dat` + `EXP_CONN_01.dat`, `BC.dat` and `POSTPROCESSING.dat`. Chapter 4 describes each of them record by record.

## Rules that apply to all files

1. The first data line of every file is the **number of records** that follow.
2. Blank lines are ignored and so is everything that follows the data (descriptions, comments); the number of records tells where the data ends.
3. Fields are separated by blanks or tabs. Real numbers may be written as `1.0`, `1e-3` or `1.0D-3`.
4. Names (`B4`, `LE`, `ISO-M`, `D-PLANE`, …) are not case sensitive.
5. Identifiers (nodes, elements, materials, …) are positive integers and must be unique inside their file. They need not be consecutive.
6. The order of the files in the directory does not matter; all the files must be in the same input directory.
