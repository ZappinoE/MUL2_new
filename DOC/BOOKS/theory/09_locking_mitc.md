# Shear locking and the MITC technique {#sec:mitc}

## The locking phenomenon

A low-order element that must represent a *thin* structure in bending produces spurious transverse shear strain: the displacement field is not rich enough to give zero shear when the element bends. The shear energy, penalised by a large shear stiffness relative to bending, then dominates and the element is far too stiff. This is called **shear locking**; for plates it is controlled by the ratio of thickness to element size and gets worse as the structure gets thinner.

Locking is a property of the discretisation, not of the physics. The remedy of the **MITC** family (Mixed Interpolation of Tensorial Components, Bathe and Dvorkin) is to replace, in the stiffness integral, the shear strains computed from the displacement derivatives by an **assumed strain field**, interpolated from the strains evaluated at a few special *tying points*.

## Assumed strain

Let $\gamma^{d}(\boldsymbol{\xi})$ be a strain component computed in the standard way. In the tied form, one writes

$$
\tilde\gamma(\boldsymbol{\xi})=\sum_{l}M_l(\boldsymbol{\xi})\,\gamma(\boldsymbol{\xi}_l),
$$ {#eq:tied}

where $\boldsymbol{\xi}_l$ are the tying points and $M_l$ the Lagrange polynomials of the tying set (tensor products of one-dimensional Lagrange polynomials). The other strain components are left untouched. In the CUF context the key point is:

> NOTE: The tying acts on the **structural** directions only. The expansion point $q$ is the same at the tying points and at the integration point; only the structural functions $N_i$ and $\nabla N_i$ are evaluated at $\boldsymbol{\xi}_l$ and interpolated.

In terms of the nucleus of Chapter {sec:nucleus}: for a tied row $r$ the structural factor $\sigma_d(p;i)$ is replaced by

$$
\tilde\sigma^{(r)}_d(p;i)=\sum_{l}M_l(\boldsymbol{\xi}_p)\,\sigma_d(\boldsymbol{\xi}_l;i),
$$ {#eq:tied-sigma}

while the expansion factor $\varepsilon_d(q;\tau)$ is unchanged. The structural matrices $S_{dd'}$ then exist in several *classes* (plain, tied by set 1, set 2, …) and the coupling coefficient is split by row class: $\Gamma_{kh,dd'}^{cc'}=\sum_{r\in c,\,r'\in c'}w_{d,k}[r]\,C_{rr'}\,w_{d',h}[r']$.

## Tying tables

The table below reproduces the choices of the baseline program ($a=1/\sqrt3$, $b=\sqrt{3/5}$; the rows are $1=xx,2=yy,3=zz,4=xz,5=yz,6=xy$).

Table: Tied strain rows and tying points. {#tab:tying}

| Element | Rows | Tying points (natural coordinates) |
|---|---|---|
| B2 | 5, 6 | $\{0\}$ |
| B3 | 5, 6 | $\{-a,+a\}$ |
| B4 | 5, 6 | $\{-b,0,b\}$ |
| Q4 | 4 | $\{0\}\times\{\pm1\}$ |
| Q4 | 5 | $\{\pm1\}\times\{0\}$ |
| Q9 | 1, 4 | $\{\pm a\}\times\{-b,0,b\}$ |
| Q9 | 2, 5 | $\{-b,0,b\}\times\{\pm a\}$ |
| Q9 | 6 | $\{\pm a\}\times\{\pm a\}$ |
| H8 | 4, 5, 6 | centre point |
| H20, H27 | 4, 5, 6 | $\{\pm a\}^3$ |

![Tying points of the Q9 element.](figures/mitc_q9.svg){#fig:mitc-q9}

For beams the tied rows are the two transverse shear strains ($\gamma_{xy}$ and $\gamma_{yz}$ in the element frame, where $y$ is the axis); the strain of the axis direction is untouched. For a Q4 plate the shear strains $\gamma_{xz},\gamma_{yz}$ are tied; for a Q9 plate the normal and shear in-plane components take part as listed.

## Where MITC is active

The analysis file selects the treatment **per family**: one word for beams, one for plates, one for solids. Values are `NONE` (full integration), `REDI` (reduced integration), `SELI` (selective integration) and `MITC` (tied shear strains).

Topologies without a tying table (Q16, T3, T6, T4, T10, P6) are integrated fully and the program prints a warning. In the validation campaign MITC with the H8 solid was found regular and effective (it reproduces the pure bending exactly), contrary to what an early version of this guide stated.

## Reduced and selective integration

Both act on the integration of the **structural element** (along the axis of a beam, over the surface of a plate, over the volume of a solid); the integration over the section or the thickness is not changed. The reduced rule has one Gauss point per direction less than the full one:

Table: Gauss points per direction of the structural elements. {#tab:redi-points}

| Element | B2 | B3 | B4 | Q4 | Q9 | Q16 | H8 | H27 |
|---|---|---|---|---|---|---|---|---|
| full (`NONE`) | 2 | 3 | 4 | 2 | 3 | 4 | 2 | 3 |
| reduced (`REDI`, `SELI`) | 1 | 2 | 3 | 1 | 2 | 3 | 1 | 2 |

* **REDI**: the whole element, stiffness and mass, is integrated with the reduced rule (as in the baseline program).
* **SELI**: the constitutive matrix is split, $\mathbf{C}=\mathbf{C}_n+\mathbf{C}_s$, where $\mathbf{C}_s$ keeps the rows and columns of the strains that cause locking and $\mathbf{C}_n$ all the others; $\mathbf{C}_n$ is integrated with the full rule, $\mathbf{C}_s$ with the reduced one, and the mass with the full rule. The reduced strains are the transverse shears of the element: $\gamma_{yz},\gamma_{xy}$ for beams (the strains that contain the derivative along the axis $y$), $\gamma_{xz},\gamma_{yz}$ for plates and all three shears for solids.

This is exactly the sum $\mathbf{K}=\int\mathbf{B}^T\mathbf{C}_n\mathbf{B}\,dV|_{full}+\int\mathbf{B}^T\mathbf{C}_s\mathbf{B}\,dV|_{reduced}$, so the stiffness matrix is symmetric. The two-set implementation reproduces the baseline program to $10^{-7}$ (displacements and frequencies of beams and plates).

> WARNING: with the reduced rule the Q4, H8 and H27 elements keep zero-energy (hourglass) modes: `REDI` can give a singular or meaningless solution for them (the baseline has the same behaviour and the program prints a warning). Use `SELI` or `MITC`. Triangles have no reduced rule and stay fully integrated.

For `REDI` the mass matrix is also reduced and therefore singular; the modal solver detects it and solves $\mathbf{M}\mathbf{x}=\mu\mathbf{K}\mathbf{x}$, discarding $\mu=0$ (the infinite frequencies).

## Practical advice

- For *slender beams* with low-order section expansions and B2/B3 elements, MITC is essential; with B4 elements (cubic) locking is already weak.
- For *thin plates* with Q4 or Q9 elements MITC is strongly recommended.
- Locking can also be reduced by using more nodes per element or finer meshes; MITC makes the coarse mesh affordable.
- MITC leaves the stiffness symmetric and positive definite: nothing changes in the solvers.
