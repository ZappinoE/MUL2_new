# Preprocessing: the model cache {#sec:preproc}

`BUILD_MODEL_CACHE(MODEL, CACHE, STATUS)` (module `MUL2_MODEL_CACHE`) turns the validated model into the arrays used by the kernels. It runs once per execution. Each step is a separate routine returning a status; the pipeline stops at the first error.

![Pipeline of BUILD_MODEL_CACHE.](figures/flow_cache.svg){#fig:flow-cache}

## Step 0: mechanical check

`CHECK_MECHANICAL_MODEL` verifies that fields 4–9 (T, P, B, SZZ, SXZ, SYZ) are `NONE` in every kinematic (only displacements are supported by 101/103) and that the model has at least one element.

## Step 1: DOF layout

`BUILD_DOF_LAYOUT` (Chapter {sec:datamodel}). For every node it looks at the incident elements through `BUILD_NODE_INCIDENCE`; `NODE_FIELD_TERM_COUNT` returns the number of terms of each field: Taylor → `TAYLOR_BASIS_TERM_COUNT` of the dimension of the expansion mesh of the incident elements (the dimensions of the meshes of all incident elements must agree, error `EXPANSION HAS MIXED DIMENSIONS` / `NODE HAS INCOMPATIBLE EXPANSION DIMENSIONS` otherwise); Lagrange → the number of nodes of the expansion mesh, and **all elements incident to a Lagrange node must use the same expansion mesh** (error `LE NODE USES INCOMPATIBLE EXPANSIONS`). A Hierarchical or user-defined family gives an explicit "not implemented" error. A node with no incident element gets no DOF and a warning.

## Step 2: element frames

`BUILD_ELEMENT_FRAMES` computes, for every element, `ORIGIN` (first node), `GLOBAL_TO_LOCAL` and `LOCAL_TO_GLOBAL` with `BUILD_BEAM_FRAME` (B2/B3/B4), `BUILD_SURFACE_FRAME` (Q4, Q9, Q16, T3, T6) or the identity (solids), using the formulas of the Theoretical Guide (chapter *Reference systems*). The versor is looked up with `FIND_VECTOR_INDEX` from the `FRAME_ID` of the element.

## Step 3: reference quadrature rules

`BUILD_EXPANSION_POINT_ORDERS` computes, for every expansion mesh $m$, the number of Gauss points per direction $n_g(m)$ needed by the Taylor orders of the nodes of the elements that use it: the largest `ORDER + 1` over the three displacement fields of those nodes (0 when the default rule is enough). The result is `CACHE%EXPANSION_ORDER(m)`.

`BUILD_REFERENCE_RULE_DATABASE` creates one `REFERENCE_RULE_TYPE` for every distinct pair (topology, order): structural topologies with the default rule, expansion topologies with `EXPANSION_POINTS(topology, n_g)` points per direction when that exceeds `DEFAULT_POINTS_PER_DIRECTION`. A rule stores

| Component | Shape | Content |
|---|---|---|
| `COORDINATE` | `(points, 3)` | natural coordinates of the points |
| `WEIGHT` | `(points)` | Gauss weights |
| `SHAPE` | `(nodes, points)` | shape function values $N_a(\xi_p)$ |
| `DERIVATIVE` | `(nodes, 3, points)` | natural derivatives $\partial N_a/\partial\xi_d$ |

`FIND_REFERENCE_RULE(db, topology, order)` returns the index of the rule (order 0 = default). The rules for more than four points per direction come from `GAUSS_LEGENDRE_1D` (Newton iteration).

## Step 4: Gauss layout

A **combined Gauss point** is a pair (structural point $p$, expansion point $q$ of a sub-element $e$). `BUILD_GAUSS_LAYOUT` numbers all of them contiguously, element by element, with the order *sub-element, structural point, expansion point* (outermost to innermost):

![Layout of the combined Gauss points of one element.](figures/gauss_layout.svg){#fig:gauss-layout}

`GAUSS_LAYOUT_TYPE` stores, for every global point number, the decomposition:

Table: Components of `GAUSS_LAYOUT_TYPE`. {#tab:layout}

| Component | Size | Meaning |
|---|---|---|
| `COUNT` | scalar | total number of combined points |
| `ELEMENT_FIRST(e)`, `ELEMENT_LAST(e)` | elements | range of the points of element $e$ |
| `ELEMENT_INDEX(g)` | points | element of point $g$ |
| `EXPANSION_ELEMENT_INDEX(g)` | points | sub-element $e_x$ inside the mesh |
| `STRUCTURAL_RULE_INDEX(g)`, `STRUCTURAL_POINT_INDEX(g)` | points | rule of the structural topology and point $p$ in it |
| `EXPANSION_RULE_INDEX(g)`, `EXPANSION_POINT_INDEX(g)` | points | rule of the sub-element topology and point $q$ in it |
| `LAMINATION_ID(g)` | points | lamination of the sub-element |
| `REFERENCE_WEIGHT(g)` | points | $w_p w_q$ |

This is a *decomposition table*: no coordinates, no Jacobians are stored per combined point, only indices. The point of element $e$, sub-element $j$, structural point $p$, expansion point $q$ has the number

$$
g=\text{ELEMENT\_FIRST}(e)+\sum_{j'<j}P\,Q_{j'}+(p-1)\,Q_j+(q-1).
$$

## Step 5: structural and expansion geometry

`BUILD_STRUCTURAL_GEOMETRY_CACHE` loops over the elements, builds the local coordinates of the nodes (`GLOBAL_TO_LOCAL × (X_node − ORIGIN)`), keeps only the active axes (`STRUCTURAL_ACTIVE_AXES`: $y$ for beams, $x,y$ for plates, $x,y,z$ for solids) and, for every structural point, calls `EVALUATE_SQUARE_JACOBIAN` to obtain `JACOBIAN`, `INVERSE_JACOBIAN`, `DETERMINANT` and the physical derivatives of the shape functions. The latter are stored in `DERIVATIVE_LOCAL(3, entry)` with the active components filled and the others zero; `DERIVATIVE_OFFSET(point)` is the first entry of the point (nodes follow one after the other). The global coordinate of the structural point (`CENTER_GLOBAL`) is also stored.

`BUILD_EXPANSION_GEOMETRY_CACHE` does the same for every sub-element of every expansion mesh (`ACTIVE_AXIS(:,mesh)` from `FIND_EXPANSION_ACTIVE_AXES`, `COORDINATE_LOCAL` of the point, determinant, local gradients). The expansion cache does not depend on the structural element: **it is shared by all elements that use the mesh**. For a solid (`S1`, dimension 0) the determinant is 1 and the gradients are zero.

`BUILD_COMBINED_GAUSS_GEOMETRY` ties the two caches together: for every combined point it stores `STRUCTURAL_CACHE_INDEX` and `EXPANSION_CACHE_INDEX`, the global coordinate $\mathbf{X}_p+\mathbf{R}^T\mathbf{c}_q$ and the **integration weight** $w_p w_q\det\mathbf{J}_{s}\det\mathbf{J}_{e}$.

## Step 6: materials

`BUILD_GAUSS_MATERIAL_CACHE` resolves every distinct lamination id used by the layout with `RESOLVE_LAMINATION` (material rotation by `BUILD_MATERIAL_ROTATION`, stiffness rotation by `ROTATE_STIFFNESS`) into `STIFFNESS_LOCAL(6,6,k)`, `DENSITY(k)`, `MATERIAL_FROM_LOCAL(3,3,k)` and stores in `MATERIAL_MAP%CACHE_INDEX(g)` the entry of each point. The number of distinct entries is the number of laminations used, not the number of points.

## MITC preparation

MITC data is element-local and is built on the fly, in the assembly, by `PREPARE_ELEMENT_MITC`: if the analysis requests MITC for the family of the element and the topology has a table (`MITC_IS_AVAILABLE`), `MITC_PREPARE_ELEMENT` fills a `MITC_DATA_TYPE` with the tied rows, the tying sets and the shape functions and local gradients at the tying points (computed with the *element* node coordinates, hence the Jacobian of the tying point itself).

## What the cache costs

For a beam with $n_e$ elements, $P$ structural and $Q$ expansion points per sub-element and $E$ sub-elements, the layout has $n_e P\sum_e Q_e$ points (84 k for the 100 000-DOF Taylor-15 benchmark) but the geometry caches only $n_eP$ structural plus $\sum Q_e$ expansion entries; this is why the memory of the cache is negligible compared with that of the matrices.
