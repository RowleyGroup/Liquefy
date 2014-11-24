## ################################################################## ##
## Liquefy - Build a Molecular Liquid
##
##   -A plugin for written for VMD-                                   ##
##                                                                    ##
## Given a parent molecule, this plugin constructs a liquid contained ##
## within a periodic cell.  New PDB, PSF, and XSC files are written   ##
## for the liquid.                                                    ##
##                                                                    ##
## Version: 1.0                                                       ##
## Authors: Leif Hickey and Christopher N. Rowley                     ##
## Contact: leif.hickey@mun.ca, crowley@mun.ca                        ##
## http://www.mun.ca/compchem                                         ##
## Date: 06/20/13                                                     ##
## ################################################################## ##

package provide liquefy 1.0
package require psfgen
package require pbctools

## Create namespace to prevent plugin conflicts
namespace eval Liquefy {
    namespace export liquefy_cli liquefy_gui
    
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
## CLI build call
## Return values: 0 -> error
##				  1 -> success
##				 -1 -> help menu exit
##
proc Liquefy::liquefy_cli { args } {
    variable options
    Liquefy::set_defaults
    set usage "
	
Usage:  liquefy_cli args1 ?args2?

Help:	liquefy_cli -help

Required args1:
  -pdb <molecule PDB file>
  -psf <molecule PSF file>
  -top <molecule RTF file>
  -savefile <save file prefix>

Optional args2:
  -niter <int> (default: 150)
  -savedir <save directory> (default: [pwd]))
  -cube <0,1> (default: 1 -> use cubic cell)
  -adj_radii <float> (default: 0.8 -> van der Waals radius scaling factor)
  -density <float> (default: 1.0 -> estimated liquid density in g/mL)
  -x <int> (default: 30 -> length box side x)
  -y <int> (default: 30 -> length box side y)
  -z <int> (default: 30 -> length box side z)

	"
    if {$args == {-help}} {
	vmdcon -info {Liquefy Help dialog}
	puts $usage
	return -1
    }
    array set options $args
    set gui 0
    set Liquefy::tot_resid 0
    set Liquefy::density {0.0 g/mL}
    
    vmdcon -info "Liquefy: Building liquid using options"
    parray options
    # Input validation is called from populate
    if {![Liquefy::populate $gui]} {
	#vmdcon -err "Could not validate arguments! Halting."
	vmdcon -info $usage
	return 0
    }
    return 1
}

