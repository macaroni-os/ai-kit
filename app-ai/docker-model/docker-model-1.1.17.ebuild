# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
inherit go-module

DESCRIPTION="Docker Model Runner"
HOMEPAGE="https://github.com/docker/model-runner"
SRC_URI="
https://api.github.com/repos/docker/model-runner/tarball/v1.1.17 -> docker-model-1.1.17-8babe24.tar.gz
mirror://macaroni/docker-model-1.1.17-mark-go-bundle-8babe24.tar.xz -> docker-model-1.1.17-mark-go-bundle-8babe24.tar.xz"
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="compress +runner"
BDEPEND="virtual/pkgconfig
	compress? ( app-arch/upx-bin )
	
"

post_src_unpack() {
	mv docker-model-runner-* ${S}
}


src_compile() {
	# Compile model-cli
	pushd cmd/cli >/dev/null
	local cli_ldflags=(
	  "-X \"github.com/docker/model-runner/cmd/cli/desktop.Version=1.1.17\""
	)
	local runner_ldflags=(
	  "-X \"main.Version=1.1.17\""
	)
	go build \
	  -ldflags "${cli_ldflags[*]}" \
	  -o ../../docker-model -v -x || die
	popd >/dev/null
	if use compress ; then
	  upx --brute -1 docker-model || die
	fi
	 if use runner ; then
	  go build \
	    -ldflags "${runner_ldflags[*]}" \
	    -o model-runner
	fi
}
src_install() {
	exeinto /usr/libexec/docker/cli-plugins
	doexe docker-model
	dodoc README.md
	if use runner ; then
	  dobin model-runner
	fi
}



# vim: filetype=ebuild
