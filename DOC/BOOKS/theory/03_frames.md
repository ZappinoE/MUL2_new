# Reference systems {#sec:frames}

Every computation in the program is done in a well defined **local frame** of each element; the results are then rotated to the global frame on request. Mixing up frames is the most common source of wrong models, so this chapter is precise about them.

## The three frames

1. **Global frame** $(X,Y,Z)$: the frame of the node coordinates, of the loads, of the constraints and (by default) of the output.
2. **Element frame** $(x,y,z)$: right-handed, built for every element from its geometry and a reference vector (the *versor*). Strains, stresses and the constitutive matrix are evaluated in this frame.
3. **Material frame** $(T,L,Z)$: the principal axes of the material (fibre direction $L$, transverse $T$, thickness $Z$). It is related to the element frame by two angles per lamination.

The sequence of transformations is

$$
\text{material}\;\xrightarrow{\ \text{LAMINATION angles}\ }\;\text{element}\;\xrightarrow{\ \text{VERSORS + geometry}\ }\;\text{global}.
$$

## Element frame

Let $\mathbf{R}\in\mathbb{R}^{3\times3}$ be the matrix whose *rows* are the local axes expressed in global components. A vector with global components $\mathbf{a}$ has local components $\mathbf{a}_{loc}=\mathbf{R}\mathbf{a}$, and conversely $\mathbf{a}=\mathbf{R}^T\mathbf{a}_{loc}$. (In the code `GLOBAL_TO_LOCAL` is $\mathbf{R}$ and `LOCAL_TO_GLOBAL` its transpose.)

### Solids

For three-dimensional elements the element frame is the global frame: $\mathbf{R}=\mathbf{I}$. The versor in the connectivity record is ignored.

### Beams

