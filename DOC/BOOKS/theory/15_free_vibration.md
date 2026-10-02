# Free vibration {#sec:modal}

## The generalised eigenvalue problem

After removing the constrained DOFs the free vibration problem is

$$
\mathbf{K}\boldsymbol{\phi}=\lambda\,\mathbf{M}\boldsymbol{\phi},\qquad\lambda=\omega^{2},\quad f=\frac{\omega}{2\pi},
$$ {#eq:gep}

with $\mathbf{K}$ symmetric positive (semi-)definite and $\mathbf{M}$ symmetric positive definite. The eigenvectors can be chosen **$\mathbf{M}$-orthonormal**,

$$
\boldsymbol{\phi}_i^{T}\mathbf{M}\boldsymbol{\phi}_j=\delta_{ij},\qquad
\boldsymbol{\phi}_i^{T}\mathbf{K}\boldsymbol{\phi}_j=\lambda_i\delta_{ij}.
$$ {#eq:orthonormal}

The frequencies requested are the lowest ones. A dense solution of {eq:gep} costs $O(n^{3})$ operations and is possible only for small problems; refined CUF models have $10^{4}$–$10^{6}$ DOF, so a **sparse eigensolver** is required.

## Shift-and-invert Lanczos

The lowest eigenvalues are the *extreme* eigenvalues of the spectral transformation

$$
\mathbf{A}=(\mathbf{K}-\sigma\mathbf{M})^{-1}\mathbf{M},\qquad
\mu=\frac{1}{\lambda-\sigma},
$$ {#eq:shift-invert}

whose eigenvectors are those of the original problem and whose **largest** eigenvalues $\mu$ correspond to the eigenvalues $\lambda$ **closest to the shift $\sigma$**. With $\sigma=0$ (the default) the largest $\mu$ are the lowest frequencies. The operator $\mathbf{A}$ is self-adjoint in the $\mathbf{M}$ inner product, hence the **Lanczos** method applies; its implicitly restarted version is implemented in the **ARPACK** library (routines `dsaupd`, `dseupd`), used in *mode 3* (shift-invert for $\mathbf{K}\mathbf{x}=\lambda\mathbf{M}\mathbf{x}$ with $\mathbf{M}$ in the inner product, `BMAT='G'`).

ARPACK works with *reverse communication*: it never sees the matrices; it returns control with a request, the calling program performs the requested product and calls it again. For mode 3 the requests are

| Request (`IDO`) | Operation |
|---|---|
| $-1$ or $1$ | $\mathbf{y}\leftarrow(\mathbf{K}-\sigma\mathbf{M})^{-1}\mathbf{M}\mathbf{x}$ (a sparse product followed by a back-substitution with the factors) |
| $2$ | $\mathbf{y}\leftarrow\mathbf{M}\mathbf{x}$ |
| $99$ | converged / finished |

The factorisation of $\mathbf{K}-\sigma\mathbf{M}$ is computed **once** with PARDISO; each iteration costs one forward-backward substitution and two sparse products. The number of Lanczos vectors is $\max(2\,n_{ev}+1,\,n_{ev}+10)$, limited by the problem size.

## Dense fallback

When the free problem has at most 400 DOF or when almost all eigenvalues are requested ($n_{ev}\ge n-2$) ARPACK is not appropriate (the subspace would be the whole space). The program then builds the dense matrices and solves {eq:gep} with the LAPACK routine `dsygv`.

## Output and checks

- The eigenvalues are sorted in ascending order and the modes returned **$\mathbf{M}$-normalised**.
- The frequency of each mode is $f=\sqrt\lambda/2\pi$ in hertz (negative eigenvalues, which can only be rounding noise of rigid-body modes, are clipped to zero with a warning).
- The relative residual $\|\mathbf{K}\boldsymbol{\phi}-\lambda\mathbf{M}\boldsymbol{\phi}\|/\|\mathbf{K}\boldsymbol{\phi}\|$ is computed for every mode (with the reduced matrices) and written in `ARPACK_SOLVER_INFO.dat`; the console reports the maximum. Values below $10^{-6}$ indicate converged modes.
- ARPACK is run with machine-precision tolerance and at most 500 restart iterations.

> WARNING: If the supports leave rigid-body modes, $\mathbf{K}$ is singular and the factorisation of $\mathbf{K}-\sigma\mathbf{M}$ with $\sigma=0$ fails. Constrain the structure sufficiently or ask for modes with a non-zero shift (not exposed in the current input format).

## Frequency of a cantilever beam as a sanity check

For an Euler–Bernoulli cantilever of length $L$, bending stiffness $EI$ and mass per unit length $\rho A$, the first bending frequency is

$$
f_1=\frac{(1.8751)^2}{2\pi}\sqrt{\frac{EI}{\rho A L^{4}}}.
$$ {#eq:eb-freq}

A refined CUF model gives a slightly lower value because it includes shear and section deformation. The ratio becomes closer to one for slender beams (Chapter {sec:verification} shows an example).

## Participation and mode shapes

Mode shapes are stored as displacement coefficients in the global numbering and expanded to displacement fields on the output grid. In the output files each mode appears as a displacement field with $\mathbf{M}$-normalised amplitude; the visual scale is arbitrary and should be set in the post-processor (ParaView, GMSH).
