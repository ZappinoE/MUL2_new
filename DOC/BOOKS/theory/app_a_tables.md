# Numerical tables and references

## Gauss–Legendre rules

Table: Points $\xi_p$ and weights $w_p$ on $[-1,1]$. {#tab:gl}

| $n$ | Points | Weights |
|---|---|---|
| 1 | 0 | 2 |
| 2 | $\pm0.5773502691896258$ | 1, 1 |
| 3 | $0$, $\pm0.7745966692414834$ | $8/9$, $5/9$ |
| 4 | $\pm0.3399810435848563$, $\pm0.8611363115940526$ | 0.6521451548625461, 0.3478548451374538 |
| $n>4$ | roots of the Legendre polynomial $P_n$ (Newton iteration, tolerance $10^{-15}$) | $w=\dfrac{2}{(1-\xi^2)\,[P_n'(\xi)]^2}$ |

## Taylor terms

Table: Number of terms of the Taylor expansion of order $N$. {#tab:te-terms}

| $N$ | beam (section, 2D) | plate (thickness, 1D) |
|---|---|---|
| 0 | 1 | 1 |
| 1 | 3 | 2 |
| 2 | 6 | 3 |
| 3 | 10 | 4 |
| 4 | 15 | 5 |
| 5 | 21 | 6 |
| 8 | 45 | 9 |
| 10 | 66 | 11 |
| 15 | 136 | 16 |

## Voigt order and engineering strains

Table: Voigt convention used everywhere (index, name, meaning). {#tab:voigt}

| Index | Strain | Stress | Component |
|---|---|---|---|
| 1 | $\varepsilon_{xx}$ | $\sigma_{xx}$ | normal along $x$ |
| 2 | $\varepsilon_{yy}$ | $\sigma_{yy}$ | normal along $y$ (beam axis) |
| 3 | $\varepsilon_{zz}$ | $\sigma_{zz}$ | normal along $z$ |
| 4 | $\gamma_{xz}$ | $\sigma_{xz}$ | shear $xz$ |
| 5 | $\gamma_{yz}$ | $\sigma_{yz}$ | shear $yz$ |
| 6 | $\gamma_{xy}$ | $\sigma_{xy}$ | shear $xy$ |

## Glossary

Table: Terms used in the guides. {#tab:glossary}

| Term | Meaning |
|---|---|
| CUF | Carrera Unified Formulation |
| TE / LE / HLE | Taylor / Lagrange / Hierarchical-Legendre expansion |
| Expansion mesh | finite element mesh of the section (beam) or thickness (plate) that carries the Lagrange functions and defines the integration sub-domains |
| Sub-element | one element of an expansion mesh |
| Structural mesh | the 1D, 2D or 3D mesh along the length (beam), surface (plate) or in space (solid) |
| Versor | reference vector that fixes the rotation of the element frame about the beam axis or in the plate plane |
| Lamination | pair (material, two orientation angles) attached to a sub-element |
| Gauss point (combined) | pair (structural point $p$, expansion point $q$) |
| Nucleus | integral of the pair of basis functions of two DOFs; see Chapter {sec:nucleus} |
| DOF | degree of freedom |
| MITC | mixed interpolation of tensorial components (assumed strain) |
| CSR | compressed sparse row storage |
| SPD | symmetric positive definite |
| ARPACK | library for large eigenvalue problems (implicitly restarted Lanczos) |
| PARDISO | direct sparse solver of the oneMKL |
| Baseline | the frozen reference program (MUL2_OPTIMIZED) used to validate this code |

## References

1. E. Carrera, M. Cinefra, M. Petrolo, E. Zappino, *Finite Element Analysis of Structures through Unified Formulation*, Wiley, 2014.
2. E. Carrera, G. Giunta, "Refined beam theories based on a unified formulation", *International Journal of Applied Mechanics* 2(1), 117–143, 2010.
3. E. Carrera, G. Giunta, M. Petrolo, *Beam Structures: Classical and Advanced Theories*, Wiley, 2011.
4. K. J. Bathe, E. N. Dvorkin, "A four-node plate bending element based on Mindlin/Reissner plate theory and a mixed interpolation", *International Journal for Numerical Methods in Engineering* 21, 367–383, 1985.
5. K. J. Bathe, *Finite Element Procedures*, Prentice Hall, 1996.
6. O. C. Zienkiewicz, R. L. Taylor, *The Finite Element Method*, Butterworth-Heinemann (any edition).
7. A. Pagani, A. G. de Miguel, E. Carrera, "Cross-sectional mapping for refined beam elements with applications to shell-like structures", *Computational Mechanics*, 2017.
8. R. B. Lehoucq, D. C. Sorensen, C. Yang, *ARPACK Users' Guide: Solution of Large-Scale Eigenvalue Problems with Implicitly Restarted Arnoldi Methods*, SIAM, 1998.
9. O. Schenk, K. Gärtner, "Solving unsymmetric sparse systems of linear equations with PARDISO", *Future Generation Computer Systems* 20, 475–487, 2004.
10. Intel oneAPI Math Kernel Library, *Developer Reference* (PARDISO, LAPACK).
