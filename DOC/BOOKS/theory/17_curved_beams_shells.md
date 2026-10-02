# Curved beams and shells with nodal triads {#sec:th-curved}

The elements of the previous chapters have a single frame: the structural geometry is described in the plane (or on the line) of that frame and the expansion lives in the remaining directions. This chapter removes the restriction. A **curved beam** and a **shell** of arbitrary geometry are described by the same kinematics (CUF, Cartesian components) and by a *three-dimensional map* built from nodal triads. Beam and shell share one kernel.

## Geometry: the nodal-triad map

Let $\xi$ be the natural coordinates of the structural element ($d_s=1$ for a beam, $d_s=2$ for a shell) and $\mathbf c$ the position of a point of the expansion mesh in its local axes (section of the beam, thickness of the shell, in lengths). The point of the element is
$$
\mathbf X(\xi,\mathbf c)=\sum_{i}N_i(\xi)\Big[\mathbf X_i+c_1\mathbf A_{1i}+c_2\mathbf A_{2i}+c_3\mathbf A_{3i}\Big],
$$
with $\mathbf X_i$ the node and $(\mathbf A_{1i},\mathbf A_{2i},\mathbf A_{3i})$ its **triad**:

| Element | $\mathbf A_1$ | $\mathbf A_2$ | $\mathbf A_3$ |
|---|---|---|---|
| beam | $\mathbf A_2\times\mathbf A_3$ | tangent of the axis | reference vector projected on the normal plane |
| shell | reference vector projected on the tangent plane | $\mathbf A_3\times\mathbf A_1$ | **director** $\mathbf V_i$ |

For a flat plate $\mathbf A_3$ is the normal and the map reduces to $\mathbf X=\mathbf X_s(\xi)+z\,\mathbf n$, the formulation of the plates. For a shell with the exact normals as directors the map is the one of the shell element with nodal directors, $\mathbf X=\sum N_i(\mathbf X_i+z\mathbf V_i)$ with $z=\zeta h/2$ the physical thickness coordinate; the thickness comes from the expansion mesh, not from a nodal value.