![Beam frame: y along the axis, z from the versor.](figures/frames_beam.svg){#fig:fr-beam}

With $\mathbf{p}_1$ the first and $\mathbf{p}_e$ the last node of the element ($e=2,3,4$ for B2, B3, B4) and $\mathbf{v}$ the versor,

$$
\mathbf{e}_y=\frac{\mathbf{p}_e-\mathbf{p}_1}{\|\mathbf{p}_e-\mathbf{p}_1\|},\qquad
\mathbf{e}_z=\frac{\mathbf{v}-(\mathbf{v}\cdot\mathbf{e}_y)\,\mathbf{e}_y}{\|\cdot\|},\qquad
\mathbf{e}_x=\mathbf{e}_y\times\mathbf{e}_z .
$$ {#eq:frame-beam}

So the **beam axis is the local $y$**, the versor chooses the direction of the local $z$ (up to its component along the axis, which is removed) and $x$ completes the right-handed triad. The section coordinates of the expansion mesh are measured on $x$ and $z$; the node of the expansion mesh with coordinates $(x_s,0,z_s)$ is physically located at

$$
\mathbf{X}=\mathbf{X}_{node}+\mathbf{R}^T\,(x_s,0,z_s)^T .
$$ {#eq:expanded-point}

> NOTE: If the versor is parallel to the beam axis the element frame is not defined and the program stops with the error `SOR IS PARALLEL TO BEAM AXIS`.

**Example.** A beam along the global $Y$ axis with versor $(0,0,1)$ has $\mathbf{e}_y=(0,1,0)$, $\mathbf{e}_z=(0,0,1)$ and $\mathbf{e}_x=\mathbf{e}_y\times\mathbf{e}_z=(1,0,0)$: local and global axes coincide. A beam along $X$ with versor $(0,0,1)$ has $\mathbf{e}_y=(1,0,0)$, $\mathbf{e}_z=(0,0,1)$, $\mathbf{e}_x=(0,-1,0)$.

### Plates

![Plate frame: z normal to the surface.](figures/frames_plate.svg){#fig:fr-plate}

With $\mathbf{p}_1$ the first node, $\mathbf{p}_2$ and $\mathbf{p}_3$ two further corners (for Q4 nodes 2 and 4, for Q9 nodes 3 and 7, for Q16 nodes 4 and 10, for triangles nodes 2 and 3),

$$
\mathbf{e}_z=\frac{(\mathbf{p}_2-\mathbf{p}_1)\times(\mathbf{p}_3-\mathbf{p}_1)}{\|\cdot\|},\qquad
\mathbf{e}_x=\frac{\mathbf{v}-(\mathbf{v}\cdot\mathbf{e}_z)\mathbf{e}_z}{\|\cdot\|},\qquad
\mathbf{e}_y=\mathbf{e}_z\times\mathbf{e}_x .
$$ {#eq:frame-plate}

The **plate normal is the local $z$** and the thickness expansion lives along it. The versor selects the local $x$ direction as its projection on the plate. The ordering of the nodes therefore decides which side is "up".

> WARNING: A plate element whose three corner nodes are collinear, or a versor perpendicular to the surface, gives the errors `DEGENERATE SURFACE` or `SOR IS NORMAL TO SURFACE`.

## Material frame and lamination angles

The lamination record gives two angles $\theta_y,\theta_z$ (degrees). The rotation that transforms *element-frame components into material-frame components* is

$$
\mathbf{A}=\mathbf{R}_z(\theta_z)\,\mathbf{R}_y(\theta_y),\qquad
\mathbf{R}_y=\begin{bmatrix}\cos\theta_y&0&\sin\theta_y\\0&1&0\\-\sin\theta_y&0&\cos\theta_y\end{bmatrix},\quad
\mathbf{R}_z=\begin{bmatrix}\cos\theta_z&\sin\theta_z&0\\-\sin\theta_z&\cos\theta_z&0\\0&0&1\end{bmatrix}.
$$ {#eq:material-rotation}

![Material axes of a lamina rotated by theta_z about the element z axis.](figures/material_frame.svg){#fig:mat-frame}

With $\theta_y=\theta_z=0$ the material axes coincide with the element axes: **$T\equiv x$, $L\equiv y$, $Z\equiv z$**. For a unidirectional composite beam with fibres along its axis, $L$ is the axis (local $y$) and the angles are zero. For a ply of a laminated plate whose fibres lie at $45^\circ$ to the local $x$ direction, $\theta_z=45^\circ$ (about the plate normal $z$).

## Transformation of strains and stresses

Because the shear strains are engineering shears, strain and stress transform with *different* $6\times6$ matrices. With the Voigt order $(xx,yy,zz,xz,yz,xy)$, for a rotation $\mathbf{A}$ ($a_{ij}$ its entries) the strain transformation $\mathbf{T}_\varepsilon$ is

$$
\mathbf{T}_{\varepsilon}=
\begin{bmatrix}
a_{11}^2&a_{12}^2&a_{13}^2&a_{13}a_{11}&a_{12}a_{13}&a_{12}a_{11}\\
a_{21}^2&a_{22}^2&a_{23}^2&a_{23}a_{21}&a_{23}a_{22}&a_{22}a_{21}\\
a_{31}^2&a_{32}^2&a_{33}^2&a_{33}a_{31}&a_{33}a_{32}&a_{32}a_{31}\\
2a_{31}a_{11}&2a_{32}a_{12}&2a_{33}a_{13}&a_{33}a_{11}+a_{31}a_{13}&a_{33}a_{12}+a_{32}a_{13}&a_{31}a_{12}+a_{32}a_{11}\\
2a_{31}a_{21}&2a_{32}a_{22}&2a_{33}a_{23}&a_{33}a_{21}+a_{31}a_{23}&a_{33}a_{22}+a_{32}a_{23}&a_{31}a_{22}+a_{32}a_{21}\\
2a_{21}a_{11}&2a_{12}a_{22}&2a_{13}a_{23}&a_{13}a_{21}+a_{11}a_{23}&a_{13}a_{22}+a_{12}a_{23}&a_{11}a_{22}+a_{12}a_{21}
\end{bmatrix}
$$ {#eq:teps}

so that $\boldsymbol{\varepsilon}_{mat}=\mathbf{T}_\varepsilon\boldsymbol{\varepsilon}_{el}$. The stiffness in the element frame follows from invariance of the strain energy:

$$
\mathbf{C}_{el}=\mathbf{T}_\varepsilon^{T}\,\mathbf{C}_{mat}\,\mathbf{T}_\varepsilon .
$$ {#eq:crot}

The inverse transformations are used for the output: strains and stresses are computed in the element frame and converted to global components on request (`GLB`) or kept in the element frame (`LOC`). The *stress* transformation $\mathbf{T}_\sigma$ is the transpose-inverse pattern of $\mathbf{T}_\varepsilon$; since the frames are orthogonal, $\mathbf{T}_\varepsilon^{-T}=\mathbf{T}_\sigma$.

## Displacement components

The displacement unknowns $u_{k\tau i}$, $k=1,2,3$ are the components of the displacement **in the global frame**. The strain operator is, however, written in the local frame, so the strain column of a global component $k$ uses the local components of the global unit vector $\mathbf{e}_k$:

$$
\mathbf{b}_{k\,i\tau}=\mathbf{B}(\nabla_{loc}\phi_{i\tau})\;\big(\mathbf{R}\,\mathbf{e}_k\big),
$$ {#eq:bcol-frame}

where $\mathbf{R}\mathbf{e}_k$ is the $k$-th column of $\mathbf{R}$. This is why loads, constraints and the displacements in the output are all in the global frame regardless of how the element frames are oriented.
