# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module cmake user

DESCRIPTION="Get up and running with Kimi-K2.6, GLM-5.2, MiniMax, DeepSeek, gpt-oss, Qwen, Gemma and other models."
HOMEPAGE="https://ollama.com"
SRC_URI="
https://api.github.com/repos/ollama/ollama/tarball/v0.33.0 -> ollama-0.33.0-ebf200f.tar.gz
mirror://macaroni/ollama-0.33.0-mark-go-bundle-ebf200f.tar.xz -> ollama-0.33.0-mark-go-bundle-ebf200f.tar.xz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="systemd clang cuda nccl vulkan cuda_sm_50 cuda_sm_52 cuda_sm_60 cuda_sm_61 cuda_sm_70 cuda_sm_75 cuda_sm_80 cuda_sm_86 cuda_sm_87 cuda_sm_89 cuda_sm_90 cuda_sm_90a cuda_sm_100 cuda_sm_101 cuda_sm_103 cuda_sm_110 cuda_sm_120 cuda_sm_121"
REQUIRED_USE="nccl? ( cuda ) cuda_sm_50? ( cuda ) cuda_sm_52? ( cuda ) cuda_sm_60? ( cuda ) cuda_sm_61? ( cuda ) cuda_sm_70? ( cuda ) cuda_sm_75? ( cuda ) cuda_sm_80? ( cuda ) cuda_sm_86? ( cuda ) cuda_sm_87? ( cuda ) cuda_sm_89? ( cuda ) cuda_sm_90? ( cuda ) cuda_sm_90a? ( cuda ) cuda_sm_100? ( cuda ) cuda_sm_101? ( cuda ) cuda_sm_103? ( cuda ) cuda_sm_110? ( cuda ) cuda_sm_120? ( cuda ) cuda_sm_121? ( cuda )"
BDEPEND=">=dev-lang/go-1.24
	clang? ( sys-devel/clang )
	
"
RDEPEND="vulkan? (
	  media-libs/vulkan-loader
	  media-libs/shaderc
	)
	cuda? (
	  dev-util/nvidia-cuda-toolkit
	)
	nccl? (
	  dev-util/nvidia-nccl
	)
	
"
DEPEND="${RDEPEND}
"

post_src_unpack() {
	mv ollama-ollama-* ${S}
}


pkg_setup() {
	ebegin "Ensuring ollama user/group exist"
	enewgroup ollama
	enewuser ollama -1 -1 /var/lib/ollama ollama
}
src_configure() {
	addpredict /proc/self/task
	local mycmakeargs=()
	if use clang ; then
	  mycmakeargs+=(
	    -DCMAKE_C_COMPILER=clang
	    -DCMAKE_CXX_COMPILER=clang++
	  )
	fi
	if use cuda ; then
	  # Upstream builds GPU backend payloads only when asked to
	  # (OLLAMA_LLAMA_BACKENDS, empty by default), and each payload
	  # targets one CUDA major. nvidia-cuda-toolkit allows only one
	  # CUDA major at a time, so detect the installed one and build
	  # only the matching backend.
	  local cuda_major=
	  cuda_major=$(
	    nvcc --version 2>/dev/null |
	    sed -n 's/.*release \([0-9][0-9]*\).*/\1/p'
	  )
	  case ${cuda_major:-12} in
	    13)
	      mycmakeargs+=(
	        -DOLLAMA_LLAMA_BACKENDS=cuda_v13
	      )
	      ;;
	    *)
	      [[ -z ${cuda_major} ]] && \
	        ewarn "Could not detect the CUDA toolkit major version (nvcc not found); defaulting to the CUDA 12 backend"
	      mycmakeargs+=(
	        -DOLLAMA_LLAMA_BACKENDS=cuda_v12
	      )
	      ;;
	  esac
	  # The architecture list comes from the enabled cuda_sm_*
	  # flags, filtered against the set the installed toolkit
	  # major can target. CUDA only drops architectures at major
	  # boundaries, so the per-major sets are:
	  #   11: 50 52 60 61 70 75 80 86 87 89 90
	  #   12: 50 52 60 61 70 75 80 86 87 89 90 90a 100 103
	  #        120 121
	  #   13: 75 80 86 87 89 90 90a 100 103 110 120 121
	  # sm_101 (Jetson Thor) is not a general nvcc target in
	  # 11.x/12.x and is renumbered to sm_110 in 13.x, so it
	  # only builds with the 13 major.
	  local cuda_supported
	  case ${cuda_major:-12} in
	    13)
	      cuda_supported="75 80 86 87 89 90 90a 100 103 110 120 121"
	      ;;
	    11)
	      cuda_supported="50 52 60 61 70 75 80 86 87 89 90"
	      ;;
	    *)
	      cuda_supported="50 52 60 61 70 75 80 86 87 89 90 90a 100 103 120 121"
	      ;;
	  esac
	  local arch cuda_archs=() cuda_dropped=()
	  for arch in 50 52 60 61 70 75 80 86 87 89 90 90a 100 101 103 110 120 121 ; do
	    use cuda_sm_${arch} || continue
	    if has "${arch}" ${cuda_supported} ; then
	      cuda_archs+=("${arch}")
	    else
	      cuda_dropped+=("${arch}")
	    fi
	  done
	  if [[ ${#cuda_archs[@]} -gt 0 || ${#cuda_dropped[@]} -gt 0 ]] ; then
	    if [[ ${#cuda_dropped[@]} -gt 0 ]] ; then
	      ewarn "Dropping CUDA architectures unsupported by the installed toolkit (major ${cuda_major:-unknown}): $(join ' ' "${cuda_dropped[@]}")"
	    fi
	    if [[ ${#cuda_archs[@]} -eq 0 ]] ; then
	      die "all enabled cuda_sm_* flags are unsupported by the installed CUDA toolkit; enable flags matching your card, or override with MYCMAKEARGS=\"-DCMAKE_CUDA_ARCHITECTURES=...\""
	    fi
	    mycmakeargs+=(
	      -DCMAKE_CUDA_ARCHITECTURES="$(join ';' "${cuda_archs[@]}")"
	    )
	  fi
	  mycmakeargs+=(
	    -DGGML_CUDA_NCCL=$(usex nccl ON OFF)
	  )
	fi
	cmake_src_configure
}
src_prepare() {
	default
	go-module_src_prepare
	cmake_src_prepare
}
src_compile() {
	cmake_src_compile
	local ollama_ldflags=(
	   "-X github.com/ollama/ollama/version.Version=${PV}"
	)
	go build --ldflags "${ollama_ldflags[*]}" -mod=mod . || die "compile failed"
}
src_install() {
	cmake_src_install
	dobin ollama
	diropts -m0750 -o ollama -g ollama
	dodir /var/lib/ollama /var/lib/ollama/models/
	keepdir /var/lib/ollama/
	diropts
	dodoc README.md
	newconfd "${FILESDIR}"/ollama.confd ollama
	if use systemd ; then
	  systemd_dounit "${FILESDIR}"/ollama.service
	else
	  newinitd "${FILESDIR}"/ollama.initd ollama
	fi
	newenvd "${FILESDIR}"/ollama.envd "90ollama"
}



# vim: filetype=ebuild
