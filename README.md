# Polybench-Metafor

Contains the source code of PolyBench/Fortran, as well as scripts used for the reproduction of Metafor-AutoPar results.

Also includes the execution times of our evaluation process in a dual socket system, as well as results for one of the NAS Parallel Benchmarks (CG).

## Included Scripts

- `preproc.sh`: Creates a preprocessed version of each benchmark (stripped of C macros)
- `weave.sh`: Creates a (potentially) parallelized version of each benchmark with Metafor-AutoPar (path must be updated to local installation)
- `compile.sh`: Compiles each benchmark (PolyBench flags should match those of the preprocessing script)
- `average.sh`: Runs each benchmark a certain number of times, storing the execution time of each run in a text file
- `compilepolly.sh/averagepolly.sh`: Same as above, but for usage with Polly
