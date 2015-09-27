# TODO: Currently, when we move elements, we join the old and new bounding box
# of moved element and clip drawing to this area. Maybe we should use unclipped
# draw for moved element always -- so we can clip and repaint only old bounding
# box are. Should not make a big differennce, but may save a few lines of code.
#
# TODO: Currently we have a fixed grab distance. We should take into account
# zoom level, maybe using device_to_user_distance.
#
# TODO: For text maybe we should put all lines into only one string?
# Fixed: After comments from geda mailing list multiple lines are put into one single
# string now, and for attributes name is left side of = sign, and value is all on right side, which may be more attributes.
# http://www.delorie.com/archives/browse.cgi?p=geda-user/2015/07/19/06:38:24
#
# TODO: For Text attributes we may have strings name and value additional to lines to avoid calling split often.
#
# TODO: We may have to replace each methods with each_alive to ignore deleted objects.
# NOTE: We do not really delete objects currently, but only mark as deleted -- so we can apply UNDO later easy.
#
# NOTE: For invisible text, we use attribute selectable = 0 (bbox = nil would be an option too)
# For components of symbols we may simple refuse to load invisible text!
#
# NOTE: For Sym and EmbSym we now use the same class and a tag field. Makes conversion in between easyer.
#
# NOTE: Now we do not include Version element in ObjectList -- Version has no valid coordinates which make handling difficult
#
module Math
	TAU = 2 * PI
	SQRT2 = sqrt(2)
end

module Pet
# TODO: we need a deep copy of elements to offer copy from popup menu!
# TODO: for diagonal nets and lines we may want a more restrictive hoover method
# TODO: Busses and images are currently not supported, should be easy to add
# TODO: Undo is also missing, would be some work...

require 'gtk3'
require 'cairo' # drawing on screen and PNG, PDF, SVG export
require 'pango' # font rendering
require_relative 'pet_conf'
require_relative 'pet_bbox'
require_relative 'pet_def'

class FileFormatError < StandardError
end

DEG2RAD_C = Math::PI / 180
RAD2DEG_C = 180 / Math::PI

DefaultLineWidth = 10

Project_Start_Date = '11-AUG-2011'
Version = '0.05 (28-SEP-2015)'

Docu = <<HERE
pet.rb -- a plain electronics tool inspired by the gEDA suite
Version: #{Version}
Author: S. Salewski
License: GPL

usage: ...

HERE

#PROGRAM_VERSION = 'xxx'
#FILEFORMAT_VERSION = 'yyy'
EGRID = 100 # pins and nets should start/end on EGRID only
MIN_STRUCTURE_SIZE = 5 # we try to prevent pollution of schematics with tiny objects

ArcChar			= 'A'
BoxChar			= 'B'
BusChar			= 'U'
CircChar		= 'V'
LineChar		= 'L'
NetSegChar	= 'N'
PathChar		= 'H'
PicChar			= 'G'
PinChar			= 'P'
SymChar			= 'C'
TextChar		= 'T'
VersionChar	= 'v'

SOLPAT	= '^'
EOLPAT	= ' *$'
INTPAT	= ' (-?\d+)'
FLOATPAT = ' (\d+(\.\d+)?([eE][-+]?\d+)?)'

ArcPar = %w[Arc type x y radius startangle sweepangle color linewidth capstyle dashstyle dashlength dashspace]
ArcPat = SOLPAT + '(' + ArcChar + ')' + INTPAT * 11 + EOLPAT

BoxPar = %w[Box type x y width height color linewidth capstyle dashstyle dashlength dashspace filltype fillwidth angle1 pitch1 angle2 pitch2]
BoxPat = SOLPAT + '(' + BoxChar + ')' + INTPAT * 16 + EOLPAT

BusPar = %w[Bus type x1 y1 x2 y2 color ripperdir]
BusPat = SOLPAT + '(' + BusChar + ')' + INTPAT * 6 + EOLPAT

CircPar = %w[Circ type x y radius color linewidth capstyle dashstyle dashlength dashspace filltype fillwidth angle1 pitch1 angle2 pitch2]
CircPat = SOLPAT + '(' + CircChar + ')' + INTPAT * 15 + EOLPAT

SymPar = %w[Symbol type x y selectable angle mirror basename]
EmbeddedSymPat = SOLPAT + '(' + SymChar + ')' + INTPAT * 5 + ' EMBEDDED' + '(.*\.sym)' + EOLPAT
ExternSymPat	= SOLPAT + '(' + SymChar + ')' + INTPAT * 5 + ' '				+ '(.*\.sym)' + EOLPAT

LinePar = %w[Line type x1 y1 x2 y2 color linewidth capstyle dashstyle dashlength dashspace]
LinePat = SOLPAT + '(' + LineChar + ')' + INTPAT * 10 + EOLPAT

PathPar = %w[Path type color linewidth capstyle dashstyle dashlength dashspace filltype fillwidth angle1 pitch1 angle2 pitch2 numlines]
PathPat = SOLPAT + '(' + PathChar + ')' + INTPAT * 13 + EOLPAT

PicPar = %w[Pic type x y width height angle ratio mirrored embedded]
PicPat = SOLPAT + '(' + PicChar + ')' + INTPAT * 5 + FLOATPAT + INTPAT * 2 + EOLPAT

PinPar = %w[Pin type x1 y1 x2 y2 color pintype whichend]
PinPat = SOLPAT + '(' + PinChar + ')' + INTPAT * 7 + EOLPAT

TextPar = %w[Text type x y color size visibility show_name_value angle alignment num_lines]
TextPat = SOLPAT + '(' + TextChar + ')' + INTPAT * 9 + EOLPAT

NetSegPar = %w[NetSeg type x1 y1 x2 y2 color]
NetSegPat = SOLPAT + '(' + NetSegChar + ')' + INTPAT * 5 + EOLPAT

VersionPar = %w[Version type version fileformat_version]
VersionPat = SOLPAT + '(' + VersionChar + ')' + INTPAT * 2 + EOLPAT

module PES # Process_Event_State
	Hoovering	= 0
	Hit				= 1
	Patch			= 5
	Dragging	= 2
	Moved			= 3
	PopupMove	= 4
end

module PEM # Process_Event_Message
	Hit_Select		= 0
	Drag_Select		= 1
	Hoover_Select	= 2
	Delta_Move		= 4
	KEY_Delete		= 5
	KEY_BackSpace	= 10
	KEY_Escape		= 9
	KEY_Edit			= 8
	Scroll_Rotate	= 6
	Check_Alive		= 11
end

module PMM # Popup_Menu_Message
	New			= 0
	Select	= 1
	Move		= 2
	Delete	= 3
	Cancel	= 4
	CW			= 5
	CCW			= 6
	Mirror	= 7
	Copy		= 8
	Done		= 9
	Back		= 10
end

Default_Line_Width_Scale = 1 #3 # compare to EGRID == 100, PIN-Length == 300

#			(c)
#			/
#		 /		(p)
#		/
# (b)
# see http://www.geometrictools.com/
#
def self.distance_line_segment_point_squared(bx, by, cx, cy, px, py)
	mx = cx - bx
	my = cy - by
	hx = px - bx
	hy = py - by
	t0 = (mx * hx + my * hy).fdiv(mx ** 2 + my ** 2)
	if t0 <= 0
	elsif t0 < 1
		hx -= t0 * mx
		hy -= t0 * my
	else
		hx -= mx
		hy -= my
	end
	return hx ** 2 + hy ** 2
end

def self.rtate(x, y, ox, oy, angle)
	if angle == 0 then return x, y end
	x -= ox
	y -= oy
	if angle == 90 || angle == -270
		x, y = -y, x
	elsif angle == 180 || angle == -180
		x, y = -x, -y
	elsif angle == 270 || angle == -90
		x, y = y, -x
	else
		angle *= DEG2RAD_C
		sin, cos = Math::sin(angle), Math::cos(angle)
		x, y = x * cos - y * sin, x * sin + y * cos 
	end
	return x + ox, y + oy
end

# TODO: move to bbox module
def self.rot_bbox(b, x, y, angle)
	angle %= 360
	return true if angle == 0
	return false if angle % 90 != 0
	b.x1, b.y1 = Pet.rtate(b.x1, b.y1, x, y, angle)
	b.x2, b.y2 = Pet.rtate(b.x2, b.y2, x, y, angle)
	b.x1, b.x2 = b.x2, b.x1 if b.x1 > b.x2
	b.y1, b.y2 = b.y2, b.y1 if b.y1 > b.y2
	true
end

class Pet_Object_List < Array
	attr_accessor :selected, :hit_selected, :xhoover, :attributes_selected
	def initialize
		super
		@xhoover = false
		@selected = 0
		@attributes_selected = false
		@hit_selected = 0
	end

	def alive
    reject {|el| el.state == State::Deleted}
  end

  def each_alive(&block)
    alive.each(&block)
  end

	def cancel_new_object
		self.pop if self.last.absorbing
	end

	def new_object(pda, t, x, y)
		if t == Input_Mode::Net
			self << NetSegment.start(x, y, pda)
		elsif t == Input_Mode::Pin
			self << Pin.start(x, y, pda)
		elsif t == Input_Mode::Line
			self << Line.start(x, y, pda)
		elsif t == Input_Mode::Box
			self << Box.start(x, y, pda)
		elsif t == Input_Mode::Circle
			self << Circ.start(x, y, pda)
		elsif t == Input_Mode::Arc
			self << Arc.start(x, y, pda)
		elsif t == Input_Mode::Path
			self << Path.start(x, y, false, pda)
		elsif t == Input_Mode::Curve
			self << Path.start(x, y, true, pda)
		elsif t == Input_Mode::Text
			self << Text.start(x, y, pda)
		end
	end

	# TODO: proof!
	def process_popup_menu(boxlist, msg, x, y)
		if !self.empty? && self.last.absorbing
			self.last.process_popup(boxlist, @hit_selected, @selected, msg, x, y)
			return
		end
		z = nil
		self.each{|el|
			h = el.process_popup(boxlist, @hit_selected, @selected, msg, x, y)
			if h
			puts 'got copy', h.class
			h.state = State::Selected
			z = h
			end
		}
		self << z if z
	end

	# third stage of user input analysis
	# handle special cases -- absorbing elements, elements returning new ones
	# or deleting itself, and single selection for overlapping elements
	# caution: this is called indirect recursively for attributes!
	# boxlist: array of bounding boxes with changed content -- accumulating for redraw
	# event: Gdk event
	# x0, y0: current mouse pointer position in user coordinates (int)
	# x, y: may be delta values for delta move
	# @hit_selected: if we move a selected element, then all selected elements are moved
	# return: is event absorbed -- this may be relevant for attributes
	def preprocess_event(boxlist, event, x0, y0, x, y, msg)
		return false if self.empty?
		if (el = self.last) && el.absorbing
			el = el.absorb(boxlist, event, x0, y0, x, y, msg) # absorbing element may create a new one or mark itself deleted
			self.pop if self[-1].state == State::Deleted
			self << el if el
			return true
		end
		if msg == PEM::Hoover_Select # set @hoover -- now after instance variable is set for attributes!
			@xhoover = false
			self.each{|el|
				if el.bbox and (el.selectable != 0) # hidden text has no valid bbox
					el.old_hoover = el.hoover
					if el.bbox.include_point?(x, y)
						el.hoover = true
						if el.attributes.find{|a| (a.bbox != nil) && (a.selectable != 0) && a.bbox.include_point?(x, y)}
							@xhoover = true
							el.hoover = false
						elsif el.core_box
							el.hoover = el.core_box.include_point?(x, y)
						end
					else
						el.hoover = false
					end
					@xhoover ||= el.hoover
				end
			}
		end
		if msg == PEM::Delta_Move then @fdm += 1 else @fdm = 0 end # first delta-move -- find @hit_selected
		msg == PEM::Hit_Select ? @hsc += 1 : @hsc = 0 # hit select count
		if @hsc == 2
			@sel_list = Array.new
			self.each{|el|
				if el.bbox && el.selectable != 0 # hidden text has no valid bbox
					@sel_list += el.attributes.select{|a| a.hoover}
					@sel_list << el if el.hoover
				end
			}
			@sel_list.sort_by!{|el| el.bbox.hit_size}
		end
		if @hsc >= 2 && @sel_list.length > 1
			@hit_selected = 1
			@sel_list.last.hoover = false
			@sel_list.last.state = State::Visible
			h = @sel_list.shift
			h.hoover = true
			h.state = State::Selected
			@sel_list.push(h)
			@sel_list.each{|el| boxlist << el.bbox if el.bbox}
			return true
		end
		if (msg == PEM::Scroll_Rotate) || (msg == PEM::Hit_Select) || (@fdm == 1)
			@hit_selected = 0
			self.each{|el|
				if el.bbox && el.selectable != 0 # hidden text has no valid bbox
					@hit_selected += 1 if el.hoover && el.state == State::Selected
				end
			}
		end
		res = nil
		absorbed = false
		old_sel = @selected
		@selected = 0
		self.each{|el|
			res = el.process_event(boxlist, event, x0, y0, x, y, @hit_selected, old_sel, msg)
			@selected += 1 if el.state == State::Selected && !(el.class == Text && el.visibility == GEDA_TEXT_INVISIBLE)
			if res
				absorbed = true
				break if res.class == NetSegment || res.class == Line
			end
		}
		self << res if res.class == NetSegment || res.class == Line
		if msg == PEM::Hoover_Select # set @hoover -- now after instance variable is set for attributes!
			@attributes_selected = false
			self.each{|el|
				if @selected == 0
					@attributes_selected ||= el.attributes.find{|a| a.state == State::Selected}
				else
					@attributes_selected = true
				end
			}
		end
		return absorbed
	end
end

class Cairo::Context
	attr_accessor :sharp_lines, :soft, :highlight, :line_width_device_min, :line_width_unscaled_user_min, :line_width_scale
	attr_accessor :text_shadow_scale, :line_shadow_fix, :text_shadow_fix, :line_shadow_scale
	attr_accessor :bbox, :g_join, :g_cap, :connections, :hair_line_scale
	attr_accessor :background_pattern, :background_pattern_offset_x, :background_pattern_offset_y, :device_grid_major
	alias :orig_init :initialize
	def initialize(surface)
		orig_init(surface)
		@background_pattern = nil
		@device_grid_major = 1
		@background_pattern_offset_x, @background_pattern_offset_y = 0, 0
		@bbox = Bounding::Box.new_ghost
		@connections = Hash.new(0)
		@sharp_lines = true # defaults, overwrite for each surface if necessary
		@soft = false
		@highlight = false
		@line_shadow_scale = 0
		@line_shadow_fix = 0
		@text_shadow_fix = 0
		@text_shadow_scale = 1
		@line_width_device_min = 0
		@hair_line_scale = 0.2
		@line_width_unscaled_user_min = 10
		@line_width_scale = Default_Line_Width_Scale
		@g_join = Array.new
		@g_join[GEDA::END_CAP[:NONE]] = Cairo::LINE_JOIN_BEVEL
		@g_join[GEDA::END_CAP[:SQUARE]] = Cairo::LINE_JOIN_MITER
		@g_join[GEDA::END_CAP[:ROUND]] = Cairo::LINE_JOIN_ROUND
		@g_cap = Array.new
		@g_cap[GEDA::END_CAP[:NONE]] = Cairo::LINE_CAP_BUTT
		@g_cap[GEDA::END_CAP[:SQUARE]] = Cairo::LINE_CAP_SQUARE
		@g_cap[GEDA::END_CAP[:ROUND]] = Cairo::LINE_CAP_ROUND
	end

	# NOTE: this may overwrite line_cap set before!
	def geda_set_dash(dashstyle, dashlength, dashspace)
		if dashstyle == GEDA::LINE_TYPE[:SOLID]
			set_dash([], 0)
		elsif dashstyle == GEDA::LINE_TYPE[:DOTTED]
			set_line_cap(Cairo::LINE_CAP_ROUND)
			set_dash([0, dashspace], 0)
		elsif dashstyle == GEDA::LINE_TYPE[:DASHED]
			set_dash([dashlength, dashspace], dashlength * 0.5)
		elsif dashstyle == GEDA::LINE_TYPE[:CENTER]
			set_line_cap(Cairo::LINE_CAP_ROUND)
			set_dash([dashlength, dashspace, 0, dashspace], dashlength * 0.5)
		elsif dashstyle == GEDA::LINE_TYPE[:PHANTOM]
			set_line_cap(Cairo::LINE_CAP_ROUND)
			set_dash([dashlength, dashspace, 0, dashspace, 0, dashspace], dashlength * 0.5)
		end
	end

	if method_defined?(:my_method_is_undefined?)
		puts 'We are unintentionally overwriting method Cairo::Context.my_method_is_undefined?'
		Process.exit!
	else
		def self.my_method_is_undefined?(sym)
			if method_defined?(sym)
				print 'We are unintentionally overwriting method Cairo::Context.', sym, "\n"
				Process.exit!
			end
			true
		end
	end

	# TODO: maybe use array instead of single values
	# TODO: tune
	if self.my_method_is_undefined?(:set_color)
		def set_color(r, g, b, a)
			if @highlight
				r = r ** 1.3 * 1.8
				g = g ** 1.3 * 1.8
				b = b ** 1.3 * 1.8
				if (m = [r, g, b].max) > 1
					r /= m
					g /= m
					b /= m
				end
			end
			self.set_source_rgba([r, g, b, a])
		end
	end

	if self.my_method_is_undefined?(:set_contrast_color)
		def set_contrast_color(rgba)
			if rgba[0..2].reduce(:+) < 1 # not 1.5, prefer black
				set_source_rgba([1, 1, 1, 1])
			else
				set_source_rgba([0, 0, 0, 1])
			end
		end
	end

	if self.my_method_is_undefined?(:get_contrast_color)
		def get_contrast_color(rgba)
			rgba[0..2].reduce(:+) < 1 ? 1 : 0 # not 1.5, prefer black
		end
	end

	if self.my_method_is_undefined?(:user_to_device_scale)
		def user_to_device_scale(w)
			Math::hypot(*user_to_device_distance(w, 0))
		end
	end

	if self.my_method_is_undefined?(:device_to_user_scale)
		def device_to_user_scale(w)
			Math::hypot(*device_to_user_distance(w, 0))
		end
	end

	if self.my_method_is_undefined?(:unscaled_user_to_device_line_width)
		def unscaled_user_to_device_line_width(u)
			u = @line_width_unscaled_user_min if u < @line_width_unscaled_user_min
			u = Math::hypot(*user_to_device_distance(u * @line_width_scale, 0))
			u > @line_width_device_min ? u : @line_width_device_min
		end
	end

	if self.my_method_is_undefined?(:device_to_user_line_width)
		def device_to_user_line_width(d)
			d = @line_width_device_min if d < @line_width_device_min
			Math::hypot(*device_to_user_distance(d, 0))
		end
	end

	if self.my_method_is_undefined?(:clamped_line_width)
		def clamped_line_width(w)
			h = device_to_user_line_width(unscaled_user_to_device_line_width(w))
			h + Math::sqrt(h) * @line_shadow_scale # sqrt is a trick
		end
	end

	# mostly used for bounding box calculation
	if self.my_method_is_undefined?(:full_clamped_line_width)
		def full_clamped_line_width(w)
			h = device_to_user_line_width(unscaled_user_to_device_line_width(w))
			h + Math::sqrt(h) * 4 ### largest grow when selected and hovering #NOTE: * 3 should be enough!
		end
	end

	# without thickness increase for selected and hovering
	if self.my_method_is_undefined?(:plain_clamped_line_width)
		def plain_clamped_line_width(w)
			device_to_user_line_width(unscaled_user_to_device_line_width(w))
		end
	end

	# smallest regular thickness divided by s
	if self.my_method_is_undefined?(:hair_line_width)
		def hair_line_width(s)
			device_to_user_line_width(unscaled_user_to_device_line_width(0)).fdiv(s)
		end
	end

	if self.my_method_is_undefined?(:set_hair_line_width)
		def set_hair_line_width(s)
			set_line_width(hair_line_width(s))
		end
	end

	if self.my_method_is_undefined?(:clamped_set_line_width)
		def clamped_set_line_width(w)
			set_line_width(clamped_line_width(w))
		end
	end

	def draw_cross_hair(x, y, s)
		move_to(x - s, y - s)
		line_to(x + s, y + s)
		move_to(x - s, y + s)
		line_to(x + s, y - s)
	end

	def draw_circle(x, y, r)
		new_sub_path
		arc(x, y, r, 0, Math::TAU)
	end

	if self.my_method_is_undefined?(:sharp_line)
		def sharp_line(x1, y1, x2, y2, wu)
			if @sharp_lines # always true? Do not confuse with @soft
				wu = @line_width_unscaled_user_min if wu < @line_width_unscaled_user_min
				wu *= @line_width_scale
				wu += Math::sqrt(wu) * @line_shadow_scale
				w = Math::hypot(*user_to_device_distance(wu, 0))
				w = @line_width_device_min if w < @line_width_device_min
				wd = w.round
				wu = Math::hypot(*device_to_user_distance(wd, 0)) if w > 1
				wd = 1 if wd < 1
				x1, y1 = user_to_device(x1, y1)
				x2, y2 = user_to_device(x2, y2)
				if (x1 - x2).abs < 0.1 # eps
					x1 = (x1 + x2) * 0.5
					x1 = (wd.even? != @soft) ? x1.round : x1.floor + 0.5
					x2 = x1
				elsif (y1 - y2).abs < 0.1 # eps
					y1 = (y1 + y2) * 0.5
					y1 = (wd.even? != @soft) ? y1.round : y1.floor + 0.5
					y2 = y1
				end
				x1, y1 = device_to_user(x1, y1)
				x2, y2 = device_to_user(x2, y2)
				set_line_width(wu)
			else
				clamped_set_line_width(wu)
			end
			move_to(x1, y1)
			line_to(x2, y2)
			stroke
		end
	end

	if self.my_method_is_undefined?(:sharp_rect)
		def sharp_rect(x1, y1, w, h, wu)
			if @sharp_lines # always true? Do not confuse with @soft
				x2 = x1 + w
				y2 = y1 + h
				wu = @line_width_unscaled_user_min if wu < @line_width_unscaled_user_min
				wu *= @line_width_scale
				wu += Math::sqrt(wu) * @line_shadow_scale
				w = Math::hypot(*user_to_device_distance(wu, 0))
				w = @line_width_device_min if w < @line_width_device_min
				wd = w.round
				wu = Math::hypot(*device_to_user_distance(wd, 0)) if w > 1
				wd = 1 if wd < 1
				x1, y1 = user_to_device(x1, y1)
				x2, y2 = user_to_device(x2, y2)
				if wd.even? != @soft
					x1 = x1.round
					y1 = y1.round
					x2 = x2.round
					y2 = y2.round
				else
					x1 = x1.floor + 0.5
					y1 = y1.floor + 0.5
					x2 = x2.floor + 0.5
					y2 = y2.floor + 0.5
				end
				x1, y1 = device_to_user(x1, y1)
				x2, y2 = device_to_user(x2, y2)
				set_line_width(wu)
				rectangle(x1, y1, x2 - x1, y2 - y1)
			else
				clamped_set_line_width(wu)
				rectangle(x1, y1, w, h)
			end
		end
	end

	# TODO: currently unused, check when used
	if self.my_method_is_undefined?(:sharp_thin_line)
		def sharp_thin_line(x1, y1, x2, y2, wu)
			if @sharp_lines
				eps = 0.1
				wu = @line_width_unscaled_user_min if wu < @line_width_unscaled_user_min
				w = user_to_device_scale(wu * @line_width_scale * @hair_line_scale)
				wd = w.round
				wu = device_to_user_scale(wd) if w > 1
				wd = 1 if wd < 1
				x1, y1 = user_to_device(x1, y1)
				x2, y2 = user_to_device(x2, y2)
				if (x1 - x2).abs < eps
					x1 = (x1 + x2) * 0.5
					x1 = (wd.even? != @soft) ? x1.round : x1.floor + 0.5
					x2 = x1
				elsif (y1 - y2).abs < eps
					y1 = (y1 + y2) * 0.5
					y1 = (wd.even? != @soft) ? y1.round : y1.floor + 0.5
					y2 = y1
				end
				x1, y1 = device_to_user(x1, y1)
				x2, y2 = device_to_user(x2, y2)
				set_line_width(wu)
			else
				clamped_set_line_width(wu) # TODO: @hair_line_scale missing?
			end
			move_to(x1, y1)
			line_to(x2, y2)
			stroke
		end
	end

	# TODO: May fail for rotated coordinate systems
	if self.my_method_is_undefined?(:faster_sharp_thin_line_h)
		def faster_sharp_thin_line_h(x1, x2, y, even)
			y = user_to_device(x1, y)[1]
			y = device_to_user(x1, even ? y.round : y.floor + 0.5)[1]
			move_to(x1, y)
			line_to(x2, y)
		end
	end

	if self.my_method_is_undefined?(:faster_sharp_thin_line_v)
		def faster_sharp_thin_line_v(y1, y2, x, even)
			x = user_to_device(x, y1)[0]
			x = device_to_user(even ? x.round : x.floor + 0.5, y1)[0]
			move_to(x, y1)
			line_to(x, y2)
		end
	end

