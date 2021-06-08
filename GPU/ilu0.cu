#include <stdio.h>
#include <stdlib.h>
#include <cusparse_v2.h>
#include <cusparse.h>
#include <cuda.h>
#include "loadMatrixMarket.h"

#define FLOAT


// Define some error checking macros.
#define cudaErrCheck(stat) { cudaErrCheck_((stat), __FILE__, __LINE__); }

void cudaErrCheck_(cudaError_t stat, const char *file, int line) {
  if (stat != cudaSuccess) {
    fprintf(stderr, "CUDA Error: %s %s %d\n", cudaGetErrorString(stat), file, line);
  }
}


#define cusparseErrCheck(stat) { cusparseErrCheck_((stat), __FILE__, __LINE__); }
void cusparseErrCheck_(cusparseStatus_t stat, const char *file, int line) {
  if (stat != CUSPARSE_STATUS_SUCCESS) {
    fprintf(stderr, "CUSPARSE Error: %d %s %d\n", stat, file, line);
  }
}


int main(int argc, char **argv)
{

  if (argc < 2) {
    fprintf(
            stderr,
            "-- Usage examples --\n"
            "  %s inline_1.mtx type: run with inline_1 matrix in matrix market format\n",
            argv[0]);
    return -1;
  }


    CSR matrixA;
    int outputbase = 0;
    loadMatrixMarket(argv[1], &matrixA, outputbase, 0 /*transpose =false*/);
    
    
    int             n  = matrixA.n;
    int *CsrRowPtrA =  matrixA.rowptr;
    int *CsrColIndA =  matrixA.colidx; 
    
    // index pointer on device
    int *dCsrRowPtrA;
    int *dCsrColIndA;
    
#ifdef FLOAT
    float alpha = (float)1.0;
    float *CsrValA = (float*)malloc(matrixA.nnz*sizeof(float));
    for(int i =0; i < matrixA.nnz; i++){
      CsrValA[i] = (float) matrixA.values[i];   
    }
    float *Y        = (float*)malloc(n*sizeof(float));
    float *X        = (float*)malloc(n*sizeof(float));
    for (int i = 0; i < n; i++) X[i] = (float) 1.0;
    // device 
    float *dCsrValA;
    float *dX;
    float *dZ; // intermediate solution Lz =b
    float *dY;
#else
    double alpha = (double)1.0;
    double *CsrValA = matrixA.values;
    double *Y        = (double*)malloc(n*sizeof(double));
    double *X        = (double*)malloc(n*sizeof(double));
    for (int i = 0; i < n; i++) X[i] = (double)1.0;
    //device 
    double *dCsrValA;
    double *dX;
    double *dZ; // intermediate solution Lz =b
    double *dY;
#endif
    
    cusparseHandle_t handle = 0;
    
    // Create the cuSPARSE handle
     cusparseErrCheck(cusparseCreate(&handle));


    // Allocate device memory to store the sparse CSR representation of A
    cudaErrCheck(cudaMalloc((void **)&dCsrRowPtrA, sizeof(int) * (n+1)));
    cudaErrCheck(cudaMalloc((void **)&dCsrColIndA, sizeof(int) * matrixA.nnz));
    
#ifdef FLOAT
    cudaErrCheck(cudaMalloc((void **)&dCsrValA, sizeof(float) * matrixA.nnz));
#else
    cudaErrCheck(cudaMalloc((void **)&dCsrValA, sizeof(double) * matrixA.nnz));
#endif 

    // Allocate device memory to store the X and Y
#ifdef FLOAT
    cudaErrCheck(cudaMalloc((void **)&dX, sizeof(float) * n));
    cudaErrCheck(cudaMalloc((void **)&dY,    sizeof(float) * n));
    cudaErrCheck(cudaMalloc((void **)&dZ,    sizeof(float) * n));
#else
    cudaErrCheck(cudaMalloc((void **)&dX, sizeof(double) * n));
    cudaErrCheck(cudaMalloc((void **)&dY,    sizeof(double) * n));
    cudaErrCheck(cudaMalloc((void **)&dZ,    sizeof(double) * n));
#endif 

    // transfer data to device 
    // Transfer the input vectors and dense matrix A to the device
    cudaErrCheck(cudaMemcpy(dCsrRowPtrA, CsrRowPtrA, sizeof(int) * (n+1), cudaMemcpyHostToDevice));
    cudaErrCheck(cudaMemcpy(dCsrColIndA, CsrColIndA, sizeof(int) * matrixA.nnz, cudaMemcpyHostToDevice));
#ifdef FLOAT
    cudaErrCheck(cudaMemcpy(dCsrValA,  CsrValA, sizeof(float) * matrixA.nnz, cudaMemcpyHostToDevice));
    cudaErrCheck(cudaMemcpy(dX,      X,     sizeof(float) * n,           cudaMemcpyHostToDevice));
#else
    cudaErrCheck(cudaMemcpy(dCsrValA, CsrValA, sizeof(double) * matrixA.nnz, cudaMemcpyHostToDevice));
    cudaErrCheck(cudaMemcpy(dX,     X,     sizeof(double) * n,          cudaMemcpyHostToDevice));
#endif


    // Create descriptor A
    cusparseMatDescr_t desc_A = 0;
    cusparseErrCheck(cusparseCreateMatDescr(&desc_A));
    cusparseErrCheck(cusparseSetMatType(desc_A, CUSPARSE_MATRIX_TYPE_GENERAL));
    cusparseErrCheck(cusparseSetMatIndexBase(desc_A, CUSPARSE_INDEX_BASE_ZERO));

    // create descriptor L
    cusparseMatDescr_t desc_L = 0;
    cusparseCreateMatDescr(&desc_L);
    cusparseSetMatIndexBase(desc_L, CUSPARSE_INDEX_BASE_ZERO);
    cusparseSetMatType(desc_L, CUSPARSE_MATRIX_TYPE_GENERAL);
    cusparseSetMatFillMode(desc_L, CUSPARSE_FILL_MODE_LOWER);
    cusparseSetMatDiagType(desc_L, CUSPARSE_DIAG_TYPE_UNIT);

    cusparseMatDescr_t desc_U = 0;
    cusparseCreateMatDescr(&desc_U);
    cusparseSetMatIndexBase(desc_U, CUSPARSE_INDEX_BASE_ONE);
    cusparseSetMatType(desc_U, CUSPARSE_MATRIX_TYPE_GENERAL);
    cusparseSetMatFillMode(desc_U, CUSPARSE_FILL_MODE_UPPER);
    cusparseSetMatDiagType(desc_U, CUSPARSE_DIAG_TYPE_NON_UNIT);

    //  Create a empty info structure
    csrilu02Info_t info_A  = 0;
    csrsv2Info_t   info_L  = 0;
    csrsv2Info_t   info_U = 0;

    cusparseCreateCsrilu02Info(&info_A);
    cusparseCreateCsrsv2Info(&info_L);
    cusparseCreateCsrsv2Info(&info_U);

    //  Query how much memory used in csric02 and csrsv2, and allocate the buffer
    int pBufferSize_A;
    int pBufferSize_L;
    int pBufferSize_U;


    // Timing variables
    cudaEvent_t start;
    cudaEvent_t stop;
    cudaErrCheck(cudaEventCreate(&start));
    cudaErrCheck(cudaEventCreate(&stop));


#ifdef FLOAT
    cusparseScsrilu02_bufferSize(handle, n, matrixA.nnz,
				desc_A, dCsrValA, dCsrRowPtrA, dCsrColIndA,
				info_A, &pBufferSize_A);

    cusparseScsrsv2_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz,
			       desc_L, dCsrValA, dCsrRowPtrA, dCsrColIndA,
			       info_L, &pBufferSize_L);

    cusparseScsrsv2_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz,
			       desc_U, dCsrValA, dCsrRowPtrA, dCsrColIndA, info_U,&pBufferSize_U);
