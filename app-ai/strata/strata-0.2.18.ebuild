# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
CMAKE_BUILD_TYPE=Release
inherit cmake systemd

DESCRIPTION="Local inference engine for Qwen3.8-Flash-Next on NVIDIA GPUs"
HOMEPAGE="https://github.com/Niko1221/Strata"
SRC_URI="https://api.github.com/repos/Niko1221/Strata/tarball/v0.2.18 -> strata-0.2.18.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="cuda cuda-native systemd
cuda_sm_75
cuda_sm_80
cuda_sm_86
cuda_sm_87
cuda_sm_89
cuda_sm_90
cuda_sm_90a
cuda_sm_100
cuda_sm_101
cuda_sm_103
cuda_sm_110
cuda_sm_120
cuda_sm_121"
REQUIRED_USE="
cuda_sm_75? ( cuda )
cuda_sm_80? ( cuda )
cuda_sm_86? ( cuda )
cuda_sm_87? ( cuda )
cuda_sm_89? ( cuda )
cuda_sm_90? ( cuda )
cuda_sm_90a? ( cuda )
cuda_sm_100? ( cuda )
cuda_sm_101? ( cuda )
cuda_sm_103? ( cuda )
cuda_sm_110? ( cuda )
cuda_sm_120? ( cuda )
cuda_sm_121? ( cuda )"
# Commons depends
CDEPEND="cuda? (
	  dev-util/nvidia-cuda-toolkit
	)
	
"
RDEPEND="${CDEPEND}
"
DEPEND="${CDEPEND}
"

post_src_unpack() {
	mv Niko1221-Strata-* ${S}
}


src_prepare() {
	# The CMake project root is engine/, not the tag tarball's root
	# (which also holds terminal/ and app/). _cmake_check_build_dir
	# takes CMAKE_USE_DIR as-is, so set it globally here and both
	# cmake_src_prepare and cmake_src_configure use it; BUILD_DIR
	# stays the eclass out-of-source default.
	CMAKE_USE_DIR="${S}/engine"
	cmake_src_prepare
}
src_configure() {
	addpredict /proc/self/task
	local mycmakeargs=(
	  -DSTRATA_BUILD_TESTS=OFF
	  -DSTRATA_WERROR=OFF
	  -DSTRATA_PORTABLE=ON
	  -DSTRATA_ENABLE_CUDA=$(usex cuda ON OFF)
	)
	local cuda_archs= cuda_major= cuda_supported=
	local arch cuda_flagged=() cuda_dropped=()
	if use cuda ; then
	  # The architecture list comes from the enabled cuda_sm_*
	  # flags, filtered against the set the installed toolkit
	  # major can target (same per-major sets as app-ai/ollama;
	  # CUDA only drops architectures at major boundaries, and
	  # sm_101 is renumbered to sm_110 in the 13.x toolkits).
	  cuda_major=$(
	    nvcc --version 2>/dev/null |
	    sed -n 's/.*release \([0-9][0-9]*\).*/\1/p'
	  )
	  case ${cuda_major:-13} in
	    13)
	      cuda_supported="75 80 86 87 89 90 90a 100 103 110 120 121"
	      ;;
	    *)
	      [[ -z ${cuda_major} ]] && \
	        ewarn "Could not detect the CUDA toolkit major version (nvcc not found); defaulting to the CUDA 12 supported set"
	      cuda_supported="60 61 70 75 80 86 87 89 90 90a 100 103 120 121"
	      ;;
	  esac
	  for arch in 75 80 86 87 89 90 90a 100 101 103 110 120 121 ; do
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
	# Precedence (as in app-ai/llama-cpp and app-ai/maya): the
	# enabled cuda_sm_* flags, then the explicit cuda-native USE
	# flag, then the package default. A raw -D in MYCMAKEARGS
	# still speaks last.
	if [[ -z ${cuda_archs} ]] ; then
	  if use cuda-native ; then
	    cuda_archs=native
	  else
	    cuda_archs='120'
	  fi
	fi
	if use cuda ; then
	  mycmakeargs+=(
	    -DCMAKE_CUDA_ARCHITECTURES="${cuda_archs}"
	  )
	fi
	cmake_src_configure
}
src_install() {
	# Upstream's CMake project defines no install() rules; stage
	# the built executables by name (the cmake eclass builds in
	# BUILD_DIR). The Qwen3.6 sibling binaries (strata-q36,
	# strata-device, strata-load, ...) are development/diagnostic
	# programs; upstream's package recipe stages the engine plus
	# the artifact tools only.
	local t
	for t in strata-plan strata-gguf strata-dequant ; do
	  test -x "${BUILD_DIR}"/${t} || die "${t} was not built"
	  dobin "${BUILD_DIR}"/${t}
	done
	if use cuda ; then
	  test -x "${BUILD_DIR}"/strata || die "the strata engine was not built although USE=cuda"
	  dobin "${BUILD_DIR}"/strata
	fi
	dodoc README.md LICENSE
	# Service payload from the strata/ files_dir shared with
	# app-ai/strata-bin (macaroni-os/kit-fixups#631 review):
	# conf.d always, then exactly ONE init flavour (geaaru's
	# rule on kit-fixups#511 -- the init script goes in the
	# else). The shipped unit and init script refuse to
	# start, with a plain message, when the engine binary is
	# absent (no USE=cuda) or STRATA_ENGINE_ARGS is unset --
	# the engine serves its GEN/T protocol only for a model
	# that already exists on disk (docs/SOURCE_INSTALL.md).
	newconfd "${FILESDIR}"/strata.confd strata
	if use systemd ; then
	  systemd_dounit "${FILESDIR}"/strata.service
	else
	  newinitd "${FILESDIR}"/strata.initd strata
	fi
}
pkg_postinst() {
	elog "app-ai/strata installs Strata's C++ inference engine (the"
	elog "strata binary is built only with USE=cuda; upstream provides"
	elog "no CPU-only engine) and its GGUF artifact tools. The engine"
	elog "needs an NVIDIA driver (libcuda.so.1) at run time and is"
	elog "driven by Strata's terminal/desktop layer together with model"
	elog "packs downloaded at run time; nothing model-related ships"
	elog "with the package (see macaroni-os/mark-issues#933)."
	elog "Service: /etc/conf.d/strata plus /etc/init.d/strata"
	elog "(or /usr/lib/systemd/system/strata.service with"
	elog "USE=systemd) supervise the engine's --serve request"
	elog "protocol (READY/GEN/T over stdin/stdout; the stdio"
	elog "end-point is a FIFO, see the conf.d comments). Set"
	elog "STRATA_ENGINE_ARGS to the args of your model's run"
	elog "config before enabling it; without USE=cuda there"
	elog "is no engine binary to run. The HTTP front-end that"
	elog "drives this worker ships with app-ai/strata-bin"
	elog "(strata-control.service, from the same shared"
	elog "payload directory; macaroni-os/kit-fixups#631)."
}



# vim: filetype=ebuild
