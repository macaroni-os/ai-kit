# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module cmake

DESCRIPTION="Get up and running with OpenAI gpt-oss, DeepSeek-R1, Gemma 3 and other models."
HOMEPAGE="https://ollama.com"
SRC_URI="
https://api.github.com/repos/ollama/ollama/tarball/v0.11.7 -> ollama-0.11.7-d3450dd.tar.gz
mirror://macaroni/ollama-0.11.7-mark-go-bundle-d3450dd.tar.xz -> ollama-0.11.7-mark-go-bundle-d3450dd.tar.xz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
BDEPEND=">=dev-lang/go-1.24
	
"

post_src_unpack() {
	mv ollama-ollama-* ${S}
}


src_prepare() {
	default
	go-module_src_prepare
	cmake_src_prepare
}
src_compile() {
	cmake_src_compile
	go build -mod=mod . || die "compile failed"
}
src_install() {
	cmake_src_install
	dobin ollama
	dodoc README.md
}



# vim: filetype=ebuild
