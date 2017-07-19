# Installation Instructions

## Linux / Mac OS X

* Create a plugin folder for added plugins ( _e.g._ `~/vmdplugins`)
* Copy the folder `liquefy/` to plugin folder ( _e.g._ `~/vmdplugins/liquefy/`)
* Add the following lines to `~/.vmdrc` or copy the provided `liquefy/vmdrc` file to `~/.vmdrc`

```
# Turn on main menu
menu main on

# Add new plugin directory to search path
set auto_path [linsert $auto_path 0 [file join $env(HOME) vmdplugins]]

# Add new plugins
vmd_install_extension liquefy liquefy_gui {Modeling/Build Molecular Liquid}

# Import liquefy_gui and liquefy_cli into global namespace
namespace import Liquefy::*
```

## Windows

To install:

* Create a plugin folder for added plugins ( _e.g._ `C:\Users\My Name\vmdplugins` )
* Copy the folder `liquefy/` to plugin folder ( _e.g._ `vmdplugins\liquefy` )
* Add the following lines to the file `vmd.rc` in your home directory, or copy the provided `vmd.rc` file to your home directory.

```
# Turn on main menu
menu main on

# Add new plugin directory to search path
set auto_path [linsert $auto_path 0 [file join $env(USERPROFILE) vmdplugins]]

# Add new plugins
vmd_install_extension liquefy liquefy_gui {Modeling/Build Molecular Liquid}

# Import liquefy_gui and liquefy_cli into global namespace
namespace import Liquefy::*
```

On Windows, you may also need to alter the "Start In" path in order for VMD to read the local vmd.rc file. This can be found by right-clicking a VMD icon, selecting "Properties" and changing the path to your home directory ( `%USERPROFILE%` ).

After installing, the vmdplugins directory should look like this:

    vmdplugins/
    +-- liquefy/
    |       +-- liquefy.tcl
    |       +-- pkgIndex.tcl

# Using the Plugin

To use the plugin, start VMD and select

*Extensions* -> *Modeling* -> *Build Molecular Liquid*

from the main menu. After filling in the required information and parameters via the graphical user interface, click the **Fill** button to build the liquid. The total number of molecules added as well as the density will be given in the **Results** frame after it finishes.

A command line interface is also provided through the Tcl proc `liquefy_cli`. Usage information is provided by the `-help` argument, _i.e._ by typing the following into the VMD console (recommend to use VMDs Tk Console under _Extensions_):

```
liquefy_cli -help
```

For example, for a single molecule of benzene,

```
liquefy_cli -pdb benzene.pdb -psf benzene.psf -top benzene.rtf -savefile benzene-liq
```

creates three new files containing a random liquid structure for benzene (`benzene-liq.pdb`, `benzene-liq.psf`, `benzene-liq.xsc`).

## Description of Parameters

The GUI provides input for the following parameters:

1.  PDB, PSF, and TOP Files

    Input files for the single molecule you wish to generate a liquid structure for.

    * PDB: Protein Data Bank
    * PSF: Protein Structure File
    * TOP: Topology file
2.  Box Dimensions

    Input the desired length along each axis of the periodic cell. Selecting the check box "Cubic Periodic Cell" will discard _y_ and _z_ input and use _x_ for all dimensions.

3.  Runtime Options

    * Failed Iteration Cut-off: the max allowed times the builder will try to place a single molecule in the cell and fail. At the cut-off point, no more molecules will be added and the builder will finish.
    * Density estimate: estimated density of the liquid. This is used to predict how many molecules are needed to fill the cell.
    * Scaling factor for van der Waals radii: the van der Waals radii are used to evaluate whether two atoms overlap while they are being placed in the cell. If the final density is too low, reducing the scaling factor can help pack the molecules more tightly in the cell. If the final density is too high, increasing the scaling factor will reduce the final density.
4.  Saving Data

    * Location: directory to save new files for the generated liquid.
    * Name: the prefix used for all new files (.pdb, .psf, and .xsc files are generated).
5.  Populate Box

    * Fill: using the given parameters, clicking this button will generate the liquid and associated files. Note, this first calls a reset function and will delete any loaded molecules or psf contexts.
    * Reset: clear molecules from display and reset psf context.
6.  Results

    * Randomly packed density: shows the density of the randomly generated structure. If changes are made, clicking "Recalculate" will calculate the new density provided the periodic boundaries are still set (see `pbctools` for more information).
    * Molecules added: total number of molecules added to the cell. In parenthesis, the number of estimated molecules from the given density is provided for reference.
