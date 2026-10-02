# Hierarchical Legendre expansions {#sec:hle}

The Taylor expansion (TE) converges slowly for sections with holes or corners, and the Lagrange expansion (LE) refines the section only by adding nodes (h-refinement). The **hierarchical Legendre expansion** (HLE) refines by raising the polynomial order $p$ of each section sub-element (p-refinement), with different orders in different sub-elements. MUL2_NEW follows the formulation of Pagani, de Miguel and Carrera (Comput. Mech., 2017).

## The expansion functions on a quadrilateral

A section sub-element HQ is a quadrilateral with natural coordinates $(r,s)\in[-1,1]^2$ and vertices $1(-1,-1)$, $2(1,-1)$, $3(1,1)$, $4(-1,1)$. Its functions come in three kinds.

**1D functions.** With $L_k$ the Legendre polynomial of degree $k$,

$$
\phi_k(x)=\frac{L_k(x)-L_{k-2}(x)}{\sqrt{2(2k-1)}}=\sqrt{\frac{2k-1}{2}}\int_{-1}^{x}L_{k-1}(t)\,dt,\qquad k\ge 2 ,
$$ {#eq:phi}

which vanishes at $x=\pm1$: it can be added to a linear function without changing the end values.

**Vertex modes** (bilinear, equal to the Q4 functions):

$$
N_\tau=\frac{1}{4}(1+r_\tau r)(1+s_\tau s),\qquad \tau=1\dots4 .
$$ {#eq:hle-vertex}

> NOTE: the formula with $(1-r_\tau r)(1-s_\tau s)$ that appears in some printed versions gives the function of the *opposite* vertex. The code and the tests use the form above.

**Side modes**, for $k=2\dots p$ (one per side):

$$
N^{1}_k=\frac{1}{2}(1-s)\phi_k(r),\quad
N^{2}_k=\frac{1}{2}(1+r)\phi_k(s),\quad
N^{3}_k=\frac{1}{2}(1+s)\phi_k(r),\quad
N^{4}_k=\frac{1}{2}(1-r)\phi_k(s).
$$ {#eq:hle-side}

**Internal modes** (bubbles), for $k\ge4$: $\phi_i(r)\phi_j(s)$ with $i,j\ge2$ and $i+j=k$. The set is the *trunk space* of Szabó and Babuška, not the tensor product $Q_p$: the number of functions is

$$
n(p)=4+4(p-1)+\frac{(p-2)(p-3)}{2}\quad(p\ge4),
$$ {#eq:hle-count}

that is $4,8,12,17,23,30,38,47$ for $p=1\dots8$. Order 1 is the bilinear Q4; order 2 is the 8-function serendipity space (**not** Q9). The local order of the modes follows the paper: the four vertices, then for each $k$ the four sides of order $k$ followed (for $k\ge4$) by the internal modes with $i+j=k$.

![Examples of the HLE functions on the reference quadrilateral.](figures/hle_modes.svg){#fig:hle-modes}

For a line sub-element (HB, used for the thickness of plates) the functions are the two linear vertex functions and $\phi_k$, $k=2\dots p$. HB of order 2 and 3 span the same spaces as the Lagrange B3 and B4.

## What is a degree of freedom

Only the vertices are nodes of the section mesh. Side and internal modes are *generalised* unknowns attached to a side (shared by the two sub-elements that own it) or to the sub-element. In the field-major numbering the "terms" of an HLE structural node are the vertex terms plus the side and internal terms of the section mesh; they are the same for all the structural nodes of the model.

## Different orders on an interface

Two sub-elements of orders $p_1$ and $p_2$ share a side. For the displacement to be continuous (C0) on the side, only the side modes of order $k\le\min(p_1,p_2)$ are kept: the modes of higher order on the richer side are **omitted** (their trace would not be matched). Internal modes involve no constraint. This is the rule of the paper for modes with a compatible trace and it removes the need for multipoint constraints.

**Signs.** The side modes are defined with respect to the direction of the side in the element. If the neighbour traverses the shared side in the opposite direction, $\phi_k(-x)=(-1)^k\phi_k(x)$, so the shared unknown is multiplied by $(-1)^k$ in one of the two elements. MUL2_NEW fixes the *global* direction of a side from the lower to the higher vertex id and applies this sign. The result does not depend on how the sub-elements are numbered (Chapter {sec:verification} and the validation report).

![Shared side of two sub-elements: orders and signs.](figures/hle_interface.svg){#fig:hle-interface}

## Curved sides

A side can be an arc of circle through its two vertices and a third point (the optional mid node). The sub-element is then mapped from the reference square with the transfinite (Gordon–Hall) interpolation

$$
\mathbf{Q}(r,s)=\sum_{\tau=1}^{4}N_\tau\mathbf{X}_\tau+\sum_{e=1}^{4}\beta_e(r,s)\big(\mathbf{c}_e(t)-\mathbf{l}_e(t)\big),
$$ {#eq:hle-map}

where $\mathbf{l}_e$ is the straight side, $\mathbf{c}_e$ the arc parameterised by its angle, $t$ the natural coordinate along the side, and $\beta_e$ the linear blending function that is 1 on side $e$ and 0 on the opposite one: $\beta_1=\frac{1}{2}(1-s)$, $\beta_2=\frac{1}{2}(1+r)$, $\beta_3=\frac{1}{2}(1+s)$, $\beta_4=\frac{1}{2}(1-r)$. A mid node that lies on the chord means a straight side. The geometry is exact (the area of an annulus sector is integrated to rounding); the expansion functions are **not** the map: the element is not isoparametric, and the physical gradients are obtained with the Jacobian of $\mathbf{Q}$.

![The blending map of a curved sub-element.](figures/hle_map.svg){#fig:hle-map}

## Verification of the formulation

Table: Checks of the HLE (details in the validation report). {#tab:hle-checks}

| Check | Result |
|---|---|
| HQ4 of order 1 against LE with Q4 | identical |
| HB order 2 / 3 against B3 / B4 | $10^{-9}$ |
| shared side traversed in opposite directions | $10^{-9}$ |
| C0 jump on the interface, orders 4\|3 and 4\|2 | $6\cdot10^{-10}$ |
| compliance of mixed orders | between the uniform bounds (Ritz) |
| tube with four curved HQ4, $p\ge4$ | within 1.1% of Timoshenko |

## Limits

HLE exists for quadrilateral sections (HQ) and for thickness lines (HB) only: no triangles and no solids. Curved sides are circular arcs. A plane constraint that cuts a curved side only constrains the side modes if both end vertices lie on the plane.
