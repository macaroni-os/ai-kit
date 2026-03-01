# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit cmake

DESCRIPTION="LLM inference in C/C++"
HOMEPAGE="https://github.com/ggml-org/llama.cpp"
SRC_URI="https://api.github.com/repos/ggml-org/llama.cpp/tarball/b8123 -> llama-cpp-0.0.8123-f75c4e8.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="static blas cuda vulkan"
# Commons depends
CDEPEND="cuda? ( x11-drivers/nvidia-drivers )
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
	if use blas ; then
	  # It seems that -lcblas -lblas is not injected. It's inject only -llapack
	  export LDFLAGS="${LDFLAGS} -lcblas -lblas"
	fi
	 local mycmakeargs=(
	  -DBUILD_SHARED_LIBS=$(usex static OFF ON)
	  -DGGML_CUDA=$(usex cuda ON OFF)
	  -DGGML_BLAS=$(usex blas ON OFF)
	  -DGGML_VULKAN=$(usex vulkan ON OFF)
	  -DGGML_BLAS_VENDOR=Generic
	  -DCMAKE_CUDA_ARCHITECTURES='12:10:9:8.9:8.7:8.9:7.5:6.1:6.2'
	  -DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1
	)
	cmake_src_configure
}
src_install() {
	cmake_src_install
	dodoc README.md SECURITY.md CONTRIBUTING.md
}



# vim: filetype=ebuild
