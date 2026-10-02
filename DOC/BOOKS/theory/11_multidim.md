# Multi-dimensional models {#sec:multidim}

A model may contain beams (1D structural elements with a 2D expansion), plates and shells (2D elements with a 1D expansion) and solids (3D elements with a point expansion) at the same time. This chapter explains why the families can coexist and how they are connected.

## One displacement field for all the families

In every family the unknowns are the **global Cartesian components** of the fields at the nodes of the expansion, and the strain is the three-dimensional strain of the continuum written in the frame of the element. A beam with a Lagrange section is a solid whose cross-section is meshed by the expansion; a plate with a Lagrange thickness is a solid with layers; a solid is the case with a single expansion point. The families therefore differ only by the map from the structural element and the expansion to the position in space, not by the physics, and no transformation of the unknowns is needed where they meet.

## Independent regions

Parts of different dimension can be analysed in one input without being connected: the system is block diagonal and every region gives the result it would give alone. The validation report checks this with a beam, a plate and a solid in one model (identical to the three runs to $10^{-9}$).

## Joints through order-0 nodes

A structural node shared by elements of different families must satisfy the term-count rule of Chapter {sec:ndk}: in practice it has the Taylor order 0. Three junctions with an exact solution (uniform stress) are reproduced to the precision of the solver:

Table: Junctions through order-0 nodes (validation report, chapter "Multi-dimensional models"). {#tab:junctions}

| Junction | Model | Error |
|---|---|---|
| 1D/3D | four bars on the corners of an H8 block | $<10^{-9}$ |
| 1D/2D | three bars on the edge of a Q9 membrane | $<10^{-9}$ |
| 2D/3D | two membranes on the faces of an H8 block | $<10^{-9}$ |

A richer expansion at the junction node (TE2 shared by a beam and a solid) is refused with an explicit message, because the term counts differ. The joints transmit forces; a moment is transmitted by a couple of order-0 nodes, never by a single one. The consequence for stiffened shells (rows of order-0 nodes lock the skin) is discussed in Chapter {sec:ndk}.

## Joints by coincident expansion nodes

When the expansion nodes of two parts coincide in space, the parts can be connected even if their structural nodes do not: a beam whose Lagrange section touches a plate, or a plate whose Lagrange thickness lies on the face of a solid. `JOIN COINCIDENT` identifies the coincident degrees of freedom (Chapter {sec:ndk}); the connection is then as rich as the common points (a line of section nodes on a plate transmits forces and moments).

## Assemblies of shells

Curved and flat shells (`S4`, `S9`, `S16`) share the nodes of their edges with a Taylor thickness expansion; at an edge the first-order term is the rotation of the node and the joint is rigid. Skins, spars, ribs and frames of a wing or a fuselage are modelled in this way. Beams on a skin (stringers) can only be attached at isolated order-0 nodes: a continuous stringer is represented by the stiffness and mass of the skin, or by a shell web.

## An example

The complete-aircraft demonstrator of the user guide (14 433 nodes, 129 093 DOF) combines curved shells (fuselage, wings, tails), shell assemblies with edges (spars, ribs, frames), curved beams (tie rods) and solids (engines), all connected by shared nodes and node-dependent kinematics. It has exactly six rigid-body modes, a clean spectrum of global modes and a clamped wing box that matches the thin-walled beam theory.

## Open points

- A beam attached to a shell with the rotation of the shell node (a stringer without order-0 nodes) needs a multipoint relation between the terms of the beam and the rotation $\boldsymbol\omega$ of the shell: it is the natural extension of the edge rule and of the alias of `JOIN COINCIDENT`.
- Mixed (RMVT) elements next to displacement elements: the transverse stresses would exist on one side only of a shared node.
