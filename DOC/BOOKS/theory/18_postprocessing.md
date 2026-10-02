# Recovery of displacements, strains and stresses {#sec:post}

The solver delivers coefficients; engineering results are values of displacement, strain and stress at **points** or on a **grid**. This chapter explains how they are recovered.

## Locating a point

Given a physical point $\mathbf{X}_t$ (a `PNT` request) the program must find the structural element, the sub-element of the expansion mesh and the natural coordinates $(\boldsymbol{\xi}_s,\boldsymbol{\xi}_e)$ that map to it. The map is

$$
\mathbf{X}(\boldsymbol{\xi}_s,\boldsymbol{\xi}_e)=\sum_i N_i(\boldsymbol{\xi}_s)\,\mathbf{X}_i+\mathbf{R}^{T}\sum_{a}M_a(\boldsymbol{\xi}_e)\,\mathbf{c}_a,
$$ {#eq:point-map}

where $\mathbf{c}_a$ are the local coordinates of the nodes of the expansion sub-element and $M_a$ their shape functions. The search is done in two steps:

1. **Rejection.** Elements whose bounding box (of the structural nodes enlarged by the section extent) does not contain the target are skipped.
2. **Newton iteration.** For every surviving (element, sub-element) pair solve $\mathbf{X}(\boldsymbol{\xi})-\mathbf{X}_t=\mathbf{0}$ with the Jacobian of the map, from the centre of the reference domain. The point is accepted when the iteration converges and the natural coordinates are inside the reference element within a small tolerance.

A point that lies outside every element gives a row of `NaN` in `POST_POINT.dat` and a warning.

> NOTE: The baseline program locates points only approximately: the evaluated position differs from the requested one by $10^{-7}$ or more. MUL2_NEW reports both, `X_EVAL` (where the field was really evaluated) and `X_REQ` (the request).

## Displacement

At the located point the displacement is the sum {eq:cuf-full} over the nodes of the element and the terms of the expansion, with the shape functions evaluated at $\boldsymbol{\xi}_s$ and the expansion functions at $\boldsymbol{\xi}_e$ (Lagrange) or at the section coordinates (Taylor). The result is in the **global frame**.

## Strain and stress

The strain column of every DOF is rebuilt from the scalar basis exactly as in the assembly, with the shape and expansion gradients at the point, and the strain is

$$
\boldsymbol{\varepsilon}_{el}=\sum_{I}\mathbf{b}_I\,q_I,
$$

in the element frame (including the **MITC interpolation of the tied rows** if MITC is active for the element), followed by the stress

$$
\boldsymbol{\sigma}_{el}=\mathbf{C}_{el}\,\boldsymbol{\varepsilon}_{el}
$$

with the stiffness of the lamination of the sub-element. For `GLB` output both are rotated to the global frame: $\boldsymbol{\varepsilon}_{gl}=\mathbf{T}_{\varepsilon}^{-1}\boldsymbol{\varepsilon}_{el}$ and similarly for the stress with the stress transformation (Chapter {sec:frames}).

> WARNING: Strains and stresses are computed from the *displacement field* at the point. They are discontinuous between elements and sub-elements (stresses between plies of a laminate in particular) because the displacement approximation is only $C^0$. No smoothing or stress-recovery by superconvergent patches is applied. Interlaminar transverse stresses obtained this way are generally less accurate than the in-plane ones; refine the expansion and the mesh to check convergence.

## Output grids

The `PARA` and `GMSH` requests write the fields on a grid that samples every element and sub-element. Each element is divided into $r\times s\times t$ cells (the nine integers of the request give $r,s,t$ separately for beam, plate and solid elements), and every cell has 8, 20 or 27 nodes at natural positions, ordered with $\xi$ outermost and $\nu$ innermost. The natural coordinates are then split into a structural part and an expansion part:

Table: Splitting of the natural triple into structural and expansion coordinates. {#tab:split}

| Element | Structural | Expansion |
|---|---|---|
| beam | $\eta$ (along the axis) | $(\xi,\nu)$ over the section |
| plate | $(\xi,\eta)$ in the surface | $\nu$ through the thickness |
| solid | $(\xi,\eta,\nu)$ | none |

Triangular parents are reached by the collapsed map $a=(1+\xi)/2$, $b=(1+\eta)/2\,(1-a)$. Quadratic cells (20 or 27 nodes) are written as VTK quadratic hexahedra (cell type 25; only the 20 serendipity nodes are used) and as GMSH second-order elements; linear cells (8 nodes) as VTK type 12. Because every sub-element of the section is sampled, a laminated beam shows each ply as a layer of cells and the discontinuity of stress between plies is visible in the plot.

## Quantities written

At every grid node the program evaluates and writes the displacement vector, the six components of strain and of stress (in the requested frame) and the von Mises stress

$$
\sigma_{VM}=\sqrt{\tfrac12\left[(\sigma_{xx}-\sigma_{yy})^2+(\sigma_{yy}-\sigma_{zz})^2+(\sigma_{zz}-\sigma_{xx})^2+6(\sigma_{xz}^2+\sigma_{yz}^2+\sigma_{xy}^2)\right]} .
$$ {#eq:vm}

For modal analysis the output contains the mode shapes (displacements only), one field per requested mode.
