# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/lib/pi/pi /usr/lib/pi/native/*/*/*/*.node"

DESCRIPTION="AI agent toolkit: unified LLM API, agent loop, TUI, coding agent CLI (upstream binary)"
HOMEPAGE="https://github.com/earendil-works/pi"
SRC_URI="
amd64? ( https://github.com/earendil-works/pi/releases/download/v1.4.0/pi-linux-x64.tar.gz -> pi-1.4.0-amd64-linux.tar.gz )
arm64? ( https://github.com/earendil-works/pi/releases/download/v1.4.0/pi-linux-arm64.tar.gz -> pi-1.4.0-arm64-linux.tar.gz )"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64"
RESTRICT="strip network-sandbox"
RDEPEND="!app-ai/pi
"
S="${WORKDIR}/pi"
src_install() {
	# Install the executable together with every sidecar in
	# one directory so the execPath-relative lookups keep
	# working through the /usr/bin/pi symlink.
	insinto /usr/lib/pi
	doins -r native theme export-html assets docs
	doins photon_rs_bg.wasm package.json
	exeinto /usr/lib/pi
	doexe pi
	dosym /usr/lib/pi/pi /usr/bin/pi
	dodoc README.md CHANGELOG.md
}


# vim: filetype=ebuild