##
## Build a window to allow user input of parameters
## Used as Tk callback proc in VMD extension menu
## Returns window handle
##
proc Liquefy::liquefy_gui {} {
    variable w
    variable options
    set gui 1
    
    if {[winfo exists .liquefy]} {
	wm deiconify $w ;# Bring window to front
	return
    }
    
    set w [toplevel .liquefy]
    wm title $w "Build Molecular Liquid"
    
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
	set e [entry $w.f1.$n-e1 -width $twidth -textvariable Liquefy::options(-$n)] 
	set cmd "set Liquefy::options(-$n) \[tk_getOpenFile\]"
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
	set e [entry $w.f2.$n-e1 -textvariable Liquefy::options(-$n) -width $nwidth \
		   -validate key -vcmd {string is int %P}]
	#	-validate key -vcmd {string is int %P}]
	set l [label $w.f2.$n-l1 -text "$n"]
	grid $l -column 0 -row $row -sticky e
	grid $e -column 1 -row $row -sticky w
	incr row
    }
    
    set cmd {
	if {$Liquefy::options(-cube)} {
	    $Liquefy::w.f2.y-e1 configure -state readonly
	    $Liquefy::w.f2.z-e1 configure -state readonly
	} else {
	    $Liquefy::w.f2.y-e1 configure -state normal
	    $Liquefy::w.f2.z-e1 configure -state normal
	}
    }
    
    set l [label $w.f2.l4 -text "Cubic Periodic Cell"]
    set c [checkbutton $w.f2.c1 -variable Liquefy::options(-cube) \
	       -command $cmd]
    grid $l -column 2 -row 0 -sticky e
    grid $c -column 3 -row 0 -sticky w
    
    # Frame containing runtime options
    grid [labelframe $w.f4 -text "Runtime Options"] -column 1 -row 1 \
	-sticky news
    
    set l [label $w.f4.l1 -text "Failed iteration cutoff"]
    set s [spinbox $w.f4.s1 -textvariable Liquefy::options(-niter) \
	       -from 100 -to 1000 -increment 50 -width $nwidth -validate key \
		-vcmd {string is int %P}]
    grid $l -column 0 -row 0 -sticky e
    grid $s -column 1 -row 0 -sticky w
    
    set l [label $w.f4.l3 -text "Density estimate (g/mL)"]
    set e [entry $w.f4.e1 -textvariable Liquefy::options(-density) \
	       -width $nwidth -validate key -vcmd {string is double %P}]
    grid $l -column 0 -row 1 -sticky e
    grid $e -column 1 -row 1 -sticky w
    
    set l [label $w.f4.l4 -text "Scaling factor for van der Waals radii"]
    set e [entry $w.f4.e2 -textvariable Liquefy::options(-adj_radii) \
	       -width $nwidth -validate key -vcmd {string is double %P}]
    grid $l -column 0 -row 2 -sticky e
    grid $e -column 1 -row 2 -sticky w

    # Frame containing new save location
    grid [labelframe $w.f3 -text "Save Location for New Data"] \
		-columnspan 2 -rowspan 1 -sticky news
    
    set l [label $w.f3.l1 -text "Location"] 
    set e [entry $w.f3.e1 -textvariable Liquefy::options(-savedir) -width $twidth] 
    set cmd "set Liquefy::options(-savedir) \[tk_chooseDirectory\]"
    set b [button $w.f3.b1 -text "Browse" -command $cmd]
    grid $l -column 0 -row 0 -sticky e
    grid $e -column 1 -row 0 -sticky ew
    grid $b -column 2 -row 0 -sticky w
    
    set l [label $w.f3.l2 -text "Name"]
    set e [entry $w.f3.e2 -textvariable Liquefy::options(-savefile) -width $twidth]
    set cmd "Liquefy::save_reload"
    set b [button $w.f3.b2 -text "Save PBD/PSF" -command $cmd]
    grid $l -column 0 -row 1 -sticky e
    grid $e -column 1 -row 1 -sticky ew
    #grid $b -column 2 -row 1
    
    # Frame containing Fill and Reset buttons
    grid [labelframe $w.f5 -text "Populate Box"] \
	-column 0 -row 3 -sticky nsew
    
    set cmd "Liquefy::populate $gui"
    set b [button $w.f5.b1 -text "Fill!" -command $cmd]
    grid $b -column 1 -row 0
    
    set cmd {
	Liquefy::clear_mols
	Liquefy::set_defaults
    }
    set b [button $w.f5.b2 -text "Reset" -command $cmd]
    grid $b -column 2 -row 0
    
    # Frame containing post-population results
    grid [labelframe $w.f6 -text "Results"] \
	-column 1 -row 3 -sticky news
    
    set l1 [label $w.f6.l1 -text "Randomly packed density:"]
    set l2 [label $w.f6.l2 -textvariable Liquefy::density]
    set cmd {
	set Liquefy::density [format "%.4f g/mL" [Liquefy::calc_density]]
    }
    set b [button $w.f6.b1 -text "Recalculate" -command $cmd]
    grid $l1 -column 0 -row 0 -sticky e
    grid $l2 -column 1 -row 0 -sticky w
    grid $b -column 2 -row 0 -sticky e
    
    set l1 [label $w.f6.l3 -text "Molecules added:"]
    set l2 [label $w.f6.l4 -textvariable Liquefy::tot_resid]
    grid $l1 -column 0 -row 1 -sticky e
    grid $l2 -column 1 -row 1 -sticky w
    
    Liquefy::set_defaults
    
    return $w
}

