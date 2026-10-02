# Global system and static solution {#sec:static}

## Global DOF numbering

Every structural node $a$ and every displacement field $k\in\{u,v,w\}$ owns a block of $T_{k}(a)$ consecutive DOFs (the number of terms of the expansion of that field at that node). The blocks are numbered **field by field**:

$$
\text{DOF}(a,k,\tau)=\text{FIRST}(a,k)+\tau-1,\qquad
\text{FIRST}(a,k)=1+\sum_{k'<k}\sum_{a'}T_{k'}(a')+\sum_{a'<a}T_k(a').
$$ {#eq:dof}

![Field-major numbering.](figures/dof_layout.svg){#fig:dof}

The numbering has no influence on the solution, but it fixes the layout of the dumped matrices and vectors (`K_MAT`, `FORCES`, `UNKNOWN`). Nodes that belong to no element receive no DOF and a warning is issued.

## Sparse storage

Two DOFs are coupled when they appear together in some element. For a Lagrange expansion they must also be associated with expansion nodes that share a sub-element (Chapter {sec:nucleus}). The global matrices are stored in *compressed sparse row* format with one-based, 64-bit indices:

- `ROW_POINTER(1:N+1)`: position of the first entry of every row;
- `COLUMN_INDEX(1:nnz)`: column of every entry, ascending in each row, the diagonal always present;
- `STIFFNESS(1:nnz)` and `MASS(1:nnz)`: values on the **same pattern**.

![Compressed sparse row storage of a small matrix.](figures/csr.svg){#fig:csr}

The full symmetric matrix is stored (not only the triangle) so that matrix–vector products are simple loops. The direct solver receives the upper triangle, extracted internally.

## The static problem

After the elimination of Section {sec:loads}, the system is symmetric positive definite (SPD):

$$
\mathbf{K}\,\mathbf{q}=\mathbf{F}.
$$ {#eq:system}

SPD guarantees that the Cholesky factorisation $\mathbf{K}=\mathbf{L}\mathbf{L}^{T}$ exists and is stable. The program uses the **PARDISO** sparse direct solver of the Intel oneMKL, which applies a fill-reducing reordering, a supernodal numerical factorisation and forward/backward substitution. The matrix type is 2 (real symmetric positive definite). Direct solution is chosen over iterative methods because the matrices of refined CUF models are strongly ill-conditioned (large ratios of stiffnesses between section terms and between thin and thick directions) and iterative methods converge slowly or not at all.

### Behaviour on ill-conditioned matrices

Very high-order Taylor models give matrices whose smallest eigenvalues are of the order of the rounding error. The Cholesky factorisation may then meet a non-positive pivot. In this case PARDISO reports the error code $-4$ and the program

1. releases the factorisation,
2. retries with the **symmetric indefinite** factorisation (`mtype -2`, Bunch–Kaufman pivoting with pivot perturbation),
3. records the warning *"Cholesky failed (ill-conditioned matrix)"*.

If even that fails the message *"ZERO PIVOT: SINGULAR MATRIX, CHECK SUPPORTS"* is given. The usual causes are: missing or insufficient supports (rigid-body motion left), disconnected parts that are not supported, H8 with MITC (Chapter {sec:mitc}) and a nearly singular Taylor basis (Chapter {sec:cuf}).

### Accuracy

For a well-posed problem the solution satisfies the system to about $\varepsilon_{mach}\kappa(\mathbf{K})$, where $\kappa$ is the condition number. High-order TE models and thin structures have large $\kappa$; the *relative displacement error* can then reach $10^{-5}$ for physically irrelevant reasons. This is one of the reasons why comparisons with reference results use tolerances larger than machine precision.

## Recovery of the solution

The solution vector contains the displacement coefficients in the global frame in the field-major order. The displacement of any point of the structure follows from {eq:cuf-full}; strains and stresses from the strain operator (Chapter {sec:post}).