end # class Cairo::Context

def self.on_egrid?(*p)
	p.each{|x| if x % EGRID != 0 then return false end}
	return true
end

def self.diagonal_line?(x1, y1, x2, y2)
	(x1 != x2) and (y1 != y2)
end

def self.line_too_short?(x1, y1, x2, y2)
	(x1 - x2) ** 2 + (y1 - y2) ** 2 < MIN_STRUCTURE_SIZE ** 2
end

# for data exchange with properties box
class Attr_Msg
	ID_NEW = 0
	ID_INHERITED = 1
	ID_MODIFIED = 2 # i.e. moved
	ID_REDEFINED = 3 # value changed
	attr_accessor :name, :name_visible, :value, :value_visible, :id
	attr_accessor :x, :y, :color, :size, :angle, :alignment
	attr_accessor :show_details
end

class Element
	attr_accessor :bbox # full bounding box
	attr_accessor :core_box # bounding box without attributes, nil if attributes.empty?
	attr_accessor :type # single character
	attr_accessor :state # module State
	attr_accessor :old_hoover # store old value, when changed redraw is necessary
	attr_accessor :hoover # mouse pointer over element?
	attr_accessor :selectable # 0 == false, 1 == true. Can only be 0 for symbols! 
	attr_accessor :absorbing # element consumes input
	attr_accessor :attributes # textual attributes, array
	attr_accessor :box_needs_fix # i.e. Text -- exact size is known after first draw
	attr_accessor :pda # reference to pet drawing area
	attr_accessor :is_component
	attr_accessor :nil_draw # boolean, set to true when unclipped draw is necessary

	def initialize(pda = nil)
		@is_component = false
		@pda = pda
		@state = State::Visible
		@hoover = false
		@old_hoover = false
		@selectable = 1
		@core_box = nil
		@absorbing = false
		@box_needs_fix = true
		@nil_draw = false
		@attributes = Pet_Object_List.new # TODO: Maybe we should use a special, simplified list
	end

	def deep_copy
		h = self.dup
		h.bbox = @bbox.dup
		h.core_box = @core_box.dup if @core_box
		h.attributes = @attributes.map{|el| el.attr_deep_copy} if @attributes
		return h
	end

	# origin of element, generally x member -- overwrite when not
	def origin_x
		@x
	end

	def origin_y
		@y
	end

	def mytos(*a)
		a.join(' ') + "\n"
	end

	def attr_to_s
		if @attributes.empty? then '' else "{\n" + @attributes.join("") + "}\n" end
	end

	def set_box
		if @attributes.empty?
			@core_box = nil
		else
			@core_box = @bbox.dup
			h = false # visible attribute?
			@attributes.each{|a| if a.visibility == GEDA_TEXT_VISIBLE then h = true; a.enlarge_bbox(@bbox) end}
			@core_box = nil unless h
		end
	end

	def origin_snap
		grid = pda.schem.active_grid
		x = origin_x.fdiv(grid).round * grid
		y = origin_y.fdiv(grid).round * grid
		translate(x - origin_x, y - origin_y)
	end

	# TODO: check later -- we have to think about multi line attributes
	def get_attributes
		s = @attributes.length == 1
		t = false # show details only for first selected attribute
		@attributes.each{|el|
			msg = Attr_Msg.new
			t ||= msg.show_details = !t && (el.state == State::Selected || s)
			msg.name, msg.value = el.lines.split('=', 2)
			msg.name_visible = (el.visibility == GEDA_TEXT_VISIBLE) && (el.show_name_value != GEDA_TEXT_SHOW_VALUE) 
			msg.value_visible = (el.visibility == GEDA_TEXT_VISIBLE) && (el.show_name_value != GEDA_TEXT_SHOW_NAME) 
			msg.x = el.x - origin_x
			msg.y = el.y - origin_y
			msg.color = el.color
			msg.size = el.size
			msg.angle = el.angle
			msg.alignment = el.alignment
			if h = instance_variable_defined?(:@attr_hash) && attr_hash[msg.name] # only symbols can have inherited attributes
				if h.lines.split('=', 2)[1] != msg.value
					msg.id = Attr_Msg::ID_REDEFINED
				elsif msg.x != h.x || msg.y != h.y || msg.color != h.color || msg.size != h.size || msg.angle != h.angle || msg.alignment != h.alignment ||
					msg.name_visible != (h.visibility == GEDA_TEXT_VISIBLE) && (h.show_name_value != GEDA_TEXT_SHOW_VALUE) ||
					msg.value_visible != (h.visibility == GEDA_TEXT_VISIBLE) && (h.show_name_value != GEDA_TEXT_SHOW_NAME)
					msg.id = Attr_Msg::ID_MODIFIED
				else
					msg.id = Attr_Msg::ID_INHERITED
				end
			else
				msg.id = Attr_Msg::ID_NEW
			end
			yield msg
		}
	end

	# TODO: check valid index?
	# TODO: Seems that this is called multiple times, why?
	def full_set_attributes(a, i)
		#puts ' full_set_attributes'
		#puts i
		#p a
		h = @attributes[i]
		a.name ||= ""
		a.value ||= ""
		h.lines = a.name + '=' + a.value #+ "\n"
		if a.value_visible
			h.show_name_value = (a.name_visible ? GEDA_TEXT_SHOW_NAME_VALUE : GEDA_TEXT_SHOW_VALUE)
			h.visibility = GEDA_TEXT_VISIBLE
			h.selectable = 1
		elsif a.name_visible
			h.show_name_value = GEDA_TEXT_SHOW_NAME
			h.visibility = GEDA_TEXT_VISIBLE
			h.selectable = 1
		else
			h.visibility = GEDA_TEXT_INVISIBLE
			h.selectable = 0
		end
		h.pda = self.pda
		h.x = a.x + origin_x
		h.y = a.y + origin_y
		h.color = a.color
		h.size = a.size
		h.alignment = a.alignment
		h.box_needs_fix = true
		#p h

		#p @attributes[1]
		if  h.visibility == GEDA_TEXT_VISIBLE
			h.nil_draw = true
			@nil_draw = true
			@box_needs_fix = true
		end
	end

	# TODO: no graphical update?
	def xrem_attribute(i)
		@attributes.delete_at(i)
	end

	def add_empty_attribute
		@attributes << Text.new(0, 0)
	end

	def enlarge_bbox(b)
		b.join(@bbox)
	end

	# TODO: check carefully -- we do not care currently!
	# returns true if element is moved or state is changed
	# works not bad, but needs cleanup,
	# we should only process attributes if necessary...
	#
	# TODO: pass msg to attributes as below!
	def process_popup(boxlist, hit_selected, selected, msg, x, y)
		return false if @state == State::Deleted
		if @absorbing && msg == PMM::Cancel
			@state = State::Deleted
		end
		if @absorbing && msg == PMM::Done
			@absorbing = false
		end
		if @absorbing && msg == PMM::Back
			absorb(boxlist, nil, x, y, x, y, PEM::KEY_BackSpace)
		end
			if @hoover && msg == PMM::Select
					@state == State::Selected ? @state = State::Visible : @state = State::Selected
			end
			if ((selected > 0) and (@state == State::Selected)) or ((selected == 0) and @hoover)
				if msg == PMM::Delete
					@state = State::Deleted
				end
				if msg == PMM::CW
			boxlist << @bbox
				self.rotate(x.round(-2) , y.round(-2), 90)
				end
				if msg == PMM::Mirror
			boxlist << @bbox
					self.mirror2x0( 2 * x.round(-2))
				end
				if msg == PMM::Copy
					return self.deep_copy
				end
			end
			boxlist << @bbox
			return nil
	end

	# TODO: Some more care is necessary for the properties box, i.e. when displayed object is deleted or unselected
	# x0, y0, x, y: selection rectangle for drag select, ...
	# depending on msg x0, y0 may be rounded to active grid (rotate) or be initial position...
	# return: true/false for absorbed indication, or maybe a new element
	def process_event(boxlist, event, x0, y0, x, y, hit_selected, selected, msg)
		silent_change = false
		return false if @state == State::Deleted || @selectable == 0
		return false if self.class == Text && @visibility == GEDA_TEXT_INVISIBLE
		if ((event.event_type == Gdk::EventType::BUTTON_PRESS) or (event.event_type == Gdk::EventType::BUTTON_RELEASE)) and (event.button > 2)
			return false # (currently) button 3 is ignored 
		end

		ctrl = event.state & Gdk::ModifierType::CONTROL_MASK != 0
		shift = event.state & Gdk::ModifierType::SHIFT_MASK != 0
		if self.instance_variable_defined?(:@attributes) and !@attributes.empty? # TODO: maybe only when really necessary
			if @attributes.preprocess_event(boxlist, event, x0, y0, x, y, msg)
				@box_needs_fix = true
				@nil_draw = true
				if (selected == 1) && (@state == State::Selected) && @pda && @pda.schem && @pda.schem.prop_box
					@pda.schem.prop_box.org_update_coordinates(self)
				end
				return true if (@state != State::Selected) || msg != PEM::Hit_Select || (ctrl or shift) || @attributes.selected > 0
			end
		end
		@attributes.each{|a| a.parent_hoover = @hoover} # TODO: maybe give each attribute a ref to parent
		old_state = @state
		if (msg == PEM::Hit_Select) or (msg ==	PEM::Drag_Select)
			if (msg == PEM::Hit_Select) && (((hit_selected > 0) && (@state == State::Selected)) || ((hit_selected == 0) && @hoover)) &&
			self.respond_to?(:special_hit_action) and (new_el = special_hit_action(boxlist, x, y, event.button))
				return new_el
			end
			if msg == PEM::Hit_Select
				sel = @hoover
			else # msg ==	PEM::Drag_Select
				sel = (@bbox and Bounding::Box.new(x0, y0, x, y).include?(@bbox))
			end
			if sel
				if ctrl # toggle
					if @state == State::Visible
						@state = State::Selected
					else
						@state = State::Visible
					end
				else # add
					@state = State::Selected
				end
			elsif not (ctrl or shift)
				silent_change = (msg == PEM::Hit_Select)

				@state = State::Visible
			end
		elsif msg == PEM::Delta_Move # TODO: only when x != 0 and y != 0 ???
		if (((hit_selected > 0) and (@state == State::Selected)) or ((hit_selected == 0) and @hoover)) && self.respond_to?(:special_move_action) && special_move_action(boxlist, x0, y0, x, y)
				return true
			elsif ((hit_selected > 0) and (@state == State::Selected)) or ((hit_selected == 0) and @hoover)
				boxlist << @bbox.dup.enlarge(x, y) # dup is required, because translate only modifies it! #TODO: wrong! maybe enlarge_abs?
				self.translate(x, y)
				if (selected == 1) && (@state == State::Selected) && @pda && @pda.schem && @pda.schem.prop_box
					@pda.schem.prop_box.org_update_coordinates(self)
				end
				return true
			end
		elsif msg == PEM::Check_Alive
			@state = State::Deleted if self.is_zombi 
		elsif msg == PEM::KEY_Delete
			if ((hit_selected > 0) and (@state == State::Selected)) or ((hit_selected == 0) and @hoover)
				@state = State::Deleted
			end
		elsif msg == PEM::KEY_Edit
			if self.class == Pet::Text && @hoover
				if @pda
					@cursor = @pda.schem.main_window.activate_entry(self)
					old_state = -1
				end
			end
		elsif (msg == PEM::Scroll_Rotate)
			if ((hit_selected > 0) and (@state == State::Selected)) or ((hit_selected == 0) and @hoover)
				if event.direction == Gdk::ScrollDirection::UP
					a = 90
				elsif event.direction == Gdk::ScrollDirection::DOWN
					a = -90
				elsif event.direction == Gdk::ScrollDirection::LEFT
					puts 'left'
				elsif event.direction == Gdk::ScrollDirection::RIGHT
					puts 'right'
				else
					fail
				end
				if a # TODO: use angle from configuration 
					a /= 6 if self.class == Text 
					boxlist << @bbox.dup
					self.rotate(x0 , y0, a)
					boxlist << @bbox.dup
					if (selected == 1) && (@state == State::Selected) && @pda && @pda.schem && @pda.schem.prop_box
						@pda.schem.prop_box.org_update_coordinates(self)
					end
				end
				return true
			end
		end
		if (@state != old_state) or (@hoover != @old_hoover)
			boxlist << @bbox
			@box_needs_fix = true unless @attributes.empty?
		end
		if @state != old_state
			@attributes.each{|el| if el.selectable != 0 && el.bbox then
			if el.state != @state then silent_change = false end
			el.state = @state; end}
		end
		return @state != old_state #&& !silent_change
	end
end

