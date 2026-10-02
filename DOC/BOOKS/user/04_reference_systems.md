# Reference systems in practice {#sec:refsys}

This chapter explains, with recipes and examples, how to orient beams, plates and materials. The theory is in the Theoretical Guide (chapter *Reference systems*); here the question is: *given my structure, what do I write in the files?*

## The three systems at a glance

Table: The three reference systems. {#tab:three-systems}

| System | Symbol | Defined by | Used for |
|---|---|---|---|
| Global | $X,Y,Z$ | the coordinates in `NODES.dat` | node coordinates, loads, constraint planes, displacements in the output, `GLB` output |
| Element (local) | $x,y,z$ | element geometry + `VERSORS.dat` | the coordinates of `EXP_MESH_nn.dat`; strain and stress in `LOC` output |
| Material | $T,L,Z$ | element system + angles of `LAMINATION.dat` | the constants of `ORT-M` and `MAT-C` |

The three axes of the element system are always right-handed.

## Beams

For a beam element the local $y$ axis **is the axis of the beam**, from its first node to its last node. The versor $\mathbf{v}$ gives the **direction of the local $z$ axis** of the section (the part of $\mathbf{v}$ along the axis is ignored), and the local $x$ is $y\times z$.

![Beam frame.](figures/frames_beam.svg){#fig:fr-beam-user}

The section coordinates written in `EXP_MESH_nn.dat` are measured on these axes: a node with `x = 0.05`, `z = -0.05` lies $0.05$ along the local $x$ and $0.05$ against the local $z$ from the axis. The `y` coordinate of a section node is always 0.

Table: Beam recipes (axis direction, versor → local axes in global components). {#tab:beam-recipes}

| Beam axis (first → last node) | Versor | Local $x$ | Local $y$ | Local $z$ |
|---|---|---|---|---|
| $+Y$ | $(0,0,1)$ | $+X$ | $+Y$ | $+Z$ |
| $+Y$ | $(1,0,0)$ | $-Z$ | $+Y$ | $+X$ |
| $+X$ | $(0,0,1)$ | $-Y$ | $+X$ | $+Z$ |
| $+X$ | $(0,1,0)$ | $+Z$ | $+X$ | $+Y$ |
| $+Z$ | $(1,0,0)$ | $+Y$ | $+Z$ | $+X$ |
| $+Z$ | $(0,1,0)$ | $-X$ | $+Z$ | $+Y$ |

**Rule of thumb.** Choose the versor along the direction that you want the *height* of the section to run (the axis whose coordinate you will put in `z`), and put the *width* in `x`. For a beam along $Y$ with the section height along $Z$ use $(0,0,1)$.

**Sign matters.** Reversing the versor ($\mathbf{v}\to-\mathbf{v}$) flips both $z$ and $x$ (a rotation by 180° of the section about the axis). It does not matter for a doubly-symmetric section; it does for an unsymmetric one.

**Beam elements of one beam must have the same orientation.** Elements that belong to the same straight beam can share the same versor id. A beam that bends (curved beam, frame) needs a versor per straight part: give each part its own `VERSOR` record and refer to it in the element records.

## Plates

For a plate the element frame is built from three corner nodes of the element (Q4: nodes 1, 2, 4; Q9: 1, 3, 7; Q16: 1, 4, 10; triangles: 1, 2, 3). The local $z$ axis is the **normal** (right-hand rule applied to node 1→2 and 1→3), the local $x$ is the **projection of the versor on the plate**, and $y=z\times x$.

![Plate frame.](figures/frames_plate.svg){#fig:fr-plate-user}

The **thickness coordinate** written in `EXP_MESH_nn.dat` (third column) is measured along the local $z$: positive values are on the side the normal points to ("top").

Table: Plate recipes (the nodes of the element are numbered counter-clockwise looking from the side of the normal). {#tab:plate-recipes}

| Plate plane | Node order (corners) | Normal $z$ | Versor | Local $x$ | Local $y$ |
|---|---|---|---|---|---|
| $XY$ | counter-clockwise seen from $+Z$ | $+Z$ | $(1,0,0)$ | $+X$ | $+Y$ |
| $XY$ | clockwise seen from $+Z$ | $-Z$ | $(1,0,0)$ | $+X$ | $-Y$ |
| $XZ$ | $X$ then $Z$ direction (corner 2 along $+X$, corner 3 along $+Z$) | $-Y$ | $(1,0,0)$ | $+X$ | $+Z$ |
| $YZ$ | corner 2 along $+Y$, corner 3 along $+Z$ | $+X$ | $(0,1,0)$ | $+Y$ | $+Z$ |

**Practical advice.** Number the nodes of every plate element in the same sense (counter-clockwise seen from the side you call "top") and use one versor per plane. With a laminate, "top" is also the side of the *last* ply of the thickness mesh: the order of the plies in `EXP_CONN` goes from the most negative to the most positive $z$ (bottom to top).

## Solids

For solid elements the element frame **is** the global frame. Nothing to choose. The versor field of the element record is ignored.

## Mixing beams, plates and solids

Elements of different families that meet at a node must use compatible expansions at that node. The structural coordinates $(X,Y,Z)$ of the node are global; each element uses its own local frame, which is built independently. The unknowns are always global displacement components, so no transformation at the junction is necessary.

## Material orientation

The elastic constants of `ORT-M` are given in the material axes $(T,L,Z)$. With zero angles they coincide with the element axes $(x,y,z)$:

- **beam**: $L=y$ (the fibre runs along the beam axis), $T=x$, $Z=z$;
- **plate**: $L=y$ (along the second in-plane local axis), $T=x$, $Z=z$ (through the thickness).

The two angles of a lamination, in degrees, rotate the material relative to the element system:

![Rotation of the material axes by theta_z about the element z axis.](figures/material_frame.svg){#fig:matframe-user}

- $\theta_z$ (`angle_z`): rotation about the local $z$. For a *plate*, this turns the fibres in the plane of the plate: $\theta_z=90^\circ$ puts the fibres along $x$ instead of $y$. For a *beam* it turns the fibres in the plane of the section.
- $\theta_y$ (`angle_y`): rotation about the local $y$, which for a plate means a rotation in the thickness plane and for a beam a rotation of the fibres about the axis.

> NOTE: The matrix $\mathbf{R}_z(\theta_z)\mathbf{R}_y(\theta_y)$ maps *element* components to *material* components; so a positive $\theta_z$ turns the material axes counter-clockwise when looking from $+z$ (as drawn above) — to check the sign in a new model, run a coupon with a known answer such as the example below.

### Example: stacking sequence of a plate strip

A cantilever strip $0.1\times1.0$ m with thickness $0.1$ m of three equal plies, material `ORT-M 1  140D9 10D9 10D9  0.3 0.3 0.4  5D9 5D9 3.5D9  1600` (fibre along $L$). The strip runs along $Y$ and has the thickness along $Z$, so the fibre direction for zero angles is along the strip. The plies are given by three laminations:

Table: Two stacking sequences of the same strip (clamped at $Y=0$, tip load 1000 N at the top face). {#tab:laminate-results}

| Laminations (bottom → top) | angle_z of the plies | Tip $w$ [m] | $f_1$ [Hz] |
|---|---|---|---|
| `LAM2 1 1 0 0`, `LAM2 2 1 0 90`, `LAM2 3 1 0 0` | 0°/90°/0° | $3.22\times10^{-4}$ | 120.97 |
| `LAM2 1 1 0 90`, `LAM2 2 1 0 0`, `LAM2 3 1 0 90` | 90°/0°/90° | $2.67\times10^{-3}$ | 49.23 |

With 0°/90°/0° the two *outer* plies (which carry the bending) have their fibres along the strip, the strip is **8 times stiffer** than in the 90°/0°/90° case, where the stiff fibre ply is in the middle near the neutral axis and the outer plies are matrix-dominated. This is a good quick check of the angle convention in any new model: *outer plies with fibres along the beam axis ⇒ stiff*.

The files are in `examples/cases/plate_lam_0_90_0_static` and `plate_lam_90_0_90_static`; the expansion mesh is three `B2` sub-elements:

@include examples/cases/plate_lam_0_90_0_static/INPUT/EXP_MESH_01.dat 8 EXP_MESH_01.dat (thickness nodes, bottom to top)

@include examples/cases/plate_lam_0_90_0_static/INPUT/EXP_CONN_01.dat 8 EXP_CONN_01.dat (one sub-element per ply, with its lamination id)

@include examples/cases/plate_lam_0_90_0_static/INPUT/LAMINATION.dat 8 LAMINATION.dat

## Output frames

Displacements are **always** written in the global frame in `POST_POINT.dat` (columns `U_X, U_Y, U_Z`). Strains and stresses are written in **both** frames: the `(LOC)` columns in the element frame of the element that contains the point, the `(GLB)` columns in the global frame. In the VTK/GMSH files the `LOC`/`GLB` word of the request selects the frame of **all** the output fields (displacement, strain, stress):

- `GLB`: all components along $X,Y,Z$;
- `LOC`: components along the element axes $x,y,z$ of each element (for a beam $y$ is the axis, so `Sigma_YY` is the axial stress; for a plate `Sigma_ZZ` is the through-thickness stress).

Strain and stress component order is always $(xx,yy,zz,xz,yz,xy)$ with engineering shear strains $\gamma$.
