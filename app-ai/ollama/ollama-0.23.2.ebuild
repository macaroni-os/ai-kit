# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module cmake user

DESCRIPTION="Get up and running with Kimi-K2.5, GLM-5, MiniMax, DeepSeek, gpt-oss, Qwen, Gemma and other models."
HOMEPAGE="https://ollama.com"
SRC_URI="
https://api.github.com/repos/ollama/ollama/tarball/v0.23.2 -> ollama-0.23.2-f866e76.tar.gz
mirror://macaroni/ollama-0.23.2-mark-go-bundle-f866e76.tar.xz -> ollama-0.23.2-mark-go-bundle-f866e76.tar.xz"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="systemd clang cuda vulkan"
BDEPEND=">=dev-lang/go-1.24
	clang? ( sys-devel/clang )
	
"
RDEPEND="vulkan? (
	  media-libs/vulkan-loader
	  media-libs/shaderc
	)
	cuda? (
	  dev-util/nvidia-cuda-toolkit
	)
	
"
DEPEND="${RDEPEND}
"

post_src_unpack() {
	mv ollama-ollama-* ${S}
}


pkg_setup() {
	ebegin "Ensuring ollama user/group exist"
	enewgroup ollama
	enewuser ollama -1 -1 /var/lib/ollama ollama
}
src_configure() {
	addpredict /proc/self/task
	local mycmakeargs=()
	if use clang ; then
	  mycmakeargs+=(
	    -DCMAKE_C_COMPILER=clang
	    -DCMAKE_CXX_COMPILER=clang++
	  )
	fi
	cmake_src_configure
}
src_prepare() {
	default
	go-module_src_prepare
	cmake_src_prepare
}
src_compile() {
	cmake_src_compile
	local ollama_ldflags=(
	   "-X github.com/ollama/ollama/version.Version=${PV}"
	)
	go build --ldflags "${ollama_ldflags[*]}" -mod=mod . || die "compile failed"
}
src_install() {
	cmake_src_install
	dobin ollama
	diropts -m0750 -o ollama -g ollama
	dodir /var/lib/ollama /var/lib/ollama/models/
	keepdir /var/lib/ollama/
	diropts
	dodoc README.md
	newconfd "${FILESDIR}"/ollama.confd ollama
	if use systemd ; then
	  systemd_dounit "${FILESDIR}"/ollama.service
	else
	  newinitd "${FILESDIR}"/ollama.initd ollama
	fi
	newenvd "${FILESDIR}"/ollama.envd "90ollama"
}



# vim: filetype=ebuild
