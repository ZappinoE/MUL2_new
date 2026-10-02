# Extending the program {#sec:extend}

This chapter lists, for the three most common extensions, **every place that must be touched**. It also shows how the layered design keeps the changes small.

## Adding a structural element topology

Example: a new quadrilateral with 8 serendipity nodes.

1. **Registry** (`MODEL/mul2_topologies.for`): add a code constant, the name in `TOPOLOGY_FROM_NAME`, the node count in `TOPOLOGY_NODE_COUNT` and the dimension in `TOPOLOGY_NATURAL_DIMENSION`.
2. **Shape functions** (`FEM/mul2_shape_functions.for`): add a case in `EVALUATE_SHAPE` and a routine computing $N_a$ and $\partial N_a/\partial\xi_d$ with the node order you want to document. Verify partition of unity and derivative consistency with the unit tests.
3. **Quadrature** (`QUADRATURE/mul2_quadrature.for`): add the default rule in `BUILD_DEFAULT_QUADRATURE`; if the topology is tensor-product also in `DEFAULT_POINTS_PER_DIRECTION` and `BUILD_ORDERED_QUADRATURE` so that Taylor expansions can use more points.
4. **Element frame** (`GEOMETRY/mul2_element_frames.for`): for surfaces, state which two corners define the plate normal (`BUILD_SURFACE_FRAME`); for beams, the end node (`BUILD_BEAM_FRAME`).
5. **MITC** (optional, `ELEMENTS/mul2_mitc.for`): add the tied rows and tying points in `DEFINE_TYING` and `MITC_IS_AVAILABLE`.
6. **Post-processing** (`POST/mul2_post_grid.for`, `POST/mul2_recovery.for`): the natural-coordinate handling of `NATURAL_INSIDE` and the cell mapping if the reference domain is new.
7. **Tests**: a patch test, a comparison of the new element with an equivalent existing one (for instance Q8 versus Q9 on a rectangular mesh) and the documentation tables.

No change is needed in the kernels, the assembly or the solvers: they only see shape functions, gradients and weights.

## Adding an expansion family

Example: the hierarchical Legendre family, now implemented (Chapter {sec:hle-impl}); it shows the hooks that a new family must fill:

Table: Where an expansion family enters the code. {#tab:hooks}

| Place | Routine | Action for a new family |
|---|---|---|
| Parser | `PARSE_EXPANSION_TOKEN` (`MODEL/mul2_kinematics.for`) | recognise the token and set `FAMILY`, `ORDER` (done for `HLE`) |
| DOF count | `NODE_FIELD_TERM_COUNT` (`ASSEMBLY/mul2_dof_layout.for`) | return the number of terms of the field at the node (for HLE the number of terms of the mesh, `N_TERM`) |
| Basis | `EVALUATE_EXPANSION_FACTOR` (`CUF/mul2_point_bases.for`) | return $F_\tau$ and its local gradient at an expansion point |
| Quadrature order | `BUILD_EXPANSION_POINT_ORDERS` (`ANALYSES/mul2_model_cache.for`) | the Gauss points per direction needed for the products of two functions |
| Sparse pattern | `MARK_LAGRANGE_DOFS`, `BUILD_COUPLING_TABLES` (`ANALYSES/mul2_model_assembly.for`) | set a table with the term couplings if the functions have local support; otherwise the family is fully coupled |
| Constraints | `ADD_PLANE_CONSTRAINT` (`BOUNDARY/mul2_boundary_application.for`) | which terms are zero or equal to the prescribed value on a plane |
| Loads | `ADD_POINT_FORCE` | how a point load is distributed over the terms |
| Post-processing | `STATE_FROM_PLACE` (`POST/mul2_recovery.for`) | uses `EVALUATE_EXPANSION_FACTOR`; normally nothing to change |

Because the separable kernel only needs `EVALUATE_EXPANSION_FACTOR` (through `EVALUATE_POINT_FACTORS`) and the number of terms, a new family automatically gets the fast kernel. Hierarchical bases need two extra pieces: the *sign convention* of the shared entities (edge modes of odd order change sign if the edge is traversed in the opposite direction) and the *interface constraints* between sub-elements of different order.

## Adding an analysis type

1. Create `ANALYSES/mul2_analysis_nnn.for` with `RUN_<NAME>_ANALYSIS(model, cache, results, status)` following the pattern of analysis 101: assemble with `ASSEMBLE_MODEL_SYSTEM`, build boundary data, solve, fill `ANALYSIS_RESULTS_TYPE`.
2. Register the source in the `MUL2_SOLVERS` list of `CMakeLists.txt`.
3. In `MUL2_DRIVER` accept the new `SOLUTION` value and add a `CASE` in the two `SELECT CASE` blocks (analysis and output).
4. Write the output routine in `MUL2_POST_OUTPUT` and add the fixed output file names.
5. Extend `ANALYSIS_TYPES` in `INTERFACE/app.js` so that the interface offers the new analysis.
6. Document the theory (new chapter), the user input and the tests.

## Rules for a good contribution

- Keep every line within 72 columns (the build checks it).
- Never `STOP` in a library routine: set an error in the status and return.
- Do not add global variables.
- Every formula in one place; reuse the existing routine instead of writing a second one.
- Write the test first: a case with a known answer (analytic, patch, or reference program).
- Update the three guides and the generated reference (`python DOC/BOOKS/build_books.py`).