##
## Reset input and results to default
##
proc Liquefy::set_defaults {} {
    variable options
    set options(-niter) 150
    set options(-pdb) ""
    set options(-psf) ""
    set options(-top) ""
    set options(-savedir) [pwd]
    set options(-savefile) ""
    set options(-cube) 0
    if {[catch {package present Tk} res]} {
	puts "No X present"
    } else {
	if {[winfo exists .liquefy]} {
	    $Liquefy::w.f2.y-e1 configure -state normal
	    $Liquefy::w.f2.z-e1 configure -state normal
	}
    }
    set options(-adj_radii) 0.8
    set options(-density) 1.0
    foreach n {x y z} {
	set options(-$n) 30
	set Liquefy::tot_resid 0
	set Liquefy::density {0.0 g/mL}
    }
    return 1
}

##
## Create a 'clean' state to build the liquid in
##
proc Liquefy::clear_mols {} {
    vmdcon -info "Removing [molinfo num] molecules"
    psfcontext reset
	set idlist [molinfo list]
    foreach id $idlist {
	mol delete $id
    }
    vmdcon -info "...done"
	return 1
}

##
## Save PDB/PSF data and reload. Called after constructing new segment
## and changing coordinates.
##
proc Liquefy::save_reload {name} {
    writepdb $name.pdb
    writepsf $name.psf
    
    mol delete [molinfo top]
    mol load psf $name.psf pdb $name.pdb
    return 1
}

##
## Validate user input
## Return values: 0 -> error
##				  1 -> success
## Also loads parent molecule.
##
proc Liquefy::validate_input { gui } {
    variable w
    variable options
    vmdcon -info "Input validation..."
    
    
    if {[llength $options(-savefile)] == 0} {
	vmdcon -err "No save filename given! Halting."
	return 0
    }
    
    # User confirm to overwrite existing files
    set basename "$options(-savedir)/$options(-savefile)"
    if {[file exists $basename.pdb] || \
	    [file exists $basename.psf] || \
	    [file exists $basename.xsc]} {
	set msg "Some project files $options(-savefile).{pdf psf xsc} exist! Overwrite?"
	if {$gui} {
	    set val [tk_messageBox -icon warning -type okcancel -title Message -parent $w \
			 -message $msg]
	    if {$val == "cancel"} { return 0 }
	} else {
	    puts "$msg \[y/n\]"
	    gets stdin val
	    if {$val == n} {
		vmdcon -info "Not overwriting files! Halting."
		return 0
	    }
	}
    }
    
    vmdcon -info "Reset display field..."
    Liquefy::clear_mols
    vmdcon -info "Populating..."
    
    vmdcon -info "Loading PBD file for parent molecule \{$options(-pdb)\}..."
    if {[catch {mol new $options(-pdb) type pdb} err]} {
	vmdcon -err "Could not load PDB file! Halting box fill."
	return 0
    }
    
    vmdcon -info "Loading PSF data into parent molecule..."
    if {[catch {mol addfile $options(-psf) type psf} err]} {
	vmdcon -info "Could not load PSF data! Halting box fill."
	return 0
    }

    vmdcon -info "Loading topology from $options(-top)..."
	topology $options(-top)
    
    # Adjust y,z for cubic periodic cell
    if {$options(-cube)} {
	foreach i {y z} {
			set options(-$i) $options(-x)
	}
    }
    foreach i {x y z} {
	if {$options(-$i) <= 0} {
	    vmdcon -err "Box dimensions must be greater than 0!"
	    vmdcon -info "Halting box fill!"
			return 0
	}
    }
    
    if {$options(-density) <= 0} {
	vmdcon -err "Density estimate has to be greater than 0!"
	vmdcon -info "Halting box fill!"
	return 0
    }

    if {$options(-adj_radii) <= 0} {
	vmdcon -err "Scaling factor for van der Waals radii has to be \
			greater than 0!"
	vmdcon -info "Halting box fill!"
	return 0
    }
    
    if {$options(-niter) <= 0} {
	vmdcon -err "Failed iteration cutoff has to be greater than 0!"
	vmdcon -info "Halting box fill!"
	return 0
    }
    
    return 1
}

