# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit cmake

DESCRIPTION="LLM inference in C/C++"
HOMEPAGE="https://llama.app"
SRC_URI="https://api.github.com/repos/ggml-org/llama.cpp/tarball/v0.3.0 -> llama-cpp-0.3.0-c1d0e7a.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="static blas cuda nccl vulkan cuda-native cuda_sm_50 cuda_sm_52 cuda_sm_60 cuda_sm_61 cuda_sm_70 cuda_sm_75 cuda_sm_80 cuda_sm_86 cuda_sm_87 cuda_sm_89 cuda_sm_90 cuda_sm_90a cuda_sm_100 cuda_sm_101 cuda_sm_103 cuda_sm_110 cuda_sm_120 cuda_sm_121"
REQUIRED_USE="nccl? ( cuda ) cuda_sm_50? ( cuda ) cuda_sm_52? ( cuda ) cuda_sm_60? ( cuda ) cuda_sm_61? ( cuda ) cuda_sm_70? ( cuda ) cuda_sm_75? ( cuda ) cuda_sm_80? ( cuda ) cuda_sm_86? ( cuda ) cuda_sm_87? ( cuda ) cuda_sm_89? ( cuda ) cuda_sm_90? ( cuda ) cuda_sm_90a? ( cuda ) cuda_sm_100? ( cuda ) cuda_sm_101? ( cuda ) cuda_sm_103? ( cuda ) cuda_sm_110? ( cuda ) cuda_sm_120? ( cuda ) cuda_sm_121? ( cuda )"
# Commons depends
CDEPEND="cuda? (
	  dev-util/nvidia-cuda-toolkit
	)
	nccl? (
	  dev-util/nvidia-nccl
	)
	vulkan? (
	  dev-util/vulkan-tools
	  media-libs/vulkan-layers
	  media-libs/vulkan-loader
	  media-libs/shaderc
	  sci-libs/gsl
	)
	blas? (
	  virtual/blas
	  virtual/lapack
	)
	
"
BDEPEND="vulkan? (
	  dev-util/vulkan-headers
	)
	
"
RDEPEND="${CDEPEND}
"
DEPEND="${CDEPEND}
"

post_src_unpack() {
	mv ggml-org-llama.cpp-* ${S}
}


src_configure() {
	addpredict /proc/self/task
	if use blas ; then
	  # It seems that -lcblas -lblas is not injected. It's inject only -llapack
	  export LDFLAGS="${LDFLAGS} -lcblas -lblas"
	fi
	export BUILD_COMMIT=c1d0e7a004015f23bc0233470b747b596f29b264
	 local mycmakeargs=(
	  -DBUILD_SHARED_LIBS=$(usex static OFF ON)
	  -DGGML_CUDA=$(usex cuda ON OFF)
	  -DGGML_BLAS=$(usex blas ON OFF)
	  -DGGML_VULKAN=$(usex vulkan ON OFF)
	  -DGGML_BLAS_VENDOR=Generic
	  -DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1
	)
	local cuda_archs= cuda_major= cuda_supported=
	local arch cuda_flagged=() cuda_dropped=()
	if use cuda ; then
	  # Multi-GPU support is optional: nccl is OFF by default and a
	  # rebuild of dev-util/nvidia-nccl (or nvidia-cuda-toolkit,
	  # which it depends on) marks this package to rebuild, since it
	  # is a build dependency.
	  mycmakeargs+=(
	    -DGGML_CUDA_NCCL=$(usex nccl ON OFF)
	  )
	  # The architecture list comes from the enabled cuda_sm_*
	  # flags, filtered against the set the installed toolkit
	  # major can target (same per-major sets as
	  # app-ai/ollama; CUDA only drops architectures at major
	  # boundaries, and sm_101 is renumbered to sm_110 in 13.x).
	  cuda_major=$(
	    nvcc --version 2>/dev/null |
	    sed -n 's/.*release \([0-9][0-9]*\).*/\1/p'
	  )
	  case ${cuda_major:-12} in
	    13)
	      cuda_supported="75 80 86 87 89 90 90a 100 103 110 120 121"
	      ;;
	    11)
	      cuda_supported="50 52 60 61 70 75 80 86 87 89 90"
	      ;;
	    *)
	      [[ -z ${cuda_major} ]] && \
	        ewarn "Could not detect the CUDA toolkit major version (nvcc not found); defaulting to the CUDA 12 supported set"
	      cuda_supported="50 52 60 61 70 75 80 86 87 89 90 90a 100 103 120 121"
	      ;;
	  esac
	  for arch in 50 52 60 61 70 75 80 86 87 89 90 90a 100 101 103 110 120 121 ; do
	    use cuda_sm_${arch} || continue
	    if has "${arch}" ${cuda_supported} ; then
	      cuda_flagged+=("${arch}")
	    else
	      cuda_dropped+=("${arch}")
	    fi
	  done
	  if [[ ${#cuda_flagged[@]} -gt 0 || ${#cuda_dropped[@]} -gt 0 ]] ; then
	    if [[ ${#cuda_dropped[@]} -gt 0 ]] ; then
	      ewarn "Dropping CUDA architectures unsupported by the installed toolkit (major ${cuda_major:-unknown}): $(join ' ' "${cuda_dropped[@]}")"
	    fi
	    if [[ ${#cuda_flagged[@]} -eq 0 ]] ; then
	      die "all enabled cuda_sm_* flags are unsupported by the installed CUDA toolkit; enable flags matching your card, or override with MYCMAKEARGS=\"-DCMAKE_CUDA_ARCHITECTURES=...\""
	    fi
	    cuda_archs="$(join ';' "${cuda_flagged[@]}")"
	  fi
	fi
	# Precedence: the enabled cuda_sm_* flags, then the explicit
	# cuda-native USE flag (per-emerge choice), then the package
	# default. A raw -D in MYCMAKEARGS still speaks last, since the
	# cmake eclass appends it after mycmakeargs and cmake's last -D
	# wins.
	if [[ -z ${cuda_archs} ]] ; then
	  if use cuda-native ; then
	    cuda_archs=native
	  else
	    cuda_archs='120;100;87;89;75'
	  fi
	fi
	mycmakeargs+=(
	  -DCMAKE_CUDA_ARCHITECTURES="${cuda_archs}"
	)
	cmake_src_configure
}
src_install() {
	cmake_src_install
	dodoc README.md SECURITY.md CONTRIBUTING.md
}



# vim: filetype=ebuild
