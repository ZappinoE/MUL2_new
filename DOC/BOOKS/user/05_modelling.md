# Modelling guide {#sec:modelling}

This chapter collects advice on how to build good models: how to choose the elements and the expansion, how fine the meshes should be, how to support and load the structure, and how to check the answer.

## Choosing the structural theory

Table: Decision guide. {#tab:model-choice}

| You want… | Use | Why |
|---|---|---|
| global response (deflection, frequencies) of a slender beam | beam, `TE 2` | the cheapest model that includes the Poisson effect of the section |
| local effects, thick or short beam, non-compact sections | beam, `TE 3`–`TE 6`, or `LE` | richer section kinematics |
| thin-walled, open or hollow section, stress concentration at a joint | beam with an `LE` section mesh | the mesh follows the geometry; no ill-conditioning |
| laminated or sandwich beam or plate | `LE` with one sub-element per ply or per group of plies | displacement continuity between plies, layer-wise stresses |
| thin plate | plate Q9 (or Q4) with `MITC`, thickness `TE 2` or `LE` | locking-free |
| full 3D | H27 solid | no kinematic assumption |

**Order of cost** (per structural node): `TE 1` (9 DOF) < `TE 2` (18) < `LE` with a few section nodes < `TE 4` (45) < … The assembly and solution cost grow faster than the number of unknowns; a good strategy is to start with a coarse model and refine.

## Mesh along the axis or in the plane

- Use **B4** (cubic) or **B3** elements along the beam when the loading is concentrated or the beam is highly loaded; at least **4 to 5 B3/B4 elements** per beam give a sound global response.
- Use **B2** only with `MITC`, and with 10 or more elements per beam.
- For plates use **Q9** with `MITC` and at least $4\times4$ elements per panel; refine near supports, loads and holes.
- Remember that each structural node carries the *whole* section expansion: refining along the axis multiplies the number of unknowns by the number of terms.

## Choosing the section mesh (Lagrange expansions)

- Use **Q9** sub-elements. One element per flat part of the cross-section gives a first answer; $2\times2$ gives a robust one.
- For bending the **height** needs more elements than the width; for a thin-walled section place at least 2–3 elements across the thickness of every wall to capture bending of the wall.
- For a laminate, use **at least one sub-element per ply** through the thickness (B2 sub-elements for a plate give a linear distribution in each ply; B3 gives a quadratic one). More sub-elements per ply improve the transverse stresses.
- The mesh must be **conforming**: nodes shared by two sub-elements must be the same node.
- For a Taylor expansion any simple convex section mesh is fine (a single Q9 or Q4 for rectangular sections; several sub-elements for a section made of several laminations).

## Coupling different parts of the model

Elements are connected by **shared nodes**; at a node every incident element must see, for every field, the same number of expansion terms (node-dependent kinematics, `KINEMATICS.dat`):

| Joint | How |
|---|---|
| same family, same expansion | share the nodes |
| same family, different Taylor orders | share the nodes; the order may change from node to node (TE2 next to TE4 is conforming) |
| Lagrange nodes | every element at the node uses the same expansion mesh (same section or thickness) |
| shells at an edge (box, rib, spar, frame) | share the nodes with `TE 1`/`TE 2`; the program uses the rotation of the node at the edge (Chapter {sec:curved}) |
| beam / plate / solid | share nodes with `TE 0` (translations only); **isolated** nodes only: a row of `TE 0` nodes along a skin locks its bending |
| parts whose expansion nodes coincide but structural nodes do not | `JOIN COINCIDENT` (next section) |

Parts of different dimension that are not connected can be analysed in the same input (independent regions). The theory is in the Theoretical Guide, chapters *Node- and field-dependent kinematics* and *Multi-dimensional models*.

## Joining by coincidence of the DOFs (`JOIN COINCIDENT`)

The ordinary joint is the **shared node**: two elements that cite the same node number share its degrees of freedom. When two parts are modelled separately, their structural nodes do not coincide even if their expansion nodes do: a beam whose section node lies on a plate, a plate and a solid that touch along a face. For these cases the last record of `ANALYSIS.dat` can be

```
JOIN COINCIDENT
```

(optionally followed by a tolerance, a fraction of the diagonal of the model, default $10^{-6}$). The program then identifies two degrees of freedom of different nodes when they are **the same field at the same point of space**, the point being the node plus the offset of the expansion node:

| Expansion | What is joined |
|---|---|
| `LE` | every expansion node of a node with those of other nodes at the same point (same field) |
| `TE` | the term 1 (the value at the node); the higher terms only if the two elements have the same orientation, since they are derivatives along the element axes |
| `HLE` | nothing (side and internal modes are not values) |

The joined DOFs are one DOF of the system. The run prints a warning with the outcome (DOFs joined, or none found). Without the record nothing changes. Remarks: nodes that must stay separate at the same position (a crack) are joined too, so use the record only when you want the joint; an `LE` DOF is never joined to a `TE` one; shells with the rotation of the node at an edge are not joined by this record (use shared nodes).

Test: `TESTS/JOIN/join_tests.py` (two beam segments whose structural nodes are shifted and whose section meshes are shifted back give the same result as the beam with a shared node, to the last digit).

## Supports

- **Clamps:** a `D-PLANE` at the end section constrains *all* DOFs of that section (every term of every node on the plane). It is a *perfect three-dimensional clamp*: the section cannot warp or contract at the root, and the structure is slightly stiffer than the beam theory predicts.
- **Simple supports and symmetry:** constrain only the components that must vanish, writing `N` for the others (see the examples of `D-PLANE`), and remember that a **Taylor** node must lie completely on the plane.
- **Avoid rigid-body motions:** a static analysis needs at least the six rigid-body motions of each connected part to be constrained; otherwise PARDISO reports a zero pivot. A modal analysis with free rigid-body modes fails for the same reason.
- **Constrain only what is needed:** over-constraining (for example all three components at all the nodes of a long edge) creates artificial stiffness and local stress peaks.

## Loads

- Only **point loads** exist. They must be applied at nodes of the section mesh of a structural node. To model a distributed load, divide the total force among the nodes consistently: for a uniform load on a Q9 edge use 1/6, 4/6, 1/6 of the total on the corner, mid and corner node; on a Q4 edge 1/2 and 1/2; on a B4 beam axis load $q$ per unit length use $q\ell\,(1/8, 3/8, 3/8, 1/8)$ on the four nodes of an element of length $\ell$ (each node shared between two elements receives the contribution of both).
- With a **Taylor expansion** a point load at a section node is *projected* on all the monomials: the same force at a corner and at the centre produces different generalised forces. A resultant at the centroid is best applied at the **centre node** of the section mesh.
- For a **tip shear on a section**, a single concentrated load produces local stress peaks at the load point (Saint-Venant): compare stresses at least one section height away from the point of application.

## Mesh convergence and model checks

1. **Refine and compare.** Double the number of elements along the axis (and/or add section elements) and verify that the quantity you care about changes by less than your tolerance.
2. **Compare expansions.** A `TE 2` result that differs more than 2–3 % from `TE 4` or `LE` signals that the model is too poor for the problem.
3. **Use a simple theory as a cross-check:** deflection $PL^3/3EI$, frequencies of Euler–Bernoulli beams, etc. (Chapter {sec:trouble}).
4. **Look at the deformed shape** (ParaView *Warp by vector*) before reading numbers: it reveals missing supports, wrong node ordering and wrong units immediately.
5. **Read `REPORT/WARNING_file.dat`** and the console after every run.
6. **Check the equilibrium** of the reaction roughly: the sum of the loads must be balanced by the supports (use the dumps `KMAT` and `FRCE` if you need the reactions).

## Strains and stresses

Strains and stresses are computed from the displacement field *at the point* and are **discontinuous** between elements and between plies. Do not average them blindly:

- At a point exactly on an element or sub-element boundary the program picks one of the two sides; ask for points slightly inside a ply (a small distance from the interface) to read the ply stresses.
- Transverse shear and normal stresses of laminates are good only with a fine thickness mesh (several sub-elements per ply) and quadratic Lagrange elements.
- Stresses near constraints, loads and re-entrant corners depend on the mesh size: they are *singular* in the continuum and converge slowly.

## Numerical hygiene

- **Scale.** Work with dimensions of order one whenever possible. For high-order Taylor models measure the section in units where its size is about 1 (for example millimetres instead of metres), because monomials of order $n$ of a very small number underflow.
- **Aspect ratios.** Elements with very large aspect ratios and thin plates with `NONE` give poorly conditioned matrices; use `MITC`.
- **Do not use `MITC` on H8 elements.**
- **High Taylor orders (> 8)** can make the matrices numerically singular. The program then retries with a more robust factorisation and prints a warning; check the answer with a different expansion.

## Memory and time

Table: Rough cost of beam models (one run, Release build, 16 cores). {#tab:cost}

| Model | DOF | Non-zeros of K | Peak memory | Static time |
|---|---|---|---|---|
| 5 B4, `TE 2` | 288 | 25 000 | < 50 MB | < 0.3 s |
| 5 B4, `LE` ($2\times2$ Q9) | 1 200 | 0.2 M | < 100 MB | < 0.5 s |
| 136 B4, 16 Q9 section elements (`LE`) | 99 387 | 20 M | 1.4 GB | 6 s |
| 82 B4, `TE 15` | 100 776 | 205 M | 7.8 GB | 26 s |

Estimate memory as: **16 bytes × (non-zeros of K)** for the matrix, **plus** the factor of PARDISO (typically 2–10 times the matrix for three-dimensional-like coupling), **plus** the same again for $\mathbf{M}$ in a modal analysis. Taylor models are dense inside each element ($n^2$ non-zeros per element) while Lagrange models only couple section nodes that share a sub-element.
