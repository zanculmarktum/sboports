DISTDIR ?= ${SBODIR}/distfiles
PACKAGE_REPOSITORY ?= ${SBODIR}/packages
WRKDIR = ${CURDIR}/work

DIST_SUBDIR ?=
ifneq (${DIST_SUBDIR}, )
FULLDISTDIR ?= ${DISTDIR}/${DIST_SUBDIR}
else
FULLDISTDIR ?= ${DISTDIR}
endif

_SUBMAKE ?= no

_MAKE = ${MAKE} -s

_test_dir = \
	if ! mkdir -p $$dir >/dev/null 2>&1; then \
		echo "===>  Error: Unable to create $$dir directory" >&2; \
		exit 1; \
	fi; \
	if [ ! -w "$$dir" ]; then \
		echo "===>  Error: Unable to write to $$dir directory" >&2; \
		exit 1; \
	fi

_import_vars = \
	for ext in info SlackBuild; do \
		i=0; \
		for j in *.$$ext; do \
			if [ ! -f "$$j" ]; then \
				echo "===>  Error: No .$$ext file found" >&2; \
				exit 1; \
			fi; \
			i=$$(($$i+1)); \
		done; \
		if [ $$i -gt 1 ]; then \
			echo "===> Error: More than one .$$ext file found" >&2; \
			exit 1; \
		fi; \
	done; \
	. ./*.info; \
	eval $$(grep '^\(BUILD\|TAG\)=' *.SlackBuild); \
	case "$$( uname -m )" in \
		i?86) ARCH="i?86" ;; \
		arm*) ARCH="arm*" ;; \
		   *) ARCH=$$( uname -m ) ;; \
	esac

_import_urls = \
	url="$$DOWNLOAD"; \
	if [ "$$(uname -m)" = "x86_64" -a -n "$$DOWNLOAD_x86_64" ]; then \
		url="$$DOWNLOAD_x86_64"; \
	fi; \
	if [ "$$url" = "UNSUPPORTED" ]; then \
		echo "Fatal: Your architecture ($$(uname -m)) is not supported" >&2; \
		exit 1; \
	fi

_possible_pkgnames = \
	${PACKAGE_REPOSITORY}/$$PRGNAM-$$VERSION-$$ARCH-$$BUILD$$TAG.txz \
	${PACKAGE_REPOSITORY}/$$PRGNAM-$$VERSION-fw-$$BUILD$$TAG.txz \
	${PACKAGE_REPOSITORY}/$$PRGNAM-$$VERSION-noarch-$$BUILD$$TAG.txz \
	${PACKAGE_REPOSITORY}/$$PRGNAM-$$VERSION-x86-$$BUILD$$TAG.txz

_is_built = \
	built=false; \
	for f in ${_possible_pkgnames}; do \
		[ -f "$$f" ] || continue; \
		built=true; \
		break; \
	done; \
	$$built

_fetch_deps = SBODIR=${SBODIR} perl ${SBODIR}/bin/do-depends

_recurse_target = \
	for d in $$(${_fetch_deps} -p); do \
		if [ ! -d "$$d" ]; then \
			echo "===>  Fatal: Pkg ($$d) does not exist" >&2; \
			exit 1; \
		fi; \
		cd $$d; \
		_SUBMAKE=yes ${_MAKE} $$target || exit 1; \
	done

_okay_words = depends dist-depends work dist package \

_clean = ${clean}
ifeq (${clean}, depends)
_clean = work
endif
ifeq (${clean}, dist-depends)
_clean = dist
endif
ifeq (${clean}, all)
_clean = work dist package
endif

build all:
ifdef clean
	@found=false; \
	for w in ${_okay_words}; do \
		if [ "$$w" = "${clean}" ]; then \
			found=true; \
			break; \
		fi; \
	done; \
	if ! $$found; then \
		echo "Fatal: unknown clean command: ${clean}" >&2; \
		echo "(not in ${_okay_words})" >&2; \
		exit 1; \
	fi; \
	${_MAKE} _internal-clean clean=${clean}
else
	@${_import_vars}; \
	${_is_built} || ${_MAKE} _internal-$@
endif

install-depends: ${SBODIR}/INDEX
ifneq (${_SUBMAKE}, yes)
	@target=install; ${_recurse_target}
endif

install: build
	@${_import_vars}; \
	echo "===>  Installing $$PRGNAM-$$VERSION from ${PACKAGE_REPOSITORY}"; \
	for f in /var/log/packages/$$PRGNAM-$$VERSION-*; do \
		[ -f "$$f" ] || continue; \
		pkg="$${f##*/}"; \
		pkg="$${pkg%-*}"; \
		pkg="$${pkg%-*}"; \
		pkg="$${pkg%-*}"; \
		if [ "$$pkg" = "$$PRGNAM" ]; then \
			echo "Package $$PRGNAM-$$VERSION is already installed"; \
			exit 0; \
		fi; \
	done; \
	pkg_file=""; \
	i=0; \
	for f in ${_possible_pkgnames}; do \
		[ -f "$$f" ] || continue; \
		pkg_file="$$f"; \
		i=$$(($$i+1)); \
	done; \
	if [ $$i -gt 1 ]; then \
		echo "Error: More than one package found" >&2; \
		exit 1; \
	elif [ $$i -eq 0 ]; then \
		echo "Fatal: No package found" >&2; \
		exit 1; \
	fi; \
	[ "$$(id -u)" = "0" ] && SUDO="" || SUDO=sudo; \
	$$SUDO /sbin/upgradepkg --install-new $$pkg_file; \
	if [ -n "$$SUDO" -a "$$?" != "0" ]; then \
		echo "Error: No password entered" >&2; \
		exit 1; \
	fi

