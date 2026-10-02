# The element library {#sec:elements}

MUL2_NEW offers fourteen structural topologies plus a one-node "point" element used as the degenerate expansion of solids. The same topologies are used for the *expansion meshes* (sections and thicknesses) that carry the Lagrange expansion.

Table: Element topologies. {#tab:topologies}

| Name | Nodes | Natural dim. | Role | Shape functions | Default Gauss rule | MITC |
|---|---|---|---|---|---|---|
| B2 | 2 | 1 | beam | linear Lagrange | 2 | yes |
| B3 | 3 | 1 | beam | quadratic Lagrange | 3 | yes |
| B4 | 4 | 1 | beam | cubic Lagrange | 4 | yes |
| Q4 | 4 | 2 | plate / section | bilinear | 2×2 | yes |
| Q9 | 9 | 2 | plate / section | biquadratic | 3×3 | yes |
| Q16 | 16 | 2 | plate / section | bicubic | 4×4 | no |
| T3 (Q3) | 3 | 2 | plate / section | linear triangle | 1 point | no |
| T6 (Q6) | 6 | 2 | plate / section | quadratic triangle | 3 points | no |
| H8 | 8 | 3 | solid | trilinear | 2×2×2 | yes |
| H20 | 20 | 3 | solid | serendipity (geometry only) | 3×3×3 | yes |
| H27 | 27 | 3 | solid | triquadratic | 3×3×3 | yes |
| T4, T10, P6 | 4, 10, 6 | 3 | solid | tetra / prism | — | no |
| S1 | 1 | 0 | expansion of solids | constant | 1 | — |

> NOTE: Shape functions of H20, T4, T10 and P6 are listed in the input syntax and the topology registry but are not yet implemented in the shape-function module of the current release; selecting them gives an explicit error. Q3/Q6 are accepted as aliases of T3/T6.

## Node numbering

The order of the nodes in the input record is the order of the shape functions. It must follow the conventions below; a different order produces a distorted or inverted element.

![Beam elements: nodes are numbered along the axis.](figures/elements_1d.svg){#fig:el-1d}

![Quadrilaterals: corners and mid-side nodes alternate counter-clockwise, interior nodes last.](figures/elements_2d.svg){#fig:el-2d}

![Triangles.](figures/elements_tri.svg){#fig:el-tri}

![Hexahedra.](figures/elements_3d.svg){#fig:el-3d}

## One-dimensional Lagrange functions

The line elements use equally spaced nodes on $[-1,1]$. For order $m$ (number of nodes $m+1$) the function of node $a$ is

$$
\ell^{m}_{a}(\xi)=\prod_{b\ne a}\frac{\xi-\xi_b}{\xi_a-\xi_b},\qquad
\xi_b=-1+\frac{2(b-1)}{m}.
$$ {#eq:lagrange}

Quadrilaterals and hexahedra are tensor products: for the biquadratic quadrilateral (Q9) node 7, for instance, sits at $(\xi_1,\xi_3)$ of the $3\times3$ grid and $N_7=\ell^2_1(\xi)\,\ell^2_3(\eta)$. The nodal order is given by the integer tables (`IX`, `IY`, `IZ`) in the shape-function module and follows Figure {fig:el-2d}.

The triangles use area coordinates $L_1=1-\xi-\eta$, $L_2=\xi$, $L_3=\eta$:

$$
\text{T3: } N_a=L_a,\qquad
\text{T6: } N_{1,2,3}=L_a(2L_a-1),\; N_4=4L_1L_2,\;N_5=4L_2L_3,\;N_6=4L_3L_1 .
$$

## Geometry in the local frame

Each structural element gets a **right-handed local frame** $(x,y,z)$ built from its node coordinates and a user-supplied reference vector (Chapter {sec:frames}). The geometric map and its Jacobian are evaluated **in that frame and only along the directions spanned by the element**:

- beam: one coordinate $y$ (the axis); $\mathbf{J}=[\partial y/\partial\xi]$ is a scalar;
- plate: two coordinates $(x,y)$ in the mid-surface; $\mathbf{J}$ is $2\times2$;
- solid: three coordinates; $\mathbf{J}$ is $3\times3$.

The gradient of a structural shape function is stored as a 3-vector in the local frame with zero components along the axes the element does not span. This is the object that enters the strain operator in Chapter {sec:cuf-strain}.

The *section* (beam) or *thickness* (plate) is **not** part of the structural Jacobian: it has its own Jacobian, computed from the expansion mesh nodes (Chapter {sec:cuf}). The total volume element is the product

$$
d\Omega=\det\mathbf{J}_{s}\;\det\mathbf{J}_{e}\;d\boldsymbol{\xi}_{s}\,d\boldsymbol{\xi}_{e},
$$ {#eq:volume}

where $s$ stands for the structural and $e$ for the expansion factor. This product structure is what the *separable kernel* of Chapter {sec:nucleus} exploits.
