#!/usr/bin/ruby -w
module Bounding

# Caution: Generally we modify the box in place -- so maybe we should add suffix ! to methods like enlarge

COORDINATE_RANGE = 1e6.to_i

# for real boxes x1 < x2 and y1 < y2
class Box
  attr_accessor :x1, :y1, :x2, :y2
  def initialize(x1, y1, x2, y2)
    @x1, @x2 = [x1, x2].minmax
    @y1, @y2 = [y1, y2].minmax
  end

  def reset(x1, y1, x2, y2)
    @x1, @x2 = [x1, x2].minmax
    @y1, @y2 = [y1, y2].minmax
		self
  end

  def reset_to_ghost()
    @x1, @y1, @x2, @y2 = COORDINATE_RANGE, COORDINATE_RANGE, -COORDINATE_RANGE, -COORDINATE_RANGE
		self
  end

  def enlarge_abs(x, y)
		if x < @x1
			@x1 = x
		elsif x > @x2
			@x2 = x
		end 
		if y < @y1
			@y1 = y
		elsif y > @y2
			@y2 = y
		end 
    self
  end

	def mirror2x0(x0)
		@x1, @x2 = x0 - @x2, x0 - @x1
		self
	end

  def hit_size()
    [[@x2 - @x1, @y2 - @y1].min, 0].max
  end

#  def ghost()
#    @x1, @y1, @x2, @y2 = COORDINATE_RANGE, COORDINATE_RANGE, -COORDINATE_RANGE, -COORDINATE_RANGE
#  end
  def Box.new_ghost # Box.new_ghost.join(other) == other
    h = Box.new(0, 0, 0, 0)
    h.x1, h.y1, h.x2, h.y2 = COORDINATE_RANGE, COORDINATE_RANGE, -COORDINATE_RANGE, -COORDINATE_RANGE
    return h
  end
  def translate(x, y)
    @x1 += x; @y1 += y; @x2 += x; @y2 += y
  end
  def grow(d)
    @x1 -= d; @y1 -= d; @x2 += d; @y2 += d
    self
  end
  def grow_x(d)
    @x1 -= d; @x2 += d
    self
  end
  def grow_y(d)
    @y1 -= d; @y2 += d
    self
  end
  def enlarge(x, y)
    if x < 0 then @x1 += x else @x2 += x end
    if y < 0 then @y1 += y else @y2 += y end
    self
  end

  def join(other)
    if @x1 > other.x1 then @x1 = other.x1 end
    if @y1 > other.y1 then @y1 = other.y1 end
    if @x2 < other.x2 then @x2 = other.x2 end
    if @y2 < other.y2 then @y2 = other.y2 end
    self
  end


#  def join4(x1, y1, x2, y2)
#    if @x1 > x1 then @x1 = x1 end
#    if @y1 > y1 then @y1 = y1 end
#    if @x2 < x2 then @x2 = x2 end
#    if @y2 < y2 then @y2 = y2 end
#    self
#  end


  def +(other)
    if @x1 > other.x1 then x1 = other.x1 else x1 = @x1 end
    if @y1 > other.y1 then y1 = other.y1 else y1 = @y1 end
    if @x2 < other.x2 then x2 = other.x2 else x2 = @x2 end
    if @y2 < other.y2 then y2 = other.y2 else y2 = @y2 end
    Box.new(x1, y1, x2, y2)
  end
  def not_overlap?(other)
    (@x2 < other.x1) or (@x1 > other.x2) or (@y2 < other.y1) or (@y1 > other.y2)
  end

  def overlap_list?(list)
    list.each{|other|
      return true if (@x2 > other.x1) and (@x1 < other.x2) and (@y2 > other.y1) and (@y1 < other.y2)
    }
    false
  end

  def overlap?(other)
    (@x2 > other.x1) and (@x1 < other.x2) and (@y2 > other.y1) and (@y1 < other.y2)
  end

  def include?(other, d = 0)
    (@x2 + d > other.x2) and (@x1 - d < other.x1) and (@y2 + d > other.y2) and (@y1 - d < other.y1)
  end

  def include_point?(x, y, d = 0)
    (x > @x1 - d) and (x < @x2 + d) and (y > @y1 -d ) and (y < @y2 + d)
  end
end

end # Bounding