uninstall deinstall:
	@${_import_vars}; \
	echo "===> Deinstalling for $$PRGNAM-$$VERSION"; \
	found=false; \
	for f in /var/log/packages/$$PRGNAM-*; do \
		[ -f "$$f" ] || continue; \
		pkg="$${f##*/}"; \
		pkg="$${pkg%-*}"; \
		pkg="$${pkg%-*}"; \
		pkg="$${pkg%-*}"; \
		if [ "$$pkg" = "$$PRGNAM" ]; then \
			found=true; \
			break; \
		fi; \
	done; \
	if $$found; then \
		[ "$$(id -u)" = "0" ] && SUDO="" || SUDO=sudo; \
		$$SUDO /sbin/removepkg "$$f"; \
		if [ -n "$$SUDO" -a "$$?" != "0" ]; then \
			echo "Error: No password entered" >&2; \
			exit 1; \
		fi; \
	else \
		echo "Package $$PRGNAM-$$VERSION is already deinstalled"; \
	fi

fetch:
	@dir=${FULLDISTDIR}; ${_test_dir}
	@${_import_vars}; \
	${_import_urls}; \
	echo "===>  Fetching files for $$PRGNAM-$$VERSION"; \
	for u in $$url; do \
		f="${FULLDISTDIR}/$${u##*/}"; \
		[ -f "$$f" ] && continue; \
		echo ">> $$u"; \
		while :; do \
			curl -L -R -C - -Y 1 -y 10 -k -g -o "$$f".part "$$u"; \
			ret="$$?"; \
			case "$$ret" in \
				0) mv -f "$$f".part "$$f";; \
				33) rm -f "$$f".part; continue;; \
				18|28|56|35) continue;; \
				*) exit "$$ret";; \
			esac; \
			break; \
		done; \
	done

fetch-depends: ${SBODIR}/INDEX
ifneq (${_SUBMAKE}, yes)
	@target=fetch; ${_recurse_target}
	@${_MAKE} fetch
endif

checksum:
	@${_import_vars}; \
	${_import_urls}; \
	md5="$$MD5SUM"; \
	if [ "$$(uname -m)" = "x86_64" -a -n "$$MD5SUM_x86_64" ]; then \
		md5="$$MD5SUM_x86_64"; \
	fi; \
	echo "===>  Checking files for $$PRGNAM-$$VERSION"; \
	if cd ${FULLDISTDIR} 2>/dev/null; then \
		i=0; \
		for u in $$url; do \
			j=0; \
			for m in $$md5; do \
				[ "$$i" -eq "$$j" ] && break; \
				j=$$(($$j+1)); \
			done; \
			echo "$$m $${u##*/}" | md5sum -c; \
			i=$$(($$i+1)); \
		done; \
	fi

checksum-depends: ${SBODIR}/INDEX
ifneq (${_SUBMAKE}, yes)
	@target=checksum; ${_recurse_target}
	@${_MAKE} checksum
endif

