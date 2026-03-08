// LAPACK dsyev wrapper for CMA-ES eigendecomposition
// macOS: links against Accelerate framework
// Linux: links against liblapack + libblas

#ifdef __APPLE__
#define ACCELERATE_NEW_LAPACK
#include <Accelerate/Accelerate.h>
#else
extern void dsyev_(char *jobz, char *uplo, int *n, double *a, int *lda,
                   double *w, double *work, int *lwork, int *info);
#endif

// MoonBit FixedArray[Double] has the data after the moonbit header
// The data pointer is passed directly by the #borrow attribute

int dec_dsyev(double *a, double *w, int n) {
    char jobz = 'V';  // compute eigenvalues and eigenvectors
    char uplo = 'U';  // upper triangle
    int lda = n;
    int info = 0;

    // Query optimal workspace size
    double work_query;
    int lwork = -1;
    dsyev_(&jobz, &uplo, &n, a, &lda, w, &work_query, &lwork, &info);
    if (info != 0) return info;

    lwork = (int)work_query;
    double work_buf[4096];  // stack buffer for small matrices
    double *work = work_buf;
    if (lwork > 4096) {
        work = (double *)malloc(lwork * sizeof(double));
        if (!work) return -999;
    }

    dsyev_(&jobz, &uplo, &n, a, &lda, w, work, &lwork, &info);

    if (work != work_buf) free(work);
    return info;
}
