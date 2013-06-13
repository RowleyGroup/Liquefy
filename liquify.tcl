## ################################################################## ##
## Liquify - Build a Molecular Liquid								  ##
##   -A plugin for written for VMD-                                   ##
##                                                                    ##
## Given a parent molecule, this plugin constructs a liquid contained ##
## within a periodic cell.  New PDB, PSF, and XSC files are written   ##
## for the liquid.                                                    ##
##                                                                    ##
## Version: 1.0                                                       ##
## Authors: Leif Hickey and Christopher N. Rowley                     ##
## Contact: leif.hickey@mun.ca, cnrowley@mun.ca                       ##
## http://www.mun.ca/compchem                                         ##
## Date: 06/13/13                                                     ##
## ################################################################## ##

package provide liquify 1.0
package require psfgen
package require pbctools

## Create namespace to prevent plugin conflicts
namespace eval ::liquify {
	#namespace export liquify
	
	# window handle
	variable w

	# Simulation parameters
	variable options
	variable segname
	set segname LIQ
	variable density
	set density {0 g/mL}
	variable tot_resid
	set tot_resid 0

	# Constants
	variable PI
	set PI 3.1415926
	variable A3_to_mL
	set A3_to_mL 1.0e-24 ;# cubic angstroms to mL conversion
}

##
## VMD menu calls this function to pop up GUI
##
proc ::liquify_tk {} {
	::liquify::build_gui
	return $liquify::w
}

##
## CLI call
##
proc ::liquify::liquify { args } {
	#if ![llength $args]
	puts pass
}

