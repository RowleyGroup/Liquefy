Liquify plugin for VMD
==============================

To install, type:
	make install

Manual install:

-copy liquify/ to vmd plugin folder (e.g. ~/vmdplugins)
-add vmdplugins to plugin search path by adding the following to the
file ~/.vmdrc
	set auto_path "$env(HOME)/vmdplugins $auto_path"
	menu main on
	vmd_install_extension liquify liquify_tk "Modeling/Setup Molecular Liquid"

