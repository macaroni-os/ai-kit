# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/lib/codex/bin/* /usr/lib/codex/codex-resources/voice/bin/* /usr/lib/codex/codex-resources/voice/lib/*"

DESCRIPTION="OpenAI's Codex CLI coding agent (upstream binary)"
HOMEPAGE="https://github.com/openai/codex"
SRC_URI="
amd64? ( https://github.com/openai/codex/releases/download/rust-v0.169.0/codex-package-x86_64-unknown-linux-musl.tar.gz -> codex-bin-0.169.0-amd64-linux.tar.gz )
arm64? ( https://github.com/openai/codex/releases/download/rust-v0.169.0/codex-package-aarch64-unknown-linux-musl.tar.gz -> codex-bin-0.169.0-arm64-linux.tar.gz )"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64"
RESTRICT="strip"
RDEPEND="!app-ai/codex
	sys-apps/bubblewrap
	sys-apps/ripgrep-bin
	
"
S="${WORKDIR}"
src_install() {
	local required
	for required in codex-package.json bin/codex bin/codex-code-mode-host ; do
		[[ -f ${required} ]] || die "upstream package is missing ${required}"
		if [[ ${required} != codex-package.json ]]; then
			[[ -x ${required} ]] || die "upstream helper is not executable: ${required}"
		fi
	done

	dodir /usr/lib/codex
	cp -a codex-package.json bin codex-path codex-resources \
		"${ED}/usr/lib/codex/" || die "failed to install upstream package"
	# The bundled helpers are distro packages here: bwrap from
	# sys-apps/bubblewrap and rg from sys-apps/ripgrep-bin
	# (RDEPEND), per the review on this PR.
	rm -f "${ED}"/usr/lib/codex/codex-resources/bwrap \
		"${ED}"/usr/lib/codex/codex-path/rg || die "failed to drop bundled helpers"
	dosym ../lib/codex/bin/codex /usr/bin/codex
}


# vim: filetype=ebuild