_internal-build _internal-all:
	@for f in ${FULLDISTDIR}/* ${FULLDISTDIR}/.*; do \
		if [ ! -e "$$f" ]; then \
			echo "===>  Error: No distribution files found" >&2; \
			echo "Try running \"make fetch\" first" >&2; \
			exit 1; \
		fi; \
		base_f="$${f##*/}"; \
		if [ "$$base_f" = "." -o "$$base_f" = ".." ]; then \
			continue; \
		fi; \
		ln -sf "$$f" "$$base_f"; \
	done
	@for dir in ${WRKDIR} ${PACKAGE_REPOSITORY}; do \
		${_test_dir}; \
	done
	@${_import_vars}; \
	echo "===>  Building for $$PRGNAM-$$VERSION"; \
	FAKEROOT=""; \
	if [ "$$(id -u)" != "0" ]; then \
		which fakeroot >/dev/null 2>&1 && FAKEROOT=fakeroot; \
	fi; \
	[ -x "$$PRGNAM.SlackBuild" ] || chmod +x $$PRGNAM.SlackBuild; \
	PATH=/usr/local/sbin:/usr/sbin:/sbin:$$PATH \
	LC_COLLATE=C \
	MAKEFLAGS="" MAKELEVEL="" MAKE_TERMERR="" MFLAGS="" \
	TMP="${WRKDIR}" \
	OUTPUT="${PACKAGE_REPOSITORY}" \
	PKGTYPE="txz" \
	$$FAKEROOT ./$$PRGNAM.SlackBuild

_internal-clean: ${SBODIR}/INDEX
ifneq (${_SUBMAKE}, yes)
ifeq ($(filter depends,${clean}), depends)
	@target=clean; ${_recurse_target}
endif
ifeq ($(filter dist-depends,${clean}), dist-depends)
	@target=distclean; ${_recurse_target}
endif
endif
	@${_import_vars}; \
	echo "===>  Cleaning for $$PRGNAM-$$VERSION"
ifeq ($(filter work,${_clean}), work)
	@rm -rf ${WRKDIR}; \
	for l in * .*; do \
		[ "$$l" = "." -o "$$l" = ".." ] && continue; \
		real_l=$$(readlink "$$l"); \
		[ "$${real_l#${FULLDISTDIR}}" = "$$real_l" ] || rm -rf "$$l"; \
	done
endif
ifeq ($(filter dist,${_clean}), dist)
	@${_import_vars}; \
	echo "===>  Dist cleaning for $$PRGNAM-$$VERSION"; \
	if cd ${FULLDISTDIR} 2>/dev/null; then \
		${_import_urls}; \
		for f in .* *; do \
			[ "$$f" = "." -o "$$f" = ".." ] && continue; \
			found=false; \
			for u in $$url; do \
				upstream_f="$${u##*/}"; \
				if [ "$$f" = "$$upstream_f" -o "$$f" = "$$upstream_f".part ]; then \
					found=true; \
					break; \
				fi; \
			done; \
			if ! $$found; then \
				echo 'rm -f "$$f"'; \
				rm -f "$$f"; \
			fi; \
		done; \
	fi
endif
ifeq ($(filter package,${_clean}), package)
	@${_import_vars}; \
	if cd ${PACKAGE_REPOSITORY} 2>/dev/null; then \
		for f in $$PRGNAM-*.t?z; do \
			[ "$$f" = "." -o "$$f" = ".." ] && continue; \
			pkg="$${f%-*}"; \
			pkg="$${pkg%-*}"; \
			pkg="$${pkg%-*}"; \
			[ "$$pkg" = "$$PRGNAM" ] || continue; \
			found=false; \
			for p in ${_possible_pkgnames}; do \
				base_p="$${p##*/}"; \
				if [ "$$f" = "$$base_p" ]; then \
					found=true; \
					break; \
				fi; \
			done; \
			if ! $$found; then \
				echo 'rm -f "$$f"'; \
				rm -f "$$f"; \
			fi; \
		done; \
	fi
endif

rebuild:
	@${_MAKE} _internal-build

clean:
	@${_MAKE} _internal-clean clean=work

clean-depends:
	@${_MAKE} clean=depends

distclean:
	@${_MAKE} clean=dist

distclean-depends:
	@${_MAKE} clean=dist-depends

print-depends: ${SBODIR}/INDEX
	@${_import_vars}; \
	echo "This pkg requires package(s) \"$$(${_fetch_deps})\" to build and/or run."

include ${SBODIR}/mk/main.mk

.PHONY: all build rebuild install install-depends \
	uninstall deinstall clean clean-depends distclean \
	distclean-depends fetch fetch-depends checksum \
	checksum-depends print-depends _internal-all \
	_internal-build _internal-clean
