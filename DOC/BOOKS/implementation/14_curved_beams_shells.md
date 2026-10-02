# Curved beams and shells {#sec:impl-curved}

This chapter documents the implementation of the general geometry (curved beams, shells). The theory is in Chapter 17 of the theoretical guide, the input in Chapter 13 of the user guide.

## Where the general geometry enters

The ordinary path is untouched: an element is *general* only when it is named `CB*`/`S*` or its nodes are off the line/plane, and every other element keeps its frame, structural cache and kernels bit for bit. The general elements are intercepted at three places and use two new modules.

| Place | What changes |
|---|---|
| `read_connectivity.for` (`ALIAS_NAME`) | `S4 S9 S16 CB2 CB3 CB4` are read as `Q4 Q9 Q16 B2 B3 B4` with `ELEMENT_TYPE%GENERAL = .TRUE.` |
| `read_directors.for` (new, `MUL2_READ_DIRECTORS`) | optional `DIRECTORS.dat`: `NODE_TYPE%DIRECTOR`, `HAS_DIRECTOR` |
| `mul2_model_cache.for` (`BUILD_MODEL_CACHE`) | after `BUILD_ELEMENT_FRAMES`, `BUILD_GENERAL_GEOMETRY` fills the new members of `ELEMENT_FRAME_DB_TYPE` |
| `mul2_gauss_geometry.for` | for a general element the flat structural Jacobian is not evaluated (identity, weight 1): the weight comes from the kernel |
| `mul2_model_assembly.for` | `EVALUATE_ELEMENT_BASE` and the coupled branch of `EVALUATE_ELEMENT` call `GENERAL_ELEMENT`; `NONLINEAR_ELEMENT` and `GEOMETRIC_ELEMENT` raise an error |
| `mul2_boundary_application.for` | `PLACED_POINT` replaces `EXPANDED_POINT` at the four places that locate an expansion node (`D-PLANE`, `V-FLOAT`, `F-POINT`, `V-POINT`) |
| `mul2_recovery.for` | `PLACE_SETUP/PLACE_EVALUATE/STATE_FROM_PLACE/NEWTON_LOCATE` have a general branch |
| `mul2_surface_loads.for` | error when a model with `Q-*` has general elements |

`ELEMENT_FRAME_DB_TYPE` (`mul2_reference_systems.for`) has four new members: `GENERAL_INDEX(element)` (0 = ordinary), `GENERAL_TRIAD(3,3,node,general)`, `GENERAL_REFERENCE(3,general)` and `GENERAL_KINK(node,general)` (shell nodes shared with another normal: 1 = edge, -1 = thickness axis opposite to the one of the first element at the node, 0 = smooth). The arrays are compact (the general elements only), allocated even when empty, so `IS_GENERAL_ELEMENT(FRAMES, E)` is always safe.

## `MUL2_GENERAL_GEOMETRY` (`SRC/GEOMETRY/mul2_general_geometry.for`)

| Procedure | Purpose |
|---|---|
| `BUILD_GENERAL_GEOMETRY` | finds the general elements (`IS_CURVED`: nodes against line/plane within $10^{-6}$), computes raw tangents/normals at the nodes with `EVALUATE_SHAPE` at the natural coordinates of the node (`GENERAL_NODE_NATURAL`), groups the entries by node (CSR: `FIRST`, `ENTRY_G`, `ENTRY_J`), and averages them within `FEATURE_COSINE` (the exact director of `DIRECTORS.dat` replaces the average); fills the triad |
| `GENERAL_MAP` | position and Jacobian rows $\mathbf g_a$ at a point: $\sum_i N_i(\mathbf X_i+c_k\mathbf A_{ki})$, `AXIS` = active axes of the expansion mesh |
| `GENERAL_FRAME` | frame rows $\mathbf R$ at a point (same rules as the ordinary frames) |
| `GENERAL_OFFSET` | $\sum c_k\mathbf A_{ki}$, used to place expansion nodes (loads, constraints) |

## `MUL2_GENERAL_KERNEL` (`SRC/ELEMENTS/mul2_general_kernel.for`)

`GENERAL_CONTEXT_TYPE` holds the geometry of one element (coordinates, triads, reference vector, active axes) and the tying families (`TIE_FAMILY_TYPE`: lists of points in $\xi$ and $\eta$, the rows they replace, shape functions and derivatives at the tying points, precomputed once per element).

