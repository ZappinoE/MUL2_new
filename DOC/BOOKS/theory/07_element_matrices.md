# Element matrices and the separable kernel {#sec:nucleus}

## From the weak form to the element matrices

Take one structural element $e_s$ with $N_n$ nodes and one expansion mesh with $T$ terms per field. The unknown vector of the element contains $N_n\times3\times T$ coefficients, ordered **node by node, then field, then term**:

$$
\mathbf{q}_e=\big[\,\underbrace{u_{1,1},\dots,u_{T,1}}_{\text{field }u}\;\underbrace{v_{1,1},\dots}_{\text{field }v}\;\underbrace{w_{1,1},\dots}_{\text{field }w}\;\big|\;\text{node 2}\;\big|\dots\big]
$$

(the *global* numbering is field-major instead; the element-local order is the one used inside the kernels and is mapped to the global order by the DOF list). The element stiffness and mass are the integrals {eq:km} over the element volume, which by {eq:volume} factorise into a structural and an expansion integral:

$$
\mathbf{K}_e=\sum_{e_x}\;\sum_{p}\sum_{q\in e_x} w_p\,w_q\,\det\mathbf{J}_{s,p}\,\det\mathbf{J}_{e,q}\;\mathbf{B}_{pq}^{T}\,\mathbf{C}_{e_x}\,\mathbf{B}_{pq},
$$ {#eq:ke}

where $e_x$ runs over the sub-elements of the expansion mesh, $p$ over the structural Gauss points and $q$ over the Gauss points of the sub-element. $\mathbf{C}_{e_x}$ is the (rotated) stiffness of the lamination of $e_x$.

## The reference ("point-by-point") evaluation

The direct way of computing {eq:ke} is to build, at every combined point $(p,q)$, the strain column of every DOF and accumulate $\mathbf{b}_I^T\mathbf{C}\mathbf{b}_J$ for all pairs $(I,J)$. The number of operations is of order

$$
\underbrace{P\,Q}_{\text{combined points}}\times\frac{n^{2}}{2}\times 12,\qquad n=3N_nT.
$$

For a TE15 beam with B4 elements ($n=1632$, $P=4$, $Q=256$ per sub-element) this is $\approx10^{10}$ floating-point operations per element and was the dominant cost in the first version of the code. MUL2_NEW keeps this evaluation as a reference (it is exact for any constitutive and quadrature layout) but uses it only as a fallback; Section {sec:sep} explains the default.

## Structure of the strain column

Inside the element frame the gradient of one basis function is, for any DOF with structural node $i$ and expansion term $\tau$,

$$
\partial_d(N_iF_\tau)=\sigma_d(\mathbf{x}_s;i)\;\varepsilon_d(\mathbf{x}_e;\tau),\qquad d\in\{x,y,z\},
$$ {#eq:sigma-eps}

with

$$
\sigma_d=\begin{cases}\partial_d N_i&d\in S\\ N_i&d\notin S\end{cases},\qquad
\varepsilon_d=\begin{cases}F_\tau&d\in S\\ \partial_d F_\tau&d\notin S\end{cases}.
$$ {#eq:sigma-eps2}

The set $S$ contains the axes spanned by the structural element: $S=\{y\}$ for a beam, $\{x,y\}$ for a plate and $\{x,y,z\}$ for a solid. In words: along a structural direction one differentiates the structural function and keeps the expansion function; along an expansion direction it is the other way round. Since the operator {eq:bop} is linear in the gradient,

$$
\mathbf{B}(\nabla\phi)\,\mathbf{r}_k=\sum_{d}\partial_d\phi\;\mathbf{w}_{d,k},\qquad
\mathbf{w}_{d,k}=\mathbf{B}(\mathbf{e}_d)\,\mathbf{r}_k,
$$ {#eq:wdk}

where $\mathbf{r}_k=\mathbf{R}\mathbf{e}_k$ is the local representation of the global unit vector of component $k$. The six-component vectors $\mathbf{w}_{d,k}$ depend only on the element frame and on the field, never on the position.

## The separable kernel {#sec:sep}

Insert {eq:sigma-eps} and {eq:wdk} into the stiffness integral of one sub-element $e_x$ and exchange sums. For the pair of DOFs $I=(i,\tau,k)$ and $J=(j,s,h)$

$$
K_{IJ}^{(e_x)}=\sum_{d,d'}\;\Gamma^{(e_x)}_{kh,dd'}\;
\underbrace{\sum_p w_p\det\mathbf{J}_{s,p}\;\sigma_d(p;i)\,\sigma_{d'}(p;j)}_{S_{dd'}(i,j)}\;
\underbrace{\sum_{q\in e_x} w_q\det\mathbf{J}_{e,q}\;\varepsilon_d(q;\tau)\,\varepsilon_{d'}(q;s)}_{E^{(e_x)}_{dd'}(\tau,s)},
$$ {#eq:sep}

with the scalar coupling coefficient

$$
\Gamma^{(e_x)}_{kh,dd'}=\mathbf{w}_{d,k}^{T}\,\mathbf{C}_{e_x}\,\mathbf{w}_{d',h}.
$$ {#eq:gamma}

Equation {eq:sep} is the fundamental nucleus of the formulation: a **$3\times3$ combination of products of a structural matrix $S_{dd'}$ (size $N_n\times N_n$) and an expansion matrix $E_{dd'}$ (size $T\times T$)**. The mass matrix is simpler:

$$
M_{IJ}=\delta_{kh}\sum_{e_x}\rho_{e_x}\Big[\sum_p w_p\det\mathbf{J}_{s,p}N_iN_j\Big]\Big[\sum_{q\in e_x}w_q\det\mathbf{J}_{e,q}F_\tau F_s\Big].
$$ {#eq:mass-sep}

The number of operations of {eq:sep} is, per sub-element,

$$
\underbrace{9\,P\,N_n^{2}}_{S_{dd'}}\;+\;\underbrace{9\,Q\,T^{2}}_{E_{dd'}}\;+\;\underbrace{9\,n^{2}/2}_{\text{combination}},
$$

i.e. **additive** in the two sets of points instead of multiplicative. For the TE15 example the cost drops from $\approx10^{10}$ to $\approx5\cdot10^{7}$ operations per element, and the assembly of a 100 000-DOF model from 526 s to 12 s (Benchmark, Chapter 13).

![Cost of the two evaluations.](figures/separable_cost.svg){#fig:sepcost}

Validity conditions:

1. $\mathbf{C}$ is constant inside each sub-element. This is true for every lamination type implemented (`LAM2`).
2. The factorisation {eq:sigma-eps} holds, i.e. structural and expansion directions do not mix. This is true for beams (section $\perp$ axis), plates (thickness $\perp$ surface) and solids.
3. The quadrature is a tensor product of a structural rule and an expansion rule, which is how the Gauss points are laid out.

If any condition fails the program falls back to the point-by-point evaluation of the same integral.

## Locality of the Lagrange expansion

For a Lagrange expansion the function $F_\tau$ of expansion node $\tau$ vanishes identically in every sub-element that does not contain node $\tau$. Hence $E^{(e_x)}_{dd'}(\tau,s)=0$ whenever $\tau$ and $s$ do not both belong to $e_x$, and summing over sub-elements, $K_{IJ}=0$ unless $\tau$ and $s$ share at least one sub-element. The global matrix therefore has **structural zeros** that are excluded from the sparse pattern. For a $4\times4$-element Q9 section the number of non-zeros of a 100 000-DOF beam drops from 120 M to 20 M.

## Taylor expansions: why $N+1$ Gauss points {#sec:te-quadrature}

The expansion functions of a Taylor model of order $N$ have degree $N$ in each of $x$ and $z$. The integrand of $E_{dd'}(\tau,s)$ contains the product of two such functions (degree $2N$, or less after differentiation) times the (constant for an affine section) Jacobian determinant. A Gauss rule with $n_g$ points integrates exactly polynomials of degree $2n_g-1$, hence

$$
2n_g-1\ge 2N\quad\Longleftrightarrow\quad n_g\ge N+\tfrac12\quad\Rightarrow\quad n_g=N+1 .
$$ {#eq:ng}

The program computes, for each expansion mesh, the largest Taylor order of the nodes of the elements that use it, and uses a tensor Gauss rule with $\max(n_g^{\text{default}},N+1)$ points per direction on the sub-elements. The rule for $n_g>4$ is computed by Newton iteration on the Legendre polynomials. With fewer points the stiffness is **not** the Taylor stiffness: the integration is inexact for $N\ge3$ on a $3\times3$ rule and the matrix was found numerically singular already for $N=4$. (This was the cause of a severe error found by the benchmark of Chapter 13 and is the reason for the regression test `beam_te8_unit`.)

## Mapping of the matrix to the global system

The element matrix is dense in its local DOFs. Each local DOF has a global number given by the field-major layout (Chapter {sec:static}). The matrices are scattered into the global CSR arrays in a fixed order, which makes the assembled matrix independent of the number of threads.

## Summary of the element computation

1. For every structural node $i$ and field $k$ obtain the number of terms and the expansion specification from the node kinematic.
2. At every structural Gauss point obtain $N_i$, $\nabla N_i$ (local frame) and $w_p\det\mathbf{J}_{s,p}$.
3. At every expansion Gauss point obtain $F_\tau$, $\nabla F_\tau$ and $w_q\det\mathbf{J}_{e,q}$.
4. Form $S_{dd'}$, $E_{dd'}$ and $\Gamma$; combine according to {eq:sep} and {eq:mass-sep}.
5. If MITC is active, replace the structural functions of the tied strain rows (Chapter {sec:mitc}) before step 4.
