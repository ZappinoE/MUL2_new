# Multiphysics: piezoelectric and thermal problems {#sec:multiphysics}

MUL2_NEW solves, with the same elements, expansions and analyses, the fields that the historical code called *T* (temperature) and *P* (electric potential), together with the displacements. No new analysis type is needed: the physics that are solved are chosen in `ANALYSIS.dat` (record `FIELDS`, below); `KINEMATICS.dat` only defines **how each field is expanded**.

## Choosing the physics

## Choosing the physics: the `FIELDS` record

The last, optional record of `ANALYSIS.dat` lists the physics that are solved:

```
FIELDS MECH PIEZO
```

| Token | Field |
|---|---|
| `MECH` | displacements $u,v,w$ (always required) |
| `THERMO` | temperature $T$ |
| `PIEZO` | electric potential $P$ |
| `STRESS` | transverse stresses of the mixed principle (RMVT): **reserved**, an error for now |

A field that is not listed is not solved, even if `KINEMATICS.dat` gives it an expansion: the same input switches the physics on and off by changing one line. A field that is listed must be expanded in at least one kinematics (otherwise the run stops with an explicit message). **Without the record** every field expanded in `KINEMATICS.dat` is solved, as before. A boundary condition on a field that is switched off (for instance a voltage with `FIELDS MECH`) has no effect.

The principle of the element (displacement-based, PLV, today) is not an analysis option: the mixed Reissner principle (RMVT) will be selected element by element with a label in `CONNECTIVITY.dat`, and an RMVT element will bring its own stress fields (`STRESS`).

`KINEMATICS.dat` has nine expansion tokens per record, in the order $u,\ v,\ w,\ T,\ P,\ B,\ \sigma_{zz},\ \sigma_{xz},\ \sigma_{yz}$. A field with `NONE` is not solved.

```text
1

KINEMATIC 1   LE LE LE  NONE LE   NONE NONE NONE NONE     ! piezoelectric
KINEMATIC 2   LE LE LE  LE NONE   NONE NONE NONE NONE     ! thermoelastic
KINEMATIC 3   LE LE LE  LE LE     NONE NONE NONE NONE     ! thermo-piezo
```

Temperature and potential accept the Lagrange (`LE`), hierarchical (`HLE`) and Taylor (`TE`) expansions like the displacements. The nodes of a model may mix them. The temperature is a **change** with respect to the stress-free reference state.

| Active fields | Problem | 101 | 103 | 104 | 105 | 106 | 108 |
|---|---|---|---|---|---|---|---|
| $u,v,w$ | structural | yes | yes | yes | yes | yes | yes |
| $+P$ | piezoelectric | yes | yes (SC/OC) | yes | yes (condensed) | yes | yes |
| $+T$ | thermoelastic | yes (monolithic) | no | yes (transient) | yes (pre-stress) | yes | yes |
| $+T+P$ | pyro/thermo-piezo | yes | no | yes | yes | yes | yes |

## Materials

All the records are in `MATERIAL.dat`; the header is `number_of_materials number_of_records` and every record refers to a material by its identifier. The records of the same material may appear in any order.

| Record | Values | Meaning |
|---|---|---|
| `Z-EXP id` | 18 | piezoelectric stress coefficients $e$ [C/m$^2$], 3 rows (electric direction $T,L,Z$) by 6 columns (Voigt $xx,yy,zz,xz,yz,xy$ of the material axes) |
| `Z-PRM id` | 9 | permittivity [F/m] at constant strain, row by row |
| `T-EXP id` | 6 or 1 | thermal expansion [1/K]: $\alpha_{TT},\alpha_{LL},\alpha_{ZZ},\alpha_{TZ},\alpha_{LZ},\alpha_{TL}$, or a single isotropic value |
| `T-CON id` | 9 or 1 | heat conductivity [W/(m K)], row by row, or a single isotropic value |
| `T-SPC id` | 1 | specific heat [J/(kg K)]; the heat capacity is $\rho c$ (needed by 104 and 106) |
| `PIROE id` | 3 | pyroelectric coefficient [C/(m$^2$ K)] **at zero stress** |
| `DAMP` | 2 | Rayleigh damping, `DAMP k_K k_M`: $C = k_M M + k_K K$ (no identifier) |

Example of a piezoelectric ceramic polarised along $Z$ (PZT-5H like):

```text
1 3

MAT-C 1   127.2D9 80.2D9 84.7D9 0 0 0   80.2D9 127.2D9 84.7D9 0 0 0   ...  7500.0
Z-EXP 1   0 0 0 0 17.03 0   0 0 0 17.03 0 0   -6.62 -6.62 23.24 0 0 0
Z-PRM 1   1.503D-8 0 0   0 1.503D-8 0   0 0 1.300D-8
```

The material axes follow the lamination angles like the stiffness: the coefficients are rotated into the element frame (tensors $e$, $\varepsilon$, $\alpha$, $k$ and the vector $p$).

**Pyroelectricity.** `PIROE` is the coefficient measured on a free body ($D = pT$ with $E=0$ and no stress). The code subtracts the part that comes from the thermal expansion, $p_\varepsilon = p_\sigma - e\,\alpha$, so that the input is the quantity found in the data sheets.

## Boundary conditions

All the planes are $a x + b y + c z + d = 0$, as in `D-PLANE`. A record with a plane that contains the whole section (or the whole model) acts on all the expansion nodes of the plane.

