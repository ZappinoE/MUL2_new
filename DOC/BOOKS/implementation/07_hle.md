# The HLE implementation {#sec:hle-impl}

This chapter describes how the hierarchical Legendre expansion of the Theoretical Guide (chapter *Hierarchical Legendre expansions*) is implemented: the modules, the data, the flow and the tests.

## Modules

Table: New and modified units. {#tab:hle-units}

| Unit | Role |
|---|---|
| `FEM/mul2_hle_shape.for` (`MUL2_HLE_SHAPE`) | the functions: `HLE_FUNCTION_COUNT`, `HLE_MODE_LIST` (kind and indices of each local mode), `HLE_SIDE_ENDS`, `HLE_PHI`, `EVALUATE_HLE_SHAPE` (values and derivatives) |
| `FEM/mul2_hle_map.for` (`MUL2_HLE_MAP`) | the blending map: `HLE_GEOMETRY_SETUP` (arcs from vertices and mid nodes), `HLE_MAP_EVALUATE` (position and Jacobian) |
| `MODEL/mul2_hle_modes.for` (`MUL2_HLE_MODES`) | `BUILD_HLE_MESH`: numbering of the generalised terms, ownership, signs |
| `MODEL/mul2_topologies.for` | pseudo-topologies: `HB = 1100+p`, `HQ = 2100+p`; `TOPOLOGY_FUNCTION_COUNT`, `TOPOLOGY_IS_HLE`, `TOPOLOGY_HLE_ORDER` |
| `MODEL/mul2_expansion_meshes.for` | new fields of the mesh and element types (below) |
| `IO/read_expansions.for` | reading of `HQ4 ... p [m1..m4]`, `HB2 ... p` |
| `GAUSS/*`, `CUF/mul2_point_bases.for`, `GEOMETRY/mul2_local_gradients.for` | number of functions larger than number of nodes; HLE case of the expansion factor; curved Jacobian |
| `ASSEMBLY/mul2_dof_layout.for`, `ANALYSES/mul2_model_assembly.for` | term count, consistency of node and mesh kind, coupling tables |
| `BOUNDARY/mul2_boundary_application.for` | plane constraints and point loads for HLE |
| `POST/mul2_recovery.for` | stress recovery on curved sub-elements |

## Data structures

The expansion element type gains `MODE_TERM(:)` (the global term of each local function) and `MODE_SIGN(:)` ($\pm1$), plus `MID_NODE_ID(4)`. The expansion mesh gains `IS_HLE`, `N_TERM`, `TERM_NODE(2,T)` (vertex term: $(node,0)$; side term: the two end vertices; internal term: $(0,0)$), `TERM_OWNER` and `NODE_TERM`, the term of each vertex node. `EXPANSION_TERM_COUNT` returns the number of terms of a mesh: for Lagrange the nodes, for HLE `N_TERM`.

## Flow

![Construction and use of the HLE data.](figures/hle_flow.svg){#fig:hle-flow}

1. **Reading.** `READ_EXPANSIONS` stores the order in the element topology code and the optional mid nodes; after all elements are read it calls `BUILD_HLE_MESH`.
2. **Numbering.** `BUILD_HLE_MESH` walks the sub-elements: vertex terms are numbered after the nodes; every side gets one term per order $k\le\min$ of the orders of the elements that share it (the side is identified by its two vertex ids, lower first); internal terms belong to one element. For each element and each local function it stores the global term in `MODE_TERM`, or 0 if the function is omitted (side mode above the minimum order), and the sign $(-1)^k$ when the local side runs from the higher to the lower vertex id.
3. **Shape evaluation.** `EVALUATE_SHAPE` dispatches HB/HQ to `EVALUATE_HLE_SHAPE`, which returns all `HLE_FUNCTION_COUNT` functions in the local order of the paper. The quadrature uses $p+2$ points per direction.
4. **Geometry cache.** For an element without mid nodes the Jacobian comes from the vertices; the gradient of every mode uses `MATMUL(DERIV, TRANSPOSE(INVERSE))`. With mid nodes the Jacobian of the map is passed through two pseudo nodes whose coordinates are $\partial\mathbf{Q}/\partial r$ and $\partial\mathbf{Q}/\partial s$ and the integration points use the mapped position.
5. **Kernels.** `EVALUATE_EXPANSION_FACTOR` finds the local mode whose `MODE_TERM` equals the requested term and multiplies by `MODE_SIGN`. The separable kernel and the reference kernel (`MUL2_GENERAL_KERNEL=1`) give the same matrices.
6. **Constraints and loads.** A plane constrains a vertex term if the vertex lies on it, a side term if both end vertices do, and all the terms of an element if all its vertices do; side and internal terms are prescribed 0. A point load goes to the vertex term of the node.

## Tests

Table: HLE tests. {#tab:hle-tests}

| Test | File | Content |
|---|---|---|
| `MUL2_HLE_TESTS` | `TESTS/mul2_hle_tests.for` | function counts, Kronecker and partition of unity at the vertices, derivatives, C0 conformity on a shared side for several orders and numberings, annulus area, arcs on circles |
| `MUL2_HLE_SOLVER_TESTS` | `TESTS/HLE/hle_tests.py` | HQ4 p=1 vs Q4; HB vs B3/B4; reversed side; fast vs reference kernel; Ritz bounds; convergence vs TE4/TE6; tube vs Euler–Bernoulli; VTK radii |
| validation campaign | `TESTS/VALIDATION` | the HLE group of the validation report |

> NOTE: running the test executables needs the oneAPI folders `mkl\2025.0\bin` and `compiler\2025.0\bin` on `PATH`; otherwise Windows shows a hidden dialog for the missing DLL and the test hangs.