class NPL < Element # Net, Pin, Line -- common methods

	attr_accessor :x1, :y1, :x2, :y2 # integer
	attr_accessor :color # index color

	def initialize(x1, y1, x2, y2, pda = nil)
		super(pda)
		@x1, @y1, @x2, @y2 = x1, y1, x2, y2
		@bbox = Bounding::Box.new(x1, y1, x2, y2) # initial dummy, overwritten from draw methode -- without first draw() fails
		@box_width = NetSegment::Min_Box_Width
		@box_needs_fix = true # draw() method should set exact sizes
	end

	def is_zombi
		@x1 == @x2 && @y1 == @y2
	end

	def origin_x
		@x1 < @x2 ? @x1 : @x2
	end

	def origin_y
		@y1 < @y2 ? @y1 : @y2
	end

	def mirror2x0(x0)
		@x1 = x0 - @x1
		@x2 = x0 - @x2
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = [@x1, @y1, @x2, @y2]
		grid = pda.schem.active_grid
		@x1 = @x1.fdiv(grid).round * grid
		@y1 = @y1.fdiv(grid).round * grid
		@x2 = @x2.fdiv(grid).round * grid
		@y2 = @y2.fdiv(grid).round * grid
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || a != [@x1, @y1, @x2, @y2]
	end

	def translate(x, y)
		@x1 += x; @y1 += y
		@x2 += x; @y2 += y
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	# TODO: we may reduce this size when we zoom in!
	def connect_dist
		@box_width / 2
	end

	# when we click close to endpoint of net then return that point
	# px, py: mouse pointer coordinates
	def connect(px, py)
		h = connect_dist ** 2
		if (@x1 - px) ** 2 + (@y1 - py) ** 2 < h
			return @x1, @y1
		elsif (@x2 - px) ** 2 + (@y2 - py) ** 2 < h
			return @x2, @y2
		else
			return nil
		end
	end
	
	# TODO: plain @box_needs_fix = @nil_draw = true may be indeed faster, because of smaller redraw area?
	def rotate(x, y, angle)
		@x1, @y1 = Pet.rtate(@x1, @y1, x, y, angle)
		@x2, @y2 = Pet.rtate(@x2, @y2, x, y, angle)
		@attributes.each{|a| a.rotate(x, y, angle)}
		Pet.rot_bbox(@bbox, x, y, angle)
		Pet.rot_bbox(@core_box, x, y, angle) if @core_box
	end

	# move endpoints
	# px, py: mouse pointer coordinates
	# dx, dy: displacement
	def special_move_action(boxlist, px, py, dx, dy)
		cd = connect_dist ** 2
		if (@x1 - px) ** 2 + (@y1 - py) ** 2 < cd
			@x1 += dx
			@y1 += dy
		elsif (@x2 - px) ** 2 + (@y2 - py) ** 2 < cd
			@x2 += dx
			@y2 += dy
		else
			return false
		end
		if @x1 == @x2 && @y1 == @y2
			@state = State::Deleted
			boxlist << @bbox
		else
			h = @bbox.dup
			@bbox.reset(x1, y1, x2, y2).grow(@box_width)
			set_box
			boxlist << h.join(@bbox)
		end
		true
	end
end

# NOTE: exact bbox size is set by draw method, because for exact net width calculation cr and par is needed
# for thin elements like nets and lines, we may like to have a box for graphics extents and one larger for grabbing --
# currently we have not
class NetSegment < NPL
	MaxNetEndmarkDia = 32 # for max 64*64 Rectangle at unconnected net ends
	EndMarkScale = 2 # red end mark square of unnconected nets -- edge length is 4 times net thickness
	EndMarkMinDia = 8 # 16*16 square min
	Box_Scale = 4 # grab box width is 4 times net thickness
	Min_Box_Width = 32 # min for grabbing
	Max_Box_Width = 2 * MaxNetEndmarkDia
	Connect_Radius = 25 # connect to endpoint
	Junction_Scale = 1.5 # junction radius is 1.5 * netwidth
	attr_accessor :overlapp # this net overlapps with another one -- mark it red!

	def initialize(x1, y1, x2, y2, pda = nil)
		super(x1, y1, x2, y2, pda)
		@overlapp = false
		@type = NetSegChar
		@color = Pet_Config::Colorindex_geda_net
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x1, @y1, @x2, @y2, @color) + attr_to_s
	end

	def NetSegment.start(x, y, pda)
		n = NetSegment.new(x, y, x, y, pda)
		pda.schem.main_window.prop_box.init_object(n)
		n.absorbing = true
		n.state = State::Selected
		return n
	end

	def check(warn = false)
		return '' if @state == State::Deleted
		if not Pet_Config::COLOR_INDEX_RANGE.include?(@color)
			return "color index (#{@color}) out of range\n"
		elsif warn && @color != Pet_Config::Colorindex_geda_net
			return " color index (#{@color}) should be #{NET_COLOR}\n" # warning
		elsif Pet.diagonal_line?(@x1, @y1, @x2, @y2) # only a warning
			t = ' diagonal net'
		elsif not Pet.on_egrid?(@x1, @y1, @x2, @y2) 
			t = 'net segment is not on e-grid'
		elsif @x1 == @x2 && @y1 == @y2
			t = 'net segment of length 0'
		else
			t = ''
		end
		t <<	", #{@x1}, #{@y1} -- #{@x2}, #{@y2}\n" unless t == ''
		return t
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		return nil if @state == State::Deleted
		if msg == PEM::Hoover_Select
			return nil if @x2 == x0 && @y2 == y0
			@x2, @y2 = x0, y0
			h = @bbox.dup
			@bbox.reset(@x1, @y1, @x2, @y2).grow(@box_width)
			set_box
			boxlist << h.join(@bbox) 
		elsif msg == PEM::Hit_Select
			@absorbing = false
			if @x1 == @x2 && @y1 == @y2
				@state = State::Deleted
				boxlist << @bbox 
			else
				@state = State::Visible
				boxlist << @bbox 
				return NetSegment.start(@x2, @y2, @pda)
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		return nil
	end

	# start new net from endpoint or split net into two
	# px, py: mouse pointer coordinates
	def special_hit_action(boxlist, px, py, button)
		return nil if @state == State::Deleted
		if button == 1 && (cp = connect(px, py))
			boxlist << @bbox
			return NetSegment.start(*cp, @pda)
		end
		if button == 2 && Pet.distance_line_segment_point_squared(@x1, @y1, @x2, @y2, px, py) < connect_dist ** 2
			grid = pda.schem.active_grid
			px = px.fdiv(grid).round * grid
			py = py.fdiv(grid).round * grid
			x = (@x2 - px) ** 2 + (@y2 - py) ** 2
			y = (@x1 - px) ** 2 + (@y1 - py) ** 2
			boxlist << @bbox
			return nil if x == 0 || y == 0
			if x < y # 1-----p--2 keep longer one, may have attributes
				x, y = @x2, @y2
				@x2, @y2 = px, py
			else
				x, y = @x1, @y1
				@x1, @y1 = px, py
			end
			@bbox.reset(@x1, @y1, @x2, @y2).grow(@box_width)
			set_box
			return NetSegment.new(px, py, x, y, @pda)
		end
		return nil
	end

	def draw_junctions(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		return if draw_hoovered || draw_selected
		return unless @bbox.overlap_list?(damage_list)
		[[@x1, @y1], [@x2, @y2]].each{|el|
			if cr.connections[el] > 7
				cr.connections.delete(el)
				cr.set_color(*par[:color_geda_junction]) # TODO: maybe caller should do this
				w = cr.plain_clamped_line_width(par[:line_width_net])
				cr.arc(el[0], el[1], Junction_Scale * w, 0, Math::TAU)
				cr.fill
			end
		}
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				[[@x1, @y1], [@x2, @y2]].each_with_index{|el, i|
					if cr.connections[el] == 4 # open, unconnected net end
						h = cr.clamped_line_width(par[:line_width_net])
						w = h * EndMarkScale
						w = EndMarkMinDia if w < EndMarkMinDia
						w = MaxNetEndmarkDia if w > MaxNetEndmarkDia
						w = h if w < h
						d = (2 * i - 1) * w / Math::hypot(@x2 - @x1, @y2 - @y1)
						dx = (@x2 - @x1) * d # dx, dy is a scaled unit vector from p2 to p1
						dy = (@y2 - @y1) * d
						dxr = -dy # that vector rotated by 90 degree
						dyr = dx
						cr.move_to(el[0] - dx - dxr, el[1] - dy - dyr)
						if @attributes.find{|a| a.lines.split('=', 2).first.downcase == 'netname'}
							[dxr + 2 * dx, dyr + 2 * dy, dxr - 2 * dx, dyr - 2 * dy].each_slice(2){|x, y|
								cr.rel_line_to(x, y)
							}
						else
							[2 * dx, 2 * dy, 2 * dxr, 2 * dyr, -2 * dx, -2 * dy].each_slice(2){|x, y|
								cr.rel_line_to(x, y)
							}
						end
						cr.set_color(*par[:color_geda_net_endpoint])
						cr.fill
					end
				}
				cr.set_line_cap(cr.g_cap[par[:net_end_cap]])
				cr.set_dash([], 0)
				@overlapp ? cr.set_color(*par[:pin_hot_end_color]) : cr.set_color(*par[Pet_Config::CIM[@color]])
				cr.sharp_line(@x1, @y1, @x2, @y2, par[:line_width_net])
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected)) # NOTE: @is_component should be always false for net
				@box_width = Box_Scale * cr.full_clamped_line_width(par[:line_width_net])
				@box_width = Min_Box_Width if @box_width < Min_Box_Width
				@box_width = Max_Box_Width if @box_width > Max_Box_Width
				@bbox.reset(@x1, @y1, @x2, @y2).grow(@box_width)
				set_box
				@box_needs_fix = false
			end
		end
	end
end

NORMAL_PIN = 0
BUS_PIN = 1 # unused
class Pin < NPL
	attr_accessor :pintype, :whichend
	attr_accessor :gen_num
	def initialize(x1, y1, x2, y2, pda = nil)
		super(x1, y1, x2, y2, pda)
		@type = PinChar
		@color = Pet_Config::Colorindex_geda_pin
		@pintype = NORMAL_PIN
		@whichend = 0
		@gen_num = 99 # set from GUI
	end

	def to_s
		return '' if @state == State::Deleted
		if @whichend == 0
			mytos(@type, @x1, @y1, @x2, @y2, @color, @pintype, @whichend) + attr_to_s
		else
			mytos(@type, @x2, @y2, @x1, @y1, @color, @pintype, @whichend) + attr_to_s
		end
	end

	def Pin.start(x, y, pda)
		p = Pin.new(x, y, x, y, pda)
		pda.schem.main_window.prop_box.init_object(p)
		p.absorbing = true
		p.state = State::Selected
		return p
	end

	def check(warn = false)
		if not Pet_Config::COLOR_INDEX_RANGE.include?(@color)
			return "color index #{@color} out of range\n"
		elsif warn && @color != Pet_Config::Colorindex_geda_pin
			return " color index (#{@color}) should be #{Pet_Config::Colorindex_geda_pin}\n" # warning
		elsif @pintype != NORMAL_PIN
			return "pintype (#{@pintype}) should be NORMAL_PIN == 0\n"
		elsif @whichend != 0 && @whichend != 1
			return "whichend (#{@whichend}) should be 0 or 1\n"
		elsif Pet.diagonal_line?(@x1, @y1, @x2, @y2)
			t = 'diagonal pin'
		elsif not Pet.on_egrid?(@x1, @y1) 
			t = 'active pin end is not on e-grid'
		elsif @x1 == @x2 && @y1 == @y2
			t = 'pin of length 0'
		elsif Pet.line_too_short?(@x1, @y1, @x2, @y2)
			t = 'very short pin'
		else
			t = ''
		end
		t <<	", #{@x1}, #{@y1} -- #{@x2}, #{@y2}\n" unless t == ''
		return t
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			return nil if @x2 == x0 && @y2 == y0
			@x2, @y2 = x0, y0
			h = @bbox.dup
			@bbox.reset(x1, y1, x2, y2).grow(@box_width)
			set_box # should be not necessary, we have no attributes yet
			boxlist << h.join(@bbox) 
		elsif msg == PEM::Hit_Select
			@absorbing = false
			if @x1 == @x2 && @y1 == @y2
				@state = State::Deleted
				boxlist << @bbox 
			elsif @x1 == @x2 || @y1 == @y2
				num = Text.new(0, 0, @pda)
				seq = Text.new(0, 0, @pda)
				name = Text.new(0, 0, @pda)
				type = Text.new(0, 0, @pda)
				num.lines << 'num'
				seq.lines << 'seq'
				name.lines << 'name'
				type.lines << 'type'
				dx = 25
				dy = 25
				if @x1 < @x2
					num.x = @x2 - dx
					num.y = @y2 + dy
					num.alignment = 6
					seq.x = @x2 - dx
					seq.y = @y2 - dy
					seq.alignment = 8
					name.x = @x2 + dx
					name.y = @y2
					name.alignment = 1
					type.x = @x2 + dx
					type.y = @y2 - 50
					type.alignment = 2
				elsif @x1 > @x2
					num.x = @x2 + dx
					num.y = @y2 + dy
					num.alignment = 0
					seq.x = @x2 + dx
					seq.y = @y2 - dy
					seq.alignment = 2
					name.x = @x2 - dx
					name.y = @y2
					name.alignment = 7
					type.x = @x2 - dx
					type.y = @y2 - 50
					type.alignment = 8
				elsif @y1 < @y2
					num.x = @x2 + dx
					num.y = @y2 - dy
					num.alignment = 2
					seq.x = @x2 - dx
					seq.y = @y2 - dy
					seq.alignment = 8
					name.x = @x2
					name.y = @y2 + dy
					name.alignment = 1
					name.angle = 90
					type.x = @x2 + 50
					type.y = @y2 + dy
					type.alignment = 2
					type.angle = 90
				elsif @y1 > @y2
					num.x = @x2 + dx
					num.y = @y2 + dy
					num.alignment = 0
					seq.x = @x2 - dx
					seq.y = @y2 + dy
					seq.alignment = 6
					name.x = @x2
					name.y = @y2 - dy
					name.alignment = 7
					name.angle = 90
					type.x = @x2 + 50
					type.y = @y2 - dy
					type.alignment = 8
					type.angle = 90
				end
				[num, seq, name, type].each{|el|
					el.bbox.reset(el.x, el.y, el.x, el.y)
					el.show_name_value = GEDA_TEXT_SHOW_VALUE
					el.size = 8
					el.color = Pet_Config::Colorindex_geda_attribute
					el.nil_draw = true
					el.lines << "=#{@gen_num}"
					self.attributes << el
				}
				name.size = 10
				name.color = Pet_Config::Colorindex_geda_text
				seq.visibility = GEDA_TEXT_INVISIBLE
				type.visibility = GEDA_TEXT_INVISIBLE
				type.lines = "type=inout"
				boxlist << @bbox 
				@box_needs_fix = true
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		@pda.schem.prop_box.show_properties(self)
		return nil
	end

	# when we click close to hot endpoint of pin then return that point
	# px, py: mouse pointer coordinates
	def connect(px, py)
		if (@x1 - px) ** 2 + (@y1 - py) ** 2 < connect_dist ** 2
			return @x1, @y1
		else
			return nil
		end
	end

	# start new net from hot pin endpoint, only for pins in symbols
	# px, py: mouse pointer coordinates
	def special_hit_action(boxlist, px, py, button)
		if @is_component && (button == 1) && (cp = connect(px, py))
			return NetSegment.start(*cp, @pda)
		end
		return nil
	end

	MarkPinJunction = false # TODO: from config
	def draw_junctions(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		return if draw_hoovered || draw_selected
		return unless @bbox.overlap_list?(damage_list) # TODO: restrict test to hot end?
		k = [@x1, @y1]
		if (h = cr.connections[k]) > 3
			cr.connections.delete(k)
			return if h < 8 && !MarkPinJunction
			cr.set_color(*par[:color_geda_junction]) # caller may do this!
			w = cr.plain_clamped_line_width(par[:line_width_net])
			w *= NetSegment::Junction_Scale if h > 7
			cr.arc(@x1, @y1, w, 0, Math::TAU)
			cr.fill
		end
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				cr.set_line_cap(cr.g_cap[par[:pin_end_cap]])
				cr.set_dash([], 0)
				cr.set_color(*par[Pet_Config::CIM[@color]])
				if !@is_component || cr.connections[[@x1, @y1]] == 3
					h = 25 / Math::hypot(@x2 - @x1, @y2 - @y1)
					h = 1 if h > 1
					dx = (@x2 - @x1) * h
					dy = (@y2 - @y1) * h
					cr.sharp_line(@x1 + dx, @y1 + dy, @x2, @y2, par[:line_width_pin])
					cr.set_color(*par[:pin_hot_end_color])
					cr.sharp_line(@x1, @y1, @x1 + dx, @y1 + dy, par[:line_width_pin])
				else
					cr.sharp_line(@x1, @y1, @x2, @y2, par[:line_width_pin])
				end
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				@box_width = NetSegment::Box_Scale * cr.full_clamped_line_width(par[:line_width_pin])
				@box_width = NetSegment::Min_Box_Width if @box_width < NetSegment::Min_Box_Width
				@box_width = NetSegment::Max_Box_Width if @box_width > NetSegment::Max_Box_Width
				@bbox.reset(@x1, @y1, @x2, @y2).grow(@box_width)
				set_box
				@box_needs_fix = false
			end
		end
	end

end

class Line < NPL
	attr_accessor :width, :capstyle, :dashstyle, :dashlength, :dashspace
	def initialize(x1, y1, x2, y2, pda = nil)
		super(x1, y1, x2, y2, pda)
		@type = LineChar
		@color = Pet_Config::Colorindex_geda_graphic
		@capstyle = GEDA::END_CAP[:ROUND]
		@dashstyle = GEDA::LINE_TYPE[:SOLID]
		@dashlength = -1
		@dashspace = -1
		@width = DefaultLineWidth
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x1, @y1, @x2, @y2, @color, @width, @capstyle, @dashstyle, @dashlength, @dashspace) + attr_to_s
	end

	def Line.start(x, y, pda)
		l = Line.new(x, y, x, y, pda)
		pda.schem.main_window.prop_box.init_object(l)
		l.absorbing = true
		l.state = State::Selected
		return l
	end

	def check(warn = false)
		if @width < 0
			return "line width should not be negative (#{@width})\n"
		elsif not GEDA::END_CAP.has_value? @capstyle
			return "unsupported cap style (#{@capstyle})\n"
		elsif not GEDA::LINE_TYPE.has_value? @dashstyle
			return "unsupported dash style (#{@dashstyle})\n"
		elsif (@dashstyle != GEDA::LINE_TYPE[:SOLID]) and (@dashspace <= 0)
			return "dashspace should be > 0 (#{@dashspace})\n" # we should query result of cairo stroke for other problems 
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index (#{@color}) out of range\n" 
		elsif Pet.line_too_short?(@x1, @y1, @x2, @y2)
			return "very short line, #{@x1}, #{@y1} -- #{@x2}, #{@y2}\n"
		else
			return ''
		end
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			return nil if @x2 == x0 && @y2 == y0
			h = @bbox.dup
			@x2, @y2 = x0, y0
			@bbox.reset(x1, y1, x2, y2).grow(@box_width)
			### set_box
			boxlist << h.join(@bbox) 
		elsif msg == PEM::Hit_Select
			@absorbing = false
			if @x1 == @x2 && @y1 == @y2
				@state = State::Deleted
			else
				@state = State::Visible
				boxlist << @bbox 
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		return nil
	end

	# start new line from endpoint
	# px, py: mouse pointer coordinates
	def special_hit_action(boxlist, px, py, button)
		return nil if @state == State::Deleted
		if button == 1 && (cp = connect(px, py))
			h = Line.start(*cp, @pda)
			h.color = @color
			h.capstyle = @capstyle
			h.dashstyle = @dashstyle
			h.dashlength = @dashlength
			h.dashspace = @dashspace
			h.width = @width
			return h
		end
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				cr.set_color(*par[Pet_Config::CIM[@color]])
				cr.set_line_cap(cr.g_cap[@capstyle])
				cr.geda_set_dash(@dashstyle, @dashlength, @dashspace)
				cr.sharp_line(@x1, @y1, @x2, @y2, @width)
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				@box_width = cr.full_clamped_line_width(@width)
				@box_width = NetSegment::Min_Box_Width if @box_width < NetSegment::Min_Box_Width
				@bbox.reset(@x1, @y1, @x2, @y2).grow(@box_width)
				set_box
				@box_needs_fix = false
			end
		end
	end

	#def deep_copy
	#e = Marshal.load(Marshal.dump(xygrid['page']))
	#return self.dup
	#end

end

class Box < Element
	attr_accessor :x, :y, :width, :height, :color, :linewidth, :capstyle, :dashstyle, :dashlength, :dashspace, :filltype, :fillwidth, :angle1, :pitch1, :angle2, :pitch2
	def initialize(x, y, width, height, pda = nil)
		super(pda)
		@type = BoxChar
		@x, @y = x, y
		@width, @height = width, height
		@color = Pet_Config::Colorindex_geda_graphic
		@linewidth = DefaultLineWidth
		@capstyle = GEDA::END_CAP[:SQUARE]
		@dashstyle = GEDA::LINE_TYPE[:SOLID]
		@dashlength = -1
		@dashspace = -1
		@filltype = GEDA::FILLING[:HOLLOW]
		@fillwidth = -1
		@angle1 = -1
		@pitch1 = -1
		@angle2 = -1
		@pitch2 = -1
		@bbox = Bounding::Box.new(@x, @y, @x + @width, @y + @height)
		@box_needs_fix = true # draw should set exact size
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x, @y, @width, @height, @color, @linewidth, @capstyle, @dashstyle, @dashlength, @dashspace, @filltype, @fillwidth, @angle1, @pitch1, @angle2, @pitch2) + attr_to_s
	end

	def Box.start(x, y, pda)
		b = Box.new(x, y, 0, 0, pda)
		b.state = State::Selected
		#pda.schem.main_window.prop_box.init_object(b)
		b.absorbing = true
		return b
	end

	def is_zombi
		@width == 0 || @height == 0 # may be negative!
	end

	def check(warn = false)
		if @linewidth < 0
			return "line width should not be negative (#{@linewidth})\n"
		elsif (@filltype == GEDA::FILLING[:MESH]) or (@filltype == GEDA::FILLING[:HATCH])
			if @pitch1 <= 0
				return "pitch1 for filling should be > 0(#{@pitch1})\n"
			elsif not (-360..360).include? @angle1
				return "angle1 for filling should be in the range -360..360 (#{@angle1})\n"
			end
			if @filltype == GEDA::FILLING[:MESH]
				if @pitch2 <= 0
					return "pitch2 for filling should be > 0(#{@pitch2})\n"
				elsif not (-360..360).include? @angle2
					return "angle2 for filling should be in the range -360..360 (#{@angle2})\n"
				elsif warn && @angle1 == @angle2
					return " mesh with angle1 == angle2 (#{@angle1})\n" # warning, may be intended for different pitch
				end
			end
		elsif not GEDA::END_CAP.has_value? @capstyle
			return "unsupported cap style (#{@capstyle})\n"
		elsif not GEDA::LINE_TYPE.has_value? @dashstyle
			return "unsupported dash style (#{@dashstyle})\n"
		elsif (@dashstyle != GEDA::LINE_TYPE[:SOLID]) and (@dashspace <= 0)
			return "dashspace should be > 0 (#{dashspace})\n" # we may query result of cairo stroke for other problems 
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index #{@color} out of range\n" 
		elsif [@width, @height].min < MIN_STRUCTURE_SIZE # should we support negative @width, @height?
			return "very small rectangle (#{@width}, #{@height})\n"
		end
		return ''
	end

	def mirror2x0(x0)
		@x = x0 - @x - @width
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = [@x, @y, @width, @height]
		grid = pda.schem.active_grid
		@x = @x.fdiv(grid).round * grid
		@y = @y.fdiv(grid).round * grid
		@width = @width.fdiv(grid).round * grid
		@height = @height.fdiv(grid).round * grid
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || a != [@x, @y, @width, @height]
	end

	def translate(x, y)
		@x += x; @y += y;
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	def rotate(x, y, angle)
		x2 = @x + @width
		y2 = @y + @height
		@x, @y = Pet.rtate(@x, @y, x, y, angle)
		x2, y2 = Pet.rtate(x2, y2, x, y, angle)
		@width = x2 - @x # can become negative
		@height = y2 - @y
		@attributes.each{|a| a.rotate(x, y, angle)}
		Pet.rot_bbox(@bbox, x, y, angle)
		Pet.rot_bbox(@core_box, x, y, angle) if @core_box
		#@box_needs_fix = true
		#@nil_draw = true
	end

	def connect_dist
		@linewidth / 2 > NetSegment::Connect_Radius ? @linewidth / 2 : NetSegment::Connect_Radius
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			return nil if (@width == x0 - @x) && (@height == y0 - @y)
			@box_needs_fix = true
			@nil_draw = true
			@width = x0 - @x
			@height = y0 - @y
			boxlist << @bbox # NOTE: here we add only the old bbox and use @nil_draw!
		elsif msg == PEM::Hit_Select
			@absorbing = false
			if @width == 0 || @height == 0 # can be negative!
				@state = State::Deleted
			else
				@state = State::Visible
				boxlist << @bbox 
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		return nil
	end

	# y2----------
	# |					|
	# h					|
	# |					|
	# xy----w---x2
	# move edges and corners
	# px, py: mouse pointer coordinates
	# dx, dy: displacement
	def special_move_action(boxlist, px, py, dx, dy)
		x2 = @x + @width
		y2 = @y + @height
		cd = connect_dist ** 2
		h = false
		if Pet.distance_line_segment_point_squared(@x, @y, @x, y2, px, py) < cd
			@x += dx
			h = true
		elsif Pet.distance_line_segment_point_squared(x2, @y, x2, y2, px, py) < cd
			x2 += dx
			h = true
		end
		if Pet.distance_line_segment_point_squared(@x, @y, x2, y, px, py) < cd
			@y += dy
			h = true
		elsif Pet.distance_line_segment_point_squared(@x, y2, x2, y2, px, py) < cd
			y2 += dy
			h = true
		end
		if h 
			@width = x2 - @x
			@height = y2 - @y
			if @width == 0 || @height == 0
				@state = State::Deleted
				boxlist << @bbox 
			else
				boxlist << @bbox 
				@box_needs_fix = true
				@nil_draw = true
			end
		end
		h
	end

	# NOTE: for linewidth > 0, alpha < 1 and filling, we get a more saturated border!
	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				cr.set_color(*par[Pet_Config::CIM[@color]])
				cr.set_line_cap(cr.g_cap[@capstyle])
				cr.set_line_join(cr.g_join[@capstyle])
				cr.geda_set_dash(@dashstyle, @dashlength, @dashspace)
				cr.sharp_rect(@x, @y, @width, @height, @linewidth)
				cr.stroke_preserve
				if @filltype == GEDA::FILLING[:FILL] # we have no separate fill color
					cr.fill
				elsif (@filltype == GEDA::FILLING[:MESH]) or (@filltype == GEDA::FILLING[:HATCH])
					cr.save
					cr.clip
					cr.translate(@x + @width * 0.5, @y + @height * 0.5)
					cr.set_dash([], 0)
					cr.clamped_set_line_width(@fillwidth)
					z = Math::hypot(@width, @height) * 0.5 
					cr.rotate(@angle1 * DEG2RAD_C)
					p = @pitch1 - z
					while p < z do
						cr.move_to(-z, p)
						cr.line_to(z, p)
						p += @pitch1
					end
					cr.stroke
					if (@filltype == GEDA::FILLING[:MESH])
						cr.rotate((@angle2 - @angle1) * DEG2RAD_C)
						p = @pitch2 - z
						while p < z do
							cr.move_to(-z, p)
							cr.line_to(z, p)
							p += @pitch2
						end
						cr.stroke
					end
					cr.restore
				else
					cr.new_path
				end
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				if (h = cr.full_clamped_line_width(@linewidth) / 2) < NetSegment::Connect_Radius
					h = NetSegment::Connect_Radius
				end
				@bbox.reset(@x, @y, @x + @width, @y + @height).grow(h)
				@box_needs_fix = false
				set_box
			end
		end
	end

