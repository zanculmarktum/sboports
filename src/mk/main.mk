_upperdir = _curdir=${CURDIR}; _curdir=$${_curdir\#${SBODIR}}; \
	upperdir=""; \
	while [ -n "$$_curdir" ]; do \
		_curdir=$${_curdir%/*}; \
		upperdir=../$${upperdir}; \
	done

index:
	@rm -f ${SBODIR}/INDEX
	@${MAKE} -s ${SBODIR}/INDEX

${SBODIR}/INDEX:
	@echo "Generating INDEX..."
	@perl ${SBODIR}/bin/do-index ${SBODIR} >$@
	@echo "Done."

print-index: ${SBODIR}/INDEX
	@${_upperdir}; awk -F\| '{ printf("Pkg:\t%s-%s\nPath:\t'$$upperdir'%s\nInfo:\t%s\nMaint:\t%s\nDeps:\t%s\n\n", $$1, $$2, $$3, $$4, $$6, $$7); }' ${SBODIR}/INDEX

search:	${SBODIR}/INDEX
ifeq (${key}${name}, )
	@echo "The search target requires a keyword or name parameter,"
	@echo "e.g.: \"make search key=somekeyword\" \"make search name=somename\""
else
ifdef key
	@${_upperdir}; awk -F\| '{ for (i=1; i<=NF; i++) { if (index(tolower($$i), tolower("${key}"))) { printf("Pkg:\t%s-%s\nPath:\t'$$upperdir'%s\nInfo:\t%s\nMaint:\t%s\nDeps:\t%s\n\n", $$1, $$2, $$3, $$4, $$6, $$7); break; } } }' ${SBODIR}/INDEX
else
	@${_upperdir}; awk -F\| 'index($$1, "${name}") { printf("Pkg:\t%s-%s\nPath:\t'$$upperdir'%s\nInfo:\t%s\nMaint:\t%s\nDeps:\t%s\n\n", $$1, $$2, $$3, $$4, $$6, $$7); }' ${SBODIR}/INDEX
endif
endif

.PHONY: index print-index search