##
## Build the liquid from parent molecule.
## Return values: 0 -> error
##				  1 -> success
##
proc Liquefy::populate { gui } {
	variable PI
	variable A3_to_mL
	variable options
	variable base_coords
	variable density
	variable tot_resid

	if {![Liquefy::validate_input $gui]} {
		vmdcon -err "Could not validate input! Halting."
		return 0
	}

	# Store info parsed from parent molecule
	set atoms [atomselect top all]
	set base_coords [$atoms get {resname name x y z}] ;# Relative atom coords
	set diam [vecdist {*}[measure minmax $atoms]] ;# Estimate molecular sphere diameter
	set radius [expr {$diam / 2.0}]
	set resnames [lsort -unique [$atoms get resname]]
	
	# Estimate number of molecules needed based on density
	set mol_mass [measure sumweights $atoms weight mass] ;# molar mass
	set mol_mass [expr {$mol_mass / 6.022e23}] ;# mass one molecule
	set vol [expr {$options(-x) * $options(-y) * $options(-z) * $A3_to_mL}]
	set num_mols [expr {round($options(-density) * $vol / $mol_mass)}]

	mol delete [molinfo top] ;# Remove parent molecule

	# Residue names can only be 1-5 characters
	# TODO could start adding new segments
	if {$num_mols > 99999} {
		vmdcon -warn "Too many molecules (>99999) would mess up resid. Halting."
		return 0
	}

	# Replicate parent molecule
	Liquefy::generate_blanks $num_mols $resnames

	# It seems necessary to write to file and reload
	Liquefy::save_reload "$options(-savedir)/$options(-savefile)"

	# Scatter molecules randomly around in the box
	vmdcon -info "Attempting to scatter $num_mols molecules..."
	set tot_resid "[Liquefy::scatter_molecules $diam] (of $num_mols)"

	Liquefy::save_reload "$options(-savedir)/$options(-savefile)"

	pbc set "$options(-x) $options(-y) $options(-z)" -all
	pbc box -center origin ;# draw periodic box

	# Represent molecules in Licorice style
	mol modstyle 0 top Licorice 0.300000 10.000000 10.000000

	vmdcon -info "Finished molecule replication"

	# Create XSC file for use with NAMD
	vmdcon -info "Writing xsc file..."
	if {![Liquefy::write_xsc]} {
		vmdcon -err "Write to xsc file failed. Halting"
		return 0
	}

	vmdcon -info "Calculating randomly packed density..."
	set density [format "%.4f g/mL" [Liquefy::calc_density]]
	vmdcon "density: $density\n"
	vmdcon "number molecules added: $tot_resid\n"

	return 1
}

##
## Create n copies of parent molecule using psfgen.
## 
proc Liquefy::generate_blanks {n resnames} {
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
	return 1
}

proc Liquefy::pbc_dist {v1 v2} {
    variable options

    set dv [vecsub $v1 $v2]
    set vec(x) [lindex $dv 0 ]
    set vec(y) [lindex $dv 1 ]
    set vec(z) [lindex $dv 2 ]

    set d2 0
    foreach c {x y z} {
	set hf [expr $options(-$c) / 2.0 ]
	set mhf [expr -$options(-$c) / 2.0 ]
	if { $vec($c) > $hf } {
	    set vec($c) [expr ($vec($c)-$options(-$c)) ]
	} elseif { $vec($c) < $mhf } {
	    set vec($c) [expr ($vec($c)+$options(-$c))]
	}
	set d2 [expr $d2 + $vec($c) * $vec($c) ]
    }
    return [expr  sqrt($d2) ]
}

