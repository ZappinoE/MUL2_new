# Time, buckling, frequency and nonlinear analyses {#sec:more-analyses}

`ANALYSIS.dat` selects the analysis with its first record. The other records (number of modes, shear-locking treatments) keep their meaning.

| Id | Analysis | Extra input file | Main output |
|---|---|---|---|
| 101 | linear static | | `STATIC/` |
| 103 | free vibration | | `DYNAMIC/FREQUENCIES.dat`, mode shapes |
| 104 | time response (Newmark) | `TIME_RESP.dat` | `DYNAMIC/TIME_HISTORY.dat`, `DYNAMIC/RESULTS_PARA_nn_Ssssssss.vtk` |
| 105 | linear buckling | | `DYNAMIC/BUCKLING_FACTORS.dat`, modes |
| 106 | frequency response | `FREQ_RESP.dat` | `DYNAMIC/FREQ_HISTORY.dat` |
| 108 | geometrically nonlinear static | `NL_INFO.dat` | `DYNAMIC/TIME_HISTORY.dat`, `STATIC/` |

The loads are the ones of `BC.dat` (forces, charges, heat, surface loads) and the prescribed values (displacements, potentials, temperatures) in all the analyses; the extra file says *how they vary*.

## Time response (104)

### TIME_RESP.dat

```text
0.0  0.5                 TI  TF
1000                     NSTEP
10                       output every 10 steps
0                        number of extra output steps (their indices follow)
---------------------
1                        number of time loads
STEP 0.0 1.0
NEWMARK 0.25 0.5         (optional)
RAYLEIGH 0.0 1.0D-4      (optional)  alpha beta   C = alpha M + beta K
THETA 1.0                (optional)  thermal theta-method, 0.5 .. 1
T0 293.0                 (optional)  reference temperature [K]
```

Dashed separator lines are ignored. The **amplitude** $a(t)$ is the sum of the load records and multiplies *every* load and prescribed value of `BC.dat` (a voltage, a temperature, a force). The initial state is $a(0)$ times the prescribed values, with zero velocity and zero temperature.

| Record | $a(t)$ |
|---|---|
| `STEP t0 A` | $A$ for $t\ge t_0$ |
| `RAMP t0 t1 A` | linear from 0 to $A$ between $t_0$ and $t_1$, then $A$ |
| `IMPU t0 A` | $A$ at the first step $t\ge t_0$ only |
| `SINU phi omega A` | $A\sin(\varphi+\omega t)$ |
| `HASU t0 F phi2 n phi1 A` | sine burst of frequency $F$ with a Hann window of $n$ cycles |
| `HACU t0 F phi2 n phi1 A` | the same with a cosine |
| `WPSU t0 F phi2 n phi1 A` | sine burst with a $\sin^2$ window |

**Damping.** The Rayleigh damping acts on the mechanical degrees of freedom. It may be given by `RAYLEIGH alpha beta` here or by the historical record `DAMP k_K k_M` of `MATERIAL.dat` (note the order: $K$ first). For a mode of frequency $\omega$ the damping ratio is $\zeta=\tfrac12(\alpha/\omega+\beta\omega)$.

**Integration.** Mechanical degrees of freedom: Newmark (default $\beta=1/4$, $\gamma=1/2$, average acceleration, unconditionally stable and without numerical damping). Temperature: first-order $\theta$-method (default backward Euler, $\theta=1$; $\theta=1/2$ is Crank-Nicolson and needs a smooth start). Potential: no inertia (algebraic). The effective matrix is factored **once**.

**Thermal coupling.** With `T-SPC` the temperature has a heat capacity $\rho c$ and the heat equation is transient. The temperature acts on the structure through the thermal expansion. The reverse coupling (thermoelastic heating, $T_0\,\beta:\dot\varepsilon$, the cause of thermoelastic damping) is added when `T0` is given.

### Output

`TIME_HISTORY.dat` has one row per output step and point of `POSTPROCESSING.dat`: the time followed by the columns of `POST_POINT.dat`. Every `PARA` record writes a VTK file per output step.

## Buckling (105)

The reference loads (and thermal loads) of the model are applied, the linear static problem is solved and the geometric stiffness $K_G$ of its stress field is built; the eigenproblem

$$(K + \lambda K_G)\,x = 0$$

gives the **load factors** $\lambda$: the critical load is $\lambda$ times the applied one. The number of factors is the *number of modes* of `ANALYSIS.dat`. `BUCKLING_FACTORS.dat` lists them in ascending order and the mode shapes are written like the vibration modes. The reference load must be compressive to give a positive factor.

The eigensolver is dense: at most 8000 free degrees of freedom. The temperature is the given field of the pre-stress (a **thermal buckling** problem is a model with a thermal load), the potential is condensed (closed circuit with the prescribed electrodes). Floating electrodes are not supported.

## Frequency response (106)

```text
0.0  400.0               FI FF  [Hz]
400                      number of steps
1                        output every n
RAYLEIGH 12.0 0.0        (optional)
T0 293.0                 (optional)
```