#else 
    cusparseDcsrilu02_bufferSize(handle, n, matrixA.nnz,
				desc_A, dCsrValA, dCsrRowPtrA, dCsrColIndA,
				info_A, &pBufferSize_A);

    cusparseDcsrsv2_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz,
			       desc_L, dCsrValA, dCsrRowPtrA, dCsrColIndA,
			       info_L, &pBufferSize_L);

    cusparseDcsrsv2_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz,
			       desc_U, dCsrValA, dCsrRowPtrA, dCsrColIndA, info_U,&pBufferSize_U);
#endif


    int   pBufferSize = max(pBufferSize_A, max(pBufferSize_L, pBufferSize_U));

    // pBuffer returned by cudaMalloc is automatically aligned to 128 bytes.
    void *pBuffer = 0;
    cudaMalloc((void**)&pBuffer, pBufferSize);

    // Timing the analysis 
    cudaEventRecord(start);

    // Perform analysis of ILU0 on A
    const cusparseSolvePolicy_t policy_A  = CUSPARSE_SOLVE_POLICY_NO_LEVEL;

#ifdef FLOAT
    cusparseScsrilu02_analysis(handle, n, matrixA.nnz, desc_A,
			       dCsrValA, dCsrRowPtrA, dCsrColIndA, info_A,
			       policy_A, pBuffer);
#else
    cusparseDcsrilu02_analysis(handle, n, matrixA.nnz, desc_A,
			      dCsrValA, dCsrRowPtrA, dCsrColIndA, info_A,
			      policy_A, pBuffer);
#endif 

    
    cudaEventRecord(stop);  
    cudaEventSynchronize(stop);
    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    float time_symbolique  = milliseconds;



    int structural_zero;
    cusparseStatus_t status = cusparseXcsrilu02_zeroPivot(handle, info_A, &structural_zero);
    if (CUSPARSE_STATUS_ZERO_PIVOT == status){
      printf("A(%d,%d) is missing\n", structural_zero, structural_zero);
      return 0;
    }

    // Perform analysis of triangular solve on L
    const cusparseSolvePolicy_t policy_L  = CUSPARSE_SOLVE_POLICY_NO_LEVEL;

