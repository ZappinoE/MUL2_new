# Hierarchical sections (HLE) {#sec:hle-user}

HLE refines a section by the **order** $p$ of its sub-elements instead of the number of nodes. A few sub-elements of order 3–5 usually describe a section better than a fine Lagrange mesh, and curved walls (tubes) are described exactly. Theory: the Theoretical Guide, chapter *Hierarchical Legendre expansions*.

## Input

**NODES.dat.** The structural nodes use the token `HLE` (no order):

```text
1   0.0D0  0.0D0  0.0D0   HLE
```

or `HLE` in `KINEMATICS.dat`.

**EXP_MESH_nn.dat.** Only the **vertices** of the sub-elements are listed (and, for curved sides, the extra mid nodes).

**EXP_CONN_nn.dat.**

```text
HQ4  id  lamination  v1 v2 v3 v4  p  [m1 m2 m3 m4]
HB2  id  lamination  v1 v2  p
```

`HQ4` is a quadrilateral (vertices counter-clockwise, like Q4), `p` its order (1–8 tested); `HB2` is a line for the thickness of a plate. The optional `m1…m4` are mid nodes of the sides 1–2, 2–3, 3–4, 4–1: a mid node off the chord makes that side a circular arc, a mid node on the chord a straight side.

Orders may differ from one sub-element to the next. On a shared side the modes up to the smaller order are shared; nothing else has to be specified, and the numbering direction of the sub-elements is free.

## Example: a tube

Four quarter-annulus sub-elements of order 4 (outer radius 0.5, inner 0.4):

```text
EXP_MESH_01.dat (20 nodes)      EXP_CONN_01.dat (4 elements)
1  0.4  0  0                    HQ4 1 1  1 2 4 3  4  100 200 101 300
2  0.5  0  0                    HQ4 2 1  3 4 6 5  4  101 201 102 301
3  0.0  0  0.4                  HQ4 3 1  5 6 8 7  4  102 202 103 302
…                               HQ4 4 1  7 8 2 1  4  103 203 100 303
```

(ids 1–8 are the vertices at 0°, 90°, 180°, 270°, inner then outer on each ray; 100–103 the mid-radius points on the rays, 200–203 the midpoints of the outer arcs and 300–303 of the inner arcs. Coordinates are local: columns $x$, $y=0$, $z$.) The tube gives a first bending frequency within 1% of Timoshenko beam theory with four elements.

## Constraints and loads

- A `D-PLANE` that contains the whole section constrains all the modes. A plane that cuts the section constrains the vertices on it and the side modes whose two end vertices lie on it; with curved sides cut by the plane this is only approximate.
- A point load must be at a vertex; it is applied to the vertex mode. Side and internal modes receive no load, so for $p\ge2$ a point load is not the exact equivalent of a traction: compare stresses away from the loaded section.

## Mixing with other expansions

An HLE node needs sub-elements of kind HQ/HB, a Lagrange node a Lagrange mesh. Taylor nodes work with any mesh, so a beam can go from HLE to LE (or TE) through a **Taylor node** on the interface, and TE and HLE nodes may share an element.

## Limits

No triangles and no solids; circular arcs only; HQ4 and HB2 only. The static viewer of the interface draws a curved side as a polyline through its mid node.

The interface (**EXP_CONN** editor) has an HLE column and the buttons *+ Add HQ4* and *+ Add HB2*.