end # box

# NOTE: @nil_draw should be set to true when linewidth is increased by GUI
class Circ < Element
	attr_accessor :x, :y, :radius, :color, :linewidth, :capstyle, :dashstyle, :dashlength, :dashspace, :filltype, :fillwidth, :angle1, :pitch1, :angle2, :pitch2
	def initialize(x, y, radius, pda = nil)
		super(pda)
		@type = CircChar
		@x, @y = x, y
		@radius = radius
		@color = Pet_Config::Colorindex_geda_graphic
		@linewidth = DefaultLineWidth
		@capstyle = GEDA::END_CAP[:ROUND]
		@dashstyle = GEDA::LINE_TYPE[:SOLID]
		@dashlength = -1
		@dashspace = -1
		@filltype = GEDA::FILLING[:HOLLOW]
		@fillwidth = -1
		@angle1 = -1
		@pitch1 = -1
		@angle2 = -1
		@pitch2 = -1
		@bbox = Bounding::Box.new(@x - @radius, @y - @radius, @x + @radius, @y + @radius)
		@box_needs_fix = true # draw should set exact size
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x, @y, @radius, @color, @linewidth, @capstyle, @dashstyle, @dashlength, @dashspace, @filltype, @fillwidth, @angle1, @pitch1, @angle2, @pitch2) + attr_to_s
	end

	def Circ.start(x, y, pda)
		c = Circ.new(x, y, 0, pda)
		c.state = State::Selected
		#pda.schem.main_window.prop_box.init_object(c)
		c.absorbing = true
		return c
	end

	def is_zombi
		@radius <= 0
	end

	def check(warn = false)
		return ''
		if @linewidth < 0
			return "line width should not be negative (#{@linewidth})\n"
		elsif @filltype == GEDA::FILLING[:MESH] || @filltype == GEDA::FILLING[:HATCH]
			if @pitch1 <= 0
				return "pitch1 for filling should be > 0(#{@pitch1})\n"
			elsif not (-360..360).include? @angle1
				return "angle1 for filling should be in the range -360..360 (#{@angle1})\n"
			end
			if @filltype == GEDA::FILLING[:MESH]
				if @pitch2 <= 0
					return "pitch2 for filling should be > 0(#{@pitch2})\n"
				elsif not (-360..360).include? @angle2
					return "angle2 for filling should be in the range -360..360 (#{@angle2})\n"
				elsif warn && @angle1 == @angle2
					return " mesh with angle1 == angle2 (#{@angle1})\n" # warning, may be intended for different pitch
				end
			end
		elsif not GEDA::END_CAP.has_value? @capstyle
			return "unsupported cap style (#{@capstyle})\n"
		elsif not GEDA::LINE_TYPE.has_value? @dashstyle
			return "unsupported dash style (#{@dashstyle})\n"
		elsif @dashstyle != GEDA::LINE_TYPE[:SOLID]
			if	@dashspace <= 0
				return "dash space should be > 0 (#{@dashspace})\n"
			elsif	@dashlength < 0
				return "dash length should be > 0 (#{@dashlength})\n"
			end
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index #{@color} out of range\n" 
		elsif @radius < MIN_STRUCTURE_SIZE
			return "very small circle (#{@radius})\n"
		end
		return ''
	end

	def mirror2x0(x0)
		@x = x0 - @x
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = [@x, @y, @radius]
		grid = pda.schem.active_grid
		#@x = (@x + grid / 2) / grid * grid # may be faster?
		@x = @x.fdiv(grid).round * grid
		@y = @y.fdiv(grid).round * grid
		@radius = @radius.fdiv(grid).round * grid
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || a != [@x, @y, @radius]
	end

	def translate(x, y)
		@x += x; @y += y;
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	def rotate(x, y, angle)
		@x, @y = Pet.rtate(@x, @y, x, y, angle)
		@attributes.each{|a| a.rotate(x, y, angle)}
		@box_needs_fix = true
		@nil_draw = true
	end

	def connect_dist
		@linewidth / 2 > NetSegment::Connect_Radius ? @linewidth / 2 : NetSegment::Connect_Radius
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			h = Math::hypot(x0 - @x, y0 - @y)
			return nil if h == @radius
			boxlist << @bbox.dup 
			@bbox.grow(h - @radius)
			@nil_draw ||= h > @radius
			@radius = h
		elsif msg == PEM::Hit_Select
			@absorbing = false
			if @radius <= 0
				@state = State::Deleted
			else
				@state = State::Visible
				boxlist << @bbox 
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		return nil
	end

	# resize circle
	# px, py: mouse pointer coordinates
	# dx, dy: displacement
	def special_move_action(boxlist, px, py, dx, dy)
		h = Math::hypot(px - @x, py - @y)
		return false if (@radius - h).abs > connect_dist
		puts 'special_move_action'
		x = px + dx
		y = py + dy
		grid = pda.schem.active_grid
		x = x.fdiv(grid).round * grid
		y = y.fdiv(grid).round * grid
		h = Math::hypot(x - @x, y - @y)
		if h != @radius
			if h == 0
				@state = State::Deleted
				boxlist << @bbox
			else
				boxlist << @bbox 
				@box_needs_fix = true
				@nil_draw = true
				@radius = h
			end
		end
		true
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				cr.set_color(*par[Pet_Config::CIM[@color]])
				cr.set_line_cap(cr.g_cap[@capstyle])
				cr.geda_set_dash(@dashstyle, @dashlength, @dashspace)
				cr.clamped_set_line_width(@linewidth)
				cr.new_sub_path
				cr.arc(@x, @y, @radius, 0, Math::TAU)
				cr.stroke_preserve
				if @filltype == GEDA::FILLING[:FILL] # we have no separate fill color
					cr.fill
				elsif @filltype == GEDA::FILLING[:MESH] or @filltype == GEDA::FILLING[:HATCH]
					cr.save
					cr.clip
					cr.translate(@x, @y)
					cr.set_dash([], 0)
					cr.clamped_set_line_width(@fillwidth)
					z = @radius 
					cr.rotate(@angle1 * DEG2RAD_C)
					p = @pitch1 - z
					while p < z do
						cr.move_to(-z, p)
						cr.line_to(z, p)
						p += @pitch1
					end
					cr.stroke
					if @filltype == GEDA::FILLING[:MESH]
						cr.rotate((@angle2 - @angle1) * DEG2RAD_C)
						p = @pitch2 - z
						while p < z do
							cr.move_to(-z, p)
							cr.line_to(z, p)
							p += @pitch2
						end
						cr.stroke
					end
					cr.restore
				else
					cr.new_path
				end
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				if (h = cr.full_clamped_line_width(@linewidth) / 2) < NetSegment::Connect_Radius
					h = NetSegment::Connect_Radius
				end
				@bbox.reset(@x, @y, @x, @y).grow(@radius + h)
				@box_needs_fix = false
				set_box
			end
		end
	end
end

class Arc < Element
	attr_accessor :x, :y, :radius, :startangle, :sweepangle, :color, :linewidth, :capstyle, :dashstyle, :dashlength, :dashspace
	attr_accessor :have_first # for absorbing, do we already have first point?
	def initialize(x, y, radius, pda = nil)
		super(pda)
		@type = ArcChar
		@x, @y = x, y
		@radius = radius
		@startangle = 0 # degree
		@sweepangle = 0
		@color = Pet_Config::Colorindex_geda_graphic
		@linewidth = DefaultLineWidth
		@capstyle = GEDA::END_CAP[:ROUND]
		@dashstyle = GEDA::LINE_TYPE[:SOLID]
		@dashlength = -1
		@dashspace = -1
		@bbox = Bounding::Box.new(@x - @radius, @y - @radius, @x + @radius, @y + @radius)
		@box_needs_fix = true # draw should set exact size
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x, @y, @radius, @startangle, @sweepangle, @color, @linewidth, @capstyle, @dashstyle, @dashlength, @dashspace) + attr_to_s
	end

	def Arc.start(x, y, pda)
		a = Arc.new(x, y, 0, pda)
		a.state = State::Selected
		a.sweepangle = 360
		a.have_first = false
		#pda.schem.main_window.prop_box.init_object(c) # TODO!
		a.absorbing = true
		return a
	end

	def is_zombi
		@radius <= 0 || @sweepangle == 0
	end

	def check(warn = false)
		if is_zombi
			return "zombi arc\n"
		elsif @linewidth < 0
			return "line width should not be negative (#{@linewidth})\n"
		elsif not GEDA::END_CAP.has_value? @capstyle
			return "unsupported cap style (#{@capstyle})\n"
		elsif not GEDA::LINE_TYPE.has_value? @dashstyle
			return "unsupported dash style (#{@dashstyle})\n"
		elsif @dashstyle != GEDA::LINE_TYPE[:SOLID]
			if	@dashspace < 0
				return "dashspace should be >= 0 (#{@dashspace})\n"
			elsif	@dashlength < 0
				return "dashlength should be >= 0 (#{@dashlength})\n"
			end
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index #{@color} out of range\n" 
#		elsif @radius < MIN_STRUCTURE_SIZE # some inductors use that!
#			return "very small arc (#{@radius})\n"
		elsif not (-360..360).include? @startangle
			return "startangle should be in the range -360..360 (#{@startangle})\n"
		elsif not (-360..360).include? @sweepangle
			return "sweepangle should be in the range -360..360 (#{@sweepangle})\n"
		end
		return ''
	end

	def mirror2x0(x0)
		@x = x0 - @x
		@startangle = 180 - @startangle - @sweepangle
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = [@x, @y, @radius, @startangle]
		grid = pda.schem.active_grid
		@x = @x.fdiv(grid).round * grid
		@y = @y.fdiv(grid).round * grid
		x = @x + Math::cos(@startangle * DEG2RAD_C) * @radius
		y = @y + Math::sin(@startangle * DEG2RAD_C) * @radius
		x = x.fdiv(grid).round * grid
		y = y.fdiv(grid).round * grid
		@sweepangle += @startangle
		@startangle = Math.atan2(y, x) * RAD2DEG_C
		@sweepangle -= @startangle
		@radius = Math::hypot(x, y)
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || a != [@x, @y, @radius, @startangle]
	end

	def translate(x, y)
		@x += x; @y += y;
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	def rotate(x, y, angle)
		@x, @y = Pet.rtate(@x, @y, x, y, angle)
		@startangle += angle
		@attributes.each{|a| a.rotate(x, y, angle)}
		@box_needs_fix = true
		@nil_draw = true
	end

	def connect_dist
		@linewidth / 2 > NetSegment::Connect_Radius ? @linewidth / 2 : NetSegment::Connect_Radius
	end

	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			if @have_first
				@sweepangle = Math.atan2(y0 - @y, x0 - @x) * RAD2DEG_C - @startangle unless y0 == @y && x0 == @x
			else
				@startangle = Math.atan2(y0 - @y, x0 - @x) * RAD2DEG_C unless y0 == @y && x0 == @x # store here, with rounded x0, y0!
				h = Math::hypot(x0 - @x, y0 - @y)
				return nil if h == @radius
				@radius = h
			end
			boxlist << @bbox 
			@box_needs_fix = true
			@nil_draw = true
		elsif msg == PEM::Hit_Select
			if @have_first
				@absorbing = false
				if @radius <= 0 || @sweepangle == 0
					@state = State::Deleted
				else
					@state = State::Visible
				end
				boxlist << @bbox 
			else
				@have_first = true
			end
		elsif msg == PEM::KEY_BackSpace || msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
			boxlist << @bbox 
		end
		return nil
	end

	# edit arc
	# px, py: mouse pointer coordinates
	# dx, dy: displacement
	def special_move_action(boxlist, px, py, dx, dy)
		x = y = 0 # we need this, otherwise lamda below uses local variables!
		update = -> () {
			x = px + dx - @x
			y = py + dy - @y
			if pda.schem.grid_snap
				grid = pda.schem.active_grid
				x = x.fdiv(grid).round * grid
				y = y.fdiv(grid).round * grid
			end
			@radius = Math::hypot(x, y)
			@nil_draw = true
			@box_needs_fix = true
			boxlist << @bbox
		}
		cd = connect_dist ** 2
		x = @x + Math::cos(@startangle * DEG2RAD_C) * @radius
		y = @y + Math::sin(@startangle * DEG2RAD_C) * @radius
		if (x - px) ** 2 + (y - py) ** 2 < cd
			update.call()
			@sweepangle += @startangle
			@startangle = Math.atan2(y, x) * RAD2DEG_C
			@sweepangle -= @startangle
			@state = State::Deleted if @radius == 0 || @sweepangle == 0
			return true
		end
		x = @x + Math::cos((@startangle + @sweepangle) * DEG2RAD_C) * @radius
		y = @y + Math::sin((@startangle + @sweepangle) * DEG2RAD_C) * @radius
		if (x - px) ** 2 + (y - py) ** 2 < cd
			update.call()
			@sweepangle = Math.atan2(y, x) * RAD2DEG_C - @startangle
			@state = State::Deleted if @radius == 0 || @sweepangle == 0
			return true
		end
		false
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if !(@is_component || draw_hoovered || draw_selected)
				cr.set_hair_line_width(2)
				cr.set_line_cap(Cairo::LINE_CAP_ROUND)
				cr.set_dash([], 0)
				cr.set_contrast_color(par[:color_geda_background])
				cr.draw_cross_hair(@x, @y, par[:text_mark_size] / 2)
				cr.stroke
			end
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				cr.set_color(*par[Pet_Config::CIM[@color]])
				cr.set_line_cap(cr.g_cap[@capstyle])
				cr.geda_set_dash(@dashstyle, @dashlength, @dashspace)
				cr.clamped_set_line_width(@linewidth)
				cr.new_sub_path
				cr.arc(@x, @y, @radius, @startangle * DEG2RAD_C, (@startangle + @sweepangle) * DEG2RAD_C)
				cr.stroke
				if !@is_component && (draw_hoovered || draw_selected)
					cr.set_hair_line_width(2)
					cr.set_line_cap(Cairo::LINE_CAP_ROUND)
					cr.set_dash([], 0)
					cr.set_contrast_color(par[Pet_Config::CIM[@color]])
					n0 = cr.clamped_line_width(@linewidth) * 0.25
					x = @x + Math::cos(@startangle * DEG2RAD_C) * @radius
					y = @y + Math::sin(@startangle * DEG2RAD_C) * @radius
					cr.draw_cross_hair(x, y, n0)
					x = @x + Math::cos((@startangle + @sweepangle) * DEG2RAD_C) * @radius
					y = @y + Math::sin((@startangle + @sweepangle) * DEG2RAD_C) * @radius
					cr.draw_cross_hair(x, y, n0)
					cr.stroke
				end
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				if (h = cr.full_clamped_line_width(@linewidth) / 2) < NetSegment::Connect_Radius
					h = NetSegment::Connect_Radius
				end
				cr.new_path
				cr.arc(@x, @y, @radius, @startangle * DEG2RAD_C, (@startangle + @sweepangle) * DEG2RAD_C)
				@bbox.reset(*cr.path_extents).grow(h)
				if !@is_component
					k = Bounding::Box.new(@x, @y, @x, @y).grow( par[:text_mark_size] / 2)
					@bbox.join(k)
				end
				@box_needs_fix = false
				set_box
			end
		end
	end
