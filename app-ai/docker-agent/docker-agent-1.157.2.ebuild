# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module

DESCRIPTION="AI Agent Builder and Runtime by Docker Engineering"
HOMEPAGE="https://docker.github.io/docker-agent/"
SRC_URI="
https://api.github.com/repos/docker/docker-agent/tarball/v1.157.2 -> docker-agent-1.157.2-c83962d.tar.gz
mirror://macaroni/docker-agent-1.157.2-mark-go-bundle-c83962d.tar.xz -> docker-agent-1.157.2-mark-go-bundle-c83962d.tar.xz"
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
	  "-X \"github.com/docker/docker-agent/pkg/version.Version=1.157.2\""
	  "-X \"github.com/docker/docker-agent/pkg/version.Commit=c83962d5e3a056e59def1d0cc4d62e6a437cfe63\""
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
