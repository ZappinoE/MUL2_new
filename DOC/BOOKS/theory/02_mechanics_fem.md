# Mechanics and finite element background {#sec:fem}

## Linear elasticity in matrix form

A deformable body occupies a volume $\Omega$ with boundary $\partial\Omega$. Under small displacements the strain is the symmetric gradient of the displacement. With the engineering-shear ordering of Chapter {sec:intro} it is written with a differential operator $\mathbf{D}$:

$$
\boldsymbol{\varepsilon}=\mathbf{D}\,\mathbf{u}, \qquad
\mathbf{D}\mathbf{u}=
\begin{bmatrix}
\partial_x u\\ \partial_y v\\ \partial_z w\\ \partial_z u+\partial_x w\\ \partial_z v+\partial_y w\\ \partial_y u+\partial_x v
\end{bmatrix}
$$ {#eq:strain}

Hooke's law gives the stress as a linear function of the strain through the $6\times6$ symmetric positive-definite matrix $\mathbf{C}$:

$$
\boldsymbol{\sigma}=\mathbf{C}\,\boldsymbol{\varepsilon}
$$ {#eq:hooke}

## Principle of virtual displacements

Equilibrium of a body loaded by body forces $\mathbf{b}$, surface tractions and point forces $\mathbf{F}_k$ is expressed weakly: for every admissible virtual displacement $\delta\mathbf{u}$ (zero where displacements are prescribed),

$$
\int_\Omega \delta\boldsymbol{\varepsilon}^{T}\boldsymbol{\sigma}\,d\Omega
=\int_\Omega \delta\mathbf{u}^{T}\mathbf{b}\,d\Omega+\sum_k \delta\mathbf{u}(\mathbf{x}_k)^{T}\mathbf{F}_k .
$$ {#eq:pvd}

For free vibration there are no loads and the inertia term $-\rho\,\ddot{\mathbf{u}}$ is added to the internal work. Looking for harmonic motion $\mathbf{u}(\mathbf{x})\,e^{i\omega t}$:

$$
\int_\Omega \delta\boldsymbol{\varepsilon}^{T}\boldsymbol{\sigma}\,d\Omega
=\omega^{2}\int_\Omega \rho\,\delta\mathbf{u}^{T}\mathbf{u}\,d\Omega .
$$ {#eq:vibration}

Everything that follows is the discretisation of {eq:pvd} (static) and {eq:vibration} (modal).

## The finite element method in one page

Choose a finite-dimensional space of displacement fields

$$
\mathbf{u}(\mathbf{x})=\mathbf{N}(\mathbf{x})\,\mathbf{q},
$$

where $\mathbf{q}$ collects the unknown coefficients ("degrees of freedom", DOF) and $\mathbf{N}$ the interpolation functions. Then $\boldsymbol{\varepsilon}=\mathbf{D}\mathbf{N}\,\mathbf{q}=\mathbf{B}\mathbf{q}$ and the weak forms become matrix equations:

$$
\mathbf{K}\mathbf{q}=\mathbf{F},\qquad \mathbf{K}\boldsymbol{\phi}=\omega^2\mathbf{M}\boldsymbol{\phi},
$$

$$
\mathbf{K}=\int_\Omega \mathbf{B}^{T}\mathbf{C}\mathbf{B}\,d\Omega,\qquad
\mathbf{M}=\int_\Omega \rho\,\mathbf{N}^{T}\mathbf{N}\,d\Omega.
$$ {#eq:km}

$\mathbf{K}$ is the *stiffness* matrix, $\mathbf{M}$ the *consistent mass* matrix. The integrals are computed element by element and the element matrices are summed (*assembled*) into global matrices.

## Isoparametric elements

An element is described on a *reference domain* with natural coordinates $\boldsymbol{\xi}$, for instance $[-1,1]^2$ for a quadrilateral. The same shape functions $N_i(\boldsymbol{\xi})$ interpolate both the geometry and the unknown:

$$
\mathbf{x}(\boldsymbol{\xi})=\sum_i N_i(\boldsymbol{\xi})\,\mathbf{x}_i .
$$ {#eq:iso}

The Jacobian $\mathbf{J}=\partial\mathbf{x}/\partial\boldsymbol{\xi}$ links derivatives and volumes:

$$
\frac{\partial N_i}{\partial \mathbf{x}}=\mathbf{J}^{-T}\frac{\partial N_i}{\partial \boldsymbol{\xi}},\qquad
d\Omega=\det\mathbf{J}\;d\boldsymbol{\xi}.
$$ {#eq:jac}

In MUL2_NEW the Jacobian of a structural element is built in the **element local frame** and only along the axes that the element really spans (the axis $y$ for a beam, the plane $x$–$y$ for a plate). This is explained in Chapter {sec:frames}.

## Numerical integration

Integrals over the reference element are computed by Gauss–Legendre quadrature,

$$
\int_{-1}^{1} f(\xi)\,d\xi\approx\sum_{p=1}^{n} w_p\,f(\xi_p),
$$

which is *exact* for polynomials of degree $2n-1$. Tensor products give rules for quadrilaterals and hexahedra. The default number of points per direction is the one that integrates the product of two shape-function derivatives exactly on an undistorted element:

Table: Default Gauss rules. {#tab:gauss}

| Element | Points per direction | Total points |
|---|---|---|
| B2, Q4, H8 | 2 | 2, 4, 8 |
| B3, Q9, H20, H27 | 3 | 3, 9, 27 |
| B4, Q16 | 4 | 4, 16 |
| T3 | 1 point at the centroid | 1 |
| T6 | 3 points (mid-edge rule) | 3 |

![Gauss–Legendre points of the quadrilateral rules.](figures/quadrature.svg){#fig:quadrature}

> WARNING: The default rule is **not** enough for the expansion of a Taylor model of high order. A Taylor expansion of order $N$ contains monomials up to degree $N$ and the stiffness integrand contains products of two of them, i.e. degree $2N$ in each direction. $N+1$ Gauss points per direction are then required. MUL2_NEW selects this number automatically for the expansion meshes (Section {sec:te-quadrature}).

## Sparse matrices and DOF numbering

A global matrix has one row and one column per DOF but each DOF is coupled only with the DOFs of the elements that share its node. The matrix is therefore *sparse*. MUL2_NEW stores it in *compressed sparse row* (CSR) format (see the Implementation Guide). The order in which DOFs are numbered does not change the mathematics but fixes the layout of the output files: the **numbering is field-major** (all $u$ DOFs, then all $v$, then all $w$).
