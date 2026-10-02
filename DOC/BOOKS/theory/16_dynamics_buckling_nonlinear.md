# Time, buckling, frequency and nonlinear analyses {#sec:th-dynamics}

All the analyses of this chapter use the element matrices of the previous chapters and add, per element, the **mass-like matrix** $M$ (the mass $\rho N_iN_j$ on the displacements, the heat capacity $\rho c\,N_iN_j$ on the temperature, nothing on the potential), the geometric matrix or the nonlinear internal force.

## 1. Time response (104)

The semi-discrete equations are, by field,
$$\begin{aligned}
M_{uu}\ddot u+C\dot u+K_{uu}u+K_{u\varphi}\varphi+K_{uT}T&=f(t)\\
K_{\varphi u}u-K_{\varphi\varphi}\varphi+K_{\varphi T}T&=Q_\varphi(t)\\
M_{TT}\dot T+K_{TT}T+C_{Tu}\dot u&=q(t)
\end{aligned}$$
with the Rayleigh damping $C=\alpha M_{uu}+\beta K_{uu}$ and the thermoelastic heating $C_{Tu}=-T_0K_{uT}^T$ (it follows from $T_0\beta:\dot\varepsilon$; it is active only when the reference temperature $T_0$ is given). Every load and prescribed value is multiplied by the amplitude $a(t)$.

**Newmark** for the displacements: with the predictors $\tilde u=u_n+\Delta t\,v_n+\Delta t^2(\tfrac12-\beta)a_n$ and $\tilde v=v_n+\Delta t(1-\gamma)a_n$,
$$u_{n+1}=\tilde u+\beta\Delta t^2a_{n+1},\qquad v_{n+1}=\tilde v+\gamma\Delta t\,a_{n+1}.$$
**$\theta$-method** for the temperature, $\tilde T=T_n+\Delta t(1-\theta)\dot T_n$, $T_{n+1}=\tilde T+\theta\Delta t\,\dot T_{n+1}$. Substituting in the equations at $t_{n+1}$ gives the effective system, one for all the fields:
$$\Big[K+\tfrac{1}{\beta\Delta t^2}M_{u}+\tfrac{1}{\theta\Delta t}M_T+\tfrac{\gamma}{\beta\Delta t}C_{\mathrm{full}}\Big]x_{n+1}
=a_{n+1}F+M\Big\{\tfrac{\tilde u}{\beta\Delta t^2},\tfrac{\tilde T}{\theta\Delta t}\Big\}+C_{\mathrm{full}}\Big(\tfrac{\gamma\tilde u}{\beta\Delta t}-\tilde v\Big).$$
For $\gamma=\tfrac12,\ \beta=\tfrac14$ the scheme is unconditionally stable and second-order accurate without algorithmic damping (the numerical period of the first mode of a cantilever differs from the exact one by $10^{-4}$ at 40 steps per period). The matrix is constant, so it is factored **once**. Prescribed values are imposed by eliminating the constrained columns at every step, which makes a time-varying voltage or temperature an exact boundary condition.

The initial acceleration solves $M_{ff}a_0=F(0)-Kx_0$ on the free mechanical degrees of freedom.

## 2. Frequency response (106)

Under harmonic loads $F e^{i\omega t}$ the response is $x e^{i\omega t}$ with
$$\big(K-\omega^2M_u+i\omega\,(C_{\mathrm{full}}+M_T)\big)\,x=F.$$
Writing $x=x_r+ix_i$ and $A=A_r+iA_i$, the complex system is the **real** block system
$$\begin{bmatrix}A_r&-A_i\\ A_i&A_r\end{bmatrix}\begin{Bmatrix}x_r\\ x_i\end{Bmatrix}=\begin{Bmatrix}F\\0\end{Bmatrix},$$
solved by PARDISO on every frequency (the matrix changes with $\omega$, the pattern does not). Near a resonance of a lightly damped structure the response is $\approx\phi\,\phi^TF/(2\zeta\omega_n^2)$; the code reproduces the modal flexibility fraction of the tip of a cantilever (0.969, theory 0.97) and places the resonance on the frequency of the free-vibration analysis.

## 3. Linear buckling (105)

For a structure loaded by $\lambda F$ the stress field is $\lambda\sigma_0$. The potential energy gains a term quadratic in the displacement gradient. In the CUF, with the displacement of a degree of freedom $i$ equal to $N_iF_\tau\,d_i$ ($d_i$ the unit vector of its component in the element frame) and $g_i=\nabla(N_iF_\tau)$,
$$K_G^{ij}=\int_V (d_i\cdot d_j)\,g_i^T\,S_0\,g_j\ \mathrm dV,$$
where $S_0$ is the stress tensor of the reference solution (the thermal stress $-\beta\theta$ included). The critical loads are the eigenvalues of
$$(K+\lambda K_G)x=0.$$
Since $K$ is positive definite the problem is solved as $K_Gx=\mu Kx$ with $\mu=-1/\lambda$; the most negative $\mu$ give the smallest positive load factors (LAPACK `DSYGV` with the potential degrees of freedom condensed). For a clamped-free beam the code gives $P_{cr}$ within $0.06\,\%$ of Euler's $\pi^2EI/4L^2$ and, with the shear term, the higher factors of a Timoshenko beam $P_n=P_{E,n}/(1+P_{E,n}/\kappa GA)$ within $0.7\,\%$.