##
## "Fill" the box by placing molecules randomly within the periodic
## boundaries. Returns the number of placed molecules (0 for failure).
##
proc Liquefy::scatter_molecules {diam} {
    variable options
    variable base_coords
    variable segname
    
    set all_atoms [atomselect top all]
    set resids [lsort -integer -unique [$all_atoms get resid]]
    set delete_mols 0 ;# Flag which switches the loop function
    set placed {} ;# List of finished molecules

	# Box boundaries with origin at centre
	foreach n {x y z} {
		set max$n [expr {$options(-$n) / 2.0}]
		set min$n [expr {-[subst \$max$n]}]
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
			
			if {$failures > $options(-niter)} {
				vmdcon -info "Reached max iterations for placing molecules at residue: $resid"
				set delete_mols 1
				delatom $segname $resid
				break
			}
			
			foreach n {x y z} {
				$atoms move [transaxis $n [Liquefy::random_angle]]
			}
			$atoms move [transoffset [Liquefy::random_xyz]]

			# New center of geometry
			set cog [measure center $atoms]
			set test_data [join [$atoms get {segid resid radius name x y z}]]

			# Adjust any atoms for PBC
			set test_data_wrapped {}
			foreach {segid resid radius name x y z} $test_data {
				foreach n {x y z} {
					set val [subst $$n]
					if {$val < [subst \$min$n]} {
						set $n [expr {$val + $options(-$n)}]
					} elseif {$val > [subst \$max$n]} {
						set $n [expr {$val - $options(-$n)}]
					}
				}
				lappend test_data_wrapped [list $segid $resid $radius $name $x $y $z]
			}

			set overlap [Liquefy::check_overlap $test_data_wrapped $placed $cog $diam]
	
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
##   args refer to molecule being scattered
##   <varname>2 refer to already placed molecule
##
## Return values: 0 -> no overlap
##				  1 -> overlap
##
proc Liquefy::check_overlap {test_data_wrapped placed cog diam} {
	variable options

	# Only bother checking segments which have been "placed"
	foreach res $placed {
	    set atoms2 [atomselect top "resid $res"]
	    set cog2 [measure center $atoms2]
	    set dr [pbc_dist $cog $cog2]
	    # Use early rejection to prevent unnecessesary checks
	    if {$dr >= $diam} {
		continue
	    }

	    # Molecular spheres overlap, check every atom pair
	    set cdata [join [$atoms2 get {name radius x y z}]]
	    foreach {segid resid radius name x y z} [join $test_data_wrapped] {
		foreach {name2 radius2 x2 y2 z2} $cdata {
		    set rcut [expr {$options(-adj_radii) * ($radius + $radius2)}] ;# atomic radii may vary
		    set dist [pbc_dist "$x $y $z" "$x2 $y2 $z2"]
		    if {$dist < $rcut} {
			return 1
		    }
		}
	    }
	}
    return 0
}

##
## Save XSC file for use with NAMD
## Return values: 0 -> error
## 				  1 -> success
##
proc Liquefy::write_xsc {} {
	variable options
	# TODO move to validate input
	if {![file isdirectory $options(-savedir)]} {
		vmdcon -err "$options(-savedir) is not a valid directory! \
		Halting."
		return 0
	}
	set fname "$options(-savedir)/$options(-savefile).xsc"
	if {[catch {open $fname w} xsc_file]} {
		vmdcon -err "Could not write XSC file to $fname! Halting."
		return 0
	}
	puts $xsc_file {#NAMD extended system configuration}
	puts $xsc_file {#$LABELS step a_x a_y a_z b_x b_y b_z c_x c_y c_z o_x o_y o_z}
	puts $xsc_file "100 $options(-x) 0 0 0 $options(-y) 0 0 0 $options(-z) 0 0 0"
	close $xsc_file
	return 1
}

##
## Returns the density of the active molecule within the periodic cell.
## Density: g/mL
##
proc Liquefy::calc_density {} {
	variable A3_to_mL

	# TODO check for PBC values > 0 before calculating
	# otherwise inf is returned
	set resids [lsort -integer -unique [[atomselect top all] get resid]]
	set atoms [atomselect top "resid [lindex $resids 0]"]
	# molar mass one molecule (residue)
	set mol_mass [measure sumweights $atoms weight mass]
	# actual mass one molecule (g)
	set mol_mass [expr {$mol_mass / 6.022e23}]
	set tot_mass [expr {$mol_mass * [llength $resids]}]
	set params [join [pbc get -now]]
	set x [lindex $params 0]
	set y [lindex $params 1]
	set z [lindex $params 2]
	set vol [expr {$x * $y * $z * $A3_to_mL}]
	return [expr {$tot_mass / $vol}] ;# g/mL
}

##
## Returns random point (x, y, z) within periodic cell as list.
## 
proc Liquefy::random_xyz {} {
	variable options
	set dr {}
	foreach n {x y z} {
		set val [expr {($options(-$n) * rand()) - ($options(-$n) / 2.0)}]
		lappend dr $val
	}
	return $dr
}

##
## Returns random angle in degrees.
##
proc Liquefy::random_angle {} {
	return [expr {360.0 * rand()}]
}