#ifdef FLOAT
    cusparseScsrsv2_analysis(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, desc_L,
			     dCsrValA, dCsrRowPtrA, dCsrColIndA,
			     info_L, policy_L, pBuffer);
#else
    cusparseDcsrsv2_analysis(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, desc_L,
			     dCsrValA, dCsrRowPtrA, dCsrColIndA,
			     info_L, policy_L, pBuffer);
#endif 

    // Perform analysis of triangular solve on U
    const cusparseSolvePolicy_t policy_U = CUSPARSE_SOLVE_POLICY_USE_LEVEL;

#ifdef FLOAT
    cusparseScsrsv2_analysis(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, desc_L,
			     dCsrValA, dCsrRowPtrA, dCsrColIndA,
			     info_U, policy_U, pBuffer);
#else
    cusparseDcsrsv2_analysis(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, desc_L,
			     dCsrValA, dCsrRowPtrA, dCsrColIndA,
			     info_U, policy_U, pBuffer);
#endif 
    
    


    // Numerical factorization
    int numerical_zero;

    // Timing the numerical factorization 
    cudaEventRecord(start);

#ifdef FLOAT
    cusparseScsrilu02(handle, n, matrixA.nnz, desc_A,
		      dCsrValA, dCsrRowPtrA, dCsrColIndA, info_A, policy_A, pBuffer);
#else
    cusparseDcsrilu02(handle, n, matrixA.nnz, desc_A,
		     dCsrValA, dCsrRowPtrA, dCsrColIndA, info_A, policy_A, pBuffer);
#endif 

    cudaEventRecord(stop);  
    cudaEventSynchronize(stop);
    milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    float time_numeric  = milliseconds;


    status = cusparseXcsrilu02_zeroPivot(handle, info_A, &numerical_zero);
    if (CUSPARSE_STATUS_ZERO_PIVOT == status){
      printf("L(%d,%d) is zero\n", numerical_zero, numerical_zero);
      return 0;
    }

    cudaEventRecord(start);
#ifdef FLOAT
    //  Solve L*z = x
    cusparseScsrsv2_solve(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, &alpha, desc_L,
			  dCsrValA, dCsrRowPtrA, dCsrColIndA, info_L,
			  dX, dZ, policy_L, pBuffer);
    // Solve L'*y = z
    cusparseScsrsv2_solve(handle, CUSPARSE_OPERATION_TRANSPOSE, n, matrixA.nnz, &alpha, desc_L,
			  dCsrValA, dCsrRowPtrA, dCsrColIndA, info_U,
			  dZ, dY, policy_U, pBuffer);
#else
    //  Solve L*z = x
    cusparseDcsrsv2_solve(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, n, matrixA.nnz, &alpha, desc_L,
			  dCsrValA, dCsrRowPtrA, dCsrColIndA, info_L,
			  dX, dZ, policy_L, pBuffer);
    // Solve L'*y = z
    cusparseDcsrsv2_solve(handle, CUSPARSE_OPERATION_TRANSPOSE, n, matrixA.nnz, &alpha, desc_L,
			  dCsrValA, dCsrRowPtrA, dCsrColIndA, info_U,
			  dZ, dY, policy_U, pBuffer);
#endif
    
    cudaEventRecord(stop);  
    cudaEventSynchronize(stop);
    milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    float time_solve  = milliseconds;
    
#ifdef FLOAT
    printf ("SINGLE PRECISION SOLVE IN  MILLISECONDS\n ");
#else
    printf ("DOUBLE PRECISION SOLVE IN  MILLISECONDS\n ");
#endif
    printf ("Symbolic = %f\n Numeric = %f \n Symbolic+ Numeric = %f\n Solve = %f\n", time_symbolique, time_numeric, time_symbolique + time_numeric,  time_solve);
 
    cudaErrCheck(cudaEventDestroy(start));             
    cudaErrCheck(cudaEventDestroy(stop));
    free(CsrValA);
    free(CsrRowPtrA);
    free(CsrColIndA);
    free(X);
    free(Y);
    cudaErrCheck(cudaFree(dY));
    cudaErrCheck(cudaFree(dX));
    cudaErrCheck(cudaFree(dCsrValA));
    cudaErrCheck(cudaFree(dCsrRowPtrA));
    cudaErrCheck(cudaFree(dCsrColIndA));
    cudaErrCheck(cudaFree(pBuffer));
    
    cusparseDestroyCsrilu02Info(info_A);
    cusparseDestroyCsrsv2Info(info_L);
    cusparseDestroyCsrsv2Info(info_U);

    cusparseErrCheck(cusparseDestroyMatDescr(desc_A));
    cusparseErrCheck(cusparseDestroyMatDescr(desc_L));
    cusparseErrCheck(cusparseDestroyMatDescr(desc_U));
    cusparseErrCheck(cusparseDestroy(handle));
    return 0;
}
