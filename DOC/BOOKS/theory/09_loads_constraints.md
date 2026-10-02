# Loads and constraints {#sec:loads}

## Point loads

A point load $\mathbf{F}=(F_x,F_y,F_z)$ (global components) applied at the physical point $\mathbf{X}_0$ contributes to the right-hand side of the equilibrium equations through the virtual work $\delta\mathbf{u}(\mathbf{X}_0)^T\mathbf{F}$. Since $\delta u_k(\mathbf{X}_0)=\sum_{i,\tau}\phi_{i\tau}(\mathbf{X}_0)\,\delta u_{k\tau i}$, the load vector has the entries

$$
f_{k\,\tau i}=F_k\;N_i(\mathbf{X}_0)\;F_\tau(\mathbf{X}_0).
$$ {#eq:load}

In practice the program restricts the point to be located *on a structural node and at a point of the section* (this is how the baseline works and what a user normally wants: loads at nodes of the section mesh). Then:

- **Lagrange expansion (LE).** $N_i=1$ at the structural node and $F_\tau(\mathbf{X}_0)$ equals one for the expansion node $\tau$ located at $\mathbf{X}_0$ and zero for all others: the load goes **directly to the single DOF** of that node of the section.
- **Taylor expansion (TE).** The functions $F_\tau$ are nonzero everywhere, so the load is **projected on all the monomials** evaluated at the section coordinates of the load point: $f_{k\tau i}=F_k\,x_0^{a}z_0^{b}$. A TE model has no node-like quantity: a point load distributes over the terms.

> NOTE: In a TE model the result of a point load depends on the evaluated expansion point: loading the section centroid or a corner gives different generalised forces. For a distributed or resultant load on a section use LE or apply several point loads.

If no node of any element matches the load location within tolerance, the program stops with `POINT LOAD LOCATION WAS NOT FOUND`.

## Displacement constraints

The constraint records fix displacement components on a **plane** $A X+B Y+C Z+D=0$ (global coordinates). The set of DOFs affected is determined **geometrically**: for each structural node and each term the physical position

$$
\mathbf{X}_{i\tau}=\mathbf{X}_i+\mathbf{R}^T\,(x_\tau,0,z_\tau)^T
$$

is tested against the plane within a tolerance.

- **LE:** every DOF of a term whose position lies on the plane is constrained ($u_\tau=\bar u$). Partial constraints of a section (for example clamping only the bottom face) are possible.
- **TE:** the plane must contain the **whole** expansion of the node (all section points). Then the constant term takes the prescribed value and all the other terms are set to zero. A plane that cuts the section would require a multi-point constraint among the monomials and is rejected with the error `PARTIAL PLANE CONSTRAINT REQUIRES MPC FOR TE`.

Each of the three components can be constrained (to a value) or left free (`N`). Conflicting prescriptions for the same DOF produce an error.

## Exact elimination for the static problem

Let the DOFs be split into free ($f$) and constrained ($c$) sets with prescribed values $\bar{\mathbf{q}}_c$. The static system

$$
\begin{bmatrix}\mathbf{K}_{ff}&\mathbf{K}_{fc}\\\mathbf{K}_{cf}&\mathbf{K}_{cc}\end{bmatrix}
\begin{bmatrix}\mathbf{q}_f\\\bar{\mathbf{q}}_c\end{bmatrix}
=\begin{bmatrix}\mathbf{F}_f\\\mathbf{F}_c\end{bmatrix}
$$

is solved for the free part:

$$
\mathbf{K}_{ff}\,\mathbf{q}_f=\mathbf{F}_f-\mathbf{K}_{fc}\,\bar{\mathbf{q}}_c .
$$ {#eq:elimination}

The implementation does not change the size of the matrix: the constrained rows and columns are zeroed, their diagonal is set to one, the right-hand side of the constrained rows is the prescribed value, and the free rows receive the correction $-\mathbf{K}_{fc}\bar{\mathbf{q}}_c$ (Figure {fig:elim}). The result is mathematically identical to {eq:elimination} and keeps the matrix symmetric and positive definite.

![Elimination of a constrained DOF.](figures/bc_elimination.svg){#fig:elim}

**Comparison with the penalty method.** The baseline program imposes constraints by adding a very large stiffness ($10^{10}$) to the constrained diagonal and a corresponding force. This is simple but (i) perturbs the solution at the level of the ratio of the stiffnesses, (ii) worsens the conditioning, and (iii) produces reaction errors. The exact elimination of MUL2_NEW agrees with the baseline to $\approx10^{-7}$ for static displacements and $\approx4\times10^{-6}$ for frequencies, which is the order of the penalty perturbation.

## Constraints in the modal problem

For free vibration the constrained DOFs are **removed**: only the free rows and columns of $\mathbf{K}$ and $\mathbf{M}$ are kept,

$$
\mathbf{K}_{ff}\boldsymbol{\phi}_f=\omega^{2}\mathbf{M}_{ff}\boldsymbol{\phi}_f,
$$

and the constrained components of the mode are zero. Prescribed non-zero displacements and applied loads have no meaning for a free vibration and are ignored (with a warning).

## Reactions

The reaction at a constrained DOF is $\mathbf{R}_c=\mathbf{K}_{cf}\mathbf{q}_f+\mathbf{K}_{cc}\bar{\mathbf{q}}_c-\mathbf{F}_c$. It is not written by the current release because the constrained rows are modified in place; the dump of $\mathbf{K}$ and $\mathbf{F}$ (`KMAT`, `FRCE`) can be used to recompute it externally.