##
## Build a window to allow user input of parameters
## $w will be passed by global liquify_tk to VMD
##
proc ::liquify::build_gui {} {
	variable w
	variable options

	if {[winfo exists .liquify]} {
		 wm deiconify $w ;# Bring window to front
		return
	}

	set w [toplevel .liquify]
	wm title $w "Build Molecular Liquid"
	::liquify::set_defaults

	set twidth 50 ;# text box width
	set nwidth 5 ;# number box width

	# Note: all options passed to Tk have to be qualified with namespace
	# or they refer to global vars
	
	# Frame containing PBD and PSF input fields
	grid [labelframe $w.f1 -text "Input Files of Molecule"] \
		-columnspan 2 -rowspan 1 -sticky news

	set row 0
	foreach n {pdb psf top} {
		set bigname [string toupper $n]
		set l [label $w.f1.$n-l1 -text "$bigname File"]
		set e [entry $w.f1.$n-e1 -width $twidth -textvariable ::liquify::options($n)] 
		set cmd "set ::liquify::options($n) \[tk_getOpenFile\]"
		set b [button $w.f1.$n-b1 -text "Browse" -command $cmd]
		grid $l -column 0 -row $row -sticky e
		grid $e -column 1 -row $row -sticky ew
		grid $b -column 2 -row $row -sticky w
		incr row
	}
	
	# Frame containing box dimensions
	grid [labelframe $w.f2 -text "Box Dimensions"] -column 0 -row 1 \
		-sticky news
	
	set row 0
	foreach n {x y z} {
		set e [entry $w.f2.$n-e1 -textvariable ::liquify::options($n) -width $nwidth \
		-validate key -vcmd {string is int %P}]
		#	-validate key -vcmd {string is int %P}]
		set l [label $w.f2.$n-l1 -text "$n"]
		grid $l -column 0 -row $row -sticky e
		grid $e -column 1 -row $row -sticky w
		incr row
	}

	set cmd {
		if {$::liquify::options(cube)} {
			$::liquify::w.f2.y-e1 config -state readonly
			$::liquify::w.f2.z-e1 config -state readonly
		} else {
			$::liquify::w.f2.y-e1 config -state normal
			$::liquify::w.f2.z-e1 config -state normal
		}
	}
			
	set l [label $w.f2.l4 -text "Cubic Periodic Cell"]
	set c [checkbutton $w.f2.c1 -variable ::liquify::options(cube) \
		-command $cmd]
	grid $l -column 2 -row 0 -sticky e
	grid $c -column 3 -row 0 -sticky w

	# Frame containing runtime options
	grid [labelframe $w.f4 -text "Runtime Options"] -column 1 -row 1 \
		-sticky news

	set l [label $w.f4.l1 -text "Failed iteration cutoff"]
	set s [spinbox $w.f4.s1 -textvariable ::liquify::options(niter) \
		-from 100 -to 1000 -increment 50 -width $nwidth -validate key \
		-vcmd {string is int %P}]
	grid $l -column 0 -row 0 -sticky e
	grid $s -column 1 -row 0 -sticky w

	set l [label $w.f4.l2 -text "Use early rejection"]
	set c [checkbutton $w.f4.c1 -variable ::liquify::options(reject)]
	grid $l -column 0 -row 1 -sticky e
	grid $c -column 1 -row 1 -sticky w

	set l [label $w.f4.l3 -text "Density estimate (g/mL)"]
	set e [entry $w.f4.e1 -textvariable ::liquify::options(density) \
	-width $nwidth -validate key -vcmd {string is double %P}]
	grid $l -column 0 -row 2 -sticky e
	grid $e -column 1 -row 2 -sticky w

	set l [label $w.f4.l4 -text "Scaling factor for van der Waals radii"]
	set e [entry $w.f4.e2 -textvariable ::liquify::options(adj_radii) \
	-width $nwidth -validate key -vcmd {string is double %P}]
	grid $l -column 0 -row 3 -sticky e
	grid $e -column 1 -row 3 -sticky w

	# Frame containing new save location
	grid [labelframe $w.f3 -text "Save Location for New Data"] \
		-columnspan 2 -rowspan 1 -sticky news
	
	set l [label $w.f3.l1 -text "Location"] 
	set e [entry $w.f3.e1 -textvariable ::liquify::options(savedir) -width $twidth] 
	set cmd "set ::liquify::options(savedir) \[tk_chooseDirectory\]"
	set b [button $w.f3.b1 -text "Browse" -command $cmd]
	grid $l -column 0 -row 0 -sticky e
	grid $e -column 1 -row 0 -sticky ew
	grid $b -column 2 -row 0 -sticky w

	set l [label $w.f3.l2 -text "Name"]
	set e [entry $w.f3.e2 -textvariable ::liquify::options(savefile) -width $twidth]
	set cmd "::liquify::save_reload"
	set b [button $w.f3.b2 -text "Save PBD/PSF" -command $cmd]
	grid $l -column 0 -row 1 -sticky e
	grid $e -column 1 -row 1 -sticky ew
	#grid $b -column 2 -row 1
	
	# Frame containing Fill and Reset buttons
	grid [labelframe $w.f5 -text "Populate Box"] \
		-column 0 -row 3 -sticky nsew

	set cmd "::liquify::populate"
	set b [button $w.f5.b1 -text "Fill!" -command $cmd]
	grid $b -column 1 -row 0

	set cmd {
		::liquify::clear_mols
		::liquify::set_defaults
	}
	set b [button $w.f5.b2 -text "Reset" -command $cmd]
	grid $b -column 2 -row 0

	# Frame containing post-population results
	grid [labelframe $w.f6 -text "Results"] \
		-column 1 -row 3 -sticky news
	
	set l1 [label $w.f6.l1 -text "Randomly packed density:"]
	set l2 [label $w.f6.l2 -textvariable ::liquify::density]
	set cmd {
		set ::liquify::density [format "%.4f g/mL" [::liquify::calc_density]]
	}
	set b [button $w.f6.b1 -text "Recalculate" -command $cmd]
	grid $l1 -column 0 -row 0 -sticky e
	grid $l2 -column 1 -row 0 -sticky w
	grid $b -column 2 -row 0 -sticky e

	set l1 [label $w.f6.l3 -text "Molecules added:"]
	set l2 [label $w.f6.l4 -textvariable ::liquify::tot_resid]
	grid $l1 -column 0 -row 1 -sticky e
	grid $l2 -column 1 -row 1 -sticky w
}

