// Native: use LAPACK dsyev via C stub for eigendecomposition
// Links against Apple Accelerate framework (macOS) or OpenBLAS (Linux)

///|
#borrow(a, w)
extern "C" fn dec_dsyev(
  a : FixedArray[Double],
  w : FixedArray[Double],
  n : Int,
) -> Int = "dec_dsyev"

fn eigen_decompose(mat : Array[Double], n : Int) -> (Array[Double], Array[Double]) {
  // Copy to FixedArray for FFI (column-major for LAPACK)
  let a : FixedArray[Double] = FixedArray::make(n * n, 0.0)
  // Our input is row-major, LAPACK expects column-major
  // For symmetric matrices, row-major == column-major, so direct copy
  for i = 0; i < n * n; i = i + 1 {
    a[i] = mat[i]
  }
  let w : FixedArray[Double] = FixedArray::make(n, 0.0)
  let ret = dec_dsyev(a, w, n)
  if ret != 0 {
    // Fallback to Jacobi
    return @linalg.eigen_symmetric(mat, n)
  }
  // Convert results
  let eigvals : Array[Double] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    eigvals[i] = w[i]
  }
  // LAPACK dsyev stores eigenvectors as columns in 'a' (column-major)
  // Our API expects row-major eigenvectors
  let eigvecs : Array[Double] = Array::make(n * n, 0.0)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      // column-major a[j*n+i] → row-major eigvecs[i*n+j]
      eigvecs[i * n + j] = a[j * n + i]
    }
  }
  (eigvals, eigvecs)
}
