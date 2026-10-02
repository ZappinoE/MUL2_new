# Post-processing {#sec:postimpl}

![Flow of the post-processing.](figures/flow_post.svg){#fig:flow-post}

## Evaluation context: `PLACE_TYPE`

To evaluate fields at an arbitrary point the program needs, for one (element, sub-element) pair, the node coordinates, the frame and the shape functions. `PLACE_TYPE` (module `MUL2_RECOVERY`) holds them:

| Component | Meaning |
|---|---|
| `ELEMENT`, `MESH`, `SUB_ELEMENT` | which element, expansion mesh, sub-element |
| `STRUCTURAL_DIMENSION`, `EXPANSION_DIMENSION`, `STRUCTURAL_TOPOLOGY`, `EXPANSION_TOPOLOGY` | dimensions and topologies |
| `STRUCTURAL_AXIS(3)`, `EXPANSION_AXIS(3)` | active local axes |
| `NODE_GLOBAL`, `NODE_LOCAL`, `EXPANSION_NODE` | coordinates of the structural nodes (global and local) and of the sub-element nodes |
| `SHAPE_STRUCTURAL`, `NATURAL_DERIVATIVE_S`, `GRADIENT_STRUCTURAL` | structural shapes, natural derivatives, local gradients at the current point |
| `SHAPE_EXPANSION`, `NATURAL_DERIVATIVE_E`, `GRADIENT_EXPANSION` | the same for the sub-element |
| `EXPANSION_POINT_LOCAL`, `POINT_GLOBAL`, `NATURAL_S` | local section point, physical point, structural natural coordinates |
| `MITC` | MITC data of the element when active |

`PLACE_SETUP(model, cache, element, sub_element, place, status)` fills the constant part; `PLACE_EVALUATE(place, model, cache, natural_s, natural_e, with_gradient, status)` evaluates shapes (`EVALUATE_SHAPE_AND_GRADIENT`), physical position and, if requested, gradients at a natural point.

## Locating a point

`LOCATE_POINT(model, cache, target, tolerance, element, sub_element, natural_s, natural_e, found, status)` implements the two-step search of the Theoretical Guide (chapter *Recovery*):

1. `POINT_NEAR_ELEMENT(model, element, target, margin)`: bounding-box test on the structural nodes enlarged by the section extent.
2. For each candidate (element, sub-element): `NEWTON_LOCATE`, with the Jacobian of the combined map ($3\times3$, `INVERT_3X3`), starting at the centre of the reference domain; converged when the correction is below the tolerance. `NATURAL_INSIDE(topology, natural, tolerance)` checks that the coordinates are inside the reference element.

For a beam the three unknowns are the axial natural coordinate (structural) and the two section coordinates (expansion); for a plate the two surface coordinates and the thickness coordinate; for a solid the three structural coordinates.

## Displacement, strain and stress

`STATE_FROM_PLACE(model, cache, place, solution, state, status)` loops over the DOFs of the element: for each (node, field, term) it evaluates the expansion factor, composes the basis with the structural shape, adds the displacement contribution $N F q$ and the strain column (`BUILD_DISPLACEMENT_OPERATOR` with the local gradient and the frame column of the field; MITC rows via `MITC_TIE_COLUMN`). Then:

```fortran
#caption: Stress recovery (POST/mul2_recovery.for, concept)
STATE%DISPLACEMENT = sum_I  phi_I * q_I                    ! global components
STATE%STRAIN_LOCAL = sum_I  b_I   * q_I                    ! element frame
STATE%STRESS_LOCAL = MATMUL( C_LOCAL(lamination), STATE%STRAIN_LOCAL )
STATE%STRAIN_GLOBAL = TRANSFORM_INVERSE( R ) * STRAIN_LOCAL
STATE%STRESS_GLOBAL = (stress rotation) * STRESS_LOCAL
```

`DISPLACEMENT_FROM_PLACE` does only the displacement part for several vectors at once (the mode shapes).

## Output grid

`BUILD_POST_GRID(model, nodes_per_cell, split, grid, status)` creates, for every element and sub-element, cells that sample the natural domain with $r\times s\times t$ divisions. `ELEMENT_SPLITS` and `SPLIT_NATURAL` map the nine integers of the request onto the structural and expansion natural coordinates of the element family (table of the chapter *Recovery* of the Theoretical Guide); `CELL_LIMITS` gives the natural coordinates of the nodes of cell $i$ of $n$ along one direction; triangular parents use `COLLAPSE_TRIANGLE`. The grid stores `CELL_ELEMENT`, `CELL_SUB_ELEMENT`, `CELL_DIMENSION`, and for every grid node its natural coordinates `NATURAL_STRUCTURAL` and `NATURAL_EXPANSION`.

`EVALUATE_GRID_STATES` evaluates the states of all cells with `!$OMP PARALLEL DO` over cells (dynamic schedule, chunks of 16): each cell sets up its own `PLACE_TYPE` and writes its own entries of `STATE`.

## Writers

- `WRITE_VTK_GEOMETRY`, `WRITE_VTK_VECTOR`, `WRITE_VTK_SCALAR`: legacy ASCII VTK (`UNSTRUCTURED_GRID`, cell types 12 and 25, `POINT_DATA` vectors and scalars).
- `WRITE_GMSH_GEOMETRY`, `WRITE_GMSH_DATA`: GMSH 2 ASCII (`$Nodes`, `$Elements`, `$NodeData`).
- `SELECT_FRAME` chooses local or global components of displacement, strain and stress for the request.
- `WRITE_CSR(file, system, value, status)` writes `row column value` lines; `WRITE_VECTOR` writes `value` lines.

The modal output always samples one quadratic cell per element (`EVALUATE_GRID_MODES`) and writes one displacement field per mode, with the frequency in the field title.
