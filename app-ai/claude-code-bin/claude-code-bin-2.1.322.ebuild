# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/bin/claude"

DESCRIPTION="Anthropic's Claude Code agentic coding CLI (upstream binary)"
HOMEPAGE="https://code.claude.com/docs/en/overview"
SRC_URI="
amd64? ( https://github.com/anthropics/claude-code/releases/download/v2.1.322/claude-linux-x64.tar.gz -> claude-code-bin-2.1.322-amd64-linux.tar.gz )
arm64? ( https://github.com/anthropics/claude-code/releases/download/v2.1.322/claude-linux-arm64.tar.gz -> claude-code-bin-2.1.322-arm64-linux.tar.gz )"
LICENSE="Anthropic PBC"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64"
RESTRICT="strip"
S="${WORKDIR}"
src_install() {
	newbin claude claude
}


# vim: filetype=ebuild
