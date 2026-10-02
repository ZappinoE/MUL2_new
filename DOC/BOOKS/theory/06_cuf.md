# The Carrera Unified Formulation {#sec:cuf}

## The idea

Classical beam theories (Euler–Bernoulli, Timoshenko) and plate theories (Kirchhoff, Reissner–Mindlin) postulate how the displacement varies across the section or thickness: linearly, with a rotation, and so on. The unified formulation does not postulate a single law. It writes the displacement as a **sum of products** of a function of the structural coordinate and a function of the remaining coordinates, and lets the user choose the second family:

$$
\mathbf{u}(x,y,z)=\sum_{\tau=1}^{T} F_\tau(x,z)\;\mathbf{u}_\tau(y)\qquad\text{(beam)}
$$ {#eq:cuf-beam}

where the *generalised displacements* $\mathbf{u}_\tau(y)$ are functions of the axis only and are themselves discretised with beam finite elements:

$$
\mathbf{u}_\tau(y)=\sum_{i=1}^{N_n} N_i(y)\,\mathbf{u}_{\tau i}.
$$

The complete approximation is therefore

$$
u_k(x,y,z)=\sum_{i=1}^{N_n}\sum_{\tau=1}^{T} N_i(y)\,F_\tau(x,z)\;u_{k\,\tau i},\qquad k\in\{u,v,w\}
$$ {#eq:cuf-full}

For a plate the structural functions $N_i$ depend on $(x,y)$ and the expansion $F_\tau(z)$ on the thickness coordinate only; for a solid the expansion is the constant $F_1=1$ (the "S1" element) and the formulation reduces to the standard three-dimensional finite element method.

![Structural functions N_i (red) times expansion functions F_tau (blue).](figures/cuf_concept.svg){#fig:cuf2}

**Why this is powerful.** The code never needs to know which theory it implements: it loops over structural nodes $i$ and expansion terms $\tau$ and multiplies two scalar functions and their derivatives. The *kinematic theory* is determined entirely by the list of functions $F_\tau$ and by their number $T$.

## Field-dependent kinematics

The three components $u,v,w$ (and the temperature and the potential) need not use the same expansion, and the expansion may change from node to node: the strain column of a DOF is always built from the scalar basis of its own field. The rules that make such models consistent (term count, conformity, order-0 joints, edges between shells, joining by coincidence) are collected in Chapter {sec:ndk}.

## Taylor expansions (TE)

In a Taylor expansion the functions $F_\tau$ are the monomials of the section coordinates up to order $N$:

$$
F_\tau(x,z)=x^{a}z^{b},\qquad a+b\le N .
$$ {#eq:taylor}

The terms are ordered by increasing total degree and, inside a degree, by increasing power of $z$: $1;\;x,\;z;\;x^2,\;xz,\;z^2;\;\dots$ The number of terms is

$$
T^{\text{beam}}_{N}=\frac{(N+1)(N+2)}{2},\qquad T^{\text{plate}}_{N}=N+1 .
$$

![Taylor monomials of a section.](figures/taylor_pyramid.svg){#fig:taylor}

Some orders are classical models in disguise:

Table: Classical models contained in the Taylor family (beam, displacement approach). {#tab:te-classical}

| Order | Terms | Displacement across the section | Corresponds to |
|---|---|---|---|
| TE0 | 1 | rigid translation | membrane/axial model without section kinematics |
| TE1 | 3 | linear in $x,z$ | Timoshenko-type beam (rotations and warping-free section) |
| TE2 | 6 | quadratic | enriched beam with in-plane deformation and Poisson effect |
| TE3, TE4 … | 10, 15, … | cubic, quartic … | refined models for thick, short or non-symmetric sections |

> WARNING: **TE0 is not a classical beam**: without section terms the Poisson contraction cannot develop and a pure axial test with $\nu\neq0$ shows spurious stiffening. Use TE1 or higher for engineering results. The uniform-strain patch tests of the verification suite use $\nu=0$ for this reason.

**Conditioning.** Monomials of high order on a small section are badly scaled: on a $10\times1$ mm section, $z^{15}\approx10^{-45}$ while $1\approx1$. The stiffness entries then span many orders of magnitude and the matrix becomes numerically singular. Practical remedies are to model the section in units close to one (for instance metres → millimetres) or to use Lagrange expansions, which are well conditioned for any size. The program prints a warning when it has to retry the factorization with a more robust algorithm (Chapter {sec:static}).

## Lagrange expansions (LE)

In a Lagrange expansion the section is itself a small finite element mesh (the *expansion mesh*) of Q4, Q9, Q16 or triangular elements (or line elements B2, B3, B4 for the thickness of a plate). Each node $\tau$ of the expansion mesh carries a Lagrange function $F_\tau$, equal to one at node $\tau$ and zero at all the other nodes. The unknown $u_{k\tau i}$ is then **the physical displacement of the point of the section that sits at expansion node $\tau$**, at structural node $i$. There is no rotation-like variable: the "rotations" are implied by the differences of the displacements of different points of the same section.

![A laminated section: each ply is one sub-element with its own material.](figures/expansion_layers.svg){#fig:layers}

Two properties make LE the natural tool for composites and local analysis:

1. The expansion is **layer-wise**: a sub-element belongs to one lamination, so the constitutive matrix jumps between sub-elements while the displacement stays continuous (interlaminar displacement continuity is automatic).
2. The functions have **local support**: terms $\tau$ and $s$ belonging to expansion nodes that do not share a sub-element never couple in the stiffness or mass matrix. The program exploits this to leave those entries out of the sparse pattern (the Implementation Guide, chapter *Assembly*).

The *order* of the Lagrange family is not an input: it is determined by the topology of the expansion elements (Q4 → linear, Q9 → quadratic, Q16 → cubic).

## Degrees of freedom

The number of unknowns is

$$
n_{\text{DOF}}=\sum_{\text{nodes}}\;\sum_{k\in\{u,v,w\}}T_k(\text{node}).
$$

Table: DOF per structural node for a few common models (three displacement fields). {#tab:dof}

| Model | Terms $T$ | DOF per node |
|---|---|---|
| Beam, TE1 | 3 | 9 |
| Beam, TE2 | 6 | 18 |
| Beam, TE4 | 15 | 45 |
| Beam, TE15 | 136 | 408 |
| Beam, LE with 4 Q9 sub-elements (25 nodes) | 25 | 75 |
| Plate, TE2 through the thickness | 3 | 9 |
| Plate, LE with 3 B2 layers (4 nodes) | 4 | 12 |
| Solid (H8, H27) | 1 | 3 |

## Strain and the fundamental nucleus {#sec:cuf-strain}

Inserting {eq:cuf-full} in the strain operator {eq:strain} gives a strain that is a linear combination of the *derivatives of the products* $N_iF_\tau$. Writing $\phi_{i\tau}=N_i F_\tau$ and using the local frame $(x,y,z)$,

$$
\nabla\phi_{i\tau}=\begin{bmatrix}
\partial_x\phi\\ \partial_y\phi\\ \partial_z\phi
\end{bmatrix}
=\begin{bmatrix}
N_i\,\partial_x F_\tau\\ \partial_y N_i\;F_\tau\\ N_i\,\partial_z F_\tau
\end{bmatrix}\quad\text{(beam)}
$$ {#eq:grad-beam}

while for a plate the structural gradient has components along $x,y$ and the expansion gradient along $z$. The strain produced by one unit coefficient of component $u_k$ is the column

$$
\mathbf{b}_{k\,i\tau}=\mathbf{B}(\nabla\phi_{i\tau})\,\mathbf{e}_k,
$$

where $\mathbf{B}(\mathbf{g})$ is the $6\times3$ operator that maps a displacement *of unit value times* a scalar function with gradient $\mathbf{g}$ into strains:

$$
\mathbf{B}(\mathbf{g})=
\begin{bmatrix}
g_x&0&0\\0&g_y&0\\0&0&g_z\\ g_z&0&g_x\\0&g_z&g_y\\ g_y&g_x&0
\end{bmatrix}.
$$ {#eq:bop}

The element stiffness is then the sum, over pairs of generalised displacements, of integrals of $\mathbf{b}^T\mathbf{C}\mathbf{b}$. The integral of one such pair is the **fundamental nucleus** of the formulation. In a hand-written CUF code the nucleus is a $3\times3$ block whose entries are combinations of four *section integrals* (of $F_\tau F_s$, $F_{\tau,x}F_s$, $F_{\tau}F_{s,x}$, $F_{\tau,x}F_{s,x}$, …) and of the corresponding structural integrals. MUL2_NEW recovers exactly this structure automatically from the scalar bases (Chapter {sec:nucleus}).

## Choosing the expansion: a decision table

Table: Which expansion for which problem. {#tab:choose}

| Situation | Recommended | Notes |
|---|---|---|
| Slender isotropic beam, global response | TE1–TE2 | cheapest; TE1 needs $\nu$-effects only through TE2 |
| Thick beam, short beam, local stress concentration | TE3–TE5 or LE | LE with moderate mesh is better conditioned |
| Thin-walled or open section | LE with a fine section mesh | warping and distortion are captured by the mesh |
| Laminated plate or sandwich | LE through the thickness (B2/B3 per ply or per layer group) | layer-wise displacement continuity |
| Thick plate | TE2–TE4 through the thickness | |
| Fully three-dimensional | H8/H27 | the S1 expansion is the identity |
