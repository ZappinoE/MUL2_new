# Constitutive models

## The stiffness matrix

All materials are linear elastic. The stress–strain relation is {eq:hooke} with a $6\times6$ symmetric positive-definite matrix $\mathbf{C}$ expressed in the **material axes** $(T,L,Z)$ and in the Voigt order $(TT,LL,ZZ,TZ,LZ,TL)$, which coincides with $(xx,yy,zz,xz,yz,xy)$ when the material axes coincide with the element axes.

## Isotropic material (`ISO-M`)

With Young's modulus $E$, Poisson's ratio $\nu$ and the Lamé constants

$$
\lambda=\frac{E\nu}{(1+\nu)(1-2\nu)},\qquad G=\frac{E}{2(1+\nu)},
$$

the matrix is

$$
\mathbf{C}=
\begin{bmatrix}
\lambda+2G&\lambda&\lambda&&&\\
\lambda&\lambda+2G&\lambda&&&\\
\lambda&\lambda&\lambda+2G&&&\\
&&&G&&\\&&&&G&\\&&&&&G
\end{bmatrix}.
$$ {#eq:iso}

The program requires $E>0$, $-1<\nu<0.5$ and $\rho\ge0$.

## Orthotropic material (`ORT-M`)

An orthotropic material has three orthogonal symmetry planes. It is defined by nine engineering constants in the input order

$$
E_L,\;E_T,\;E_Z,\;\nu_{LT},\;\nu_{LZ},\;\nu_{TZ},\;G_{LT},\;G_{LZ},\;G_{TZ},\;\rho .
$$

Internally the axes are ordered $(T,L,Z)=(1,2,3)$ and the normal part of the compliance matrix is

$$
\mathbf{S}_n=\begin{bmatrix}
1/E_T&-\nu_{LT}/E_L&-\nu_{TZ}/E_T\\
-\nu_{LT}/E_L&1/E_L&-\nu_{LZ}/E_L\\
-\nu_{TZ}/E_T&-\nu_{LZ}/E_L&1/E_Z
\end{bmatrix},\qquad
\mathbf{C}_n=\mathbf{S}_n^{-1},
$$ {#eq:ort}

while the shear part is diagonal with $C_{44}=G_{TZ}$, $C_{55}=G_{LZ}$, $C_{66}=G_{LT}$. The program checks that the compliance is positive and non-singular.

> NOTE: The definition of the Poisson ratios follows the convention $\nu_{LT}=-\varepsilon_T/\varepsilon_L$ in a uniaxial test along $L$. A unidirectional carbon/epoxy lamina with fibres along $L$ typically has $E_L\approx140$ GPa, $E_T=E_Z\approx10$ GPa, $\nu_{LT}\approx0.3$, $G_{LT}\approx5$ GPa.

## General anisotropic material (`MAT-C`)

The user can supply the 36 entries of $\mathbf{C}$ in the material axes (row by row) followed by the density. The reader checks symmetry and keeps the data even if it is not symmetric; the assembled matrices are symmetric only if $\mathbf{C}$ is, and the symmetric solvers require it.

## Orientation: from the material to the element frame

Each lamination refers to one material and rotates it with the angles of Chapter {sec:frames}. The stiffness in the element frame is $\mathbf{C}_{el}=\mathbf{T}_\varepsilon^T\mathbf{C}_{mat}\mathbf{T}_\varepsilon$, equation {eq:crot}. This matrix is computed **once per lamination** and cached; every Gauss point of a sub-element that uses the lamination reads the same $6\times6$ block.

A **laminate** is obtained by giving each sub-element of the expansion mesh its own lamination (and hence material and angle). Because the lamination is attached to the *sub-element of the expansion mesh*, it is constant inside the sub-element and may change from one sub-element to the next, which is exactly the situation the *separable kernel* of Chapter {sec:nucleus} requires.

## Density and the mass matrix

The density of the material of the lamination enters the consistent mass matrix {eq:km}. In an orthotropic material the density is a scalar: no direction dependence.

## Quantities not used in 101/103

Thermal expansion (`T-EXP`), specific heat (`T-SPC`), conductivity (`T-CON`), viscosity (`VISCO`), piezoelectric, magnetic, hygroscopic and damping records of the historical material file are *recognised and ignored* by this release (a warning states that non-mechanical data were preserved). They remain in the file format so that the same input files can be used by the full program.
