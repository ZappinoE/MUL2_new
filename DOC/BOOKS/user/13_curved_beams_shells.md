# Curved beams and shells {#sec:curved}

The beam elements `B2 B3 B4` and the plate elements `Q4 Q9 Q16` of the previous chapters have **one straight axis** or **one flat plane** per element. This chapter describes the same families when the geometry is *curved*: a curved beam (arch, ring, frame of a fuselage) and a **shell** (skin of a wing, of a fuselage, a tube, a dome). There is no new element name to learn and **no new input file** is required for the usual case; the nodes decide.

## What you write

| You write | The program does |
|---|---|
| `B3`, `B4` with the nodes **on a curve** (not on a line) | curved beam: the axis is the polynomial curve through the nodes |
| `Q4`, `Q9`, `Q16` with the nodes **out of a plane** | shell: the surface is the polynomial surface through the nodes |
| `CB2 CB3 CB4`, `S4 S9 S16` instead of `B2 B3 B4`, `Q4 Q9 Q16` | the same topology, with the curved geometry **forced** |

A node deviation larger than $10^{-6}$ of the length (beam) or of the diagonal (plate) from the line or from the plane makes an element curved. Flat plates and straight beams keep the previous formulation (and the previous results to the last digit). Use `S9` for the flat panels of a model that also has curved ones: all the shells then share the same formulation (MITC9).

The *section* of a beam and the *thickness* of a shell are described, as before, by the expansion mesh of the element (`EXP_MESH_nn.dat`, `EXP_CONN_nn.dat`) and by the kinematics of the nodes (`TE n`, `LE`, `HLE`, `KINEMATICS.dat`):

| Element | Expansion mesh | Where it lives |
|---|---|---|
| curved beam | 2D (the section) | in the plane normal to the axis |
| shell | **1D (the thickness)**, exactly as for a plate | along the director, normal to the surface |

**The thickness is therefore the extent of the 1D expansion mesh.** It is not a separate input and it does not have to be constant in the model: each zone uses its own expansion mesh (`expansion_id` of the element). The geometry of an element is the mid-surface of the nodes plus the position in the expansion mesh along the director, so a thickness step between two zones is a real step of the faces; the mid-surface is continuous. Any expansion (`TE` of any order, `LE` layer-wise with one or more layers, `HLE`) can be used for the thickness.

## Reference vector (`VERSORS.dat`)

The record `frame_id` of the element selects a vector in `VERSORS.dat`, as for the straight elements. For curved elements it is used at **every point**:

* curved beam: the vector is projected on the plane normal to the axis and gives the local axis $e_3$ of the section (as for a straight beam). It must not be parallel to the axis anywhere on the element;
* shell: the vector is projected on the tangent plane and gives the local axis $e_1$, the **direction of the $0^\circ$ fibres** of the laminate. It must not be normal to the surface anywhere (error `SOR IS NORMAL TO SURFACE`). Use one global direction for a part: the span for a wing, the axis for a fuselage, a tube or a cylinder.

The frame of a point is $(e_1,e_2,e_3)$ with $e_3$ the normal of the shell ($e_2$ the tangent of the beam axis), so stresses and strains of the output (`LOC` frame) are in the axes of the material.

## Directors

A shell node has a **director**, the unit vector along which the thickness is measured (the normal). By default the director of a node is the average of the normals of the elements that share it, **limited to the elements within $40^\circ$ of the normal of the element**: on a smooth surface the director is continuous, on a true edge (two walls of a box, a rib on a skin) every element keeps its own normal.

The normals follow the order of the nodes: $a_1\times a_2$, with $a_1$ the direction of the first side of the element (from node 1 towards node 2 for `Q4`, `Q9`, `Q16`) and $a_2$ the second one. **Number the nodes of the shells of a surface so that the normals point to the same side**; the program warns (`SHELL NORMALS ARE OPPOSITE AT A SHARED NODE`) when two elements with opposite normals share a node.

The polynomial surface is not exactly the real surface: on a cylinder discretised with quadratic elements of $45^\circ$ the director of the polynomial surface is a few degrees off the radial direction (about $0.3^\circ$ with $15^\circ$ elements). If the exact normal is known (CAD, analytic surface) give it in the optional file `DIRECTORS.dat`:

```text
8                       number of directors
1   0.0 0.0 1.0         node_id  Vx Vy Vz  (any length)
2   0.7071 0.0 0.7071
...
```

The directors of the file replace the average for the elements within $40^\circ$ of them; the other nodes keep the automatic ones. The effect on the results is small (below $10^{-3}$ on the pinched cylinder), the effect on the positions of the thickness points of a model with `LE` expansion is visible: a point load on an `LE` thickness node is found by its coordinates and needs the exact director.

## Shear and membrane locking

`ANALYSIS.dat` selects the treatment per family (beam, plate, solid) as before. For curved elements:

| Token | Curved beam | Shell |
|---|---|---|
| `NONE` | compatible strains | compatible strains (**locks**: do not use for thin shells) |
| `MITC` | axial strain and the two shears tied at the $n-1$ Gauss points of the axis | `S9`: MITC9 (Bucalem-Bathe); `S4`: MITC4 (transverse shears); `S16`: compatible strains |
| `REDI`, `SELI` | **error** | **error** |