| Record | Effect |
|---|---|
| `V-PLANE id a b c d V` | electric potential $V$ [V] on a plane (electrode) |
| `V-POINT id x y z V` | potential at a section node |
| `V-FLOAT id a b c d` | floating electrode: all the potential degrees of freedom of the plane are tied to one unknown value (open circuit, sensor). Supported by 101 and 103 |
| `F-POINT id x y z fx fy fz [Q]` | the optional last value is an electric charge |
| `T-PLANE id a b c d T` | temperature on a plane |
| `T-POINT id x y z T` | temperature at a section node |
| `T-CONST id T` | uniform temperature everywhere (thermal load without conduction) |
| `Q-POINT id x y z P` | heat power [W] at a section node |
| `Q-PLANE id a b c d q` | heat flux $q$ [W/m$^2$] *into* the exposed surface of a plane |
| `Q-SUN id sx sy sz G a` | solar load on the whole exposed skin: $q = a\,G\,\max(0,\ \mathbf n\cdot\mathbf s)$; $\mathbf s$ points towards the sun, $G$ [W/m$^2$] irradiance, $a$ absorptivity |
| `Q-CONV id a b c d h Tinf` | convection $q = h (T_\infty - T)$ on the exposed surface of a plane; the plane `0 0 0 0` means all the skin |

Every value record (`D-PLANE`, `V-PLANE`, `V-POINT`, `T-PLANE`, `T-POINT`, `T-CONST`, `Q-PLANE`) may end with the number of a **field** of `FIELDS.dat` (next section): the value is multiplied by the field at the position of every node (or integration point).

**The exposed skin.** Surface loads act on the surfaces that are not shared with another element: the lateral surface and the ends of a beam, top, bottom and sides of a plate, the faces of a solid. The outward normal points away from the element. The sun does not cast shadows: every exposed face with $\mathbf n\cdot\mathbf s>0$ is lit. There is no radiation to the environment (use `Q-CONV`).

With only `Q-SUN` and `Q-CONV` a steady solution exists without any prescribed temperature: the convection makes the conduction matrix definite. The console log reports for every surface load the area it selected and the power it applies.

## Fields (FIELDS.dat)

A field is a function $F(x,y,z)$ written as a sum of terms. The optional file has the number of fields, then, for every field, a header and one line per term.

```text
2

FIELD 1 1
Y-EXP 1.0D0 1.0D0                    ! F = y

FIELD 2 2
CONST 1.0D0
SIN-X 0.5D0 6.2832D0 0.0D0           ! F = 1 + 0.5 sin(2 pi x)
```

| Term | Constants | Value |
|---|---|---|
| `CONST` | $c_1$ | $c_1$ |
| `X-EXP`, `Y-EXP`, `Z-EXP` | $c_1\ c_2$ | $c_1 x^{c_2}$ (idem $y$, $z$) |
| `COS-X`, `COS-Y`, `COS-Z` | $c_1\ c_2\ c_3$ | $c_1\cos(c_2 x + c_3)$ |
| `SIN-X`, `SIN-Y`, `SIN-Z` | $c_1\ c_2\ c_3$ | $c_1\sin(c_2 x + c_3)$ |
| `ATNZX` | $c_1\ c_2\ c_3$ | $c_1\,\mathrm{atan2}(z-c_2, x-c_3)$ in degrees |
| `B-SIN` | $c_1\dots c_5$ | $c_1\sin(c_2\pi x/c_3)\sin(c_4\pi y/c_5)$ |

A traveling-wave or sinusoidal voltage distribution on an electrode, a temperature gradient or a spatially varying heat flux are examples. A reference to a missing field is read as 1.

## Results

- `STATIC/POST_POINT.dat`: the column `DT` is the temperature, `VOLT` the potential, `E11..D33` the electric field and displacement, and three more columns at the end give the heat flux $\mathbf q=-k\nabla T$ (global frame).
- The VTK files hold `TEMPERATURE_[C]`, `VOLTAGE[V]`, the electric displacement, `EX/EY/EZ` and the vector `HeatFlux`.
- The stresses are the mechanical ones, $\sigma = C(\varepsilon-\alpha T)+\dots$: the thermal strain is not part of the stress.

## Checks you can repeat

| Test | Closed form | Error |
|---|---|---|
| free piezoelectric slab, 100 V | $u_z = d_{33}V$, $E=-V/t$ | $< 10^{-6}$ |
| thickness resonance, short / open circuit | piezoelectric stiffening $c+e^2/\varepsilon$ | $0.03$ % (OC) |
| bar with a uniform temperature rise | $u=\alpha\,\Delta T\,L$, no stress; clamped: $\sigma=-E\alpha\Delta T$ | $10^{-9}$ |
| conduction between two temperatures | linear profile, $q=-k\Delta T/L$ | exact |
| heat power at the end of a bar | $T = Q L/(kA)$ | $10^{-9}$ |
| convection in series with conduction | $T_L = h T_\infty/(k/L+h)$ | $10^{-9}$ |
| pyroelectric slab | closed circuit $D=pT$; open circuit $V = pTt/\varepsilon^T$ | $5\cdot10^{-7}$ |

The scripts are in `TESTS/PIEZO`, `TESTS/THERMAL` and `TESTS/DYNAMICS`.

## Limits

The floating electrode (`V-FLOAT`) works in 101 and 103 only. The temperature is not solved by 103 (modal analysis: use 106 for the dynamic behaviour of a thermo-mechanical model). `Q-SUN` has no shadowing and no emission. `FIELDS.dat` is not used for laminate angles, point forces or `F-PRESS`.
