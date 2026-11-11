# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/bin/codex"

DESCRIPTION="OpenAI's Codex CLI coding agent (upstream binary)"
HOMEPAGE="https://github.com/openai/codex"
SRC_URI="
amd64? ( https://github.com/openai/codex/releases/download/rust-v0.167.1/codex-x86_64-unknown-linux-musl.tar.gz -> codex-bin-0.167.1-amd64-linux.tar.gz )
arm64? ( https://github.com/openai/codex/releases/download/rust-v0.167.1/codex-aarch64-unknown-linux-musl.tar.gz -> codex-bin-0.167.1-arm64-linux.tar.gz )"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64"
RESTRICT="strip"
RDEPEND="!app-ai/codex
"
S="${WORKDIR}"
src_install() {
	# Exactly one of the two USE-gated assets is fetched per
	# profile, so there is a single binary in the workdir.
	local bin=$(find . -maxdepth 1 -type f \
		-name 'codex-*-unknown-linux-musl' -print -quit)
	[[ -n ${bin} ]] || die "codex binary not found in ${S}"
	newbin "${bin}" codex
}


# vim: filetype=ebuild