##
## Reset input and results to default
##
proc ::liquify::set_defaults {} {
	variable options
	set options(niter) 150
	set options(pdb) ""
	set options(psf) ""
	set options(top) ""
	set options(savedir) $::env(PWD)
	set options(savefile) myliquid
	set options(cube) 0
	set options(reject) 1
	set options(adj_radii) 1.0
	set options(density) 1.0
	foreach n {x y z} {
		set options($n) 30
	set ::liquify::tot_resid 0
	set ::liquify::density {0.0 g/mL}
	}
}

##
## Create a 'clean' state to build the liquid in
##
proc ::liquify::clear_mols {} {
	vmdcon -info "Removing [molinfo num] molecules"
	psfcontext reset
	set idlist [molinfo list]
	foreach id $idlist {
		mol delete $id
	}
	vmdcon -info "...done"
}

##
## Save PDB/PSF data and reload. Called after constructing new segment
## and changing coordinates.
##
proc ::liquify::save_reload {name} {
	writepdb $name.pdb
	writepsf $name.psf

	mol delete [molinfo top]
	mol load psf $name.psf pdb $name.pdb
}

##
## Returns 1 (true) for valid user input.
## Loads parent molecule.
##
proc ::liquify::validate_input {} {
	variable w
	variable options
	vmdcon -info "Input validation..."


	if {[llength $options(savefile)] == 0} {
		vmdcon -err "No save filename given! Halting."
		return 0
	}

	# User confirm to overwrite existing files
	set basename "$options(savedir)/$options(savefile)"
	if {[file exists $basename.pdb] || \
		[file exists $basename.psf] || \
		[file exists $basename.xsc]} {
			set val [tk_messageBox -icon warning -type okcancel -title Message -parent $w \
				-message "Some project files $options(savefile).{pdb psf xsc} exist! Overwrite?"]
      		if {$val == "cancel"} { return 0 }
   	}

	vmdcon -info "Reset display field..."
	::liquify::clear_mols
	vmdcon -info "Populating..."

	vmdcon -info "Loading PBD file for parent molecule \{$options(pdb)\}..."
	if [catch {mol new $options(pdb) type pdb} err] {
		vmdcon -err "Could not load PDB file! Halting box fill."
		return 0
	}
	
	vmdcon -info "Loading PSF data into parent molecule..."
	if [catch {mol addfile $options(psf) type psf} err] {
		vmdcon -info "Could not load PSF data! Halting box fill."
		return 0
	}

	vmdcon -info "Loading topology from $options(top)..."
	topology $options(top)

	# Adjust y,z for cubic periodic cell
	if $options(cube) {
		foreach i {y z} {
			set options($i) $options(x)
		}
	}
	foreach i {x y z} {
		if {$options($i) <= 0} {
			vmdcon -err "Box dimensions must be greater than 0!"
			vmdcon -info "Halting box fill!"
			return 0
		}
	}

	if [expr $options(density) <= 0] {
		vmdcon -err "Density estimate has to be greater than 0!"
		vmdcon -info "Halting box fill!"
		return 0
	}

	if [expr $options(adj_radii) <= 0] {
		vmdcon -err "Scaling factor for van der Waals radii has to be \
			greater than 0!"
		vmdcon -info "Halting box fill!"
		return 0
	}
	
	if [expr $options(niter) <= 0] {
		vmdcon -err "Failed iteration cutoff has to be greater than 0!"
		vmdcon -info "Halting box fill!"
		return 0
	}

	return 1
}

