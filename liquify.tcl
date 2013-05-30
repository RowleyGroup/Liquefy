# liquidgen plugin for VMD
# Setup a Molecular Liquid Simulation 

package provide liquify 1.0
package require psfgen
package require pbctools

# Setup namespace to prevent plugin conflicts
namespace eval ::liquify {
	#namespace export liquify
	
	# window handler
	variable w
	set w [toplevel .liquify]

	# Simulation parameters
	variable options

	# Constants
	#variable PI
	#set PI $math::constants::pi
}

# Build a window to allow user input of parameters
# $w will be passed by global liquify_tk to VMD
proc ::liquify::build_gui {} {
	variable w
	variable options
	wm title $w "Setup Molecular Liquid"

	set twidth 50 ;# text box width
	set nwidth 10 ;# number box width

	# Note: all options passed to Tk have to be qualified with namespace
	# or they refer to global vars
	
	# Frame containing PBD and PSF input fields
	# PDB File
	grid [labelframe $w.f1 -text "Load Molecule"] -columnspan 2 -rowspan 1

	set row 0
	foreach n {pdb psf top} {
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
		set e [entry $w.f2.$n-e1 -textvariable ::liquify::options($n) -width $nwidth \
		-validate key -vcmd {string is int %P}]
		#	-validate key -vcmd {string is int %P}]
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
		-from 100 -to 1000 -increment 50 -width $nwidth -validate key \
		-vcmd {string is int %P}]
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

	set cmd "::liquify::reset"
	set b [button $w.f5.b2 -text "Reset" -command $cmd]
	grid $b -column 1 -row 0
}

# Save new PDB and PSF files
proc ::liquify::save_files {} {
	puts "saving files...maybe"
}

# Start populating the box
proc ::liquify::populate {} {
	variable atoms
	variable options
	vmdcon -info "Reset display field..."
	# Remove any molecules currently loaded
	::liquify::clear_mols
	vmdcon -info "Populating..."
	# Add new molecule
	vmdcon -info "Loading PBD file \{$options(pdb)\}..."
	if [catch {mol new $options(pdb) type pdb} err] {
		vmdcon -info "Halting box fill!"
		return 1
	}
	vmdcon -info "...done"
	# Load structure information into new molecule
	vmdcon -info "Loading PSF data into new molecule..."
	if [catch {mol addfile $options(psf) type psf} err] {
		vmdcon -info "Halting box fill!"
		return 1
	}
	vmdcon -info "...done"
	topology $options(top)
	set parentid [molinfo top]
	# Check box dimensions
	# values will be ints (entry validation)
	if $options(cube) {
		foreach i {y z} {
			set options($i) $options(x)
		}
	}
	foreach i {x y z} {
		if {$options($i) <= 0} {
			vmdcon -err "Box dimensions must be greater than 0!"
			vmdcon -info "Halting box fill!"
			return 1
		}
	}
	
	# Retrive info from parent molecule
	set atoms [atomselect top all]
	set resids [lsort -unique [$atoms get resid]]
	set resnames [lsort -unique [$atoms get resname]]
	set atomnames [$atoms get name]
	set coords [join [$atoms get {name x y z}]]
	# Replicate parent molecule
	for {set i 1} {$i < $options(niter)} {incr i} {
		set segname S$i
		segment $segname {
			first NONE
			last NONE
			foreach resname $resnames {
				residue 1 $resname
			}
		}
		coordpdb $options(pdb) $segname

		# It seems necessary to write to file in order to get
		# segment recognized XXX
		set tempid [molinfo top]
		writepdb tmp.pdb
		writepsf tmp.psf
		mol delete	$tempid
		mol load psf tmp.psf pdb tmp.pdb

		set atoms [atomselect top "segname $segname"]
		foreach n {x y z} {
			$atoms move [transaxis $n [::liquify::random_angle]]
		}
		$atoms move [transoffset [::liquify::random_xyz]]
		set data [join [$atoms get {segid resid name x y z}]]
		foreach {segid resid name x y z} $data {
			coord $segid $resid $name "$x $y $z"
		}
	}

	# Use pbctools to draw periodic box
	pbc set "$options(x) $options(y) $options(z)" -all
	pbc box -center origin ;# draw box
	mol delete $parentid
	writepdb tmp.pdb
	writepsf tmp.psf
	vmdcon -info "Finished molecule replication"
}

# Clear all input and loaded molecules
proc ::liquify::reset {} {
	variable options
	::liquify::clear_mols
	::liquify::set_defaults
}

# Reset input fields to default
proc ::liquify::set_defaults {} {
	variable options
	set options(niter) 10
	set options(pdb) "/home/leif/src/liquify/thiophene/thiophene.pdb"
	set options(psf) "/home/leif/src/liquify/thiophene/thiophene.psf"
	set options(cube) 0
	set options(reject) 0
	foreach n {x y z} {
		set options($n) 75
	}
}

# Return {x y z} list of random points within periodic box
proc ::liquify::random_xyz {} {
	variable options
	set dr {}
	foreach n {x y z} {
		set val [expr ($options($n) * rand()) - ($options($n) / 2.0)]
		lappend dr $val
	}
	puts "DR: $dr"
	return $dr
}

proc ::liquify::random_angle {} {
	return [expr (360.0 * rand())]
}

# Unload all molecules
# Reasoning: for setting up liquids -> no other molecules
# can just delete a few after to put in another foreign molecule
# if desired
proc ::liquify::clear_mols {} {
	vmdcon -info "Removing [molinfo num] molecules"
	set idlist [molinfo list]
	foreach id $idlist {
		mol delete $id
	}
	resetpsf
	vmdcon -info "...done"
}

# VMD menu calls this function when selected
proc ::liquify_tk {} {
	::liquify::set_defaults
	::liquify::build_gui
	return $liquify::w
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
