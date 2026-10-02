# Hexagonal auxetic cell (theta = 0): nonlinear opening, exact shape, extruded plates

Geometry of `AUXETIC/auxetic_cell_geometry.m` (triangular blocks, L = 20 mm, t = 3 mm,
theta = 0). Six blocks around a point, each the mirror image of the previous one; lateral
pieces of adjacent blocks merged into rigid parts; hinges at the vertices of the six
rotating triangles (18 hinges).

    python make_auxetic.py --out RUN --force 15 --steps 100 --load-control --refine 0
    python make_auxetic.py --out RUN --force 15 --steps 70 --lmax 0.3 --refine 1   # arc length
    cd RUN && MUL2_V3.exe INPUT
    python plot_auxetic.py RUN 1            # curve + deformed shapes
    python plot_paths.py OUT.png a=RUN1 b=RUN2 --steps 10

Model: every part is meshed with its exact polygon (T6 plates, thickness S, Taylor order 1
through the thickness); zero-width cracks (separate nodes) between the lateral pieces; a gap
KERF between each triangle and the pieces around it; the TPU hinge is a strip of Q9 plates
(width HW along the cut, length KERF across it) at the end of each triangle edge. Shared nodes
everywhere else, no multipliers. Loads: radial forces on the six corners of the hexagon; pin
and roller at the hub (vertical planes); planar response. Parameters at the top of
`make_auxetic.py`.

Results (`RESULTS/`): `mesh.png` (mesh, red = TPU), `auxetic_shapes.png` (deformed shapes,
scale 1), `auxetic_curve.png`, `auxetic_limit_point.png` (limit load for two meshes).