##
## Create a liquid from parent molecule.
## Returns 1 (true) for success
##
proc ::liquify::populate {} {
	variable PI
	variable A3_to_mL
	variable options
	variable base_coords
	variable density
	variable tot_resid

	if ![::liquify::validate_input] {
		vmdcon -err "Could not validate input! Halting."
		return 0
	}

	# Store info parsed from parent molecule
	set atoms [atomselect top all]
	set base_coords [$atoms get {resname name x y z}] ;# Relative atom coords
	set diam [vecdist {*}[measure minmax $atoms]] ;# Estimate molecular sphere diameter
	set radius [expr $diam / 2.0]
	set resnames [lsort -unique [$atoms get resname]]
	
	# Estimate number of molecules needed based on density
	set mol_mass [measure sumweights $atoms weight mass] ;# molar mass
	set mol_mass [expr $mol_mass / 6.022e23] ;# mass one molecule
	set vol [expr $options(x) * $options(y) * $options(z) * $A3_to_mL]
	set num_mols [expr round($options(density) * $vol / $mol_mass)]

	mol delete [molinfo top] ;# Remove parent molecule

	# Residue names can only be 1-5 characters
	# TODO could start adding new segments
	if {$num_mols > 99999} {
		vmdcon -warn "Too many molecules (>99999) would mess up resid. Halting."
		return 0
	}

	# Replicate parent molecule
	::liquify::generate_blanks $num_mols $resnames

	# It seems necessary to write to file and reload
	::liquify::save_reload "$options(savedir)/$options(savefile)"

	# Scatter molecules randomly around in the box
	vmdcon -info "Attempting to scatter $num_mols molecules..."
	set tot_resid "[::liquify::scatter_molecules $diam] (of $num_mols)"

	::liquify::save_reload "$options(savedir)/$options(savefile)"

	pbc set "$options(x) $options(y) $options(z)" -all
	pbc box -center origin ;# draw periodic box

	# Represent molecules in Licorice style
	mol modstyle 0 top Licorice 0.300000 10.000000 10.000000

	vmdcon -info "Finished molecule replication"

	# Create XSC file for use with NAMD
	vmdcon -info "Writing xsc file..."
	if ![::liquify::write_xsc] {
		vmdcon -err "Write to xsc file failed. Halting"
		return 0
	}

	vmdcon -info "Calculating randomly packed density..."
	set density [format "%.4f g/mL" [::liquify::calc_density]]
	vmdcon "density: $density\n"

	return 1
}

##
## Create n copies of parent molecule using psfgen.
## 
proc ::liquify::generate_blanks {n resnames} {
	variable segname

	segment $segname {
		first NONE
		last NONE
		for {set i 0} {$i < $n} {incr i} {
			foreach resname $resnames {
				residue $i $resname
			}
		}
	}
}

##
## "Fill" the box by placing molecules randomly within the periodic
## boundaries. Returns the number of placed molecules (0 for failure).
##
proc ::liquify::scatter_molecules {diam} {
	variable options
	variable base_coords
	variable segname

	set all_atoms [atomselect top all]
	set resids [lsort -integer -unique [$all_atoms get resid]]
	set delete_mols 0 ;# Flag which switches the loop function
	set placed {} ;# List of finished molecules

	# Box boundaries with origin at centre
	foreach n {x y z} {
		set max$n [expr $options($n) / 2.0]
		set min$n [expr -[subst \$max$n]]
	}

	# Move one molecule at a time while delete_mols is 0.
	# Delete remaining molecules when delete_mols is 1.
	foreach resid $resids {
		set atoms [atomselect top "resid $resid"]
		set test_data {} ;# proposed new coordinates
		set test_data_wrapped {} ;# adjusted for PBC
		set overlap 1 ;# initially "overlapped"
		set failures 0

		# Skip moving/checking and delete the unplaced molecules
		if {$delete_mols} {
			delatom $segname $resid
			continue
		}

		# Set relative atom coordinates
		$atoms set {resname name x y z} $base_coords

		# Translate and rotate a molecule
		while {$overlap} {
			incr failures
			
			if {$failures > $options(niter)} {
				vmdcon -info "Reached max iterations for placing molecules at residue: $resid"
				set delete_mols 1
				delatom $segname $resid
				break
			}
			
			foreach n {x y z} {
				$atoms move [transaxis $n [::liquify::random_angle]]
			}
			$atoms move [transoffset [::liquify::random_xyz]]

			# New center of geometry
			set cog [measure center $atoms]
			set test_data [join [$atoms get {segid resid radius name x y z}]]

			# Adjust any atoms for PBC
			set test_data_wrapped {}
			foreach {segid resid radius name x y z} $test_data {
				foreach n {x y z} {
					set val [subst $$n]
					if {$val < [subst \$min$n]} {
						set $n [expr $val + $options($n)]
					} elseif {$val > [subst \$max$n]} {
						set $n [expr $val - $options($n)]
					}
				}
				lappend test_data_wrapped [list $segid $resid $radius $name $x $y $z]
			}

			set overlap [::liquify::check_overlap $test_data_wrapped $placed $cog $diam]
	
			# Reset coords if atoms are overlapped
			if {$overlap} {
				$atoms set {resname name x y z} $base_coords
			}

		}

		# Record coordinates for psfgen
		if {!$delete_mols} {
			foreach {segid resid radius name x y z} $test_data {
				coord $segid $resid $name "$x $y $z"
			}

			lappend placed $resid
		}
	}
	return [llength $placed]
}

