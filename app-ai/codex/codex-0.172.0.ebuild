# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
PYTHON_COMPAT=( python3+ )
inherit python-any-r1 toolchain-funcs

DESCRIPTION="OpenAI's Codex CLI coding agent"
HOMEPAGE="https://github.com/openai/codex"
SRC_URI="https://api.github.com/repos/openai/codex/tarball/rust-v0.172.0 -> codex-0.172.0.tar.gz"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
PATCHES=(
	"${FILESDIR}/codex-0.167.1-python39.patch"
	"${FILESDIR}/codex-0.167.1-system-ripgrep.patch"
	"${FILESDIR}/codex-0.167.1-system-voice.patch"
)
IUSE="voice"
RESTRICT="network-sandbox"
BDEPEND=">=virtual/rust-1.96
	dev-libs/openssl
	virtual/pkgconfig
	sys-libs/zlib
	sys-apps/coreutils
	
"
RDEPEND="!app-ai/codex-bin
	dev-libs/openssl
	sys-libs/zlib
	voice? (
	  media-libs/gstreamer
	  media-libs/gst-plugins-good
	  media-libs/gst-plugins-bad[opus]
	)
	|| (
	  sys-apps/ripgrep-bin
	  sys-apps/ripgrep
	)
	sys-apps/bubblewrap
	
"
DEPEND="${RDEPEND}
"

post_src_unpack() {
	mv openai-codex-* ${S}
}


src_compile() {
	# Keep the cargo registry and git checkouts in the build
	# area (they are fetched by src_compile, not src_unpack,
	# because the dependency graph is network-resolved).
	export CARGO_HOME="${T}/cargo-home"
	export CARGO_TARGET_DIR="${S}/codex-rs/target"
	export CODEX_REPO_ROOT="${S}"
	export TMPDIR="${T}"
	export STABLE_GIT_COMMIT="main"
	 local rust_target
	rust_target=$(rustc -vV | sed -n 's/^host: //p') || die
	[[ -n ${rust_target} ]] || die "could not determine the native Rust target"
	case ${rust_target} in
	  x86_64-unknown-linux-gnu|aarch64-unknown-linux-gnu) ;;
	  *) die "native voice resources require x86_64 or aarch64 glibc Linux" ;;
	esac
	 # Use the externally packaged sandbox; Codex embeds its exact digest.
	local bwrap
	bwrap=$(command -v bwrap) || die "bwrap (sys-apps/bubblewrap) must be installed."
	CODEX_BWRAP_SHA256=$(sha256sum "${bwrap}") || die
	export CODEX_BWRAP_SHA256=${CODEX_BWRAP_SHA256%% *}
	 local rg_bin
	rg_bin=$(command -v rg) || die "ripgrep must be installed."
	 cd "${S}" || die
	# Upstream builds codex, code-mode-host and exec-server, configures the
	# matching checksum-verified V8 artifacts, and writes the package manifest.
	${EPYTHON} scripts/build_codex_package.py \
	  --bwrap-bin "${bwrap}" \
	  --rg-bin "${rg_bin}" \
	  --target "${rust_target}" \
	  --variant codex \
	  --package-version "0.172.0" \
	  --cargo-profile release \
	  --strip all --strip-tool "$(tc-getSTRIP)" \
	  --package-dir "${T}/codex-package" --force || die "assembling Codex package failed"
	 if use voice ; then
	   # Use the system GStreamer ABI and the seven explicitly loaded plugins.
	  local gst_libdir plugin
	   gst_libdir=$(pkg-config --variable=libdir gstreamer-1.0) || die
	  export CODEX_SYSTEM_GSTREAMER_CORE="${gst_libdir}/libgstreamer-1.0.so.0"
	  CODEX_SYSTEM_GSTREAMER_PLUGIN_DIR=$(pkg-config --variable=pluginsdir gstreamer-1.0) || die
	  export CODEX_SYSTEM_GSTREAMER_PLUGIN_DIR
	  [[ -f ${CODEX_SYSTEM_GSTREAMER_CORE} ]] || die "system GStreamer library is missing"
	  [[ -n ${CODEX_SYSTEM_GSTREAMER_PLUGIN_DIR} ]] || die "system GStreamer plugin path is missing"
	  for plugin in app audioconvert audioresample coreelements opus rtp rtpmanager; do
	    [[ -f ${CODEX_SYSTEM_GSTREAMER_PLUGIN_DIR}/libgst${plugin}.so ]] || die "missing GStreamer plugin: ${plugin}"
	  done
	   ${EPYTHON} "${FILESDIR}/build_codex_voice.py" \
	    --source "${S}" \
	    --package "${T}/codex-package" \
	    --output "${T}/codex-package-voice" \
	    --target "${rust_target}" \
	    --commit "${STABLE_GIT_COMMIT}" --version "0.172.0" \
	    --pkg-config "pkg-config" \
	    --strip "$(tc-getSTRIP)" \
	    || die "building and assembling voice resources failed"
	fi
}
src_install() {
	local package_dir="${T}"/codex-package
	for b in codex codex-code-mode-host codex-exec-server ; do
	  dobin "${package_dir}"/bin/${b}
	done
	# Remove bwrap and ripgrep binary and the bin/*. We use the packages.
	rm -rf "${package_dir}"/codex-path "${package_dir}"/bin/
	dodir /usr/lib/codex/
	cp -a "${package_dir}/codex-package.json" "${package_dir}/codex-resources/" \
	  "${ED}/usr/lib/codex/" || die
	if use voice ; then
	    cp -a "${T}"/codex-package-voice/codex-resources \
	    "${ED}/usr/lib/codex/" || die
	fi
	rm "${ED}"/usr/lib/codex/codex-resources/bwrap || true
	# Executables were stripped before the voice manifest was generated.
	# Preserve all bytes covered by its checksums and the embedded bwrap digest.
	dostrip -x /usr/lib/codex
	dodoc README.md
}



# vim: filetype=ebuild
