# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7

DESCRIPTION="OpenAI's Codex CLI coding agent (built from sources)"
HOMEPAGE="https://github.com/openai/codex"
SRC_URI="https://api.github.com/repos/openai/codex/tarball/rust-v0.167.1 -> codex-0.167.1.tar.gz"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
RESTRICT="network-sandbox"
BDEPEND=">=virtual/rust-1.96
	dev-libs/openssl
	virtual/pkgconfig
	sys-libs/zlib
	
"
RDEPEND="!app-ai/codex-bin
	dev-libs/openssl
	sys-libs/zlib
	
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
	cd codex-rs || die
	cargo build --release -p codex-cli --bin codex \
	  --target-dir target || die
}

src_install() {
	newbin codex-rs/target/release/codex codex
	dodoc README.md
}



# vim: filetype=ebuild
