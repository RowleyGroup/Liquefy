# liquidgen plugin for VMD
# Setup a Molecular Liquid Simulation 

package provide liquify 1.0
#package require psfgen
#package require namdgui

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

# Build a window to allow user input of parameters
# $w will be passed by global liquify_tk to VMD
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
	grid [labelframe $w.f1 -text "Load Molecule"] -columnspan 2 -rowspan 1

	set row 0
	foreach n {pdb psf} {
		set bigname [string toupper $n]
		set l [label $w.f1.$n-l1 -text "$bigname File"]
		set e [entry $w.f1.$n-e1 -width $twidth -textvariable ::liquify::options($n)] 
		set cmd "set ::liquify::options($n) \[tk_getOpenFile\]"
		set b [button $w.f1.$n-b1 -text "Browse" -command $cmd]
		grid $l -column 0 -row $row
		grid $e -column 1 -row $row
		grid $b -column 2 -row $row
		incr row
	}
	
	# Frame containing box dimensions
	grid [labelframe $w.f2 -text "Box Dimensions"] -column 0 -row 1
	
	set row 0
	foreach n {x y z} {
		set e [entry $w.f2.$n-e1 -textvariable ::liquify::options($n) -width $nwidth]
		set l [label $w.f2.$n-l1 -text "$n"]
		grid $l -column 0 -row $row
		grid $e -column 1 -row $row
		incr row
	}

	set l [label $w.f2.l4 -text "Use Cube"]
	set c [checkbutton $w.f2.c1 -variable ::liquify::options(cube)]
	grid $l -column 2 -row 0
	grid $c -column 3 -row 0

	# Frame containing number iterations
	grid [labelframe $w.f4 -text "Runtime Options"] -column 1 -row 1

	set l [label $w.f4.l1 -text "Number of iterations"]
	set s [spinbox $w.f4.s1 -textvariable ::liquify::options(niter) \
		-from 100 -to 1000 -increment 50 -width $nwidth]
	grid $l -column 0 -row 0
	grid $s -column 1 -row 0

	set l [label $w.f4.l2 -text "Use early rejection"]
	set c [checkbutton $w.f4.c1 -variable ::liquify::options(reject)]
	grid $l -column 0 -row 1
	grid $c -column 1 -row 1

	# Save new PDB and PSF files
	# Click button save -> prompt for directory and name
	grid [labelframe $w.f3 -text "Save New Data"] -columnspan 2 -rowspan 1
	
	set l [label $w.f3.l1 -text "Location"] 
	set e [entry $w.f3.e1 -textvariable ::liquify::options(savedir) -width $twidth] 
	set cmd "set ::liquify::options(savedir) \[tk_chooseDirectory\]"
	set b [button $w.f3.b1 -text "Browse" -command $cmd]
	grid $l -column 0 -row 0
	grid $e -column 1 -row 0
	grid $b -column 2 -row 0

	set l [label $w.f3.l2 -text "Name"]
	set e [entry $w.f3.e2 -textvariable ::liquify::options(savefile) -width $twidth]
	set cmd "::liquify::save_files"
	set b [button $w.f3.b2 -text "Save PBD/PSF" -command $cmd]
	grid $l -column 0 -row 1
	grid $e -column 1 -row 1
	grid $b -column 2 -row 1
	
	# Frame containing generate and reset buttons
	grid [labelframe $w.f5 -text "Populate Box"] -columnspan 2 -rowspan 1

	set cmd "::liquify::populate"
	set b [button $w.f5.b1 -text "Fill!" -command $cmd]
	grid $b -column 0 -row 0
}

# temp
proc ::liquify::print_options {} {
	variable options
	parray options
}

# Save new PDB and PSF files
proc ::liquify::save_files {} {
	puts "saving files...maybe"
}

# Start populating the box
proc ::liquify::populate {} {
	vmdcon -info "Reset display field..."
	::liquify::reset
	vmdcon -info "Populating..."
	foreach n {pdb psf} {
		set bigname [string toupper $n]
		vmdcon -info "Loading $bigname file..."
		set err [::liquify::add_mol $::liquify::options($n)]
		if {$err} {
			vmdcon -info "Halting box fill!"
			return 1
		}
		vmdcon -info "$bigname loaded successfully"
	}
}

# Unload all molecules
proc ::liquify::reset {} {
	vmdcon -info "Removing [molinfo num] molecules"
	set idlist [molinfo list]
	foreach id $idlist {
		mol delete $id
	}
	vmdcon -info "...done"
}

# VMD menu calls this function when selected
proc ::liquify_tk {} {
	::liquify::build_gui
	return $liquify::w
}

proc ::liquify::add_mol {pdbfile} {
	# Use VMD file handling
	return [catch {mol addfile $pdbfile} err]
}
# Need to validate user input
proc ::liquify::validate_input {} {
	variable options
	puts "Input validation..."
}
# PBC
# ER
	#grid [button $w.f1.b4 -text "Load" \
	-command {mol new $psffile type psf first 0 last -1 step 1 waitfor 1}] \
	-column 3 -row 1
