# liquidgen plugin for VMD
# Setup a Molecular Liquid Simulation 

package require psfgen
package require namdgui
package provide liquify 1.0

# Setup namespace to prevent plugin conflicts
namespace eval ::Liquify {
	#namespace export liquify
	# window handler
	variable w
}
# GUI

proc Liquify::liquify {} {
	variable w
	set w [toplevel .liquify]
	set pdbfile ""
	wm title .liquify "Setup Molecular Liquid"

	# Frame containing PBD and PSF input fields
	# PDB File
	grid [labelframe .liquify.f1 -text "Load Molecule"]
	grid [label .liquify.f1.l1 -text "PDB File"] -column 0 -row 0
	grid [entry .liquify.f1.e1 -width 20 -textvariable pdbfile] \
	-column 1 -row 0
	grid [button .liquify.f1.b1 -text "Browse" -command {set pdbfile \
		[tk_getOpenFile]}] -column 2 -row 0
	# PSF File
	grid [label .liquify.f1.l2 -text "PSF File"] -column 0 -row 1
	grid [entry .liquify.f1.e2 -width 20 -textvariable psffile] \
		-column 1 -row 1
	grid [button .liquify.f1.b2 -text "Browse" -command {set psffile \
		[tk_getOpenFile]}] -column 2 -row 1
	
	# Frame containing box dimensions
	grid [labelframe .liquify.f2 -text "Box Dimensions"]
	grid [entry .liquify.f2.e1 -textvariable x -width 5] \
		-column 1 -row 0
	grid [entry .liquify.f2.e2 -textvariable y -width 5] \
		-column 1 -row 1
	grid [entry .liquify.f2.e3 -textvariable z -width 5] \
		-column 1 -row 2
	grid [label .liquify.f2.l1 -text "x"] -column 0 -row 0
	grid [label .liquify.f2.l2 -text "y"] -column 0 -row 1
	grid [label .liquify.f2.l3 -text "z"] -column 0 -row 2
	#grid [button .liquify.f2.b1 -text "print file" -command {vmdcon \
		-info "PDB file is $pdbfile $x $y $z"}]
	#grid [button .liquify.f2.b2 -text "print file" -command {vmdcon \
		-info "PSF file is $psffile"}]
}

proc liquify_tk {} {
	Liquify::liquify
	return $Liquify::w
}
# PBC
# ER
