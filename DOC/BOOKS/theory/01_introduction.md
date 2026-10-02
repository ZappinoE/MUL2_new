# Introduction and scope

## What this guide is for

This guide explains the **theory** behind MUL2_NEW, a finite-element program for the linear analysis of beams, plates, shells-as-plates and solids written with the *Carrera Unified Formulation* (CUF). It is written for a student or a new developer who knows basic mechanics of solids and has seen the finite element method once, and who wants to understand *what the program computes and why*, before looking at *how it is coded* (the Implementation Guide) or *how it is used* (the User Guide).

The three guides are meant to be read together:

| Guide | Question it answers | Typical reader |
|---|---|---|
| Theoretical Guide (this one) | What equations are solved? Which approximations are made? | Anyone who wants to trust or extend the results |
| Implementation Guide | How are those equations coded? Where is each formula? | Developers |
| User Guide | How do I describe a structure and run it? | Analysts and students |

## What the program does

MUL2_NEW solves two problems for linear elastic structures:

- **Analysis 101 – linear static analysis.** Given a structure, supports and point loads, find the displacement field $\mathbf{u}$ that satisfies equilibrium, and recover strains and stresses.
- **Analysis 103 – linear free vibration.** Find the natural frequencies $f_k$ and the mode shapes $\boldsymbol{\phi}_k$ of the unloaded, supported structure.

Both are *mechanical* problems: only the three displacement fields $u$, $v$, $w$ are unknowns. (The unified formulation has room for temperature, electric potential, humidity and mixed stress fields, and the input syntax already contains the corresponding columns; they are not active in 101/103.)

The distinguishing feature of CUF is that **beam, plate and solid models are produced by the same code**. A structure is described by

1. a *structural mesh* – one-dimensional (beam), two-dimensional (plate) or three-dimensional (solid) finite elements; and
2. an *expansion over the remaining dimensions* – for a beam the cross-section, for a plate the thickness – chosen freely: a polynomial (Taylor, TE) or a finite-element mesh of the section (Lagrange, LE).

Changing the expansion changes the kinematic theory (from an Euler–Bernoulli-like beam to a three-dimensional-quality solution) *without changing a line of code*. This is why a few thousand lines of Fortran cover a very wide family of models.

![Beam as a one-dimensional structural mesh whose nodes carry a section expansion.](figures/cuf_concept.svg){#fig:cuf-concept}

## Notation

Vectors and matrices are written in bold, scalars in italic. Indices $i, j$ number structural nodes, $\tau, s$ number expansion terms, $p$ a structural Gauss point and $q$ an expansion Gauss point. The conventions used throughout (and in the code) are:

Table: Notation used in the three guides. {#tab:notation}

| Symbol | Meaning | Code name |
|---|---|---|
| $x, y, z$ | local element coordinates; for a beam $y$ is the axis and $x$–$z$ the section; for a plate $x$–$y$ is the mid-surface and $z$ the thickness | `LOCAL` frame |
| $\mathbf{u}=(u,v,w)$ | displacement | `SOLUTION` |
| $\boldsymbol{\varepsilon}$ | strain $[\varepsilon_{xx},\varepsilon_{yy},\varepsilon_{zz},\gamma_{xz},\gamma_{yz},\gamma_{xy}]^T$ (engineering shear strains) | `STRAIN_*` |
| $\boldsymbol{\sigma}$ | stress $[\sigma_{xx},\sigma_{yy},\sigma_{zz},\sigma_{xz},\sigma_{yz},\sigma_{xy}]^T$ | `STRESS_*` |
| $\mathbf{C}$ | $6\times 6$ stiffness (elasticity) matrix | `STIFFNESS_LOCAL` |
| $N_i(\xi)$ | structural shape function of node $i$ | `SHAPE` |
| $F_\tau(x,z)$ | expansion function number $\tau$ | `EPS`, `FACTOR_VALUE` |
| $\mathbf{K}, \mathbf{M}$ | global stiffness and mass matrices | `STIFFNESS`, `MASS` |
| $\xi,\eta,\nu$ | natural coordinates of an element | `NATURAL` |
| $\mathbf{J}$ | Jacobian of the isoparametric map | `JACOBIAN` |

> NOTE: The engineering-shear convention matters. The shear strains $\gamma_{xz},\gamma_{yz},\gamma_{xy}$ are *twice* the tensor components. Stress and strain therefore transform differently under rotation (Chapter {sec:frames}), and the constitutive matrix couples them without extra factors of two.

## Structure of the guide

Chapter 2 recalls the continuum mechanics and the finite element ideas that are needed. Chapter 3 introduces the element library. Chapters 4 to 6 develop the unified formulation, the reference systems and the constitutive models. Chapter 7 derives the element matrices, including the *separable* form that makes high-order expansions affordable. Chapter 8 treats shear locking, Chapter 9 loads and constraints, Chapters 10 and 11 the solution of the static and eigenvalue problems, Chapter 12 the recovery of strains and stresses and Chapter 13 the verification of the program. Appendices collect numerical tables and references.
