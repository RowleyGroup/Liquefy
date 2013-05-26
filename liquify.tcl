# liquidgen plugin for VMD
# Setup a Molecular Liquid Simulation 

package require psfgen
package require namdgui
package provide liquify 1.0

# Setup namespace to prevent plugin conflicts
namespace eval ::liquify {
	#namespace export liquify
	# window handler
	variable w
	set w [toplevel .liquify]
	# Simulation parameters
	variable options
	set options(niter) 100
	set options(pdbfile) ""
	set options(psffile) ""
	set options(cube) 0
	set options(reject) 0
	foreach n {x y z} {
		set options($n) 10
	}
}
# GUI

proc ::liquify::build_gui {} {
	variable w
	variable options
	parray options
	wm title $w "Setup Molecular Liquid"

	set twidth 50 ;# text box width
	set nwidth 10 ;# number box width

	# Note: all options passed to Tk have to be qualified with namespace
	# or they refer to global vars
	
	# Frame containing PBD and PSF input fields
	# PDB File
	grid [labelframe $w.f1 -text "Load Molecule"] \
		-columnspan 2 -rowspan 1
	grid [label $w.f1.l1 -text "PDB File"] -column 0 -row 0
	grid [entry $w.f1.e1 -width $twidth -textvariable \
		::liquify::options(pdbfile)] -column 1 -row 0
	grid [button $w.f1.b1 -text "Browse" -command {set \
		::liquify::options(pdbfile) [tk_getOpenFile]}] -column 2 -row 0
	
	# PSF File
	grid [label $w.f1.l2 -text "PSF File"] -column 0 -row 1
	grid [entry $w.f1.e2 -width $twidth -textvariable \
		::liquify::options(psffile)] -column 1 -row 1
	grid [button $w.f1.b2 -text "Browse" -command {set \
		::liquify::options(psffile) [tk_getOpenFile]}] -column 2 -row 1
	
	# Frame containing box dimensions
	grid [labelframe $w.f2 -text "Box Dimensions"] \
		-column 0 -row 1
	grid [entry $w.f2.e1 -textvariable ::liquify::options(x) -width \
		$nwidth] -column 1 -row 0
	grid [entry $w.f2.e2 -textvariable ::liquify::options(y) -width \
		$nwidth] -column 1 -row 1
	grid [entry $w.f2.e3 -textvariable ::liquify::options(z) -width \
		$nwidth] -column 1 -row 2
	grid [label $w.f2.l1 -text "x"] -column 0 -row 0
	grid [label $w.f2.l2 -text "y"] -column 0 -row 1
	grid [label $w.f2.l3 -text "z"] -column 0 -row 2
	grid [label $w.f2.l4 -text "Use Cube"] \
		-column 2 -row 0
	grid [checkbutton $w.f2.c1 -variable ::liquify::options(cube)] \
	-column 3 -row 0

	# Frame containing number iterations
	grid [labelframe $w.f4 -text "Runtime Options"] \
		-column 1 -row 1
	grid [label $w.f4.l1 -text "Number of iterations"] \
		-column 0 -row 0
	grid [spinbox $w.f4.s1 -textvariable ::liquify::options(niter) \
		-from 100 -to 1000 -increment 50 -width $nwidth] -column 1 -row 0
	grid [label $w.f4.l2 -text "Use early rejection"] \
		-column 0 -row 1
	grid [checkbutton $w.f4.c1 -variable ::liquify::options(reject)] \
		-column 1 -row 1

	# Frame containing generate and reset buttons
	grid [labelframe $w.f5 -text "Populate Box"] -columnspan 2 -rowspan 1
	grid [button $w.f5.b1 -text "Populate!" -command \
		{::liquify::populate}]


	# Save new PDB and PSF files
	# Click button save -> prompt for directory and name
	grid [labelframe $w.f3 -text "Save New Data"] \
		-columnspan 2 -rowspan 1
	grid [label $w.f3.l1 -text "Location"] -column 0 -row 0
	grid [entry $w.f3.e1 -textvariable ::liquify::options(savedir) \
		-width $twidth] -column 1 -row 0
	grid [button $w.f3.b1 -text "Browse" -command {set \
		::liquify::options(savedir)	[tk_chooseDirectory]}] \
		-column 2 -row 0
}

# temp
proc ::liquify::print_options {} {
	variable options
	parray options
}

# Start populating the box
proc ::liquify::populate {} {
	puts "Populating!!"
	print_options
}

# VMD menu calls this function when selected
proc ::liquify_tk {} {
	::liquify::build_gui
	return $liquify::w
}
# PBC
# ER
	#grid [button $w.f1.b4 -text "Load" \
	-command {mol new $psffile type psf first 0 last -1 step 1 waitfor 1}] \
	-column 3 -row 1