* `GENERAL_CONTEXT_SETUP(CTX, element, ..., TYING)`: fills the context; with `TYING` chooses the tables of the topology (Q9: three families; Q4: two; B2-B4: one; Q16: none).
* `GENERAL_POINT_COLUMNS(CTX, N, DN, NATURAL, C, DOFs, FV, FG, BCOL, VALUE, G, R, DET)`: the strain columns of all the DOFs at a point. For each tying point the jacobian `GM` at the same $\mathbf c$ is formed once; the rows of the family are replaced by $\sum_mL_m\tilde{\boldsymbol\gamma}(\xi_m)$ (`TIE_WEIGHTS`, `LAGRANGE`); then `BUILD_T` gives the $6\times6$ matrix $\mathbf T(\mathbf Q)$. The fields $P$ and $T$ get the Cartesian gradient.
* **Edges.** After the columns of a point are built, for every node with `KINK` /= 0 the three first-order DOFs (same node, expansion function $, fields 1-3: recognised by `FG(axis)=1` and `FV=c`) are replaced by the combinations `BCOL*A` and `VALUE*A` with `A` = the skew matrix of the director (`q1 = omega x V`) or `-I` for opposite axes. The transformation is therefore applied once, in the columns, and serves the stiffness, the mass, the coupling blocks and the recovery. It needs a Taylor expansion (TE) of order 1 or 2; an LE expansion has no first-order term.
* `BUILD_GENERAL_ELEMENT_MATRICES`: loops over the points in batches (`MAX_BATCH`), evaluates the expansion factors once per distinct (kinematic, field, term) with `EVALUATE_POINT_FACTORS` (so every expansion family, TE, LE, HLE and the node-dependent kinematics, goes through the existing code), calls `GENERAL_POINT_COLUMNS` and accumulates $B^T(WMB)$ with `ACCUMULATE_UPPER_PRODUCT` on the upper triangle, mass and heat capacity with the same helper. `COUPLING` returns only the thermoelastic and pyroelectric blocks (`EVALUATE_ELEMENT`).

The kernel keeps no state (OpenMP safe: the assembly evaluates the elements of a chunk in parallel exactly as for the ordinary ones, the result does not depend on the number of threads). The same two procedures serve the recovery: `GENERAL_STATE_PART` of `mul2_recovery.for` collects the DOFs of the element, the factors at the point and calls `GENERAL_POINT_COLUMNS`, then the ordinary material block gives stress, electric displacement and heat flux; `POINT_STATE_TYPE%FRAME` stores the frame of the point (used by the output in the local frame).

## Joining by coincidence (`MUL2_COINCIDENT_JOIN`)

`SRC/BOUNDARY/mul2_coincident_join.for`, called by `BUILD_MODEL_CACHE` after the frames and the triads when `ANALYSIS%JOIN_COINCIDENT` is true. `JOIN_COINCIDENT_DOFS` builds the list of the `LE` and `TE` DOFs with their position (`PLACED_POINT`: node + offset of the expansion node, in the frame or in the triad of the element), a spatial hash (cells of twice the tolerance, counting sort), unites the pairs of the same field and class within the tolerance (union-find) and stores in `DOF_LAYOUT_TYPE%ALIAS` the map provisional number $\to$ final number; `GLOBAL_DOF` applies it and `TOTAL_DOF` is reduced. Every consumer uses `GLOBAL_DOF` and `TERM_COUNT`, so assembly, constraints, loads and recovery need no change. Cost: $O(N)$ with 27 cells per entry.

## Tests

`TESTS/CURVED/curved_tests.py` (ctest `MUL2_CURVED_TESTS`, ~10 s, also run in Debug with `/check:all`): equivalence of every general topology with the ordinary one, rigid modes, quarter ring (force, couple, stress, frequency), pinched cylinder (TE, LE, directors, locking), tubes, stringer joint. The unit checks of Chapter 10 are unchanged.

## Extending

* A new shell topology: add its node-natural coordinates to `GENERAL_NODE_NATURAL` and a tying table to `GENERAL_CONTEXT_SETUP`.
* State-dependent analyses (105, 108): `GENERAL_POINT_COLUMNS` also returns, on request, the gradient of the basis in the frame of the point (`GRADL` $=\mathbf R\,\mathbf G^{-1}\partial\varphi$) and the global direction of each DOF (`DIRG`: an axis, or a combination of the axes for the first-order term at a kinked node). `BUILD_GENERAL_STATE_MATRICES` fills the **point contract** of `MUL2_ELEMENT_MATRICES` (`POINT_STATE_WORK_TYPE`: basis, strain column, gradient and direction in the frame of the point) and calls the shared operators `GEOMETRIC_POINT` and `NONLINEAR_POINT`, the same ones used by the ordinary elements. `GENERAL_POINT_INPUT` gives the shapes and expansion factors of a point to both builders. The directions also give the mass (`M += w\rho\,(N_iD_i)\cdot(N_jD_j)`) and the recovered displacement at the kinked nodes.
* Surface loads: the area element is $\|\mathbf g_1\times\mathbf g_2\|$ at the face of the expansion mesh.