## 4. Geometrically nonlinear statics (108)

The formulation is **total Lagrangian**. With $H=\nabla u$ the displacement gradient, $F=I+H$, the Green strain and the second Piola-Kirchhoff stress are
$$E=\tfrac12(H+H^T+H^TH),\qquad S=\mathbf C\,E-\beta\theta+e^T\nabla\varphi\quad(\text{St. Venant-Kirchhoff}).$$
In the generalised notation the strain is $\Gamma(u)=\{E(u),\nabla\varphi,\nabla\theta\}$ and the variation of $E$ for a degree of freedom $i$ is the linear strain plus the term $\tfrac12(H^Td_i\otimes g_i+g_i\otimes H^Td_i)$ (in Voigt form, with doubled shears). The internal force and the tangent matrix of an element are
$$f_{\mathrm{int}}^i=\int \mathbf B(u)_i^T\Sigma\,\mathrm dV,\qquad
K_T^{ij}=\int\mathbf B(u)_i^T\,\mathbf M\,\mathbf B(u)_j\,\mathrm dV+\int (d_i\!\cdot\!d_j)\,g_i^TS\,g_j\,\mathrm dV
+K^{ij}_{\mathrm{coup}}.$$
The solution is the **Newton-Raphson** iteration
$$K_T(x_k)\,\Delta x=\lambda F-f_{\mathrm{int}}(x_k),\qquad x_{k+1}=x_k+\Delta x,$$
on $N$ increments $\lambda_n=n/N$ of the loads and prescribed values, until $\|R\|\le\mathrm{tol}\cdot R_{\mathrm{ref}}$ with $R_{\mathrm{ref}}$ the largest force seen so far (a self-equilibrated thermal load has no external force, so a reference based on the current iteration would be zero at convergence). The convection of the surface loads is linear and kept as a separate matrix.

Tests: the elastica of a cantilever ($PL^2/EI=1$ and $2$) within $0.3\,\%$ and $0.06\,\%$ of the exact solution; a beam-column under $P_{cr}/2$ within $0.7\,\%$ of the amplification $3(\tan u-u)/u^3$; the Green-measure expansion of a heated bar, $\sqrt{1+2\alpha\Delta T}-1$, to $10^{-10}$ (the thermal strain is a Green strain, so the coupling terms are consistent). Newton converges in 4-5 iterations per step on all of them, the signature of a consistent tangent.

**Arc length.** To pass limit points the load factor becomes an unknown, $R(x,\lambda)=\lambda F-f_{\mathrm{int}}(x)=0$, and a constraint on the increment $\Delta u$ from the last converged state is added (Crisfield, cylindrical): $\Delta u^T W\Delta u=\Delta s^2$, with $W$ selecting the displacement unknowns. Each iteration solves with the same tangent
$$\delta u_R=K_T^{-1}R,\qquad \delta u_F=K_T^{-1}F,\qquad \Delta u\leftarrow \Delta u+\delta u_R+\delta\lambda\,\delta u_F,$$
and $\delta\lambda$ is the root of the quadratic obtained by inserting this update into the constraint; of the two roots the one that keeps the direction of the current increment ($\Delta u_{new}^T W\Delta u_{old}$ larger) is taken, which prevents turning back along the path. The predictor is $\delta\lambda=\pm\Delta s/\|\delta u_F\|_W$ with the sign of $\delta u_F^TW\Delta u_{\mathrm{prev}}$ (it flips at a limit point, where $\lambda$ starts to decrease). The step is adapted with $\Delta s\leftarrow\Delta s\sqrt{5/n_{it}}$ and halved when Newton fails. The constraint is imposed on the displacements only, so that temperature or potential unknowns (different units) do not enter the norm; prescribed values must be zero because $\lambda F$ is the whole driving term.

Test: a clamped shallow arch (span 10, depth 1, rise 2.5; the nodes lie on a parabola, but every beam element is straight, because curved elements are not yet supported) loaded at the crown; below the limit load the path equals load control to $3\cdot10^{-10}$, the limit load ($\lambda\approx1.96$) found with two very different step sizes agrees within $0.14\,\%$, and the path continues through the descending branch (the load drops below half of the limit load) up to the inverted configuration.

**Shear locking.** MITC ties the linear part of the strain only; the quadratic part $H^TH$ is not tied. For slender beams and plates with large rotations a fine mesh or reduced integration of the nonlinear terms should be checked.
