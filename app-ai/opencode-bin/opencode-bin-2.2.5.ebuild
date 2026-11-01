# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/bin/opencode"

DESCRIPTION="The open source AI coding agent (upstream binary)"
HOMEPAGE="https://opencode.ai"
SRC_URI="
amd64? ( https://github.com/anomalyco/opencode/releases/download/v2.2.5/opencode-linux-x64.tar.gz -> opencode-2.2.5-amd64-linux.tar.gz )
arm64? ( https://github.com/anomalyco/opencode/releases/download/v2.2.5/opencode-linux-arm64.tar.gz -> opencode-2.2.5-arm64-linux.tar.gz )"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64"
RESTRICT="strip"
RDEPEND="!app-ai/opencode
"
S="${WORKDIR}"
src_install() {
	newbin opencode opencode
}


# vim: filetype=ebuild
