* * *

## About ReSpaSol  

This repository is a collection of codes and scripts to evaluate the performance benefit
of using reduced precision in parallel sparse linear systems solvers. The associated
manuscript is available at [http://eprints.maths.manchester.ac.uk/2811/](http://eprints.maths.manchester.ac.uk/2811).


## Dependencies

### Libraries 
To use the routines provided here, the parallel sparse solvers evaluated and additional  must be downloaded and installed.
These include:

1. MUMPS 5.2.1 or recent version available at [http://mumps.enseeiht.fr/](http://mumps.enseeiht.fr)
2. SuperLU_MT 3.1  available at [https://github.com/group-gu/superlu-mt](https://github.com/group-gu/superlu-mt)
3. SuperLU 5.2.1 available at [https://github.com/xiaoyeli/superlu](https://github.com/xiaoyeli/superlu)
4. Pardiso from MKL 2020 or a recent version available at [http://scc.ustc.edu.cn/zlsc/intel/2020/mkl/ps2020/get_started.htm](http://scc.ustc.edu.cn/zlsc/intel/2020/mkl/ps2020/get_started.htm)
5. CUDA 10 or recent version available at [https://developer.nvidia.com/cuda-downloads](https://developer.nvidia.com/cuda-downloads)

Once the libraries are installed, the `Makefile` should be modified to set the
correct paths to the libraries. The default configuration serves only as an example.

### Sparse matrices
The matrices used in the experimentations are selected  from the [SuiteSparse Matrix Collection](https://sparse.tamu.edu/).
We use the matrix market format. The matrix can be downloaded directly from the SuiteSparse Matrix Collection.
The matrices are divided in two groups. The first 21 matrices are from the medium size group with 700, 000 to 5, 000, 000 nonzero elements. It takes a few
seconds on average to factorize these matrices using 10 cores. The second group contains larger matrices with 7,000,000
to 64,000,000 nonzeros and it takes on average a few minutes to factorize most of the matrices in this
group using 10 cores.

The matrices can be automatically downloaded by using the bash script
provided as shown below:

```bash
$ cd matrices/moderate # from ReSpaSol home directory
$ ./getModerateSizeMatrices.sh
```
This script will download and unzip all the medium size matrices.

Similarly, the large matrices can also be downloaded as shown below:
```bash
$ cd matrices/big # from ReSpaSol home directory
$ ./getLargerMatrices.sh
```

## Checkout and build
1. Download ReSpaSol
```bash
$ git clone  https://github.com/mawussi/ReSpaSol.git
$ cd ReSpaSol
```
2. Compile the library designed to read and load matrices from Matrix Market format to CSR/CSC data structure
```bash
$ cd ReadMatrixMarket
$ make
```
This will create the library `libloadmatrix.a` in the ReadMatrixMarket repository.  

3. Compile the codes for CPU experiments
```bash
$ cd ../  # back the ReSpaSol home directory
$ make
```
This will create the  following executable files: `test_superLU_MT`, `test_superILU`, `test_pardiso`, `test_mumps`,
`test_spmv`.

4. Compile codes for GPU experiments 
```bash
$ cd ./GPU
$ make
```
This will create the  following executable files:  `test_spmv`, `test_ilu0`.

## Run the experiments
To avoid redundancy, we use the same code for both single and double precision experiments.
To run the single precision experiment, one have to uncomment `#define FLOAT` directive in
the code. In the same to flush denormals to zero, the routine  call `ftz()` should be uncommented as
it is commented by default. Note that this is only meaningful for single precision runs.
Below are few example with mumps. All the commands are executed from the home repository.

1. Run double precision mumps solver using 10 CPU cores
   * Open test_mumps.c and make sure `#define FLOAT` is commented (`//#define FLOAT`)
   * Compile the code  ``` $ make  ```
   * Run ``` $ OMP_NUM_THREADS=10 ./run_mumps.sh > mumps10CoresFP64.txt```

2. Run single precision mumps solver using 10 CPU cores
   * Open test_mumps.c and make sure `#define FLOAT` is not commented
   * Also make sure the routine call `ftz()` is commented out (`//ftz()`)
   * Compile the code  ``` $ make  ```
   * Run ``` $ OMP_NUM_THREADS=10 ./run_mumps.sh > mumps10CoresFP32.txt```

3. Run single precision mumps solver using 10 CPU cores with subnormals flushed to zero
   * Open test_mumps.c and make sure `#define FLOAT` and `ftz()` are not commented out
   * Compile the code  ``` $ make  ```
   * Run ``` $ OMP_NUM_THREADS=10 ./run_mumps.sh >  mumps10CoresFP32Ftz.txt```

For each run the output file contains details on the time spent in different steps: reordering and symbolic factorization,
numerical factorization, solve, and additional details.

The scripts are provided in the home directory for other experiments as well.
Note that  the code for SpMV benchmark `test_spmv.c` runs both single precision
and double precision experiments in a single execution, and details the results accordingly.
The GPU experiments are similar expect the scripts are located in the GPU repository.

## Additional details on the sparse matrices used

### List of medium size matrices
| Matrices |Links to download Matrix Market formats |
| :--- | :--- | 
|2cubes_sphere | https://suitesparse-collection-website.herokuapp.com/MM/Um/2cubes_sphere.tar.gz |
|ASIC_320ks | https://suitesparse-collection-website.herokuapp.com/MM/Sandia/ASIC_320ks.tar.gz   |
|Baumann|https://suitesparse-collection-website.herokuapp.com/MM/Watson/Baumann.tar.gz |
|cfd2|https://suitesparse-collection-website.herokuapp.com/MM/Rothberg/cfd2.tar.gz |
|crashbasis |https://suitesparse-collection-website.herokuapp.com/MM/QLi/crashbasis.tar.gz|
|ct20stif |https://suitesparse-collection-website.herokuapp.com/MM/Boeing/ct20stif.tar.gz |
|dc1 |https://suitesparse-collection-website.herokuapp.com/MM/IBM_EDA/dc1.tar.gz |
|Dubcova3 |https://suitesparse-collection-website.herokuapp.com/MM/UTEP/Dubcova3.tar.gz|
|ecology2 | https://suitesparse-collection-website.herokuapp.com/MM/McRae/ecology2.tar.gz|
|FEM_3D_thermal2| https://suitesparse-collection-website.herokuapp.com/MM/Botonakis/FEM_3D_thermal2.tar.gz|
|G2_circuit |https://suitesparse-collection-website.herokuapp.com/MM/AMD/G2_circuit.tar.gz|
|Goodwin_095| https://suitesparse-collection-website.herokuapp.com/MM/Goodwin/Goodwin_095.tar.gz|
|matrix-new_3|https://suitesparse-collection-website.herokuapp.com/MM/Schenk_IBMSDS/matrix-new_3.tar.gz |
|offshore |https://suitesparse-collection-website.herokuapp.com/MM/Um/offshore.tar.gz|
|para-10 |https://suitesparse-collection-website.herokuapp.com/MM/Schenk_ISEI/para-10.tar.gz|
|parabolic_fem|https://suitesparse-collection-website.herokuapp.com/MM/Wissgott/parabolic_fem.tar.gz |
|ss1|https://suitesparse-collection-website.herokuapp.com/MM/VLSI/ss1.tar.gz |
|stomach|https://suitesparse-collection-website.herokuapp.com/MM/Norris/stomach.tar.gz|
|thermomech_TK|https://suitesparse-collection-website.herokuapp.com/MM/Botonakis/thermomech_TK.tar.gz|
|tmt_unsym|https://suitesparse-collection-website.herokuapp.com/MM/CEMW/tmt_unsym.tar.gz|
|xenon2|https://suitesparse-collection-website.herokuapp.com/MM/Ronis/xenon2.tar.gz|




### List of larger matrices
| Matrices |Links to download Matrix Market formats |
| :--- | :--- | 
|af_shell10 | https://suitesparse-collection-website.herokuapp.com/MM/Schenk_AFE/af_shell10.tar.gz|
|af_shell2|https://suitesparse-collection-website.herokuapp.com/MM/Schenk_AFE/af_shell2.tar.gz|
|atmosmodd|https://suitesparse-collection-website.herokuapp.com/MM/Bourchtein/atmosmodd.tar.gz |
|atmosmodl|https://suitesparse-collection-website.herokuapp.com/MM/Bourchtein/atmosmodl.tar.gz |
|cage13|https://suitesparse-collection-website.herokuapp.com/MM/vanHeukelum/cage13.tar.gz|
|CurlCurl_2 |https://suitesparse-collection-website.herokuapp.com/MM/Bodendiek/CurlCurl_2.tar.gz|
|dielFilterV2real|https://suitesparse-collection-website.herokuapp.com/MM/Dziekonski/dielFilterV2real.tar.gz |
|Geo_1438| https://suitesparse-collection-website.herokuapp.com/MM/Janna/Geo_1438.tar.gz|
|Hook_1498|https://suitesparse-collection-website.herokuapp.com/MM/Janna/Hook_1498.tar.gz|
|ML_Laplace| https://suitesparse-collection-website.herokuapp.com/MM/Janna/ML_Laplace.tar.gz|
|nlpkkt80|https://suitesparse-collection-website.herokuapp.com/MM/Schenk/nlpkkt80.tar.gz|
|Serena|https://suitesparse-collection-website.herokuapp.com/MM/Janna/Serena.tar.gz|
|Si87H76|https://suitesparse-collection-website.herokuapp.com/MM/PARSEC/Si87H76.tar.gz |
|StocF-1465 |https://suitesparse-collection-website.herokuapp.com/MM/Janna/StocF-1465.tar.gz|
|Transport|https://suitesparse-collection-website.herokuapp.com/MM/Janna/Transport.tar.gz|
