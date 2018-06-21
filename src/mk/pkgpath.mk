PKGPATH ?= ${CURDIR}

_fragment = \
	for subdir in ${SUBDIR}; do \
		(cd $$subdir && SBODIR=${SBODIR} PKGPATH=${PKGPATH}/$$subdir ${MAKE} -s $@); \
	done
