#!/usr/bin/ruby -w
module GEDA

# line pattern
LINE_TYPE = {
  :SOLID   => 0, # -----
  :DOTTED  => 1, # . . . 
  :DASHED  => 2, # - - -
  :CENTER  => 3, # - . - .
  :PHANTOM => 4, # - .. - ..
}

# line end/join
END_CAP = {
  :NONE   => 0,
  :SQUARE => 1,
  :ROUND  => 2,
}

# filling
FILLING = {
  :HOLLOW => 0,
  :FILL   => 1,
  :MESH   => 2,
  :HATCH  => 3,
}

end

