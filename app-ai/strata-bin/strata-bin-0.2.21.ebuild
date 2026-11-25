# Distributed under the terms of the GNU General Public License v2
# Autogen by MARK Devkit

EAPI=7
QA_PREBUILT="/usr/lib/strata-bin/*"
inherit systemd

DESCRIPTION="Strata Terminal and serving API for local AI (upstream binary)"
HOMEPAGE="https://github.com/Niko1221/Strata"
SRC_URI="
amd64? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-control-0.1.67-linux-x86_64.tar.gz -> strata-bin-0.2.21-strata-control-linux-x86_64.tar.gz )
arm64? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-control-0.1.67-linux-aarch64.tar.gz -> strata-bin-0.2.21-strata-control-linux-aarch64.tar.gz )
cuda12? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-cuda-cuda12.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-cuda-cuda12.tar.gz )
cuda13? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-cuda-cuda13.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-cuda-cuda13.tar.gz )
hip_rx6000? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-hip-rx6000.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-hip-rx6000.tar.gz )
hip_rx7900? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-hip-rx7900.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-hip-rx7900.tar.gz )
hip_rx9070? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-hip-rx9070.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-hip-rx9070.tar.gz )
hip_halo? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-hip-halo.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-hip-halo.tar.gz )
sycl? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-x86_64-sycl.tar.gz -> strata-bin-0.2.21-strata-engine-linux-x86_64-sycl.tar.gz )
arm64_cuda13? ( https://github.com/Niko1221/Strata/releases/download/v0.2.21/strata-engine-0.1.67-linux-aarch64-cuda-cuda13.tar.gz -> strata-bin-0.2.21-strata-engine-linux-aarch64-cuda-cuda13.tar.gz )"
LICENSE="MIT"
SLOT="0"
KEYWORDS="*"
IUSE="amd64 arm64 systemd cuda12 cuda13 hip_rx6000 hip_rx7900 hip_rx9070 hip_halo sycl arm64_cuda13"
REQUIRED_USE=" cuda12? ( amd64 ) cuda13? ( amd64 ) hip_rx6000? ( amd64 ) hip_rx7900? ( amd64 ) hip_rx9070? ( amd64 ) hip_halo? ( amd64 ) sycl? ( amd64 ) arm64_cuda13? ( arm64 )"
RESTRICT="strip"
RDEPEND="sys-libs/glibc
	
"
S="${WORKDIR}/control"
src_unpack() {
	# All distfiles here are FLAT archives (no top-level dir) and
	# the engine bundles share file names with each other (each
	# ships its own ./strata, BUILD.json, engine-component.json),
	# so they must extract into separate directories; portage's
	# unpack() cannot target one, hence direct tar with the
	# control bundle at ${S} (the cp -a idiom of the control-only
	# shape this entry keeps) and each engine under
	# ${WORKDIR}/engine-dist/<distfile>/.
	mkdir -p "${S}" || die
	local f d have_control=0
	for f in ${A}; do
		d="${WORKDIR}/engine-dist/${f}"
		case "${f}" in
			*-strata-control-*)
				d="${S}"
				have_control=1
				;;
		esac
		mkdir -p "${d}" || die
		tar xzf "${DISTDIR}/${f}" -C "${d}" || die "unpacking ${f}"
	done
	[ "${have_control}" -eq 1 ] ||
		die "no strata-control distfile for this architecture"
}

