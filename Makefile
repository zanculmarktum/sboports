all:
	@:

setup:
ifndef DESTDIR
	@echo "The setup target requires a DESTDIR parameter,"
	@echo "e.g.: \"make setup DESTDIR=/path/to/slackbuilds/repo/\""
else
	@if [ ! -d "$$DESTDIR" ]; then \
		echo "===>  Error: $$DESTDIR is not a directory or it does not exist" >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$$DESTDIR/.git/" ]; then \
		echo "===>  Error: $$DESTDIR does not look like a git repository" >&2; \
		exit 1; \
	fi; \
	if ! which git >/dev/null 2>&1; then \
		echo "===>  Error: No git found on your system" >&2; \
		exit 1; \
	fi; \
	cd $$DESTDIR; \
		if [ "$$(git config --get remote.origin.url)" != "git://git.slackbuilds.org/slackbuilds.git" ]; then \
			echo "===>  Error: $$DESTDIR does not look like a slackbuilds repository" >&2; \
			exit 1; \
		fi; \
		categories=$$(git ls-tree -d --name-only HEAD); \
		packages=$$(git ls-tree -dr --name-only HEAD | awk -F/ 'NF==2{print $$0}'); \
	cd - >/dev/null; \
	echo "===>  Creating Makefile"; \
	n=$$(sed -ne '/@category@/=' src/Makefile.in); \
	>$$DESTDIR/Makefile; \
	sed -ne "1,$$(($$n-1))p" src/Makefile.in >>$$DESTDIR/Makefile; \
	for cat in $$categories; do \
		echo "SUBDIR += $$cat" >>$$DESTDIR/Makefile; \
	done; \
	sed -ne "$$(($$n+1)),"'$$p' src/Makefile.in >>$$DESTDIR/Makefile; \
	echo "===>  Creating bin subdir"; \
	rm -rf $$DESTDIR/bin; \
	mkdir -p $$DESTDIR/bin; \
	cp -pf src/bin/* $$DESTDIR/bin; \
	echo "===>  Creating mk subdir"; \
	rm -rf $$DESTDIR/mk; \
	mkdir -p $$DESTDIR/mk; \
	cp -pf src/mk/*.mk $$DESTDIR/mk; \
	for cat in $$categories; do \
		echo "===>  Creating $$cat/Makefile and $$cat/*/Makefile"; \
		pkgs=$$(echo "$$packages" | sed -ne "\,^$$cat/,s,,,p"); \
		mkdir -p $$DESTDIR/$$cat; \
		>$$DESTDIR/$$cat/Makefile; \
		echo 'SBODIR = $${CURDIR:/'"$$cat"'=}' >>$$DESTDIR/$$cat/Makefile; \
		echo "" >>$$DESTDIR/$$cat/Makefile; \
		for pkg in $$pkgs; do \
			echo 'SUBDIR += '"$$pkg" >>$$DESTDIR/$$cat/Makefile; \
		done; \
		echo "" >>$$DESTDIR/$$cat/Makefile; \
		echo 'include $${SBODIR}/mk/sbo.subdir.mk' >>$$DESTDIR/$$cat/Makefile; \
		for pkg in $$pkgs; do \
			if [ -f "$$DESTDIR/$$cat/$$pkg/Makefile" ]; then \
				while read line; do \
					if [ "$${line#SBODIR}" = "$$line" ]; then \
						echo "Warning: $$cat/$$pkg/Makefile is already exists" >&2; \
						continue 2; \
					fi; \
					break; \
				done <$$DESTDIR/$$cat/$$pkg/Makefile; \
			fi; \
			mkdir -p $$DESTDIR/$$cat/$$pkg; \
			>$$DESTDIR/$$cat/$$pkg/Makefile; \
			echo 'SBODIR = $${CURDIR:/'"$$cat"'/'"$$pkg"'=}' >>$$DESTDIR/$$cat/$$pkg/Makefile; \
			echo "" >>$$DESTDIR/$$cat/$$pkg/Makefile; \
			echo 'DIST_SUBDIR ?= '"$$pkg" >>$$DESTDIR/$$cat/$$pkg/Makefile; \
			echo "" >>$$DESTDIR/$$cat/$$pkg/Makefile; \
			echo 'include $${SBODIR}/mk/sbo.mk' >>$$DESTDIR/$$cat/$$pkg/Makefile; \
		done; \
	done
endif

.PHONY: all setup
