# Node- and field-dependent kinematics {#sec:ndk}

The expansion of the Carrera Unified Formulation is not a property of the element: in MUL2_NEW it is a property of the **node** and of the **field**. This chapter collects the rules that follow from that choice; they are the basis of the multi-dimensional models of the next chapter.

## Kinematics per field

A node refers to a *kinematic*: a record of `KINEMATICS.dat` that gives an expansion family and an order to each of the nine fields of the formulation, $u, v, w, T, P, B, \sigma_{zz}, \sigma_{xz}, \sigma_{yz}$ (B and the three stresses are reserved). The displacement components may therefore use different expansions, and the temperature or the electric potential may use an expansion different from the displacements (a quadratic temperature through a thickness that carries a cubic displacement, for instance). The kernels allow it because the strain column of a degree of freedom is always built from the scalar basis of **its own** field (Chapter {sec:nucleus}).

The kinematics only define *how* a field is expanded. *Which* fields are solved is a choice of the analysis: the record `FIELDS MECH [THERMO] [PIEZO]` of `ANALYSIS.dat` switches the temperature and the potential on and off without touching the kinematics; without the record every expanded field is solved. The principle of the element is a further, separate choice: today every element is displacement based (PLV); a mixed element (RMVT) will be selected element by element and will bring the transverse stresses, whose expansion slots already exist.

## Kinematics per node

Each node has its own kinematic, so the order can change along a beam, across a plate or inside a shell (node-dependent kinematics, NDK). The degrees of freedom of a node are

$$
n_{\text{DOF}}(\text{node})=\sum_{f}T_f(\text{node}),
$$

with $T_f$ the number of terms of the field $f$ at that node. Two rules make a node consistent:

1. **Term count.** Every element that shares the node sees, for every field, the same number of terms. For a Taylor expansion this means expansion meshes of the same dimension (all beam sections, or all plate thicknesses); for a Lagrange expansion it means **the same expansion mesh** (the terms are its nodes).
2. **Conformity.** At an interface between a node of high order and one of low order, the unknowns of the missing terms are simply absent. The displacement is continuous only if the lower expansion is a subset of the higher one (TE2 next to TE4). A mixed LE/TE interface is not conforming in general; the hierarchical expansions keep, on a shared side, only the modes of the lower order (Chapter {sec:hle}).

## Order-0 nodes

A Taylor expansion of order 0 has a single term, the translation of the node. It has the same number of terms on a section (1D element), on a thickness (2D element) and at a point (3D element), so it is the natural **junction between families**: a beam, a plate and a solid can share an order-0 node.

An order-0 node has no rotation and no section deformation: through it the families exchange forces, not moments. A beam attached to a solid at one order-0 node is hinged there; a beam attached at several order-0 nodes of a section transmits a moment through the couple of forces. The limitation that follows is important for stiffened structures: the elements around an order-0 node cannot develop a slope or a thickness strain there. A *row* of order-0 nodes along a skin (a stringer, a ring modelled as beams on the skin nodes) forces the bending slope of the skin to vanish along the row and makes the structure several times too stiff. Order-0 joints are therefore admissible at **isolated** nodes only.

## Edges between shells

At a node shared by shells of different normals (the corner of a box, a rib on a skin) the director of each element is its own normal. The Taylor term of order one, $\mathbf q_1=\partial\mathbf u/\partial c$, is then a different quantity in each element: the rotation of one wall and the thickness stretch of the other. Sharing it as a Cartesian vector would tie these quantities and suppress the bending slope at the edge. MUL2_NEW writes the first-order term of each element as the rotation $\boldsymbol\omega$ of the node acting on its own director,

$$
\mathbf q_1^{e}=\boldsymbol\omega\times\mathbf V^{e},
$$

with $\boldsymbol\omega$ the shared unknown: displacements and rotations are continuous through the edge (a rigid joint), without multipliers. Elements whose normals are exactly opposite (a knife edge) share $\mathbf q_1$ with the sign of their thickness axis. The rule acts on the columns of the strain and of the basis (and on the directions of the DOFs used by the mass and by the recovery); it needs a Taylor thickness expansion of order 1 or 2 (Chapter {sec:th-curved}).

## Joining by coincidence

A shared node is the ordinary joint. With the record `JOIN COINCIDENT` of `ANALYSIS.dat` the program also identifies the degrees of freedom of *different* nodes that are the same field at the same point of space, the point being the node plus the offset of the expansion node:

- Lagrange expansions: every expansion node (it is a value of the field at a point);
- Taylor expansions: the term of order 0 (the value at the node); the higher terms only for elements of the same orientation, since they are derivatives along the element axes;
- hierarchical expansions: nothing (their side and internal modes are not values).

The joined unknowns become one unknown of the system (an alias of the DOF numbering), so assembly, constraints and recovery are unchanged.

## Summary of the joints

Table: Admissible joints. {#tab:joints}

| Joint | How | Continuity |
|---|---|---|
| same family, same expansion | shared node | full |
| same family, different Taylor orders | shared nodes, NDK | the common terms |
| shells meeting at an edge | shared nodes, Taylor order 1-2 | displacement and rotation |
| beam / plate / solid | shared order-0 nodes, isolated | translations |
| Lagrange section on a Lagrange thickness or on a solid | `JOIN COINCIDENT` | the field at the common points |
| two parts with coincident nodes but different numbers | `JOIN COINCIDENT` | as if the nodes were shared |