`MITC` (the default of the examples) is the one to use. The pinched cylinder below reaches $0.98$ of the reference with MITC9 on $8\times8$ elements per octant and $0.35$ without tying on $6\times6$.

## Joining the elements: shared nodes and node-dependent kinematics

Elements are connected by **shared nodes**, with **no multipliers and no constraint equations**: the displacements are the global components of the nodes, so two elements that share a node are continuous. The only rule is the existing one: *every element that shares a node sees the same number of expansion terms at that node*. Within one element each node may have its own kinematics (node-dependent kinematics, `KINEMATICS.dat`), so the order can change from node to node.

| Joint | How |
|---|---|
| shell – shell, flat or curved, also at an edge (box, rib, spar) | share the nodes, same thickness expansion order (`TE 2` on both sides works for walls at $90^\circ$: square tube within 1.3 % of beam theory) |
| shell – shell with another thickness | the zones have different expansion meshes; `TE` nodes of the same order can be shared (the faces step, the mid-surface is continuous) |
| beam – shell (stringer on a skin) | share the nodes and give them the **order 0** (`TE 0`: only $u,v,w$) in the beam and in the shell; the other nodes of both keep their own kinematics |
| curved beam – straight beam | share the nodes; the section meshes may differ with `TE` if the term counts agree |

**Edges (kinks).** At a node shared by shell elements whose normals differ (more than the $40^\circ$ feature angle, e.g. the corner of a box, a rib on a skin) the program does not share the first-order Taylor term as a Cartesian vector (that would tie the thickness derivative of walls with different thickness axes and lock the bending: a box came out 5 to 10 times too stiff) but expresses it as the rotation $\boldsymbol\omega$ of the node acting on the director of each element, $\mathbf q_1=\boldsymbol\omega\times\mathbf V$. The joint is then a rigid edge: displacements and rotations are continuous. Elements of opposite normals at the same node (a knife edge, the trailing edge of a wing) share the term with the sign of the thickness axis. This needs no input, but it is available for TE kinematics of order 1 or 2 (not for LE) and **every shell at the node must be a general element** (name them S4/S9/S16).

A node with `TE 0` has no rotation: the skin is rotationally restrained at the node, which is what a stiff stringer does and the stringer is a rod (axial and shear stiffness). **Use `TE 0` only at isolated nodes**: a *line* of `TE 0` nodes across the bending direction of a skin (a rod along a whole rib, a ring) forces the slope to zero and the structure is several times too stiff. The test `skin + stringer` gives the exact axial stiffness $E(tb+A)/L$ to $2\cdot10^{-5}$.

## Boundary conditions and loads

* `D-PLANE` on a **shell** selects the nodes by their **mid-surface point**: a plane through a shell node constrains the whole thickness of the node (all the terms), even if the director is a fraction of a degree off the plane. For a **beam** the section points are used (a plane can cut the section, as before).
* `F-POINT` is applied at the node and at the expansion node whose position (node + offset along the triad of the node) coincides with the point; for a `TE` node the load goes to the terms through the basis at the point.
* The surface loads `Q-PLANE`, `Q-SUN`, `Q-CONV` are **not available** with curved elements (error).
* Analyses: 101, 103, 104 and 106 (also with the temperature and potential fields); **105 and 108 stop with an error** when the model has curved elements.

## Output

The points of `POSTPROCESSING.dat` are located inside the curved elements (Newton iteration on the map) and the displacements, strains, stresses (and, in the multiphysics models, potential and temperature) are written as for the other elements; the `LOC` frame is the frame of the point. The VTK output (`PARA`) draws the nodes of the expansion along the directors.

## Examples (all in `TESTS/CURVED/curved_tests.py`)

| Problem | Reference | Result |
|---|---|---|
| quarter ring cantilever, tip force, `CB4` | energy solution (bending, axial, shear) | $0.9999$ with 4 elements ($\nu=0$) |
| the same with $\nu=0.3$ | same | $0.995$ with 8 elements (the 3D clamp is slower, as for a straight beam) |
| ring, tip couple | $M x/I$ | stress within 0.1 % |
| free ring (103) | six rigid-body modes | first elastic frequency $4.9037$ Hz, converged to $10^{-5}$ |
| flat plate `S9` | `Q9` | identical to the last digit (TE, LE, MITC, rotated ply) |
| pinched cylinder, `S9`, `TE 2`, `LE` | MacNeal-Harder $1.8248\cdot10^{-5}$ | $0.98$ ($8\times8$), $1.00$ ($12\times12$) |
| cantilever circular tube | beam theory | $0.990$ |
| cantilever square tube (shared corner nodes, rotation at the edges) | beam theory | $0.995$ to $1.03$ |
| skin + stringer joined at `TE 0` nodes | $E(tb+A)/L$ | $2\cdot10^{-5}$ |

## Limits

* No curved beams or shells in 105 (buckling) and 108 (nonlinear); no surface loads on them.
* No arbitrary surface or body loads: loads are nodal (`F-POINT`), as before.
* A beam shares nodes with a shell only at the nodes where both have the same number of terms (order 0 in practice).
* `S16` has no tying table (compatible strains).
* The directors of a very coarse surface are inaccurate: use `DIRECTORS.dat` or refine.