end # Arc

# Cubic Bezier Spline
# http://cairographics.org/manual/cairo-Paths.html#cairo-curve-to
# cairo curve: p0 is start, p1, p2 control points, p3 end point
#	p1			p2
# |	. .	  |
#	| .  .  |
# |.		. |
# p0			p3
#
# We enter points in order (p0) p1, p3, p2 in GUI
# p3 is start of next segment also, and first control
# point of next segment is given by p2 mirrored at p3,
# giving smooth curves

# start point, and degenerated case p1 == p0, p2 == p3
def self.mytos(*a) # TODO: remove
	a.join(' ') + "\n"
end
class Path_P
	attr_accessor :x, :y
	def initialize(x, y)
		@x, @y = x, y
	end
	def d(x, y)
		(@x - x) ** 2 + (@y - y) ** 2
	end
	def to_s(c = 'L')
		Pet.mytos c, "#{@x},#{@y}"
	end
end

class Path_T
	attr_accessor :x, :y, :x1, :y1, :x2, :y2 # p3 is stored in x, y
	def initialize(x1, y1, x2, y2, x, y)
		@x1, @y1, @x2, @y2, @x, @y = x1, y1, x2, y2, x, y
	end
	# closest squared distance to one of the three points -- did user clicked one?
	def d(x, y)
		[(@x - x) ** 2 + (@y - y) ** 2, (@x1 - x) ** 2 + (@y1 - y) ** 2, (@x2 - x) ** 2 + (@y2 - y) ** 2].min
	end
	def to_s
		Pet.mytos 'C', "#{@x1},#{@y1}", "#{@x2},#{@y2}", "#{@x},#{@y}"
	end
end

# NOTE: @nil_draw and @box_needs_fix:
# For some elements like nets or thin lines we can set the bounding box immedeately.
# For more difficult objects like arcs or curves/paths it is not easy to find the bounding box.
# So when such an element is changed, we generally set @box_needs_fix to true, so that draw()
# method will set new exact box. Often we set also @nil_draw to true at the same time to ensure
# that draw() will do an unclipped draw, which is necessary if bounding box has grown.
# But @nil_draw and @box_needs_fix are not strongly coupled -- i.e. for first draw after program
# startup @box_needs_fix is true for most objects, but @nil_draw can be false, because we draw
# the whole sheet with bounding box of same large size. 

class Path < Element
	attr_accessor :color, :linewidth, :capstyle, :dashstyle, :dashlength, :dashspace, :filltype, :fillwidth, :angle1, :pitch1, :angle2, :pitch2, :numlines, :closed
	attr_accessor :input # input buffer, 6 points max
	attr_accessor :nodes # array of Path_P and Path_T
	attr_accessor :curve # boolean, curve or plain path, for input processing only
	def initialize(pda = nil)
		super(pda)
		@type = PathChar
		@color = Pet_Config::Colorindex_geda_graphic
		@linewidth = DefaultLineWidth
		@capstyle = GEDA::END_CAP[:ROUND]
		@dashstyle = GEDA::LINE_TYPE[:SOLID]
		@dashlength = -1
		@dashspace = -1
		@filltype = GEDA::FILLING[:HOLLOW]
		@fillwidth = -1
		@angle1 = -1
		@pitch1 = -1
		@angle2 = -1
		@pitch2 = -1
		@numlines = 0
		@closed = false
		@nodes = Array.new
		@input = Array.new
		@box_needs_fix = true # draw should set exact size
		@show_edit = false
	end

	def to_s
		return '' if @state == State::Deleted
		if @closed
			z = "Z\n"
			i = 1
		else
			z = ''
			i = 0
		end
		mytos(@type, @color, @linewidth, @capstyle, @dashstyle, @dashlength, @dashspace, @filltype, @fillwidth, @angle1, @pitch1, @angle2, @pitch2 ,@nodes.length + i) +
		@nodes.first.to_s('M') + @nodes[1..-1].join('') + z + attr_to_s
	end

	def init_box(x, y)
		@bbox = Bounding::Box.new(x, y, x, y)
	end
	
	def Path.start(x, y, curve, pda)
		p = Path.new(pda)
		p.state = State::Selected
		p.init_box(x, y)
		p.curve = curve
		p.absorbing = true
		#pda.schem.main_window.prop_box.init_object(c) # TODO!
		p.nodes << Path_P.new(x, y)
		p.input << x << y
		return p
	end

	def is_zombi
		l = @nodes.length
		!(l > 2 || (l == 2 && @nodes.last.class == Path_T) || @nodes.first.x != @nodes.last.x || @nodes.first.y != @nodes.last.y)
	end

	def check(warn = false)
		if is_zombi
			return "zombi path\n"
		elsif @linewidth < 0
			return "line width should not be negative (#{@linewidth})\n"
		elsif not GEDA::END_CAP.has_value? @capstyle
			return "unsupported cap style (#{@capstyle})\n"
		elsif not GEDA::LINE_TYPE.has_value? @dashstyle
			return "unsupported dash style (#{@dashstyle})\n"
		elsif @dashstyle != GEDA::LINE_TYPE[:SOLID]
			if	@dashspace < 0 # == 0 is OK, i.e. for dotted line
				return "dashspace should be >= 0 (#{@dashspace})\n"
			elsif	@dashlength < 0
				return "dashlength should be >= 0 (#{@dashlength})\n"
			end
		elsif @filltype == GEDA::FILLING[:MESH] || @filltype == GEDA::FILLING[:HATCH]
			if @pitch1 <= 0
				return "pitch1 for filling should be > 0(#{@pitch1})\n"
			elsif not (-360..360).include? @angle1
				return "angle1 for filling should be in the range -360..360 (#{@angle1})\n"
			end
			if @filltype == GEDA::FILLING[:MESH]
				if @pitch2 <= 0
					return "pitch2 for filling should be > 0(#{@pitch2})\n"
				elsif not (-360..360).include?
					return "angle2 for filling should be in the range -360..360 (#{@angle2})\n"
				elsif warn && @angle1 == @angle2
					return " mesh with angle1 == angle2 (#{@angle1})\n" # warning, may be intended for different pitch
				end
			end
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index #{@color} out of range\n" 
		end
		return ''
	end

	def origin_x
		@nodes.first.x
	end

	def origin_y
		@nodes.first.y
	end

	def mirror2x0(x0)
		@nodes.each{|n|
			n.x = x0 - n.x
			if n.class == Path_T
				n.x1 = x0 - n.x1
				n.x2 = x0 - n.x2
			end
		}
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = Array.new
		b = Array.new
		grid = pda.schem.active_grid
		@nodes.each{|n|
			a << n.x << n.y
			n.x = n.x.fdiv(grid).round * grid
			n.y = n.y.fdiv(grid).round * grid
			b << n.x << n.y
			if n.class == Path_T
				a << n.x1 << n.y1 << n.x2 << n.y2 
				n.x1 = n.x1.fdiv(grid).round * grid
				n.y1 = n.y1.fdiv(grid).round * grid
				n.x2 = n.x2.fdiv(grid).round * grid
				n.y2 = n.y2.fdiv(grid).round * grid
				b << n.x1 << n.y1 << n.x2 << n.y2 
			end
		}
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || (a != b)
	end

	def translate(x, y)
		@nodes.each{|n|
			n.x += x
			n.y += y
			if n.class == Path_T
				n.x1 += x
				n.y1 += y
				n.x2 += x
				n.y2 += y
			end
		}
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	def rotate(x, y, angle)
		@nodes.each{|n|
			n.x, n.y = Pet.rtate(n.x, n.y, x, y, angle)
			if n.class == Path_T
				n.x1, n.y1 = Pet.rtate(n.x1, n.y1, x, y, angle)
				n.x2, n.y2 = Pet.rtate(n.x2, n.y2, x, y, angle)
			end
		}
		@attributes.each{|a| a.rotate(x, y, angle)}
		@box_needs_fix = true
		@nil_draw = true
	end

	def connect_dist
		@linewidth / 2 > NetSegment::Connect_Radius ? @linewidth / 2 : NetSegment::Connect_Radius
	end

	# fill input buffer, and add node when we have all 6 values
	# BackSpace removes last two values from input, or removes last node if input.length < 3
	# x0, y0: mouse pointer position (rounded to active grid if msg == PEM::Hoover_Select)
	# TODO: maybe we do not need x, y
	def absorb(boxlist, event, x0, y0, x, y, msg)
		if msg == PEM::Hoover_Select
			return nil if @input[-2] == x0 && @input[-1] == y0
			@input[-2] = x0
			@input[-1] = y0
		elsif msg == PEM::KEY_BackSpace
			unless (@input.length > 2 && @input.pop(2)) || (@nodes.pop && !@nodes.empty?)
				@state = State::Deleted
				@absorbing = false
			end
		elsif msg == PEM::Hit_Select # caution: x0, y0 is not rounded to active grid here!
			if event.button == 2 # done
				@absorbing = false
				if @nodes.last.class == Path_P && @nodes.last.x == @nodes.first.x &&	@nodes.last.y == @nodes.first.y
					@closed = true
					@nodes.pop
				end
				@state = State::Deleted if @nodes.length == 1
			elsif event.button == 1 # add
				if !@curve
					@nodes << Path_P.new(input[0], input[1])
				elsif @input.length == 6
					if (@input[0] == @nodes[-1].x && @input[1] == @nodes[-1].y) && (@input[2] == @input[4] && @input[3] == @input[5])
						@nodes << Path_P.new(@input[2], @input[3])
					else
						@nodes << Path_T.new(@input[0], @input[1], @input[4], @input[5], @input[2], @input[3])
					end
					@input = [2 * @input[2] - @input[4], 2 * @input[3] - @input[5], @input[4], @input[5]] # next control point is last one mirrored!
				else
					@input << x0 << y0 # new unrounded dummy value, updated by next mouse move # TODO: use rounded @input[-2..-1]?
					return nil
				end
			end
		elsif msg == PEM::KEY_Delete || msg == PEM::KEY_Escape
			@state = State::Deleted
			@absorbing = false
		end
		boxlist << @bbox
		@box_needs_fix = true
		@nil_draw = true
		return nil
	end

	# find node clicked with mouse -- returns node n and "index" i, or nil
	def find(x, y)
		a = connect_dist ** 2
		i = 0
		n = nil
		self.nodes.each{|m|
			if (d = (m.x - x) ** 2 + (m.y - y) ** 2) < a
				a = d
				i = 0
				n = m
			end
			if @state == State::Selected && m.class ==	Path_T
				if (d = (m.x1 - x) ** 2 + (m.y1 - y) ** 2) < a
					a = d
					i = 1
					n = m
				end
				if (d = (m.x2 - x) ** 2 + (m.y2 - y) ** 2) < a
					a = d
					i = 2
					n = m
				end
			end
		}
		return n, i
	end

	# edit path
	# move control points
	# px, py: mouse pointer coordinates
	# dx, dy: displacement
	# no grid snap!
	def special_move_action(boxlist, px, py, dx, dy)
		m, i = find(px, py)
		return false unless m
		if i == 0
			m.x += dx
			m.y += dy
		elsif i == 1
			m.x1 += dx
			m.y1 += dy
		else
			m.x2 += dx
			m.y2 += dy
		end
		if m.class == Path_T
			i = self.nodes.index(m)
			p = self.nodes[i - 1]
			if (m.x1 == p.x && m.y1 == p.y) && (m.x2 == m.x && m.y2 == m.y)
				self.nodes[i] = Path_P.new(m.x, m.y)
			end
		end
		boxlist << @bbox
		@nil_draw = @box_needs_fix = true
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			must_draw_edit = !@is_component && (@state == State::Selected)
			draw_edit = must_draw_edit && !draw_hoovered && !draw_selected && !cr.soft
			draw_it = draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
			if draw_edit || draw_it
				nil_draw_edit = draw_edit && !@show_edit
				if @nil_draw || nil_draw_edit
					cr.save
					cr.reset_clip
				end
				n = self.nodes
				@box_needs_fix ||= (must_draw_edit != @show_edit)
				@show_edit &&= must_draw_edit
				if draw_edit
					@show_edit = true
					cr.set_hair_line_width(2)
					cr.set_contrast_color(par[:color_geda_background])
					cr.set_line_cap(Cairo::LINE_CAP_ROUND)
					cr.set_dash([], 0)
					n.each{|el|
						if el.class == Path_P
							cr.move_to(el.x, el.y)
						else
							cr.line_to(el.x1, el.y1)
							cr.move_to(el.x2, el.y2)
							cr.line_to(el.x, el.y)
						end
					}
					pcl = connect_dist
					h = pcl / Math::SQRT2
					n.each{|el|
						cr.draw_circle(el.x, el.y, pcl)
						cr.draw_cross_hair(el.x, el.y, h)
						if el.class == Path_T
							cr.draw_cross_hair(el.x1, el.y1, h)
							cr.draw_cross_hair(el.x2, el.y2, h)
						end
					}
					@bbox.join(Bounding::Box.new(*cr.path_extents)) if @box_needs_fix
					cr.stroke
				end
				if draw_it
					cr.set_color(*par[Pet_Config::CIM[@color]])
					cr.clamped_set_line_width(@linewidth)
					cr.set_line_cap(cr.g_cap[@capstyle])
					cr.geda_set_dash(@dashstyle, @dashlength, @dashspace)
					cr.set_line_join(Cairo::LINE_JOIN_MITER)
					###cr.new_path
					n.each{|el|
						### if el == n0
						###	cr.move_to(el.x, el.y)
						if el.class == Path_P
							cr.line_to(el.x, el.y)
						else # if el.class == Path_T
							cr.curve_to(el.x1, el.y1, el.x2, el.y2, el.x, el.y)
						end
					}
					cr.close_path if @closed
					if @absorbing
						cr.move_to(n.last.x, n.last.y) # if @closed
						if @input.length == 2
							cr.line_to(*@input)
						elsif	@input.length == 4
							cr.curve_to(*@input, @input[-2], @input[-1])
						else
							cr.curve_to(@input[0], @input[1], @input[4], @input[5], @input[2], @input[3])
						end
					end
					cr.stroke_preserve
					if @box_needs_fix && (cr.soft || !must_draw_edit)
						@bbox.reset(*cr.path_extents)
					end
					if @filltype == GEDA::FILLING[:FILL]
						cr.fill
					elsif @filltype == GEDA::FILLING[:MESH] or @filltype == GEDA::FILLING[:HATCH]
						cr.set_dash([], 0)
						cr.clamped_set_line_width(@fillwidth)
						e1, e2, e3, e4 = cr.path_extents
						cr.save
						cr.clip
						cr.rotate(@angle1 * DEG2RAD_C)
						x1, y1, x2, y2 = cr.path_extents
						y1 += @pitch1
						while y1 < y2 do
							cr.move_to(x1, y1)
							cr.line_to(x2, y1)
							y1 += @pitch1
						end
						cr.stroke
						if @filltype == GEDA::FILLING[:MESH]
							cr.rotate(-@angle1 * DEG2RAD_C) # undo previous rotation
							cr.rectangle(e1, e2, e3 - e1, e4 - e2)
							cr.rotate(@angle2 * DEG2RAD_C)
							x1, y1, x2, y2 = cr.path_extents
							y1 += @pitch2
							while y1 < y2 do
								cr.move_to(x1, y1)
								cr.line_to(x2, y1)
								y1 += @pitch2
							end
							cr.stroke
						end
						cr.restore
					else
						cr.new_path
					end
					if draw_hoovered || draw_selected
						cr.set_hair_line_width(2) # TODO: from config?
						cr.set_line_cap(Cairo::LINE_CAP_ROUND)
						cr.set_dash([], 0)
						cr.set_contrast_color(par[Pet_Config::CIM[@color]])
						h = cr.clamped_line_width(@linewidth) / 4
						n.each{|el| cr.draw_cross_hair(el.x, el.y, h)}
						cr.stroke
					end
				end
				if @nil_draw || nil_draw_edit
					cr.restore
					@nil_draw = false if !cr.soft && @draw_it
				end
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				if (h = cr.full_clamped_line_width(@linewidth) / 2) < NetSegment::Connect_Radius
					h = NetSegment::Connect_Radius
				end
				@bbox.grow(h)
				@box_needs_fix = false
				set_box
			end
		end
	end
end # Path