The system $(K - \omega^2 M + i\omega C)\,x = F$ is solved on $N+1$ frequencies, with the loads of `BC.dat` as unit harmonic amplitudes (phase 0) and the prescribed values at phase 0. The temperature rows get $i\omega\rho c$ and the thermoelastic heating (with `T0`). `FREQ_HISTORY.dat` has for every frequency and point the real and imaginary parts of $u_x,u_y,u_z$, $T$ and the potential: the modulus is $\sqrt{\mathrm{Re}^2+\mathrm{Im}^2}$ and the phase $\mathrm{atan2}(\mathrm{Im},\mathrm{Re})$. Each frequency is a new factorization of a system twice as large as the static one.

## Geometrically nonlinear static (108)

```text
1                        technique (1 = load control, 2 = arc length)
10                       number of load steps
30                       maximum iterations per step
1.0D-8                   relative residual tolerance
1                        output every n steps
```

The loads and prescribed values are applied in $N$ equal increments. The formulation is total Lagrangian with the Green strain and the second Piola-Kirchhoff stress of the (St. Venant-Kirchhoff) material; the electric potential and the temperature are solved in the same system, so thermal strains, the pyroelectric effect and the piezoelectric coupling are present. Loads are **dead** (they keep their direction). The tangent matrix is rebuilt and factored at every iteration. `TIME_HISTORY.dat` holds the load factor $\lambda$ in its time column; the standard `STATIC/` files hold the final state (strain and stress there are the linearised measures of the final displacements).

A prescribed displacement is a displacement-controlled step. With technique 1 a limit point (snap-through under load control) cannot be followed; a loss of convergence is reported with the step and the residual.

### Arc length (technique 2)

With technique 2 the load factor $\lambda$ becomes an unknown and the equilibrium path is followed through limit points (snap-through, snap-back). The method is Crisfield's with a cylindrical constraint on the displacement degrees of freedom, $\|\Delta u\|=\Delta s$; the reference load ($\lambda=1$) is the force of the model. The record `number of load steps` is now the **maximum number of arc-length steps**, and a sixth record is added:

```text
2                        technique: arc length
100                      maximum number of steps
30                       maximum iterations per step
1.0D-8                   relative residual tolerance
1                        output every n steps
0 0 0 3.0                ds0 dsmin dsmax lambda_max   (optional)
```

`ds0`, `dsmin`, `dsmax` equal to 0 mean automatic values (the first step is 10 % of $\lambda_{max}$ in the linear regime, $\Delta s_{min}=10^{-4}\Delta s_0$, $\Delta s_{max}=10\,\Delta s_0$). After each step $\Delta s$ is multiplied by $\sqrt{5/n_{it}}$ (limited by `dsmin`, `dsmax`); a step that does not converge is repeated with half the arc length. The path ends when $\lambda\ge\lambda_{max}$ (default 1) or after the maximum number of steps; $\lambda$ may become negative on the way (snap-back, inverted snap-through). `TIME_HISTORY.dat` has $\lambda$ in the time column, one row per output step.

Restrictions: all the prescribed values (displacements, potentials, temperatures) must be zero, because the load is the parameter; the norm of $\Delta u$ uses only the displacement unknowns. Chosen $\lambda_{max}$ below the first limit load, the arc-length path coincides with load control (checked to $10^{-9}$).

## Checks you can repeat

| Test | Reference | Error |
|---|---|---|
| step load on a cantilever | peak $2u_s$, period $=1/f_1$ | 2.4 %, $10^{-4}$ |
| Rayleigh damping | overshoot $e^{-\pi\zeta/\sqrt{1-\zeta^2}}$ | 5 % |
| heat conduction with capacity | series solution | $<0.3$ % |
| lumped bar with sun and convection | $T = \frac{aGA}{hS}(1-e^{-t/\tau})$ | see `dynamics_tests.py` |
| thermoelastic damping | decay only with `T0` | 6.5 % in 2 periods |
| frequency response | resonance at $f_1$, amplitude $\approx 1/(2\zeta)$ | $<1$ % |
| buckling of a cantilever | $\pi^2EI/4L^2$ | 0.06 % |
| clamped-clamped bar, thermal | $4\pi^2EI/L^2$ with the shear term | 5 % |
| elastica $PL^2/EI=1,2$ | Bisshopp-Drucker | 0.3 %, 0.06 % |
| beam-column, $P=P_{cr}/2$ | $3(\tan u-u)/u^3$ | 0.7 % |
| thermal expansion, Green measure | $\sqrt{1+2\alpha\Delta T}-1$ | $10^{-10}$ |

The scripts are in `TESTS/DYNAMICS`, `TESTS/BUCKLING` and `TESTS/NONLINEAR`.

## Limits

- Floating electrodes (`V-FLOAT`) work only in 101 and 103.
- 104 has a constant time step, zero initial conditions and one amplitude function for all the loads.
- 105 is dense (8000 free degrees of freedom) and the buckling problem is the one of a perfect structure: no post-buckling.
- 108 has an arc-length method (technique 2) only for loads with zero prescribed values; it has no material nonlinearity and no follower loads; MITC ties only the linear part of the strain.
