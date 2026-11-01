# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/lib/pi/pi /usr/lib/pi/native/*/*/*/*.node"

DESCRIPTION="AI agent toolkit: unified LLM API, agent loop, TUI, coding agent CLI (built from sources)"
HOMEPAGE="https://github.com/earendil-works/pi"
SRC_URI="https://github.com/earendil-works/pi/releases/download/v1.4.0/pi-1.4.0-source.tar.gz -> pi-1.4.0-source.tar.gz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
RESTRICT="strip network-sandbox"
BDEPEND=">=net-libs/nodejs-22.19.0
	|| ( dev-lang/bun dev-lang/bun-bin )
	
"
RDEPEND="!app-ai/pi-bin
"
src_compile() {
	# Upstream release recipe (scripts/build-binaries.sh
	# --offline-model-data), linux only. Keep npm's cache and
	# HOME inside the build area.
	export HOME="${T}"
	export npm_config_cache="${T}/npm-cache"

	# Install the JS dependency graph from the committed
	# package-lock.json (.npmrc has save-exact=true, so pins
	# are exact). --ignore-scripts exactly like upstream: the
	# hooks are dev tooling (the husky prepare would want git).
	npm ci --ignore-scripts || die "npm ci failed (needs npm-registry access)"

	# Workspace chain build telemetry -> chord -> tui ->
	# codemode -> mcp -> ai:build:offline -> durable -> env ->
	# agent -> coding-agent; the offline variant never shells
	# out to hydrate:model-data, the hydrated model snapshot
	# is compiled in from the archive.
	npm run build:offline || die

	cd packages/coding-agent || die
	local bun_target platform_arch
	case ${ARCH} in
		amd64) bun_target=bun-linux-x64-baseline; platform_arch=linux-x64 ;;
		arm64) bun_target=bun-linux-arm64; platform_arch=linux-arm64 ;;
		*) die "unsupported ARCH: ${ARCH}" ;;
	esac

	# --compile embeds the bun runtime (hence RESTRICT=strip);
	# the two worker scripts must stay explicit entrypoints so
	# that they are embedded (upstream comment), and the
	# autoload opt-outs are upstream issues #7684 and #10473.
	bun build --compile --no-compile-autoload-bunfig \
		--no-compile-autoload-dotenv --target="${bun_target}" \
		./dist/bun/cli.js ./src/utils/image-resize-worker.ts \
		./src/extensions/codemode/worker.ts --outfile dist/pi || die

	# Stage the release directory like the "Copy shared files"
	# loop of scripts/build-binaries.sh. examples/ is skipped:
	# demo TypeScript the program never reads, and the pi-bin
	# flavour does not install it either.
	local stage=${S}/pi-stage
	mkdir -p "${stage}"/theme "${stage}"/assets \
		"${stage}"/native/linux/prebuilds || die
	cp dist/pi package.json README.md CHANGELOG.md "${stage}"/ || die
	cp ../../node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm \
		"${stage}"/ || die
	cp dist/modes/interactive/theme/*.json "${stage}"/theme/ || die
	cp dist/modes/interactive/assets/* "${stage}"/assets/ || die
	cp -r dist/core/export-html docs "${stage}"/ || die
	cp -R ../tui/native/linux/prebuilds/"${platform_arch}" \
		"${stage}"/native/linux/prebuilds/ || die
}

src_install() {
	# Identical file set and layout to the pi-bin entry above:
	# the executable resolves every runtime sidecar relative to
	# dirname(process.execPath) (getPackageDir in
	# packages/coding-agent/src/config.ts), so the whole staged
	# tree goes under /usr/lib/pi and /usr/bin/pi is a symlink
	# into it; README/CHANGELOG go in via dodoc.
	cd "${S}/pi-stage" || die
	insinto /usr/lib/pi
	doins -r native theme export-html assets docs
	doins photon_rs_bg.wasm package.json
	exeinto /usr/lib/pi
	doexe pi
	dosym /usr/lib/pi/pi /usr/bin/pi
	dodoc README.md CHANGELOG.md
}


# vim: filetype=ebuild
