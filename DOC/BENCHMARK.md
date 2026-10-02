# MUL2_NEW – Benchmark against the baseline (≈100 000 DOF)

Baseline = frozen `MUL2/MUL2_OPTIMIZED` (`MUL2.exe`). New = `MUL2_V3.exe`
(Release, MKL sequential, OpenMP 16 cores / 22 logical). Machine: Windows 11,
31 GB RAM. One run per entry, wall time, peak working set. Scripts and inputs:
`TESTS/BENCH/` (`bench.ps1 -Exe <exe> -Case <dir> -RunDir <dir>`).

## Cases

| Case | Model | DOF |
|------|-------|-----|
| `beam_te15_100k` | 82 B4 elements, Taylor order **15** (408 DOF/node), unit section, tip load | 100 776 |
| `beam_le_100k` | 136 B4 elements, Lagrange section of 16 Q9 sub-elements (243 DOF/node) | 99 387 |
| `*_modal` | same models, analysis 103, 6 modes, clamped root | same |

## Results

| Case | Analysis | Baseline | MUL2_NEW |
|------|----------|----------|----------|
| TE15, 100 776 DOF | 101 static | 82.9 s, 12.9 GB | **26.4 s, 7.8 GB** |
| TE15, 100 776 DOF | 103, 6 modes | 183.7 s, 13.5 GB | **80.3 s, 13.9 GB** |
| LE 16×Q9, 99 387 DOF | 101 static | 14.1 s, 4.1 GB | **6.4 s, 1.4 GB** |
| LE 16×Q9, 99 387 DOF | 103, 6 modes | 28.1 s, 4.2 GB | **14.8 s, 1.6 GB** |

Accuracy: tip displacement of the TE15 beam agrees with the baseline to 1e-8
(0.03998167279 m vs 0.03998167278 m); modal frequencies agree to 3e-7 (the
baseline enforces constraints with a penalty, MUL2_NEW exactly). The LE matrix
has 20.0 M non-zeros in both programs (baseline 19.97 M).

Threaded MKL (`-DMUL2_MKL_THREADED=ON`, separate build folder) was tried: no
significant gain on these cases (PARDISO is memory bound), so the default stays
sequential and bit-reproducible.

## What the benchmark found and what was changed

1. **Bug (TE order > 2).** The expansion mesh was integrated with its default
   Gauss rule (3×3 for Q9). A Taylor expansion of order *N* needs *N+1* points
   per direction (integrand of degree 2N); with less the stiffness was wrong.
   Old tests only used TE ≤ 2, where the default rule happens to be exact.
   Now each expansion mesh gets `N+1` points per direction (same choice as the
   baseline). New regression case: `TESTS/CASES/beam_te8_unit`.
2. **Cholesky breakdown.** Ill-conditioned (high-order Taylor) matrices can give
   a non-positive pivot in `mtype 2`; `PARDISO_FACTOR_LOADED` retries with the
   symmetric indefinite factorization and reports a warning.
3. **Separable CUF kernel** (`SRC/ELEMENTS/mul2_separable_kernel.for`). The
   point-by-point kernel costs `points_struct × points_expansion × n²`; the
   separable form computes structural integrals and expansion integrals
   separately and combines them (`Λ ⊗ EM`), so the costs add. Element matrices
   are identical to round-off (global K, M agree to 1e-15 with the reference
   kernel, which stays as fallback and is selectable with
   `MUL2_GENERAL_KERNEL=1`). TE15 assembly: 526 s → 12 s.
4. **Structural zeros.** With Lagrange expansions, terms that do not share a
   sub-element do not couple. The CSR pattern now excludes them (6× fewer
   non-zeros, same as the baseline), which shrinks the factor, the matrix
   products and the memory.
5. **Memory.** The static solve frees the assembled matrix right after PARDISO
   has its own copy of the upper triangle; the modal analysis frees the full
   system and the reduction map after the reduced K, M are built; K is not
   allocated for mass when only 101 is run.
6. Smaller items: batched dense kernels without stack temporaries,
   thread-balanced assembly chunks, OpenMP sparse matrix–vector product.

## Reproduce

    powershell TESTS\BENCH\bench.ps1 -Exe BUILD\WINDOWS_IFX\Release\MUL2_V3.exe ^
        -Case TESTS\BENCH\beam_te15_100k -RunDir C:\temp\run_new
    powershell TESTS\BENCH\bench.ps1 -Exe <MUL2_OPTIMIZED>\INTERFACE\MUL2.exe ^
        -Case TESTS\BENCH\beam_te15_100k -RunDir C:\temp\run_old

## Remaining limits

* Point-by-point fallback is used when the constitutive matrix varies inside a
  sub-element or the Gauss layout is not the standard one (none of the current
  inputs).
* The TE15 modal case needs 13.9 GB (K, M and the factor are stored with full
  TE coupling); the baseline uses the same amount. A symmetric (upper-only)
  storage of K and M would halve the matrices.
* Unit-size sections are used for TE15: monomials `x^a z^b` of order 15 on a
  millimetre-sized section underflow (z^15 ≈ 1e-50); normalise the section or
  use moderate orders.
