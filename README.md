Liquify Plugin for VMD
==============================
---

Installation Instructions
------------------------------

__Linux / Mac OS X__

To install:

- Create a plugin folder for added plugins (_e.g._ `~/vmdplugins`)
- Copy the folder `liquify/` to plugin folder (_e.g._ `~/vmdplugins/liquify/`)
- Add the following lines to `~/.vmdrc` (or create the file)

        # Turn on main menu
        menu main on

        # Add new plugin directory to search path
        set auto_path [linsert 0 [file join $env(HOME) vmdplugins]]

        # Add new plugins
        vmd_install_extension liquify liquify_gui {Modeling/Build Molecular Liquid}`

__Windows__

To install:

- Follow the steps above, substituting pathnames as needed.

    e.g. change:
    
	- the file name `.vmdrc` _to_ `vmd.rc`
    - the directory `$HOME` _to_ `%USERPROFILE%` (_e.g._ C:\\Users\\myuser\\vmd.rc)
    - the line 

        `set auto_path [linsert 0 [file join $env(HOME) vmdplugins]]` 

        _to_

        `set auto_path [linsert 0 {C:\\vmdplugins}`

        (substitute C:\\vmdplugins with your plugin directory location)

After installing, the vmdplugins directory should look like this:
        
        vmdplugins/
        +-- liquify/
        |       +-- liquify.tcl
        |       +-- pkgIndex.tcl

Using the Plugin
------------------

To use the plugin, start VMD and select 

_Extensions_ -> _Modeling_ -> _Build Molecular Liquid_ 

from the main menu.  After filling in the required information and parameters via the graphical user interface, click the __Fill__ button to build the liquid.  The total number of molecules added as well as the density will be given in the __Results__ frame after it finishes.

A command line interface is also provided through the Tcl proc `liquify_cli`. Usage information is provided by the `-help` argument, _i.e._ by typing the following into the VMD console (recommend to use VMDs Tk Console under _Extensions_):
   
    namespace import Liquify::liquify_cli
    liquify_cli -help

Description of Parameters
-------------------------

The GUI provides input for the following parameters:

1. PDB, PSF, and TOP Files

    > Input files for the single molecule you wish to generate a liquid structure for.
 

    - PDB: Protein Data Bank 
 
    - PSF: Protein Structure File

    - TOP: Topology file

2. Box Dimensions

    > Input the desired length along each axis of the periodic cell. Selecting the check box "Cubic Periodic Cell" will discard _y_ and _z_ input and use _x_ for all dimensions.

3. Runtime Options

    - Failed Iteration Cut-off: the max allowed times the builder will try to place a single molecule in the cell and fail. At the cut-off point, no more molecules will be added and the builder will finish. 

    - Density estimate: estimated density of the liquid. This is used to predict how many molecules are needed to fill the cell.

    - Scaling factor for van der Waals radii: the van der Waals radii are used to evaluate whether two atoms overlap while they are being placed in the cell.  If the final density is too low, reducing the scaling factor can help pack the molecules more tightly in the cell. If the final density is too high, increasing the scaling factor will reduce the final density.

4. Saving Data

    - Location: directory to save new files for the generated liquid.

    - Name: the prefix used for all new files (.pdb, .psf, and .xsc files are generated).

5. Populate Box

    - Fill: using the given parameters, clicking this button will generate the liquid and associated files.  Note, this first calls a reset function and will delete any loaded molecules or psf contexts.

    - Reset: clear molecules from display and reset psf context.

6. Results

    - Randomly packed density: shows the density of the randomly generated structure. If changes are made, clicking "Recalculate" will calculate the new density provided the periodic boundaries are still set (see `pbctools` for more information).

    - Molecules added: total number of molecules added to the cell. In parenthesis, the number of estimated molecules from the given density is provided for reference.