**Directors and tangents** at a node are the mean of the normals (of the tangents, with the sign aligned) of the elements that share it, *restricted to the elements whose normal is within the feature angle $\theta_f=40^\circ$ of the normal of the one that is being built*:
$$
\mathbf V_{ie}=\frac{\sum_{e'}\mathbf n_{e'i}\,H(\mathbf n_{e'i}\!\cdot\!\mathbf n_{ei}-\cos\theta_f)}{\big\|\sum_{e'}\cdots\big\|},\qquad \mathbf n_{ei}=\frac{\mathbf a_1\times\mathbf a_2}{\|\mathbf a_1\times\mathbf a_2\|}\Big|_{\xi_i},
$$
with $\mathbf a_\alpha=\sum_k\partial_\alpha N_k\mathbf X_k$ at the natural coordinates of the node. A smooth surface has one continuous director per node (the faces of neighbouring elements coincide, $\mathbf X^A=\mathbf X^B$ on the shared side for every $\mathbf c$); on a true edge every element keeps its own director. The nodal director of the optional file replaces the mean for the elements within $\theta_f$ of it.

**Jacobian.** The active natural coordinates are the structural ones followed by the active axes of the expansion mesh, $\mathbf t=(\xi_1,\dots,\xi_{d_s},c_{k_1},\dots)$, with $d_s+d_e=3$. The rows of the Jacobian are
$$
\mathbf g_a=\frac{\partial\mathbf X}{\partial t_a},\qquad
\mathbf g_\alpha=\sum_i\partial_\alpha N_i\,(\mathbf X_i+c_k\mathbf A_{ki}),\qquad
\mathbf g_{d_s+m}=\sum_iN_i\mathbf A_{k_mi},
$$
$\mathbf J=[\mathbf g_1;\mathbf g_2;\mathbf g_3]$, and the volume element
$$
dV=|\det\mathbf J|\;d\xi\;d\mathbf c .
$$
$\mathbf g_\alpha=\mathbf a_\alpha+c\,\mathbf b_\alpha$ is linear in the thickness: $\mathbf J=\mathbf J_0+c\,\mathbf J_1=(\mathbf I+c\,\mathbf S)\mathbf J_0$, and for exact normals $\det(\mathbf I+c\mathbf S)=1-2Hc+Kc^2$ ($H,K$ mean and Gauss curvature): the factor $(1+c/R_1)(1+c/R_2)$ of the Lamé shells is **included without knowing the radii**, for any curvature. The determinant is not factorised in the implementation: it is computed at every point.

## Strains in the covariant basis

The displacement is $\mathbf u=\sum_{\tau i}F_\tau(\mathbf c)N_i(\xi)\,\mathbf q_{\tau i}$ with $\mathbf q$ in global components. With $\varphi=F_\tau N_i$ and $\mathbf e_f$ the global direction of the component $f$,
$$
\tilde\varepsilon_{ab}=\tfrac12\big(\mathbf g_a\!\cdot\!\mathbf u_{,b}+\mathbf g_b\!\cdot\!\mathbf u_{,a}\big)
=\tfrac12\big(\varphi_{,b}\,g_{a,f}+\varphi_{,a}\,g_{b,f}\big),\qquad
\boldsymbol\gamma=(\tilde\varepsilon_{11},\tilde\varepsilon_{22},\tilde\varepsilon_{33},\tilde\gamma_{13},\tilde\gamma_{23},\tilde\gamma_{12}),
$$
(the order is the one of the code, $xx,yy,zz,xz,yz,xy$). The strain of the **material frame** $(\mathbf e_1,\mathbf e_2,\mathbf e_3)=\mathbf R$ is obtained with $Q_{ma}=\mathbf e_m\!\cdot\!\mathbf g^a$, $\mathbf Q=\mathbf R\mathbf J^{-1}$:
$$
\varepsilon^L_{mn}=Q_{ma}Q_{nb}\tilde\varepsilon_{ab}\ \Longrightarrow\ \boldsymbol\varepsilon^L=\mathbf T(\mathbf Q)\,\tilde{\boldsymbol\gamma},
$$
$T_{rs}=Q_{ma}Q_{na}$ for the normal components and $T_{rs}=\tfrac12(Q_{ma}Q_{nb}+Q_{mb}Q_{na})$ for the shears, twice that for the rows with $m\ne n$ (engineering shear). The frame $\mathbf R$ is built at every point: beam, $\mathbf e_2$ the tangent of the axis and $\mathbf e_3$ the projected reference vector; shell, $\mathbf e_3$ the normal $\mathbf g_1\times\mathbf g_2$ and $\mathbf e_1$ the projected reference vector. This is the convention of the plates and of the straight beams, so the cached constitutive matrices of the laminates (ply angle measured from $\mathbf e_1$) are used **unchanged**.

Without tying $\mathbf T\tilde{\boldsymbol\gamma}$ is exactly the Cartesian strain of a solid: $\mathbf B^L=\mathrm{sym}(\nabla\varphi\otimes\mathbf e_f)$ rotated to the material frame. This is a check of the implementation (the algebra of the kernel gives, to the last digit, the results of the straight beam and of the flat plate, which have another code path).

The potential and the temperature use the Cartesian gradient $\mathbf R\,\mathbf J^{-1}\partial_{\mathbf t}\varphi$ and the generalised constitutive matrix of the multiphysics chapter, so the piezoelectric, thermoelastic and pyroelectric couplings of Chapter 15 hold for curved elements (the assembly of $K_{uT}$ and $K_{\phi T}$ uses the same columns).

## Locking and MITC

A shell with compatible strains locks in transverse shear and in membrane; a curved beam in shear and, with quadratic elements, in membrane. The remedy is the interpolation of the assumed strains on the covariant components, **at the same position in the thickness** $\mathbf c$:
$$
\tilde\gamma^{AS}_{ab}(\xi,\mathbf c)=\sum_{m}L_m(\xi)\,\tilde\gamma_{ab}(\xi_m,\mathbf c),
$$
with the tying points $\xi_m$ and the Lagrange interpolants $L_m$ of the table ($a=1/\sqrt3$, $b=\sqrt{3/5}$):

| Element | Components | Tying points | $L_m$ |
|---|---|---|---|
| `S9` (MITC9) | $\tilde\varepsilon_{11},\tilde\gamma_{13}$ | $\xi\in\{\pm a\}$, $\eta\in\{-b,0,b\}$ (6) | linear in $\xi$, quadratic in $\eta$ |
| | $\tilde\varepsilon_{22},\tilde\gamma_{23}$ | $\xi\in\{-b,0,b\}$, $\eta\in\{\pm a\}$ (6) | quadratic, linear |
| | $\tilde\gamma_{12}$ | $\{\pm a\}\times\{\pm a\}$ (4) | bilinear |
| `S4` (MITC4) | $\tilde\gamma_{13}$, $\tilde\gamma_{23}$ | $(0,\pm1)$, $(\pm1,0)$ | linear |
| `CB2 CB3 CB4` | $\tilde\varepsilon_{11},\tilde\gamma_{12},\tilde\gamma_{13}$ | the $n-1$ Gauss points of the axis | Lagrange of degree $n-2$ |
| `S16` | none | | |

$\tilde\varepsilon_{33}$ stays compatible. The rows are replaced **before** the rotation to the material frame, with the $\mathbf T$ of the integration point (not of the tying points). The tying uses $\mathbf g_a$ and the shape functions of the tying point and the factors $F_\tau,F_{\tau,\zeta}$ of the integration point. The values of the table are the ones of MITC9 (Bucalem and Bathe) used in the CUF shell papers; the flat `S9` reproduces the MITC of the ordinary plate `Q9`, and the same for `S4` and for the beams, to the last digit.

## Integration and matrices

The stiffness is the sum over the points of the combined rule (structural $\times$ expansion), $K^{\tau si j}=\sum_p W_p\,\mathbf B_{\tau i}^{L\,T}\mathbf M\mathbf B^L_{sj}$, with
$$
W_p=w_{\xi}\;w_{\mathbf c}\;|\det\mathbf J_{\mathbf c}|_{\exp}\;|\det\mathbf J|,
$$
$w_{\mathbf c}|\det\mathbf J_{\mathbf c}|$ the weight and the Jacobian of the expansion mesh (thickness variations are free, every sub-element has its own length). The generalised constitutive matrix $\mathbf M$ is the cached one (6, 9 or 12 rows). The mass matrix is $M^{\tau si j}=\mathbf I_3\sum_pW_p\rho F_\tau F_sN_iN_j$ (rotary inertia of the thickness is in the terms of $F_\tau$) and the heat capacity is added when the temperature is active.

## Joining elements

The displacements are global components of the nodes, so **continuity is node sharing**. For two shells that share a smooth edge the maps agree for every $\mathbf c$ (same $\mathbf V_i$). At a true edge the elements have different directors $\mathbf V_a\ne\mathbf V_b$ at the node and the Taylor term $\mathbf q_1=\partial\mathbf u/\partial c$ has a different meaning in each of them (rotation of one wall, thickness stretch of the other): sharing it as a Cartesian vector is a spurious constraint that suppresses the bending slope at the edge (a thin box came out 5 to 10 times too stiff). The first-order term of an element is therefore written as the rotation $\boldsymbol\omega$ of the node acting on the director of that element, $\mathbf q_1^{e}=\boldsymbol\omega\times\mathbf V^{e}$, with $\boldsymbol\omega$ the shared unknown (three components, no multiplier). Both walls see the same rigid rotation, so displacements and rotations are continuous; the thickness stretch of the first-order term is dropped at the node (the second-order term remains). The transformation acts on the columns of the strain and of the basis, so stiffness, mass, loads and recovery use it. Normals exactly opposite at a node (trailing edge) share $\mathbf q_1$ with the sign of the thickness axis, which is the continuity of $\mathbf u$ along the same line. The beam–shell joint uses nodes of order 0 on both sides (terms $\mathbf q_0$ only), the one that has the same number of terms in a 1D and a 2D expansion mesh; the stringer is a rod of exact axial stiffness, and since a node of order 0 carries no rotation it must be an isolated node (a line of them across the bending direction locks the shell).

## Recovery

At an arbitrary point the element is located with a Newton iteration on $\mathbf X(\xi,\mathbf c)$ (the columns of the Jacobian are $\mathbf g_a$ and the combination of the nodal triads for the expansion coordinates), the shape and expansion factors are evaluated and the same columns $\mathbf B^L$ of the stiffness give strain and stress, in the frame of the point.

## Verification

| Check | Result |
|---|---|
| straight beam named `CB2 CB3 CB4`, flat plate named `S4 S9 S16`, with and without MITC, TE / LE, rotated ply | equal to the ordinary element to $10^{-9}$ |
| free quarter ring, 103 | exactly six rigid-body modes; first frequency $4.9037$ Hz, converged to $10^{-5}$ |
| quarter ring, tip force, $\nu=0$ | energy solution to $6\cdot10^{-5}$ (4 `B4`) |
| ring, tip couple | $\sigma=Mx/I$ to $10^{-3}$ |
| pinched cylinder (MacNeal-Harder), `TE 2`, `LE` | $0.98$ of $1.8248\cdot10^{-5}$ with $8\times8$ per octant, $1.003$ with $12\times12$; compatible strains: $0.35$ with $6\times6$ |
| circular and square tube, shared corner nodes | $0.990$, $0.995$ to $1.03$ of beam theory |

Note on the first-order convergence of the clamped cantilever: with $\nu\ne0$ the 3D solution has a singularity at the clamp edge and every element of the family converges as $h^1$ (the straight cantilever of the validation suite behaves in the same way); with $\nu=0$ the curved beam converges at once.

References: M. L. Bucalem and K. J. Bathe, *Higher-order MITC general shell elements*, Int. J. Numer. Meth. Eng. 36, 1993; D. Chapelle and K. J. Bathe, *The Finite Element Analysis of Shells*, Springer 2011; M. Cinefra and E. Carrera, *Shell finite elements with different through-the-thickness kinematics*, Int. J. Numer. Meth. Eng. 93, 2013; E. Carrera et al., *Finite Element Analysis of Structures through Unified Formulation*, Wiley 2014; R. H. MacNeal and R. L. Harder, *A proposed standard set of problems to test finite element accuracy*, Finite Elem. Anal. Des. 1, 1985.
