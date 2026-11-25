# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
CMAKE_BUILD_TYPE=Release
inherit cmake systemd user

DESCRIPTION="Local inference engine for huge GGUF MoE models, with a web dashboard (GPU required)"
HOMEPAGE="https://github.com/mw00/project-maya"
SRC_URI="
https://api.github.com/repos/mw00/project-maya/tarball/v1.1.80 -> maya-1.1.80.tar.gz
https://github.com/ggml-org/llama.cpp/archive/3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz -> llama-cpp-3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="cuda cuda-native systemd
cuda_sm_60
cuda_sm_61
cuda_sm_70
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
cuda_sm_60? ( cuda )
cuda_sm_61? ( cuda )
cuda_sm_70? ( cuda )
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
RDEPEND="dev-lang/python
	dev-python/jinja
	${CDEPEND}
	
"
DEPEND="${CDEPEND}
"

post_src_unpack() {
	mv mw00-project-maya-* ${S}
}


pkg_setup() {
	ebegin "Ensuring maya user/group exist"
	enewgroup maya
	enewuser maya -1 -1 /var/lib/maya maya
}
src_prepare() {
	# EAPI 7 does not dispatch the cmake eclass' src_prepare
	# through default (cf. dev-util/opencl-icd-loader).
	cmake_src_prepare
	# Engines resolve via BUILD = ROOT / "build" (maya.py:103),
	# the single source of every engine path; they install in
	# /usr/bin, so point the constant there.
	sed -i 's|^BUILD = ROOT / "build"$|BUILD = Path("/usr/bin")|' \
	  maya.py || die "engine-path sed failed (BUILD constant in maya.py)"
	# The same constant is the --exe default of the offline
	# CLIs (tools/maya_quant/kl_eval.py:29, zs_engine.py:22,
	# tools/strata/glm53_long_gate.py:76).
	sed -i 's|pathlib\.Path(__file__)\.resolve()\.parents\[2\] / "build" / "maya"|pathlib.Path("/usr/bin") / "maya"|g' \
	  tools/maya_quant/kl_eval.py tools/maya_quant/zs_engine.py \
	  tools/strata/glm53_long_gate.py || die "tools engine-path sed failed"
	# Model downloads default to ROOT.parent/Maya-data/models
	# (six sites in maya.py): /usr/share/Maya-data on a system
	# prefix. Move the default to the user's home; upstream's
	# --models-dir and installer.models_dir still override it.
	sed -i 's|ROOT\.parent / "Maya-data" / "models"|Path.home() / "Maya-data" / "models"|g' \
	  maya.py || die "model-dir sed failed (maya.py)"
	# serve/models.py is NOT sed'ed: its fallback feeds
	# models_dirs(), a storage listing that filters home
	# folders out by design, not a download target.
}
src_configure() {
	addpredict /proc/self/task
	local mycmakeargs=(
	  -DSTRATA_BUILD_TESTS=OFF
	  -DSTRATA_WERROR=OFF
	  -DSTRATA_GGML_DIR=${WORKDIR}/llama.cpp-3cf03257f219afbe7334045ff7c6a06ac68c627d
	  -DSTRATA_ENABLE_CUDA=$(usex cuda ON OFF)
	)
	local cuda_archs= cuda_major= cuda_supported=
	local arch cuda_flagged=() cuda_dropped=()
	if use cuda ; then
	  # The enabled cuda_sm_* flags filtered against the set
	  # the installed toolkit major targets (per-major sets
	  # as in app-ai/ollama).
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
	  for arch in 60 61 70 75 80 86 87 89 90 90a 100 101 103 110 120 121 ; do
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
	# Precedence (as in app-ai/llama-cpp): flags, then
	# cuda-native, then the default; MYCMAKEARGS speaks last.
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
	# Upstream defines no install() rules; stage the binaries
	# by name (the cmake eclass builds in BUILD_DIR).
	local t
	for t in strata-plan strata-gguf strata-dequant ; do
	  test -x "${BUILD_DIR}"/${t} || die "${t} was not built"
	  dobin "${BUILD_DIR}"/${t}
	done
	if use cuda ; then
	  test -x "${BUILD_DIR}"/maya || die "the maya engine was not built although USE=cuda"
	  dobin "${BUILD_DIR}"/maya
	  # maya-ds4/maya-mm3 are defined only above their own
	  # CUDA arch floors (CMakeLists.txt); install what built.
	  local e
	  for e in maya-ds4 maya-mm3 ; do
	    if [[ -x "${BUILD_DIR}"/${e} ]] ; then
	      dobin "${BUILD_DIR}"/${e}
	    fi
	  done
	fi
	# The dashboard layer is a directory-relative Python app
	# (maya.py resolves ROOT to its own directory): app
	# sources and data files only.
	insinto /usr/share/maya
	doins -r serve tools data assets
	doins maya.py setup.py chat.py VERSION
	dodoc README.md SECURITY.md CONTRIBUTING.md
	dodoc LICENSE LICENSE.deepseek-v41 LICENSE.minimax-m31 LICENSE.qwen-community-1.0
	# /usr/bin/maya is the engine binary, so the dashboard
	# launcher takes the service-side name (the ollama
	# binary-vs-service split); maya.service runs this same
	# launcher, so the unit and the shell share one path.
	printf '%s\n' \
	  '#!/bin/sh' \
	  '# Project Maya dashboard launcher (app-ai/maya): the' \
	  '# packaged dashboard on the system interpreter; engines' \
	  '# resolve from /usr/bin and downloads default to' \
	  '# ~/Maya-data/models (see pkg_postinst).' \
	  '#   maya-server' \
	  '#       -> the dashboard on the mock engine' \
	  '#   maya-server --engine maya --config maya-<model>.json' \
	  '#       -> serve a downloaded model' \
	  'exec python3 /usr/share/maya/serve/server.py "$@"' \
	  > "${T}"/maya-server
	# newbin: the insinto above is still in effect (newins
	# would stage under /usr/share/maya).
	newbin "${T}"/maya-server maya-server
	# Service payload: /etc/conf.d always, then exactly one
	# init flavour -- the systemd unit with USE=systemd, the
	# OpenRC script without it; the unit reads the same
	# conf.d through EnvironmentFile-.
	newconfd "${FILESDIR}"/maya.confd maya
	if use systemd ; then
	  systemd_dounit "${FILESDIR}"/maya.service
	else
	  newinitd "${FILESDIR}"/maya.initd maya
	fi
	diropts -m0750 -o maya -g maya
	dodir /var/lib/maya
	keepdir /var/lib/maya
	diropts
}
pkg_postinst() {
	elog "app-ai/maya installs the engine binaries (USE=cuda only;"
	elog "upstream has no CPU-only engine) and the ggml artifact tools"
	elog "in /usr/bin, the dashboard layer in /usr/share/maya, and the"
	elog "dashboard launcher /usr/bin/maya-server (the name"
	elog "/usr/bin/maya is the engine itself)."
	elog ""
	elog "Model downloads default to ~/Maya-data/models; override"
	elog "with --models-dir on maya.py's setup flows or an"
	elog "installer.models_dir config entry."
	elog ""
	elog "The dashboard service: configure /etc/conf.d/maya"
	elog "(MAYA_HOST, MAYA_PORT, MAYA_API_KEY, MAYA_SERVER_ARGS)"
	elog "and enable it with rc-update add maya default, or"
	elog "systemctl enable maya with USE=systemd (which installs"
	elog "the unit instead of the init script). It runs as user"
	elog "maya with HOME=/var/lib/maya and never downloads:"
	elog "without a model's run config in MAYA_SERVER_ARGS the"
	elog "scripted mock engine answers. Set MAYA_API_KEY before"
	elog "binding MAYA_HOST to a routable address."
	elog ""
	elog "Per upstream the dashboard needs a Python 3.10 or newer"
	elog "interpreter, which the tree currently masks (see"
	elog "macaroni-os/mark-issues#932); the native engines are"
	elog "unaffected. Nothing model-related ships with the package."
}



# vim: filetype=ebuild
