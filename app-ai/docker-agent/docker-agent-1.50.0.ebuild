# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module

DESCRIPTION="AI Agent Builder and Runtime by Docker Engineering"
HOMEPAGE="https://docker.github.io/docker-agent/"
SRC_URI="
https://api.github.com/repos/docker/docker-agent/tarball/v1.50.0 -> docker-agent-1.50.0-45f74a1.tar.gz
mirror://macaroni/docker-agent-1.50.0-mark-go-bundle-45f74a1.tar.xz -> docker-agent-1.50.0-mark-go-bundle-45f74a1.tar.xz"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="+compress"
BDEPEND="virtual/pkgconfig
	compress? ( app-arch/upx-bin )
	
"

post_src_unpack() {
	mv docker-docker-agent-* ${S}
}


src_compile() {
	custom_ldflags=(
	  "-X \"github.com/docker/docker-agent/pkg/version.Version=1.50.0\""
	  "-X \"github.com/docker/docker-agent/pkg/version.Commit=45f74a168c09a99019bff39e5f5a4b65df98c406\""
	)
	go build \
	  -ldflags "${custom_ldflags[*]}" \
	  -o docker-agent -v -x || die
	if use compress ; then
	  upx --brute -1 docker-agent || die
	fi
}
src_install() {
	exeinto /usr/libexec/docker/cli-plugins
	doexe docker-agent
	dodoc README.md
}



# vim: filetype=ebuild
