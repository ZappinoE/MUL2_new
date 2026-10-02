# Multiphysics: the generalised strain {#sec:th-multiphysics}

The Carrera Unified Formulation expands every field as $\phi(x,y,z)=N_i(\xi)\,F_\tau(x_e)\,\phi_{i\tau}$, with $N_i$ the structural shape functions and $F_\tau$ the expansion over the section. The temperature $\theta$ and the electric potential $\varphi$ are fields like the displacements and use **the same expansion machinery** (Taylor, Lagrange, hierarchical); only the *kinematic operator* and the *constitutive law* differ. This chapter states the formulation in one place; the numerical procedures that use it (time integration, buckling, nonlinearity) are in the next chapter.

**Activation.** The fields that are solved are selected in the analysis (`FIELDS` record of `ANALYSIS.dat`); the expansions of the fields are defined in the kinematics. The principle of the element is a separate choice: all the elements are displacement-based (PLV); the expansion slots of the transverse stresses $\sigma_{zz},\sigma_{xz},\sigma_{yz}$ already exist as explicit fields, so that a mixed (RMVT) element will be an element label, not a change of the data structures.

## 1. Generalised strain and constitutive law

At a point the gradients of all the fields are collected in the generalised strain
$$\Gamma=\begin{Bmatrix}\varepsilon\\ \nabla\varphi\\ \nabla\theta\end{Bmatrix}\in\mathbb R^{12},$$
with $\varepsilon=\mathbf B\mathbf u$ the (engineering) strain, and the generalised stress $\Sigma=\{\sigma,\ D,\ q'\}$ is given by one symmetric matrix
$$\Sigma=\mathbf M\,\Gamma-\begin{Bmatrix}\beta\,\theta\\ -p_\varepsilon\theta\\ 0\end{Bmatrix},\qquad
\mathbf M=\begin{bmatrix}C&e^{T}&0\\ e&-\epsilon&0\\ 0&0&k\end{bmatrix}.$$
In words: $\sigma=C\varepsilon+e^T\nabla\varphi-\beta\theta$ with $\beta=C\alpha$ (Hooke's law with piezoelectric and thermal terms), $D=e\varepsilon-\epsilon\nabla\varphi+p_\varepsilon\theta$ (electric displacement, with $E=-\nabla\varphi$) and $q'=k\nabla\theta$ (the heat flux is $q=-q'$, Fourier's law). $C$ is the stiffness at constant field, $e$ the piezoelectric stress coefficients, $\epsilon$ the permittivity at constant strain, $\alpha$ the expansion, $k$ the conductivity and $p_\varepsilon$ the pyroelectric coefficient at constant strain. All the tensors are given in the material axes and **rotated** into the element frame with the transformation of the engineering strain $T$:
$$C'=T^TCT,\quad e'=A^TeT,\quad \epsilon'=A^T\epsilon A,\quad k'=A^TkA,\quad \alpha'=T(A^T)\alpha,\quad p'=A^Tp.$$
The pyroelectric coefficient that a data sheet gives is measured on a free body, $p_\sigma$; the model needs $p_\varepsilon=p_\sigma-e\,\alpha$ (the free expansion contributes $e\alpha\theta$ to $D$).

Because $\mathbf M$ contains the blocks side by side, the kernel of Chapter {sec:nucleus} is unchanged: the element matrix is
$$\mathbf K^e=\int_{V}\mathbf B_\Gamma^T\,\mathbf M\,\mathbf B_\Gamma\,\mathrm dV
+\mathbf K^e_{\mathrm{coup}},$$
where the columns of $\mathbf B_\Gamma$ are the strain of a displacement degree of freedom, the gradient of a potential one (rows 7-9) or of a temperature one (rows 10-12). Selective integration only reduces the transverse shear rows of the mechanical block.

## 2. Coupling terms and the monolithic system

The temperature enters the mechanical and electric equations through its **value**, not its gradient, so it is outside $\mathbf M$:
$$K_{uT}^e=-\int \mathbf B_u^T\beta\,N_T\,\mathrm dV,\qquad
K_{\varphi T}^e=+\int (\nabla N_\varphi)\cdot p_\varepsilon\,N_T\,\mathrm dV.$$
In the stationary problem the reverse blocks vanish, so the system
$$\begin{bmatrix}K_{uu}&K_{u\varphi}&K_{uT}\\ K_{\varphi u}&-K_{\varphi\varphi}&K_{\varphi T}\\ 0&0&K_{TT}\end{bmatrix}
\begin{Bmatrix}u\\ \varphi\\ T\end{Bmatrix}=\begin{Bmatrix}f\\ Q_\varphi\\ q\end{Bmatrix}$$
is block triangular and **not symmetric**. It is assembled and solved as one system (a non-symmetric PARDISO factorization), instead of solving the heat problem first and applying a thermal load. $K_{TT}$ is positive definite, the piezoelectric block is indefinite, so the unsymmetric factorization is also the robust choice for thermo-piezoelectric problems.

*Why one-way?* The heat equation contains the term $T_0\,\beta:\dot\varepsilon$ (thermoelastic heating); it vanishes in a stationary state because $\dot\varepsilon=0$. The transient and harmonic analyses add it (Chapter {sec:th-dynamics}).

## 3. Electrodes

A potential prescribed on an electrode is an ordinary constraint of the degrees of freedom on a plane (`V-PLANE`). A **floating** electrode (open circuit) is an equipotential surface with an unknown value: the degrees of freedom of the plane are tied to a master. In algebra, with $\mathbf T$ the tie matrix, $\mathbf K\to\mathbf T^T\mathbf K\mathbf T$ and $f\to\mathbf T^Tf$ (the charge is the sum on the electrode, zero for an open circuit). The implementation rebuilds the CSR rows with the slaves added to their master, and copies the master value to the slaves after the solution.

**Short and open circuit.** A modal analysis with the potential degrees of freedom free gives the frequencies of the open-circuit structure, with grounded electrodes those of the short circuit. The potential has no inertia, so its rows are eliminated by static condensation, $K^*=K_{uu}-K_{u\varphi}K_{\varphi\varphi}^{-1}K_{\varphi u}$, before the eigenproblem. For a plate of thickness $t$ polarised across the thickness the fundamental frequency is
$$f_n=\frac{2n-1}{4t}\sqrt{\bar c/\rho},\qquad \bar c_{\mathrm{OC}}=c_{33}+\frac{e_{33}^2}{\epsilon_{33}}:$$
the open-circuit modes are stiffer (piezoelectric stiffening), and the code reproduces the closed form within 0.03 %.

## 4. Surface loads

A heat flux enters the right-hand side as $\int_\Gamma N_T\,q\,\mathrm d\Gamma$. In CUF a surface is the **product of a part of the structural element and a part of the expansion element**, with two parameters in all:

| Element | Surface = structural part $\times$ expansion part |
|---|---|
| beam | axis $\times$ edge of the section (lateral skin); end node $\times$ whole section |
| plate | surface $\times$ end of the thickness (faces); edge $\times$ whole thickness (sides) |
| solid | face |

For a Gauss point of the surface the two natural coordinates give the tangent vectors $\mathbf t_1,\mathbf t_2$ (the structural ones from the node coordinates, the expansion ones rotated by the element frame), the area element is $\mathrm d\Gamma=|\mathbf t_1\times\mathbf t_2|$ and the normal $\mathbf n=\mathbf t_1\times\mathbf t_2/|\cdot|$, oriented away from the centre of the element. A piece is *exposed* when no other piece has the same centre. The loads are
$$q=q_0F(\mathbf x),\qquad q=aG\max(0,\mathbf n\cdot\mathbf s),\qquad q=h(T_\infty-T);$$
the convection also adds $h\int N_TN_T^T\mathrm d\Gamma$ to the conduction matrix. The sun is a plane wave without shadowing.

## 5. Spatial fields

A value $v$ of a boundary condition may be multiplied by a function $F(x,y,z)$ from `FIELDS.dat`. For a constraint $v F(\mathbf x_i)$ is the value of every degree of freedom with the position $\mathbf x_i$ of its node (Lagrange and vertex hierarchical modes; the Taylor terms of a section take the structural node); for a surface load $F$ is evaluated at the Gauss point.