##
## Check the atomic overlap between two molecules.
## args -> molecule being scattered
## <varname>2 -> already placed molecule
##
proc ::liquify::check_overlap {test_data_wrapped placed cog diam} {
	variable options

	# Only bother checking segments which have been "placed"
	foreach res $placed {
		set atoms2 [atomselect top "resid $res"]
		set cog2 [measure center $atoms2]
		set dr [vecdist $cog $cog2]
		
		# Use early rejection to prevent uncessesary checks
		# TODO remove option from GUI
		if {$options(reject) && $dr >= $diam} {
			continue
		}

		# Molecular spheres overlap, check every atom pair
		set cdata [join [$atoms2 get {name radius x y z}]]
		foreach {segid resid radius name x y z} [join $test_data_wrapped] {
			foreach {name2 radius2 x2 y2 z2} $cdata {
				set rcut [expr $options(adj_radii) * ($radius + $radius2)] ;# atomic radii may vary
				set dist [vecdist "$x $y $z" "$x2 $y2 $z2"]
				if {$dist < $rcut} {
					# Atomic overlap, reject move
					return 1
				}
			}
		}
	}
	return 0 ;# No atomic overlap, accept move
}

##
## Save XSC file for use with NAMD
##
proc ::liquify::write_xsc {} {
	variable options
	# TODO move to validate input
	if ![file isdirectory $options(savedir)] {
		vmdcon -err "$options(savedir) is not a valid directory! \
		Halting."
		return 0
	}
	set fname "$options(savedir)/$options(savefile).xsc"
	if [catch {open $fname w} xsc_file] {
		vmdcon -err "Could not write XSC file to $fname! Halting."
		return 0
	}
	puts $xsc_file {#NAMD extended system configuration\n}
	puts $xsc_file {#$LABELS step a_x a_y a_z b_x b_y b_z c_x c_y c_z o_x o_y o_z\n}
	puts $xsc_file "100 $options(x) 0 0 0 $options(y) 0 0 0 $options(z) 0 0 0\n"
	close $xsc_file
	return 1
}

##
## Returns the density of the active molecule within the periodic cell.
## Density: g/mL
##
proc ::liquify::calc_density {} {
	variable A3_to_mL

	# TODO check for PBC values > 0 before calculating
	# otherwise inf is returned
	set resids [lsort -integer -unique [[atomselect top all] get resid]]
	set atoms [atomselect top "resid [lindex $resids 0]"]
	# molar mass one molecule (residue)
	set mol_mass [measure sumweights $atoms weight mass]
	# actual mass one molecule (g)
	set mol_mass [expr $mol_mass / 6.022e23]
	set tot_mass [expr $mol_mass * [llength $resids]]
	set params [join [pbc get -now]]
	set x [lindex $params 0]
	set y [lindex $params 1]
	set z [lindex $params 2]
	set vol [expr $x * $y * $z * $A3_to_mL]
	return [expr $tot_mass / $vol] ;# g/mL
}

##
## Returns random point (x, y, z) within periodic cell as list.
## 
proc ::liquify::random_xyz {} {
	variable options
	set dr {}
	foreach n {x y z} {
		set val [expr ($options($n) * rand()) - ($options($n) / 2.0)]
		lappend dr $val
	}
	return $dr
}

##
## Returns random angle in degrees.
##
proc ::liquify::random_angle {} {
	return [expr (360.0 * rand())]
}