src_install() {
	local dest=/usr/lib/strata-bin
	dodir "${dest}"
	# Keep the bundle layout and upstream's exec bits (108
	# executables including the interpreter and bin/strata; doins
	# would flatten them to 644) via the cp -a idiom.
	cp -a "${S}/." "${D}${dest}/" || die "installing strata-control tree"
	# The bundle's launcher resolves its own path following
	# symlinks on purpose ("so `strata` can live on PATH", see
	# the header of bin/strata) -- sandbox-proved: dosym'd into
	# /usr/bin, --version rc 0 from the moved tree. The public
	# name is strata-control, NOT strata: app-ai/strata, the
	# SOURCE atom of the same upstream
	# (macaroni-os/kit-fixups#630), installs /usr/bin/strata --
	# file sets stay disjoint by construction, so no mutual
	# block is needed.
	dosym "${dest}/bin/strata" /usr/bin/strata-control

	# USE-selected engine bundles -> ${dest}/engines/<backend>/
	# (upstream's own backend token, e.g. cuda-cuda13). NOT
	# /usr/bin: the engine's main binary is also named strata
	# and must not collide with app-ai/strata (#630); the
	# directory is wired in by 'strata components add-build'
	# below, which is exactly its folder contract (strata, its
	# libraries and BUILD.json).
	local f name backend
	for f in "${WORKDIR}/engine-dist/"*-strata-engine-*; do
		[ -d "${f}" ] || continue
		name="$(basename "${f}")"
		backend="${name#*-strata-engine-}"
		backend="${backend%.tar.gz}"
		backend="${backend#linux-x86_64-}"
		backend="${backend#linux-aarch64-}"
		dodir "${dest}/engines/${backend}"
		cp -a "${f}/." "${D}${dest}/engines/${backend}/" ||
			die "installing strata engine ${backend}"
	done

	# Service payload from the shared strata/ files_dir (the
	# macaroni-os/kit-fixups#631 review ask): conf.d always,
	# then exactly ONE init flavour (geaaru's rule on
	# kit-fixups#511 -- the init script goes in the else).
	# strata-control.service reads the same
	# /etc/conf.d/strata-control through EnvironmentFile-,
	# like the ollama unit reads /etc/conf.d/ollama.
	newconfd "${FILESDIR}"/strata-control.confd strata-control
	if use systemd ; then
		systemd_dounit "${FILESDIR}"/strata-control.service
	else
		newinitd "${FILESDIR}"/strata-control.initd strata-control
	fi
}

pkg_postinst() {
	elog "${PF} is the upstream strata-control bundle installed"
	elog "under /usr/lib/strata-bin; start it as"
	elog "/usr/bin/strata-control."
	elog "Engines enabled via USE install under"
	elog "/usr/lib/strata-bin/engines/<backend>/ (NOT on PATH:"
	elog "the engine binary is also named strata and belongs to"
	elog "app-ai/strata, kit-fixups#630). Wire one up with the"
	elog "CLI's own contract (docs/SOURCE_INSTALL.md:"
	elog "'strata components add-build <folder>', the folder"
	elog "holding strata, its libraries and BUILD.json), e.g."
	elog "  strata-control components add-build \\"
	elog "    /usr/lib/strata-bin/engines/cuda-cuda13"
	elog "-- it is then a local, unsigned engine in use; 'use"
	elog "newest' goes back to upstream's signed runtime feed,"
	elog "which 'strata-control update' keeps serving either way"
	elog "(see macaroni-os/mark-issues#949)."
	elog "Headless serving: create a model run config first"
	elog "with 'strata-control launch' (the guided flow, or"
	elog "--yes --no-tui; that flow is where models are"
	elog "downloaded and prepared), point STRATA_PROFILE in"
	elog "/etc/conf.d/strata-control at its JSON path, then"
	elog "enable the service -- rc-update add"
	elog "strata-control default (OpenRC) or systemctl enable"
	elog "strata-control (USE=systemd, which installs the"
	elog "unit instead of the init script). The service runs"
	elog "'strata-control serve' and never downloads:"
	elog "without STRATA_PROFILE it refuses to start, on"
	elog "purpose. app-ai/strata, the source atom of the same"
	elog "upstream, ships the matching strata unit set from"
	elog "the same shared payload directory (the follow-up to"
	elog "macaroni-os/kit-fixups#631)."
}


# vim: filetype=ebuild
