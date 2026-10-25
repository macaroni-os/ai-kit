# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7

DESCRIPTION="The open source AI coding agent (built from sources)"
HOMEPAGE="https://opencode.ai"
SRC_URI="https://api.github.com/repos/anomalyco/opencode/tarball/refs/tags/v2.1.4 -> opencode-2.1.4-68bc26b.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
RESTRICT="strip network-sandbox"
BDEPEND="|| ( dev-lang/bun dev-lang/bun-bin )
"
RDEPEND="!app-ai/opencode-bin
"

post_src_unpack() {
	mv anomalyco-opencode-* ${S}
}


src_prepare() {
	default
	# packages/script/src/index.ts hard-fails unless the running
	# bun satisfies ^1.4.4 (root package.json packageManager pin).
	# Downgrade the throw to a warning, exactly like the postPatch
	# of upstream's nix/opencode.nix derivation.
	sed -i \
	  's/throw new Error(`This script requires bun/console.warn(`Warning: This script requires bun/' \
	  packages/script/src/index.ts || die
}

src_configure() { :; }

src_compile() {
	# Keep bun's download cache inside the build area.
	export BUN_INSTALL_CACHE_DIR="${T}/bun-cache"
	 # Pin the embedded version/channel: without OPENCODE_VERSION
	# the shared build script queries registry.npmjs.org at build
	# time, and without OPENCODE_CHANNEL it shells out to git,
	# neither of which belongs in an ebuild sandbox (nix recipe
	# sets the same pair).
	export OPENCODE_VERSION="2.1.4"
	export OPENCODE_CHANNEL="prod"
	# The bundle is memory-hungry; same bump as nix/opencode.nix.
	export NODE_OPTIONS="--max-old-space-size=4096"
	 # Install the JS dependency graph from the checked-in lockfile,
	# scoped like upstream's nix/node_modules.nix recipe (root
	# workspace for peer resolution + the CLI, the embedded web UI
	# and the desktop workspace). Scripts are skipped: they only
	# set up dev tooling. NOTE: this needs network access; see the
	# spec comment and PR #480 for the offline-build discussion.
	bun install \
	  --filter './' \
	  --filter './packages/cli' \
	  --filter './packages/desktop' \
	  --filter './packages/app' \
	  --frozen-lockfile \
	  --ignore-scripts \
	  --no-progress || die "bun install failed (needs npm-registry access)"
	 # --single: build only the native glibc target of this ARCH
	#   (v1 wrote dist/opencode-linux-<arch>/, v2 dist/cli-linux-
	#   <arch>/, so the install phase globs for the binary).
	# --skip-install: dependency graph prepared just above.
	local clipkg=packages/cli
	[[ -d ${clipkg} ]] || clipkg=packages/opencode
	cd "${clipkg}" || die
	bun --bun ./script/build.ts --single --skip-install || die
}

src_install() {
	# dist/<target>/bin/opencode, exactly one target with --single.
	local bin=$(find packages/cli/dist packages/opencode/dist \
	  -type f -path '*/bin/opencode' -print -quit 2>/dev/null)
	[[ -n ${bin} ]] || die "compiled binary not found under packages/*/dist"
	newbin "${bin}" opencode
}



# vim: filetype=ebuild