GEDA_TEXT_INVISIBLE = 0
GEDA_TEXT_VISIBLE = 1
GEDA_TEXT_VIS_RANGE = GEDA_TEXT_INVISIBLE..GEDA_TEXT_VISIBLE
GEDA_TEXT_SHOW_NAME_VALUE = 0
GEDA_TEXT_SHOW_VALUE = 1
GEDA_TEXT_SHOW_NAME = 2
GEDA_TEXT_SHOW_RANGE = GEDA_TEXT_SHOW_NAME_VALUE..GEDA_TEXT_SHOW_NAME
TEXT_SIZE_DEFAULT = 10
TEXT_SIZE_MIN = 2
GEDA_TEXT_ALIGNMENT_RANGE = 0..8
# alignment
# 2 5 8
# 1 4 7
# 0 3 6
# x = -(a / 3) * 0.5 # origin transformation: cairo/pango top/left to gschem's alignment 
# y = -1 + (a % 3) * 0.5
# Attribute (name = value) or plain text
class Text < Element
	attr_accessor :x, :y, :color, :size, :visibility, :show_name_value, :angle, :alignment
	attr_accessor :lines, :parent_hoover, :xyalign, :cursor , :initial_attr_visibility
	def initialize(x, y, pda = nil)
		super(pda)
		@type = TextChar
		@x, @y = x, y
		@color = Pet_Config::Colorindex_geda_text
		@size = TEXT_SIZE_DEFAULT
		@visibility = GEDA_TEXT_VISIBLE
		@show_name_value = GEDA_TEXT_SHOW_VALUE
		@angle = 0
		@bbox = Bounding::Box.new(x, y, x, y)
		@box_needs_fix = true # draw should set exact size
		@alignment = 0
		@xyalign = Array.new
		@lines = '' # string
		@parent_hoover = false
		@cursor = -1
	end

	# NOTE: attributes should never have attributes themself!
	def attr_deep_copy
		fail if (@attributes && !@attributes.empty?) || @core_box
		#fail if @attributes || @core_box
		h = self.dup
		h.bbox = @bbox.dup # should never be nil
		h.xyalign = @xyalign.map{|el| el.dup} if @xyalign
		h.lines = @lines.dup if @lines
		return h
	end

	def deep_copy
		h = self.dup
		h.bbox = @bbox.dup # should never be nil
		h.core_box = @core_box.dup if @core_box
		h.attributes = @attributes.map{|el| el.attr_deep_copy} if @attributes
		h.xyalign = @xyalign.map{|el| el.dup} if @xyalign
		h.lines = @lines.dup if @lines
		return h
	end

	def to_s
		return '' if @state == State::Deleted
		mytos(@type, @x, @y, @color, @size, @visibility, @show_name_value, @angle, @alignment, @lines.lines.count) + @lines + "\n" + attr_to_s
	end

	def Text.start(x, y, pda)
		t = Text.new(x, y, pda)
		t.lines  = "New_Text?"
		t.state = State::Visible
		t.show_name_value = GEDA_TEXT_SHOW_NAME_VALUE
		t.cursor = pda.schem.main_window.activate_entry(t)
		#pda.schem.main_window.prop_box.init_object(c) # TODO!
		t.absorbing = false
		t.box_needs_fix = true
		t.nil_draw = true
		return t
	end

	def is_zombi
		@lines == ''
	end

	def check(warn = false)
		if is_zombi
			return "zombi text\n"
		elsif not Pet_Config::COLOR_INDEX_RANGE.include? @color
			return "color index #{@color} out of range\n"
		elsif @size < TEXT_SIZE_MIN
			return "tiny text (#{@size})\n"
		elsif not GEDA_TEXT_SHOW_RANGE.include? @show_name_value
			return "show name/value is invalid (#{@show_name_value})\n"
		elsif not GEDA_TEXT_VIS_RANGE.include? @visibility
			return "visibility is a boolean 0/1 (#{@visibility})\n"
		elsif not GEDA_TEXT_ALIGNMENT_RANGE.include? @alignment
			return "alignment range is 0..8 (#{@alignment})\n"
		elsif not (-360..360).include? @angle
			return "angle should be in the range -360..360 (#{@angle})\n"
		else
			return ''
		end
	end

