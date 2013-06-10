installdir=${HOME}/vmdplugins/liquify

all:
	@echo "Nothing to build"

install: liquify.tcl pkgIndex.tcl vmdrc
	@echo "Copying files..."
	mkdir -p ${installdir}
	cp liquify.tcl ${installdir}/
	cp pkgIndex.tcl ${installdir}/
	cp vmdrc ${HOME}/.vmdrc

pkgIndex.tcl:
	@echo "Generating pkgIndex.tcl ..."
	( echo pkg_mkIndex . liquify.tcl ) | tclsh

clean:
	rm pkgIndex.tcl
