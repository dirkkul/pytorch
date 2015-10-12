#include "caffe2/core/context_gpu.h"
#include "caffe2/operators/clip_op.h"

namespace caffe2 {
namespace {

template <typename T>
__device__ T cuda_min(T x, T y);
template <typename T>
__device__ T cuda_max(T x, T y);
template <>
__device__ float cuda_min(float x, float y) { return fminf(x, y); }
template <>
__device__ float cuda_max(float x, float y) { return fmaxf(x, y); }
template <>
__device__ double cuda_min(double x, double y) { return fmin(x, y); }
template <>
__device__ double cuda_max(double x, double y) { return fmax(x, y); }



template <typename T>
__global__ void ClipKernel(const int N, const T minval, const T maxval,
                           const T* X, T* Y) {
  CUDA_1D_KERNEL_LOOP(i, N) {
    Y[i] = cuda_min<T>(cuda_max<T>(X[i], minval), maxval);
  }
}

template <typename T>
__global__ void ClipGradientKernel(const int N,  const T minval,
                                   const T maxval, const T* X,
                                   const T* dY, T* dX) {
  CUDA_1D_KERNEL_LOOP(i, N) {
    dX[i] = dY[i] * (X[i] > minval && X[i] < maxval);
  }
}
}  // namespace

template <>
bool ClipOp<float, CUDAContext>::RunOnDevice() {
  auto& X = Input(0);
  auto* Y = Output(0);
  CAFFE_DCHECK_GT(X.size(), 0);
  Y->ReshapeLike(X);
  ClipKernel<<<CAFFE_GET_BLOCKS(X.size()), CAFFE_CUDA_NUM_THREADS,
               0, device_context_.cuda_stream()>>>(
      X.size(), min_, max_, X.data<float>(), Y->mutable_data<float>());
  return true;
}

template <>
bool ClipGradientOp<float, CUDAContext>::RunOnDevice() {
  auto& X = Input(0);
  auto& dY = Input(1);
  auto* dX = Output(0);
  CAFFE_DCHECK_GT(X.size(), 0);
  CAFFE_DCHECK_EQ(dY.size(), X.size());
  dX->ReshapeLike(X);
  ClipGradientKernel<<<CAFFE_GET_BLOCKS(X.size()), CAFFE_CUDA_NUM_THREADS,
                       0, device_context_.cuda_stream()>>>(
      X.size(), min_, max_, X.data<float>(), dY.data<float>(),
      dX->mutable_data<float>());
  return true;
}

namespace {
REGISTER_CUDA_OPERATOR(Clip, ClipOp<float, CUDAContext>)
REGISTER_CUDA_OPERATOR(ClipGradient, ClipGradientOp<float, CUDAContext>)
}  // namespace
}  // namespace caffe2
