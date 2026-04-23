require 'mkmf'

dir_config ('dislin')
have_library ('dislnc', 'disini')
create_makefile ('dislin')