# 2 5 8
# 1 4 7
# 0 3 6
TextMirrorX	= [6,7,8,3,4,5,0,1,2]
TextMirrorXX = [2,1,0,5,4,3,8,7,6]
	def mirror2x0(x0)
		@x = x0 - @x
		if @angle <= 45 || (@angle >= 135 && @angle <= 225) || @angle >= 315
			@alignment = TextMirrorX[@alignment]
			@angle = (360	- @angle) % 360
		else
			@angle = (360 + 180 - @angle) % 360
			@alignment = TextMirrorXX[@alignment]
		end
		@attributes.each{|a| a.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		a = [@x, @y]
		grid = pda.schem.active_grid
		@x = @x.fdiv(grid).round * grid
		@y = @y.fdiv(grid).round * grid
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || a != [@x, @y]
	end

	def translate(x, y)
		@x += x; @y += y;
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
	end

	def rotate(x, y, angle)
		@angle = (@angle + angle) % 360
		@x, @y = Pet.rtate(@x, @y, x, y, angle)
		@attributes.each{|a| a.rotate(x, y, angle)}
		@box_needs_fix = true # without this bbox would never shrink
		@nil_draw = true
	end

	# change alignment and snap to grid
	# px, py: mouse pointer coordinates
	def special_hit_action(boxlist, px, py, button)
		if button == 2
			cd = NetSegment::Connect_Radius ** 2
			(0..8).each{|a|
				x, y = @xyalign[a]
				if (h = (x - px) ** 2 + (y - py) ** 2) < cd
					cd = h
					@alignment = a
				end
			}
			if cd < NetSegment::Connect_Radius ** 2
				grid = pda.schem.active_grid
				x, y = @xyalign[@alignment]
				x = x.fdiv(grid).round * grid
				y = y.fdiv(grid).round * grid
				boxlist << @bbox.dup # yes, the old one before translate()
				translate(x - @x, y - @y)
				@box_needs_fix = true
				@nil_draw = true
				return true
			end
		end
		return nil
	end

	# TODO: check
	def get_text
		t = lines
		if @show_name_value == GEDA_TEXT_SHOW_NAME_VALUE
			t
		else
			n, v = t.split('=', 2)
			if @show_name_value == GEDA_TEXT_SHOW_NAME
				n
			else
				v
			end
		end
	end

	# TODO: check
	def set_text(t, cursor)
		t = t.dup
		@cursor = cursor
		if @show_name_value == GEDA_TEXT_SHOW_NAME_VALUE
			@lines = t
		else
			n, v = @lines.split('=', 2)
			if @show_name_value == GEDA_TEXT_SHOW_NAME
				@lines = t + '=' + v
			else
				@lines = n + '=' + t
			end
		end
		@box_needs_fix = true
		@pda.darea.grab_focus if cursor < 0
	end

# 2 5 8
# 1 4 7
# 0 3 6
XA = [0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0]
YA = [0.0, 0.5, 1.0, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0]
	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		return if @visibility == GEDA_TEXT_INVISIBLE || @lines == ''
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			draw_edit = !(@is_component || draw_hoovered || draw_selected || cr.soft) # crosshair
			hoov = @hoover || @parent_hoover
			draw_it = draw_hoovered == hoov && draw_selected == (@state == State::Selected)
			if draw_it || draw_edit
				@nil_draw ||=	@last_state != @state && (@state == State::Selected) || hoov && !@last_hoover
				@box_needs_fix ||= @last_state != @state || hoov != @last_hoover
				cr.save
				if @nil_draw
					cr.reset_clip
					@nil_draw &&= cr.soft
				end
				cr.translate(@x, @y)
				if draw_it
					if @show_name_value == GEDA_TEXT_SHOW_NAME_VALUE || !@lines.index('=')
						t = @lines.dup
					else
						t = String.new
						n, v = lines.split('=', 2)
						### if v == nil
						###	t << l
						if @show_name_value == GEDA_TEXT_SHOW_VALUE
							t << v
						else
							t << n
						end
					end
					markup = t.length > 6 # may string contain valid markup like <i>x<\i>
					overbar = t.index('_') != nil
					if fancy = (markup || overbar) && @cursor < 0
						parse_error = false
						begin
						attr_list, plain_text = Pango.parse_markup(t)
						rescue GLib::Error
						parse_error = true
						end
						if !parse_error && overbar
							o = Array.new
							overline = false
							last_char = ' '
							i = 0
							plain_text.each_char{|c|
								if c == "\n"
									i += 1
								elsif c == '_' && last_char == '\\'
									o.pop unless (overline ^= TRUE)
									i -= 1
								else
									o.push(i) if overline
									last_char = c
									i += 1
								end
							}
							t.gsub!('\_', '')
							attr_list, plain_text = Pango.parse_markup(t)
						else
							o = nil
						end
					end
					layout = cr.create_pango_layout
					if fancy && !parse_error
						layout.set_text(plain_text)
						layout.set_attributes(attr_list)
					elsif fancy #parse_error
						layout.set_text('!!!' + t) # TODO: use alert color?
					else
						layout.set_text(t)
					end
					desc = Pango::FontDescription.new(par[:text_font_name])
					fontsize = @size * par[:text_size_sys_scale] * par[:text_size_user_scale]
					desc.set_size(fontsize * Pango::SCALE)
					desc.set_weight(400 + cr.text_shadow_fix)
					layout.set_font_description(desc)
					unless true#false#par[:text_field_transparent] # TODO: check if we want this
						al = Pango::AttrList.new
						background_attr = Pango::AttrBackground.new(0,0,60)#*cvalue[BACKGROUND_COLOR].map{|x| x * (2**16 - 1)})
						background_attr.start_index = 0 # Pango::ATTR_INDEX_FROM_TEXT_BEGINNING # Since: 1.24
						background_attr.end_index = -1 # Pango::ATTR_INDEX_TO_TEXT_END # Since: 1.24
						al.insert(background_attr)
						layout.set_attributes(al)
					end
					# cr.update_pango_layout(layout) # should be not necessary
					@log_rect = layout.pixel_extents[1]
				end
				dx = XA[@alignment] * @log_rect.width
				dy = YA[@alignment] * @log_rect.height
				cr.rotate(@angle * DEG2RAD_C)
				cr.translate(-dx, -dy)
				if draw_edit
					cr.set_line_cap(Cairo::LINE_CAP_ROUND)
					cr.set_hair_line_width(2)
					cr.set_dash([], 0)
					d = par[:text_mark_size] * 0.5
					c = cr.get_contrast_color(par[:color_geda_background])
					cr.set_source_rgba([c, c, c, 1])
					cr.draw_cross_hair(dx, dy, d)
					cr.stroke
					if @hoover
						cr.set_source_rgba([c, c, c, 0.5])
						(0..8).each{|align|
							dx = XA[align] * @log_rect.width
							dy = YA[align] * @log_rect.height
							@xyalign[align] = cr.user_to_device(dx, dy)
							cr.draw_cross_hair(dx, dy, d) unless align == @alignment
						}
						cr.stroke
					end
				end
				if draw_it
					cr.set_color(*par[Pet_Config::CIM[@color]])
					cr.move_to(@log_rect.x, @log_rect.y + @log_rect.height)
					cr.scale(1, -1) # reset our mirrored y axis, now we have the default again
					cr.show_pango_layout(layout)
					cr.new_path # clear what is left from move_to
					cr.scale(1, -1)
					if @cursor >= 0
						iter = layout.iter
						@cursor.times{iter.next_char!}
						strong = iter.char_extents
						cr.set_line_width(fontsize * 0.1)
						cr.move_to(strong.x / Pango::SCALE, strong.y / Pango::SCALE)
						cr.rel_line_to(0, strong.height / Pango::SCALE)
						cr.stroke
					end
					if o && (o.length) > 0 # NOTE: maybe we should join adjanced overline segments?
						iter = layout.iter
						cr.set_line_cap(Cairo::LINE_CAP_ROUND)
						cr.set_dash([], 0)
						cr.set_line_width(fontsize * 0.1)
						j = 0
						o.each{|i|
							while j < i
								iter.next_char!
								j += 1
							end
							pos = iter.char_extents
							cr.move_to(pos.x / Pango::SCALE, @log_rect.height - pos.y / Pango::SCALE)
							cr.rel_line_to(pos.width / Pango::SCALE, 0)
						}
						cr.stroke
					end
					if @box_needs_fix && !cr.soft
						cr.rectangle(@log_rect.x, @log_rect.y, @log_rect.width, @log_rect.height)
						cr.rotate(-@angle * DEG2RAD_C)
						x1, y1, x2, y2 = cr.path_extents
						x1, y1 = cr.user_to_device(x1, y1)
						x2, y2 = cr.user_to_device(x2, y2)
						cr.new_path # ensure path is cleared when we left
						cr.restore
						@bbox.reset(*cr.device_to_user(x1, y1), *cr.device_to_user(x2, y2))
					else
						cr.restore
					end
					@last_hoover = hoov
					@last_state = @state
				else
					cr.restore
				end
			end
			if draw_edit && @hoover
				@xyalign.map!{|x, y| cr.device_to_user(x,y)}
			end
			if @box_needs_fix && !cr.soft && (@is_component || (draw_hoovered && draw_selected))
				@bbox.grow(NetSegment::Connect_Radius)
				@box_needs_fix = false
				set_box
			end
		end
	end

end

module State
	Deleted = 0
	Visible = 1
	Selected = 4
end

class Sym < Element
	attr_accessor :x, :y, :selectable, :angle, :mirrored, :basename
	attr_accessor :components # pins, attributes and graphical elements
	attr_accessor :attributes, :attr_hash
	attr_accessor :embedded
	def initialize(x, y, pda = nil)
		super(pda)
		@embedded = false
		@type = SymChar
		@x, @y = x, y
		@selectable = 0
		@angle = 0
		@mirrored = 0
		@basename = nil
		@box_needs_fix = true
		@components = Array.new
		@attributes = Pet_Object_List.new
		@attr_hash = Hash.new
		@bbox = Bounding::Box.new(x, y, x, y)
	end

	# TODO: multiline attributes may be a problem still
	def attr_to_s
		res = String.new
		@attributes.each{|el|
			el_name, el_value = el.lines.split('=', 2)
			id = Attr_Msg::ID_NEW
			if h = instance_variable_defined?(:@attr_hash) && attr_hash[el_name] # only symbols can have inherited attributes
				if h.lines.split('=', 2)[1] != el_value
					### id = Attr_Msg::ID_REDEFINED
				elsif el.x != h.x || el.y != h.y || el.color != h.color || el.size != h.size || el.angle != h.angle ||
					el.alignment != h.alignment || el.visibility != h.visibility || el.show_name_value != h.show_name_value
					### id = Attr_Msg::ID_MODIFIED
				else
					id = Attr_Msg::ID_INHERITED
				end
			else
				### id = Attr_Msg::ID_NEW
			end
			if id != Attr_Msg::ID_INHERITED || el_name == 'symversion'
				res += el.to_s
			end
		}
		res == '' ? '' : "{\n" + res + "}\n"
	end

	def comp_to_s
		if @components.empty? then '' else "[\n" + @components.join('') + "]\n" end
	end

	def to_gsym(as_shown)
		unless as_shown
			mirror2x0(origin_x * 2) if @mirrored != 0
			rotate(origin_x, origin_y, -@angle) unless @angle == 0
		end
		minx = components.min_by{|el| el.origin_x}.origin_x.fdiv(100).round * 100
		miny = components.min_by{|el| el.origin_y}.origin_y.fdiv(100).round * 100
		translate(-minx, -miny)
		h = @components.reject{|el| el.class == Text && el.lines.index('=')}.join('')
		h += @attributes.join('')
		# undo -- maybe we should use a copy instead?
		translate(minx, miny)
		unless as_shown
			rotate(origin_x, origin_y, @angle) unless @angle == 0
			mirror2x0(-origin_x * 2) if @mirrored != 0
		end
		h
	end

	def to_s
		return '' if @state == State::Deleted
		if @embedded
			mytos(@type, @x, @y, @selectable, @angle, @mirrored, 'EMBEDDED' + @basename) + comp_to_s + attr_to_s
		else
			mytos(@type, @x, @y, @selectable, @angle, @mirrored, @basename) + attr_to_s
		end
	end

	def Sym.start(x, y, pda) end

	def is_zombi
		@components.empty? #&& @attributes.empty?
	end

	def check(warn = false)
		if @type != SymChar
			return "type should be SymChar (#{SymChar}) but is #{@type}\n"
		elsif @selectable != 0 && @selectable != 1
			return "selectable should be 0 or 1 (#{@selectable})\n"
		elsif not [0, 90, 180, 270].include? @angle
			return "angle should be 0, 90, 180 or 270 (#{@angle})\n"
		elsif @mirrored != 0 && @mirrored != 1
			return "mirrored should be 0 or 1 (#{@mirrored})\n"
		else
			return ''
		end
	end

	def mirror2x0(x0)
		@x = x0 - @x
		@mirrored = 1 - @mirrored
		@components.each{|el| el.mirror2x0(x0)}
		@attributes.each{|el| el.mirror2x0(x0)}
		@bbox.mirror2x0(x0)
		@core_box.mirror2x0(x0) if @core_box
	end

	def snap(attr = false)
		ax, ay = @x, @y
		grid = pda.schem.active_grid
		@x = @x.fdiv(grid).round * grid
		@y = @y.fdiv(grid).round * grid
		h = false
		@attributes.each{|a| h ||= a.snap} if attr
		@box_needs_fix = @nil_draw = h || @x != ax || @y != ay
	end

	def translate(x, y)
		@x += x; @y += y;
		@bbox.translate(x, y)
		@core_box.translate(x, y) if @core_box
		@attributes.each{|a| a.translate(x, y)}
		@components.each{|el| el.translate(x, y)}
	end

	def rotate(x, y, angle)
		@angle = (@angle + angle) % 360
		@x, @y = Pet.rtate(@x, @y, x, y, angle)
		@components.each{|o| o.rotate(x, y, angle)}
		@attributes.each{|o| o.rotate(x, y, angle)}
		Pet.rot_bbox(@bbox, x, y, angle)
		Pet.rot_bbox(@core_box, x, y, angle) if @core_box
	end

	# start new net from hot pin endpoint
	# px, py: mouse pointer coordinates
	def special_hit_action(boxlist, px, py, button)
		@components.each{|c|
			if (c.class == Pin) && (cp = c.connect(px, py))
				return NetSegment.start(*cp, @pda)
			end
		}
		return nil
	end

	def draw(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		if @bbox.overlap_list?(damage_list)
			@attributes.each{|a| a.draw(cr, par, damage_list, draw_hoovered, draw_selected)}
			if draw_hoovered == @hoover && draw_selected == (@state == State::Selected)
				if @nil_draw
					cr.save
					cr.reset_clip
				end
				@components.each{|x| x.draw(cr, par, damage_list, false, false) unless x.class == Text}
				if @nil_draw
					cr.restore
					@nil_draw &&= cr.soft
				end
			end
			if @box_needs_fix && draw_hoovered && draw_selected && !cr.soft
				if @core_box
					@bbox.reset(@core_box.x1, @core_box.y1, @core_box.x2, @core_box.y2)
				else
					@bbox.reset_to_ghost
					@components.each{|x|
						if x.class != Text # text is handled by attributes
							x.enlarge_bbox(@bbox)
						end
					}
				end
				set_box
				@box_needs_fix = false
			end
		end
	end

	def draw_junctions(cr, par, damage_list, draw_hoovered, draw_selected)
		return if @state == State::Deleted
		return if draw_hoovered || draw_selected
		if @bbox.overlap_list?(damage_list)
			@components.select{|x| x.class == Pin}.each{|x| x.draw_junctions(cr, par, damage_list, false, false)}
		end
	end

end

# special character indicating end of file
# NewLine() will set @ThisLine[0] to this character if end of file is reached
EOFC = ['~']

class Schem
	attr_accessor :major_grid, :minor_grid, :active_grid, :pda, :main_window, :filename, :input_mode, :prop_box, :grid_snap

	def initialize
		@filename = ''
		@pda = nil
		@major_grid, @minor_grid, @active_grid = 100, 100, 100
		@grid_snap = true
		@input_mode = Input_Mode.default
		@ObjectList = Pet_Object_List.new
		@state = PES::Hoovering
		@ActiveObject = nil
		@SymDirs = Pet_Config::DefaultSymDirs	
		@ThisLine = ''
		@Error=''
		@InputFile = nil
		@SymbolFile = nil
		@Last_selected = nil
		@bbox = Bounding::Box.new(0, 0, 1000, 1000)
		@log = Array.new
		@dia = nil
		@prop_box = nil
	end

	# TODO: check later
	def prep_popup(msg, event = nil)
		if msg == PMM::New
			@ObjectList.new_object(@pda, @input_mode, @pxr, @pyr)
			return
		end
		if msg == PMM::Move
			@state = PES::PopupMove
			return
		end
		boxlist = Array.new # list of bounding boxes which require redraw
		@ObjectList.process_popup_menu(boxlist, msg, @curx, @cury)
		@pda.update_canvas(boxlist)
		if msg == PMM::Copy
			@state = PES::PopupMove
		end
	end

	# TODO: check later
	def init_popup_menu
		@d_popup_menu = Gtk::Menu.new # delete and similar tasks -- for seleted objects or objects under mouse pointer
		@c_popup_menu = Gtk::Menu.new # cancel
		@cd_popup_menu = Gtk::Menu.new # cancel & done
		@c_popup_menu.append(@popup_cancel_item = Gtk::MenuItem.new("Cancel"))
		#@cd_popup_menu.append(@popup_cancel_item)
		@cd_popup_menu.append(@popup_cancel2_item = Gtk::MenuItem.new("Cancel"))
		@cd_popup_menu.append(@popup_done_item = Gtk::MenuItem.new("Done"))
		@cd_popup_menu.append(@popup_back_item = Gtk::MenuItem.new("Back"))
		@popup_cancel_item.signal_connect('activate') {|w| prep_popup(PMM::Cancel)}
		@popup_cancel2_item.signal_connect('activate') {|w| prep_popup(PMM::Cancel)}
		@popup_done_item.signal_connect('activate') {|w| prep_popup(PMM::Done)}
		@popup_back_item.signal_connect('activate') {|w| prep_popup(PMM::Back)}
		@c_popup_menu.show_all
		@cd_popup_menu.show_all
		@d_popup_menu.append(@popup_new_item = Gtk::MenuItem.new("New"))
		@popup_new_item.signal_connect('activate') {|w| prep_popup(PMM::New)}
		@d_popup_menu.append(@popup_sel_item = Gtk::MenuItem.new("Select"))
		@popup_sel_item.signal_connect('activate') {|w| prep_popup(PMM::Select)}
		@d_popup_menu.append(@popup_mir_item = Gtk::MenuItem.new("Copy"))
		@popup_mir_item.signal_connect('activate') {|w| prep_popup(PMM::Copy)}
		@d_popup_menu.append(@popup_mir_item = Gtk::MenuItem.new("Mirror"))
		@popup_mir_item.signal_connect('activate') {|w| prep_popup(PMM::Mirror)}
		@d_popup_menu.append(@popup_move_item = Gtk::MenuItem.new("Move"))
		@popup_move_item.signal_connect('activate') {|w| prep_popup(PMM::Move, w)}
		@d_popup_menu.append(@popup_cw_item = Gtk::MenuItem.new("CW"))
		@popup_cw_item.signal_connect('activate') {|w| prep_popup(PMM::CW)}
		@d_popup_menu.append(@popup_ccw_item = Gtk::MenuItem.new("CCW"))
		@popup_ccw_item.signal_connect('activate') {|w| prep_popup(PMM::CCW)}
		@d_popup_menu.append(@popup_del_item = Gtk::MenuItem.new("Delete"))
		@popup_del_item.signal_connect('activate') {|w| prep_popup(PMM::Delete)}
		@d_popup_menu.show_all
		@pda.darea.signal_connect("button_press_event") do |widget, event|
			if event.button == 3
				if	@ObjectList.last.absorbing
					if @input_mode == Input_Mode::Path || @input_mode == Input_Mode::Curve
						@cd_popup_menu.popup(nil, nil, event.button, event.time)
					else
						@c_popup_menu.popup(nil, nil, event.button, event.time)
					end
				else
					@popup_del_item.sensitive = @ObjectList.selected > 0 || @ObjectList.xhoover
					@popup_move_item.sensitive = @popup_del_item.sensitive?
					@popup_sel_item.sensitive = @ObjectList.xhoover
					@d_popup_menu.popup(nil, nil, event.button, event.time)
				end
			end
		end
	end

	def set_dialog_widget(d, pb)
		@dia = d
		@prop_box = pb
	end

	def set_input_mode(m)
		@input_mode = Input_Mode.const_get(m)
	end

	# TODO: check later
	def enlarge(s)
		h = s * (@bbox.x2 - @bbox.x1) / 2
		@bbox.x1 -= h
		@bbox.x2 += h
		h = s * (@bbox.y2 - @bbox.y1) / 2
		@bbox.y1 -= h
		@bbox.y2 += h
		pda.darea_new_box
	end
	
	# we should check for duplicates -- to be done
	def OpenSymFile(name)
 		@SymbolFile = nil
		for base in @SymDirs
			if n = Dir.glob(File.join(base, '**', name))[0]
				@SymbolFile = File.open(n, 'r')
				break
			end
		end
		return @SymbolFile
	end

	def NextLine
		if @SymbolFile 
			if not (@ThisLine = @SymbolFile.gets)
				@SymbolFile.close
				@SymbolFile = nil
				@ThisLine = ']'
			end
		elsif not (@ThisLine = @InputFile.gets)
			@ThisLine = EOFC
		end
	end

	def FirstIs(c) return @ThisLine[0..0] == c end
	
	def ProcessVersion
		if Regexp.new(VersionPat).match(@ThisLine)
			NextLine()
		else
			raise FileFormatError, 'Invalid File Version'
		end
	end
	
	def ProcessLine(is_component)
		if match = Regexp.new(LinePat).match(@ThisLine)
			el = Line.new(*match[2..5].map{|x| x.to_i}, @pda)
			el.is_component = is_component
			el.color = match[6].to_i
			el.width = match[7].to_i
			el.capstyle = match[8].to_i
			el.dashstyle = match[9].to_i
			el.dashlength = match[10].to_i
			el.dashspace = match[11].to_i
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
			NextLine()
			ProcessAttributes(el.attributes)
			return el
		else
			raise FileFormatError, 'Invalid Line'
		end
	end

	def ProcessNetSegment()
		if match = Regexp.new(NetSegPat).match(@ThisLine)
			el = NetSegment.new(*match[2..5].map{|x| x.to_i}, @pda)
			el.color = match[6].to_i
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
			NextLine()
			ProcessAttributes(el.attributes)
			return el
		else
			raise FileFormatError, 'Invalid Net'
		end
	end

	def ProcessBox(is_component)
		if match = Regexp.new(BoxPat).match(@ThisLine)
			el = Box.new(*match[2..5].map{|x| x.to_i}, @pda)
			el.is_component = is_component
			el.color = match[6].to_i
			el.linewidth = match[7].to_i
			el.capstyle = match[8].to_i
			el.dashstyle = match[9].to_i
			el.dashlength = match[10].to_i
			el.dashspace = match[11].to_i
			el.filltype = match[12].to_i
			el.fillwidth = match[13].to_i
			el.angle1 = match[14].to_i
			el.pitch1 = match[15].to_i
			el.angle2 = match[16].to_i
			el.pitch2 = match[17].to_i
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
			NextLine()
			ProcessAttributes(el.attributes)
			return el
		else
			raise FileFormatError, 'Invalid Box'
		end
	end

	def ProcessCirc(is_component)
		if match = Regexp.new(CircPat).match(@ThisLine)
			el = Circ.new(*match[2..4].map{|x| x.to_i}, @pda)
			el.is_component = is_component
			el.color = match[5].to_i
			el.linewidth = match[6].to_i
			el.capstyle = match[7].to_i
			el.dashstyle = match[8].to_i
			el.dashlength = match[9].to_i
			el.dashspace = match[10].to_i
			el.filltype = match[11].to_i
			el.fillwidth = match[12].to_i
			el.angle1 = match[13].to_i
			el.pitch1 = match[14].to_i
			el.angle2 = match[15].to_i
			el.pitch2 = match[16].to_i
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
			NextLine()
			ProcessAttributes(el.attributes)
			return el
		else
			raise FileFormatError, 'Invalid Circle'
		end
	end

	def ProcessArc(is_component)
		if match = Regexp.new(ArcPat).match(@ThisLine)
			el = Arc.new(*match[2..4].map{|x| x.to_i}, @pda)
			el.is_component = is_component
			el.startangle = match[5].to_i
			el.sweepangle = match[6].to_i
			el.color = match[7].to_i
			el.linewidth = match[8].to_i
			el.capstyle = match[9].to_i
			el.dashstyle = match[10].to_i
			el.dashlength = match[11].to_i
			el.dashspace = match[12].to_i
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
			NextLine()
			ProcessAttributes(el.attributes)
			return el
		else
			raise FileFormatError, 'Invalid Arc'
		end
	end

	Move_To_Pat = /[ML]( -?\d+,-?\d+)+/
	Curve_To_Pat = /C( -?\d+,-?\d+ -?\d+,-?\d+ -?\d+,-?\d+)+/
	Close_Path_Pat = /Z/

	def ProcessPath(is_component)
		if match = Regexp.new(PathPat).match(@ThisLine)
			el = Path.new(@pda)
			el.is_component = is_component
			el.color =	match[2].to_i
			el.linewidth =	match[3].to_i
			el.capstyle =	match[4].to_i
			el.dashstyle =	match[5].to_i
			el.dashlength =	match[6].to_i
			el.dashspace =	match[7].to_i
			el.filltype =	match[8].to_i
			el.fillwidth =	match[9].to_i
			el.angle1 =	match[10].to_i
			el.pitch1 =	match[11].to_i
			el.angle2 =	match[12].to_i
			el.pitch2 =	match[13].to_i
			el.numlines =	match[14].to_i
			NextLine()
		else
			raise FileFormatError, 'Path: Invalid start'
		end
		el.numlines.times{
			if Move_To_Pat.match(@ThisLine)
				@ThisLine[2..-1].split(' ').each{|t|
					el.nodes << Path_P.new(*t.split(',').map!{|x| x.to_i})
				}
			elsif Curve_To_Pat.match(@ThisLine)
				@ThisLine[2..-1].split(/[ ,]/).map!{|x| x.to_i}.each_slice(6){|t|
					el.nodes << Path_T.new(*t)
				}
			elsif Close_Path_Pat.match(@ThisLine)
				el.closed = true
			else
				raise FileFormatError, 'Path: Invalid nodes'
			end
			NextLine()
		}
		@Error = el.check
		raise FileFormatError, @Error if !@Error.empty?
		ProcessAttributes(el.attributes)
		el.init_box(el.nodes.first.x, el.nodes.first.y)
		return el
	end

	def ProcessText(is_component, allow_attributes = true)
		if match = Regexp.new(TextPat).match(@ThisLine)
			el = Text.new(match[2].to_i, match[3].to_i, @pda)
			el.is_component = is_component
			el.color = match[4].to_i
			el.size = match[5].to_i
			el.visibility = match[6].to_i
			el.show_name_value = match[7].to_i
			el.angle = match[8].to_i
			el.alignment = match[9].to_i
			num_lines = match[10].to_i
			NextLine()
		else
			raise FileFormatError, 'Text: Invalid start'
		end
		num_lines.times do
			el.lines << @ThisLine
			NextLine()
		end
		el.lines.chomp!
		@Error = el.check
		raise FileFormatError, @Error if !@Error.empty?
		if FirstIs('{')
			if allow_attributes || !el.lines.index('=')
				ProcessAttributes(el.attributes)
			else
				raise FileFormatError, 'Nested Attributes not allowed!'
			end
		end
		return el
	end
	
	def ProcessAttributes(a)
		if FirstIs('{')
			NextLine()
			while true
				if FirstIs('}')
					NextLine()
					break
				else
					a.push(ProcessText(false, false))
				end
			end
		end
	end
	
	def ProcessPin(is_component)
		if match = Regexp.new(PinPat).match(@ThisLine)
			el = Pin.new(match[2].to_i, match[3].to_i, match[4].to_i, match[5].to_i, @pda)
			el.is_component = is_component
			el.color = match[6].to_i
			el.pintype = match[7].to_i
			el.whichend = match[8].to_i
			if el.whichend != 0
				el.x1, el.x2 = el.x2, el.x1
				el.y1, el.y2 = el.y2, el.y1
			end
			NextLine()
			@Error = el.check
			raise FileFormatError, @Error if !@Error.empty?
		else
			raise FileFormatError, 'Pin: Invalid start'
		end
		ProcessAttributes(el.attributes)
		return el
	end

	# Add new symbol to schematic
	# @Sym == new el if success
	def ProcessSymFile(name)
		@InputFile = nil
		begin
			@InputFile = File.open(name, 'r')
			NextLine()
			el = Sym.new(0, 0)
			while @ThisLine != EOFC
				if FirstIs(VersionChar)
					ProcessVersion()
				elsif FirstIs(LineChar)
					el.components.push(ProcessLine(true))
				elsif FirstIs(NetSegChar)
					el.componnents.push(ProcessNetSeg())
				elsif FirstIs(BoxChar)
					el.components.push(ProcessBox(true))
				elsif FirstIs(CircChar)
					el.components.push(ProcessCirc(true))
				elsif FirstIs(ArcChar)
					el.components.push(ProcessArc(true))
				elsif FirstIs(PathChar)
					el.components.push(ProcessPath(true))
				elsif FirstIs(TextChar)
					el.components.push(ProcessText(true, false))
				elsif FirstIs(PinChar)
					el.components.push(ProcessPin(true))
				else
					raise FileFormatError, 'Symbol: Syntax error'
				end
			end
			el.components.select{|c| c.class == Pet::Text}.each{|c|
				n, v = c.lines.split('=', 2)
				if n && v && !n.empty? && !v.empty?
					el.attr_hash[n] = c
					el.attributes << c.deep_copy
					el.attributes.last.is_component = false
					c.initial_attr_visibility = c.visibility
					c.visibility = 0
				end
			}
			@Sym = el
			@Sym.basename = File.basename(name)
			@pda.set_cursor(Pet_Canvas::Cursor_Type::ADD_SYM)
			@main_window.push_msg('Press LMB to place symbol...')
		rescue FileFormatError => e
				Log::print 'Error in file ', name, ': ', e.message, "\n"
				Log::print '-=> Line ', @InputFile.lineno, ': ', @ThisLine, "\n"
		rescue => e
				Log::print e.message
		ensure
			if @InputFile
				@InputFile.close
				@InputFile = nil
			end
		end
	end

	def ProcessSym
		if match = Regexp.new(EmbeddedSymPat).match(@ThisLine)
			el = Sym.new(match[2].to_i, match[3].to_i, @pda)
			el.embedded = true
			NextLine()
			if FirstIs('[')
				NextLine()
			else
				raise FileFormatError, 'Symbol: Missing [ for embedded symbol'
			end
		elsif match = Regexp.new(ExternSymPat).match(@ThisLine)
			el = Sym.new(match[2].to_i, match[3].to_i, @pda)
			if OpenSymFile(match[7])
				@SymFileName = match[7]
				NextLine()
			else
				raise FileFormatError, 'Symbol: File not found'
			end
		else
			raise FileFormatError, 'Symbol: Invalid start'
		end
		el.selectable = match[4].to_i
		el.angle = match[5].to_i
		el.mirrored = match[6].to_i
		el.basename = match[7]	
		while true
			if FirstIs(']')
				NextLine()
				break
			elsif FirstIs(VersionChar)
				ProcessVersion()
			elsif FirstIs(LineChar)
				el.components.push(ProcessLine(true))
			elsif FirstIs(NetSegChar)
				el.componnents.push(ProcessNetSeg())
			elsif FirstIs(BoxChar)
				el.components.push(ProcessBox(true))
			elsif FirstIs(CircChar)
				el.components.push(ProcessCirc(true))
			elsif FirstIs(ArcChar)
				el.components.push(ProcessArc(true))
			elsif FirstIs(PathChar)
				el.components.push(ProcessPath(true))
			elsif FirstIs(TextChar)
				el.components.push(ProcessText(true, false))
			elsif FirstIs(PinChar)
				el.components.push(ProcessPin(true))
			else
				raise FileFormatError, 'Symbol: Syntax error'
			end
		end
		ProcessAttributes(el.attributes)
		unless el.embedded
			el.components.each{|o| o.translate(el.x, el.y); o.rotate(el.x, el.y, el.angle)}
			el.mirror2x0(2 * el.x) if el.mirrored == 1
		end
		h = Hash[el.attributes.map{|a| [a.lines.split('=', 2).first, a]}]
		el.components.select{|c| c.class == Pet::Text}.each{|c|
			n, v = c.lines.split('=', 2)
			if n && v && !n.empty? && !v.empty?
				el.attr_hash[n] = c
				if !h.include?(n)
					el.attributes << c.deep_copy
					el.attributes.last.is_component = false
					c.initial_attr_visibility = c.visibility
					c.visibility = 0
				end
			end
		}
		return el
	end

	def ProcessInputFile(name)
		begin
			@InputFile = nil
			@InputFile = File.open(name, 'r')
			NextLine()
			while !FirstIs(EOFC)
				if FirstIs(VersionChar)
					ProcessVersion()
				elsif FirstIs(LineChar)
					@ObjectList.push(ProcessLine(false))
				elsif FirstIs(NetSegChar)
					@ObjectList.push(ProcessNetSegment())
				elsif FirstIs(PinChar)
					@ObjectList.push(ProcessPin(false))
				elsif FirstIs(BoxChar)
					@ObjectList.push(ProcessBox(false))
				elsif FirstIs(CircChar)
					@ObjectList.push(ProcessCirc(false))
				elsif FirstIs(ArcChar)
					@ObjectList.push(ProcessArc(false))
				elsif FirstIs(PathChar)
					@ObjectList.push(ProcessPath(false))
				elsif FirstIs(TextChar)
					@ObjectList.push(ProcessText(false, true))
				elsif FirstIs(SymChar)
					@ObjectList.push(ProcessSym())
				else
					raise FileFormatError, 'Syntax error'
				end
			end
			@bbox = Bounding::Box.new_ghost
			@ObjectList.each{|o| o.enlarge_bbox(@bbox)}
		rescue FileFormatError => e
			if @SymbolFile
				Log::print 'Error in file ', @SymFileName, ': ', e.message, "\n"
				Log::print '-=> Line ', @SymbolFile.lineno, ': ', @ThisLine, "\n"
				@SymbolFile.close
				@SymbolFile = nil
			else
				Log::print 'Error in file ', name, ': ', e.message, "\n"
				Log::print '-=> Line ', @InputFile.lineno, ': ', @ThisLine, "\n"
			end
		rescue => e
			Log::print e.message
		ensure
			if @InputFile
				@InputFile.close
				@InputFile = nil
			end
		end
		return true
	end

	def zoom_original
		@bbox = Bounding::Box.new_ghost
		@ObjectList.each{|o| o.enlarge_bbox(@bbox)}
	end

LSS = [0, 1, 2, 3] # line_shadow_scale
# TODO: Shadow may be clipped when an object is increased in size, because reset_clip does not work!
	def write_to_context(cr, damage_list, new_background)
		return if damage_list.empty?
		conf = Pet_Config::get_default_config.get_conf(Pet_Config::SCR_S)
		shift = 0.2 * cr.device_to_user_line_width(cr.unscaled_user_to_device_line_width(0)) # TODO: check, tune, simplify?
		damage_list.map!{|el| el.dup.enlarge(3 * shift, -3 * shift).enlarge(-1.5 * shift, 1.5 * shift).grow(NetSegment::MaxNetEndmarkDia)} # dont clip red rectangle!
		hl = Array.new # list of visible horizontal net segments
		vl = Array.new
		hpl = Array.new # list of visible horizontal pins
		vpl = Array.new
		h = Array.new
		damage_list.each{|el| h << el.x1 << el.x2}
		x1, x2 = h.minmax
		h.clear
		damage_list.each{|el| h << el.y1 << el.y2}
		y1, y2 = h.minmax
		xa1 = x1 - NetSegment::MaxNetEndmarkDia # for pins connected to nets -- take pins into account even if hot end is outside of dammage list
		ya1 = y1 - NetSegment::MaxNetEndmarkDia
		xa2 = x2 + NetSegment::MaxNetEndmarkDia
		ya2 = y2 + NetSegment::MaxNetEndmarkDia
		cons = Hash.new(0) # net connection markers
		@ObjectList.reject{|n| (n.class != NetSegment && n.class != Sym) || n.state == State::Deleted || n.bbox.x2 < x1 || n.bbox.x1 > x2 || n.bbox.y2 < y1 || n.bbox.y1 > y2}.each{|n|
			if n.class == NetSegment
				vl << n if n.x1 == n.x2 
				hl << n if n.y1 == n.y2
				cons[[n.x1, n.y1]] += 4
				cons[[n.x2, n.y2]] += 4
				else # if n.is_a?(Sym)
				# check only hot pin end position, assuming that red mark is never longer than MaxNetEndmarkDia
				n.components.reject{|a| a.class != Pin || a.x1 < xa1 || a.x1 > xa2 || a.y1 < ya1 || a.y1 > ya2}.each{|a|
					vpl << a if a.x1 == a.x2 
					hpl << a if a.y1 == a.y2 
					cons[[a.x1, a.y1]] += 3
				}
			end
		}
		hl.each{|el|
			x1, x2 = el.x1, el.x2
			x1, x2 = x2, x1 if x2 < x1 
			vl.each{|t|
				[[t.x1, t.y1], [t.x2, t.y2]].each {|tx, ty|
					if ty == el.y1
						if tx >= x1 && tx <= x2
							if tx > x1 && tx < x2
								cons[[tx, ty]] += 4
							else
								cons[[tx, ty]] -= 1 # supress junction mark at corners -- for hl only is sufficient, skipped for vl
							end
						end
						break # not much benefit
					end
				}
			}
			vpl.each{|t|
				cons[[t.x1, t.y1]] += 5 if t.y1 == el.y1 && t.x1 > x1 && t.x1 < x2
			}
		}
		vl.each{|el|
			y1, y2 = el.y1, el.y2
			y1, y2 = y2, y1 if y2 < y1 
			hl.each{|t|
				cons[[t.x1, t.y1]] += 4 if t.x1 == el.x1 && t.y1 > y1 && t.y1 < y2
				cons[[t.x2, t.y2]] += 4 if t.x2 == el.x1 && t.y2 > y1 && t.y2 < y2
			}
			hpl.each{|t|
				cons[[t.x1, t.y1]] += 5 if t.x1 == el.x1 && t.y1 > y1 && t.y1 < y2
			}
		}
		cr.connections = cons
		h = Hash.new{|h, k| h[k] = Array.new} # check for fully overlapping nets, mark red!
		vl.each{|el|
			h[el.x1] << el
			el.overlapp = false
		}
		h.each_value{|el|
			el.sort_by!{|n| n.y1 + n.y2}
			el.each_cons(2){|a, b|
				if a.y1 > b.y1 || a.y2 > b.y1 || a.y1 > b.y2 || a.y2 > b.y2
					(a.y2 - a.y1).abs < (b.y2 - b.y1).abs ? a.overlapp = true : b.overlapp = true
				end
			}
		}
		h.clear
		hl.each{|el|
			h[el.y1] << el
			el.overlapp = false
		}
		h.each_value{|el|
			el.sort_by!{|n| n.x1 + n.x2}
			el.each_cons(2){|a, b|
				if a.x1 > b.x1 || a.x2 > b.x1 || a.x1 > b.x2 || a.x2 > b.x2
					(a.x2 - a.x1).abs < (b.x2 - b.x1).abs ? a.overlapp = true : b.overlapp = true
				end
			}
		}
		major = @major_grid
		minor = @minor_grid
		mac = conf[:color_geda_mesh_grid_major]
		mic = conf[:color_geda_mesh_grid_minor]
		if minor > major
			mic, mac = mac, mic
			minor, major = major, minor
		end
		if new_background or !cr.background_pattern
			cr.background_pattern.destroy if cr.background_pattern
			@old_origin_x, @old_origin_y	= cr.device_to_user(0, 0)
			box = cr.bbox
			cr.push_group
			cr.set_source_rgb(conf[:color_geda_background][0..2]) # ignore alpha
			cr.paint
			cr.device_grid_major = cr.user_to_device_distance(major, 0)[0].round
			mesh_grid_minor_frac = 1 # 0..1 from config
			mesh_grid_major_frac = 1
			[[minor, mic, mesh_grid_minor_frac], [major, mac, mesh_grid_major_frac]].each{|grid, col, frac|
				if (grid > 0) and (cr.user_to_device_scale(grid) > 4)
					xi1 = box.x1.to_i / grid * grid
					xi2 = box.x2.to_i / grid * grid + grid
					yi1 = box.y1.to_i / grid * grid
					yi2 = box.y2.to_i / grid * grid + grid
					cr.set_line_cap(frac == 0 ? Cairo::LINE_CAP_ROUND : Cairo::LINE_CAP_BUTT)
					if frac == 1
						cr.set_dash([], 0)
					else
						l = grid * frac
						cr.set_dash([l, grid - l], l * 0.5)
					end
					cr.set_source_rgba(col)
					wu = cr.line_width_unscaled_user_min * cr.line_width_scale * cr.hair_line_scale
					w = cr.user_to_device_scale(wu)
					wd = w.round
					wu = cr.device_to_user_scale(wd) if w > 1
					cr.set_line_width(wu)
					even = wd > 1 && wd.even?
					skip_major = (grid == minor) and (mesh_grid_minor_frac == 1) and (mesh_grid_major_frac == 1)
					Range.new(xi1, xi2).step(grid){|j|
						cr.faster_sharp_thin_line_v(yi1, yi2, j, even) unless skip_major and (j.modulo(major) == 0)
					}
					cr.stroke
					Range.new(yi1, yi2).step(grid){|j|
						cr.faster_sharp_thin_line_h(xi1, xi2, j, even) unless skip_major and (j.modulo(major) == 0)
					}
					cr.stroke
				end
			}
			cr.background_pattern = cr.pop_group.surface
		else
			x, y = cr.device_to_user(0, 0)
			x = (x - @old_origin_x) % major
			y = (y - @old_origin_y) % major
			if x * 2 > major then x -= major end
			if y * 2 > major then y -= major end
			x, y = cr.user_to_device_distance(-x, -y)
			cr.background_pattern_offset_x, cr.background_pattern_offset_y = x.round, y.round
		end
		# start foreground
		cr.set_operator(Cairo::OPERATOR_CLEAR)
		damage_list.each{|box| ### TODO: can we merge this with M45 below?
			cr.rectangle(box.x1, box.y1, box.x2 - box.x1, box.y2 - box.y1)
			cr.fill
		}
		cr.set_operator(Cairo::OPERATOR_OVER)
		@ObjectList.select{|x| x.class == Sym || x.class == NetSegment}.each{|x| x.draw_junctions(cr, conf, damage_list, false, false)} # junctions -- maybe we should clip this call?
		cr.push_group # prepair shadows
		cr.new_path
		damage_list.each{|box|
			cr.rectangle(box.x1, box.y1, box.x2 - box.x1, box.y2 - box.y1)
		}
		cr.clip
		cr.soft = true
		1.upto(3) {|i|
			cr.translate(shift, -shift)
			cr.line_shadow_fix += (shift.fdiv(cr.line_width_scale))
			cr.line_shadow_scale = LSS[i]
			cr.text_shadow_fix += 100
			@ObjectList.each{|x| x.draw(cr, conf, damage_list, (i != 2),	(i != 1))}
		}
		cr.line_shadow_scale = 0 # reset values
		cr.line_shadow_fix = 0
		cr.text_shadow_fix = 0
		cr.soft = false
		cr.set_source_rgba([0, 0, 0, 1])
		cr.set_operator(Cairo::OPERATOR_IN)
		cr.reset_clip # necessary for nil_draw!
		cr.paint # make it black
		cr.pop_group_to_source
		cr.paint(0.9) # paint not fully opaque
		cr.new_path
		damage_list.each{|box| ### M45, merge possible
			cr.rectangle(box.x1, box.y1, box.x2 - box.x1, box.y2 - box.y1)
		}
		cr.clip
		cr.save # maybe undo translate() is good enough?
		shift *= 0.5
		@ObjectList.each{|x| x.draw(cr, conf, damage_list, false, false)}
		cr.highlight = true
		1.upto(3) {|i|
			cr.translate(-shift, shift)
			cr.line_shadow_fix += (shift.fdiv(cr.line_width_scale))
			cr.line_shadow_scale = LSS[i] * 0.5
			cr.text_shadow_fix += 100
			@ObjectList.each{|x| x.draw(cr, conf, damage_list, (i != 2),	(i != 1))}
		}
		cr.highlight = false
		cr.restore
		cr.line_shadow_scale = 0 # reset values
		cr.line_shadow_fix = 0
		cr.text_shadow_fix = 0
		cr.reset_clip
		damage_list.clear
	end # write_to_context

	def hoovering?()
		@ObjectList.xhoover
	end

	DirMap = {Gdk::Keyval::KEY_Up => [0, 1], Gdk::Keyval::KEY_Down => [0, -1], Gdk::Keyval::KEY_Left => [-1, 0], Gdk::Keyval::KEY_Right => [1, 0]}

	def cancel_insert_obj
		@ObjectList.cancel_new_object
		@state = PES::Hoovering
		@pda.set_cursor(Pet_Canvas::Cursor_Type::DEFAULT)
		@main_window.pop_msg
		@Sym = nil
	end

	# second stage of user input analysis
	# investigate event, determine Pet_Event_Message (PEM) and call
	# @ObjectList.preprocess_event() if necessary
	# boxlist: Array of bounding boxes with changed content -- accumulating for redraw
	# event: Gdk event
	# px, py: mouse pointer position in user coordinates (float)
	# no return value
	def investigate_event(boxlist, event, px, py)
		@pxr = px.fdiv(@active_grid).round * @active_grid
		@pyr = py.fdiv(@active_grid).round * @active_grid
		px = px.round
		py = py.round
		# maybe we should process menu button here...
		if event.event_type == Gdk::EventType::MOTION_NOTIFY
			if @state == PES::PopupMove
				@state = PES::Moved
				@px, @py = px, py
			end
			@curx, @cury = px, py
			if (event.state & Gdk::ModifierType::BUTTON2_MASK) != 0
				@state = PES::Dragging
				return
			end
			if @state == PES::Hit && (event.state & Gdk::ModifierType::SHIFT_MASK) != 0
				@state = PES::Dragging
				return
			end
			if @state == PES::Hit || @state == PES::Moved
				dx = @pxr - @pxxr
				dy = @pyr - @pyyr
				if dx != 0 || dy != 0
				@pxxr = @pxr
				@pyyr = @pyr
					@state = PES::Moved
					absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, dx, dy, PEM::Delta_Move)
					@px += dx
					@py += dy
				end
				return # selection state is unchanged, fast exit
			elsif @state == PES::Hoovering
				absorbed = @ObjectList.preprocess_event(boxlist, event, @pxr, @pyr, px, py, PEM::Hoover_Select)
			elsif @state == PES::Dragging || @state == PES::Patch
				@state = PES::Dragging
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::Drag_Select)
			end
		elsif event.event_type == Gdk::EventType::KEY_PRESS
			if @Sym
				self.cancel_insert_obj
			elsif event.keyval == Gdk::Keyval::KEY_Delete
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::KEY_Delete)
			elsif event.keyval == Gdk::Keyval::KEY_BackSpace
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::KEY_BackSpace)
			elsif event.keyval == Gdk::Keyval::KEY_Escape
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::KEY_Escape)
			elsif event.keyval == Gdk::Keyval::KEY_e
					absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::KEY_Edit)
				elsif h = DirMap[event.keyval]
					dx, dy = h.map{|el| el * @active_grid}
					absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, dx, dy, PEM::Delta_Move)
					@px, @py = px, py
				elsif event.keyval == Gdk::Keyval::KEY_m
					if @state == PES::Hoovering 
						@state = PES::Moved
						@px, @py = px, py
					elsif @state == PES::Moved
						@state = PES::Hoovering 
					end
				end
			elsif (event.event_type == Gdk::EventType::BUTTON_PRESS)
				if @Sym # add new loaded symbol TODO: fix -- we may find a better solution?
					if event.button == 1 # TODO: fix later, i.e. own methode
						@Sym.pda = @pda
						@Sym.bbox.reset_to_ghost
						@Sym.components.each{|x|
							if x.class != Text #&&  x.class != Versio # text is handled by attributes
								x.enlarge_bbox(@Sym.bbox)
							end
						}
						@Sym.translate(@pxr, @pyr)
						@Sym.nil_draw = true
						@Sym.selectable = 1
						@ObjectList.push(@Sym)
						@prop_box.show_properties(@Sym)
						boxlist << @Sym.bbox
						@Sym = nil
						@pda.set_cursor(Pet_Canvas::Cursor_Type::DEFAULT)
						@main_window.pop_msg
					else
						self.cancel_insert_obj
					end
				else
					@px, @py = px, py
					@pxxr = @pxr
					@pyyr = @pyr
					if @state == PES::Moved # from keyboard m
						@state ==	PES::Hoovering
					elsif @pda.hit
						@state = PES::Hit
					else 
						@state =PES::Patch
					end
				end
			elsif (event.event_type == Gdk::EventType::BUTTON2_PRESS) # TODO: do we really want/need this?
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::KEY_Edit)
		elsif event.event_type == Gdk::EventType::BUTTON_RELEASE
			if @state == PES::Patch && (event.button == 1) && (@ObjectList.selected == 0) && (!@ObjectList.attributes_selected) && (@ObjectList.empty? || !@ObjectList.last.absorbing)
				@ObjectList.new_object(@pda, @input_mode, @pxr, @pyr) # generally this new object is absorbing now (consumes input)
				boxlist << @ObjectList.last.bbox
			elsif @state == PES::Hit || @state == PES::Patch
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::Hit_Select)
				if !absorbed
					@ObjectList.new_object(@pda, @input_mode, @pxr, @pyr)
					boxlist << @ObjectList.last.bbox
				end
			elsif @state == PES::Dragging # action should have no result?
				absorbed = @ObjectList.preprocess_event(boxlist, event, @px, @py, px, py, PEM::Drag_Select) unless event.button == 2
			elsif @state == PES::Moved
				absorbed = @ObjectList.preprocess_event(boxlist, event, 0, 0, 0, 0, PEM::Check_Alive)
			end
			@state = PES::Hoovering
		elsif event.event_type == Gdk::EventType::SCROLL
			absorbed = @ObjectList.preprocess_event(boxlist, event, @pxr, @pyr, px, py, PEM::Scroll_Rotate)
			pda.scroll_event(pda.darea, event) unless absorbed
		end
		if (sel = @ObjectList.find{|el| el.state == State::Selected}) != @Last_selected
			@prop_box.show_properties(sel)
			@Last_selected = sel
		end
	end

	def write(name)
		#begin
			file = File.open(name, 'w')
			file.write("v 20140308 2\n")
			@ObjectList.each{|x| file.write(x.to_s)}
			file.close
		#rescue => e
			#puts e.message
		#end
	end

	def create_symbol()
		s = Sym.new(0, 0, @pda)
		@ObjectList.each_alive{|el|
			el.old_hoover = true # we use this field as marker
			if el.state == State::Selected && el.class != Sym && el.class != NetSegment	
				el.state = State::Visible
				el.attributes.each_alive{|a| a.state = State::Visible}
				s.components << el
			end
		}
		@ObjectList.each_alive{|el| s.components << el if el.class != Sym && el.class != NetSegment} if s.components.empty?
		return false if s.components.empty?
		s.components.each{|el| el.old_hoover = false}
		@ObjectList.keep_if{|el| el.old_hoover}
		###@ObjectList -= s.components # does not work, seems to return a plain Array
		s.x = s.components.min_by{|el| el.origin_x}.origin_x.round(-2)
		s.y = s.components.min_by{|el| el.origin_y}.origin_y.round(-2)
		s.bbox.reset_to_ghost
		s.components.each{|o| o.enlarge_bbox(s.bbox)}
		x = s.bbox.x1.round(-2)
		y = s.bbox.y2.round(-2)
		#%w(footprint refdes).each{|attr|
		%w(refdes).each{|attr|
			unless s.components.index{|el| el.class == Text && el.lines.split('=', 2).first == attr}
				t = Text.new(x, y, @pda)
				t.lines = attr + "=?"
				t.show_name_value = GEDA_TEXT_SHOW_VALUE
				t.nil_draw = true
				s.components << t
				y += 100
			end
		}
		@bbox.enlarge_abs(x, y)
		s.components.select{|c| c.class == Pet::Text}.each{|c|
			n, v = c.lines.split('=', 2)
			if n && v && !n.empty? && !v.empty?
				s.attr_hash[n] = c
				s.attributes << c.attr_deep_copy
				c.visibility = 0
			end
		}
		s.state = State::Selected
		s.selectable = 1
		@ObjectList << s
		pda.darea_new_box
		true
	end

	def save_symbol(name, as_shown)
		sym = nil
		n_sym = n_sel = 0
		@ObjectList.select{|el| el.class == Sym}.each{|el|
			n_sym += 1
			sym ||= el
			if el.state == State::Selected
				n_sel += 1
				sym = el
			end
		}
		if n_sel == 1 || n_sym == 1
			sym.basename = File.basename(name)
			begin
				File.open(name, 'w') do |f|
					f.write("v 20140308 2\n")
					f.write(sym.to_gsym(as_shown))
				end  
			rescue => e
				puts e.message
			end
		else
			if n_sel > 1
				Log::puts('Select only one symbol!')
			elsif n_sym > 1
				Log::puts('Select a symbol!')
			elsif n_sym < 1
				Log::puts('No symbol in this sheet!')
			end
		end
	end

	def can_save_symbol
		'test.sym'
	end

	def bbox()
		[@bbox.x1, @bbox.y1, @bbox.x2 - @bbox.x1, @bbox.y2 - @bbox.y1]
	end

end # Schem


def main
	if (ARGV[0] == nil) or (ARGV[0] == '-h') or (ARGV[0] == '--help')
		print Docu
	else
		s1 = Schem.new
		s1.ProcessInputFile(ARGV[0])
s1.write_png('out.png', 1400,1200)
		s1.write('txt.txt')
	end
end

# Start processing after all functions are read
#main
end # module Pet
# 4452
#
#
#
#


