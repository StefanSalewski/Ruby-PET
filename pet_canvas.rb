#!/usr/bin/ruby
#
module Pet_Canvas
#
# peted.rb, GUI for pet.rb -- a tiny electronics schematics editor
# Currently this is (only) a demo for zooming, panning, scrolling with Ruby/GTK/Cairo
# v 0.03
# (c) S. Salewski, 21-DEC-2010
# License GPL

require 'gtk3'
require 'cairo'
require_relative 'pet_bbox'

ZOOM_FACTOR_MOUSE_WHEEL = 1.1
ZOOM_FACTOR_SELECT_MAX = 10 # ignore zooming in tiny selection
ZOOM_NEAR_MOUSEPOINTER = true # mouse wheel zooming -- to mousepointer or center
SELECT_RECT_COL = [0, 0, 1, 0.5] # blue with transparency

=begin
Zooming, scrolling, panning...

|-------------------------|
|<-------- A ------------>|
|                         |
|  |---------------|      |
|  | <---- a ----->|      |
|  |    visible    |      |
|  |---------------|      |
|                         |
|                         |
|-------------------------|

a is the visible, zoomed in area == @darea.allocation.width
A is the total data range
A/a == @user_zoom >= 1
For horizontal adjustment we use
@hadjustment.set_upper(@darea.allocation.width * @user_zoom) == A
@hadjustment.set_page_size(@darea.allocation.width) == a
So @hadjustment.value == left side of visible area

Initially, we set @user_zoom = 1, scale our data to fit into @darea.allocation.width
and translate the origin of our data to (0, 0)

=end

=begin
Zooming: Mouse wheel or selecting a rectangle with left mouse button pressed
Scrolling: Scrollbars
Panning: Moving mouse while middle mouse button pressed 
=end


# drawing area and scroll bars in 2x2 table (PDA == Peted Drawing Area)

class Pos_Adj < Gtk::Adjustment
  attr_accessor :handler_ID
  def initialize
    super(0, 0, 1, 1, 10, 1) # value, lower, upper, step_increment, page_increment, page_size
  end
end

$OFFSET = 64

module Cursor_Type
  DEFAULT = 0
  ADD_SYM = 1
  DELETE = 2
end

class PDA < Gtk::Table
attr_accessor :darea, :cr7#, :background_pattern
attr_accessor :schem, :cursor, :cursor_type
attr_accessor :raw_x, :raw_y
	attr_accessor :hit, :panned, :ebdx , :ebdy
	  attr_accessor :user_zoom

  def initialize(schematic)
    @schem = schematic
    super(2, 2, false)
		@ebdx = @ebdy = 0

    @zoom_near_mousepointer = ZOOM_NEAR_MOUSEPOINTER # mouse wheel zooming
    @selecting = false
    @cursor = nil
    @cursor_type =  Pet_Canvas::Cursor_Type::DEFAULT
    @user_zoom = 1.0
    @surf = nil
@cr7=nil
#@background_pattern = nil
#@cra=nil
#@crb=nil
@new_cr = nil
@offx = $OFFSET
@offy = $OFFSET
@adj_last_x = -1
@adj_last_y = -1

@old_height = nil
@old_width = nil
@old_zoom = nil

    @darea = Gtk::DrawingArea.new
    #@darea.signal_connect('expose-event') { darea_expose_callback }
    @darea.signal_connect('draw') { darea_expose_callback }
    @darea.signal_connect('configure-event') { darea_configure_callback }
    # @darea.double_buffered = true # we use our own buffering -- but true is useful for selecting rectangle
    # @darea.can_focus = true # catch keyboard events
    # we use Gdk::Event::POINTER_MOTION_HINT_MASK to get not too many event when panning
    @darea.add_events(Gdk::EventMask::BUTTON_PRESS_MASK | Gdk::EventMask::BUTTON_RELEASE_MASK | Gdk::EventMask::SCROLL_MASK |
                      Gdk::EventMask::BUTTON1_MOTION_MASK | Gdk::EventMask::BUTTON2_MOTION_MASK | Gdk::EventMask::POINTER_MOTION_HINT_MASK)
   # @darea.signal_connect('motion-notify-event') { |w, e| on_motion(@darea, e) }
    ###@darea.signal_connect('scroll_event')        { |w, e| scroll_event(@darea, e) }
   #@darea.signal_connect('button_press_event')  { |w, e| button_press_event(@darea, e) }
   # @darea.signal_connect('button_release_event'){ |w, e| button_release_event(@darea, e) }
    @hadjustment = Pos_Adj.new # @darea.allocation.width is still invalid
    @hadjustment.handler_ID = @hadjustment.signal_connect('value-changed') { on_adjustment_event }
    @vadjustment = Pos_Adj.new
    @vadjustment.handler_ID = @vadjustment.signal_connect('value-changed') { on_adjustment_event }
    @hscrollbar  = Gtk::Scrollbar.new(:horizontal, @hadjustment)
    @vscrollbar  = Gtk::Scrollbar.new(:vertical, @vadjustment)
    attach(@darea, 0, 1, 0, 1, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 0, 0)
    attach(@hscrollbar, 0, 1, 1, 2, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 0, 0, 0)
    attach(@vscrollbar, 1, 2, 0, 1, 0, Gtk::AttachOptions::EXPAND | Gtk::AttachOptions::FILL, 0, 0)
  end

  def register_painter(p)
    @painter = p
  end

  def set_cursor(c)
    if c == Pet_Canvas::Cursor_Type::DEFAULT
      self.cursor = nil
    elsif c == Pet_Canvas::Cursor_Type::ADD_SYM
      self.cursor = Gdk::Cursor.new(Gdk::CursorType::X_CURSOR)
    end
    self.cursor_type = c
    self.window.cursor = self.cursor
  end

  # event coordinates to user space
  def get_user_coordinates(event_x, event_y)
    [(event_x - @hadjustment.upper * 0.5 + @hadjustment.value) / (@full_scale * @user_zoom) + @data_x + @data_width * 0.5,
     #(event_y - @vadjustment.upper * 0.5 + @vadjustment.value) / (@full_scale * @user_zoom) + @data_y + @data_height * 0.5]

     ( - (event_y - @vadjustment.upper * 0.5 + @vadjustment.value)) / (@full_scale * @user_zoom) + @data_y + @data_height * 0.5]


#(-(event_y - @darea.allocation.height) - @vadjustment.upper * 0.5 + @vadjustment.value) / (@full_scale * @user_zoom) + @data_y + @data_height * 0.5] # mirrored for geschem
  end


  def get_user_coordinates_delta(dx, dy)
    [dx / (@full_scale * @user_zoom), - dy / (@full_scale * @user_zoom)]
  end

  def get_x_bbox(dx)
    if dx > 0
      [get_user_coordinates(-$OFFSET, @darea.allocation.height + $OFFSET),  get_user_coordinates(dx - $OFFSET, -$OFFSET)].flatten
    else
      [get_user_coordinates(@darea.allocation.width + $OFFSET + dx, @darea.allocation.height + $OFFSET),  get_user_coordinates(@darea.allocation.width + $OFFSET, -$OFFSET)].flatten
    end
  end

  

  def get_user_bbox()
    #[get_user_coordinates(0, @darea.allocation.height),  get_user_coordinates(@darea.allocation.width, 0)].flatten
    [get_user_coordinates(-$OFFSET, @darea.allocation.height + $OFFSET),  get_user_coordinates(@darea.allocation.width + $OFFSET, -$OFFSET)].flatten
#[get_user_coordinates(-$OFFSET, @darea.allocation.height + 0 * $OFFSET),  get_user_coordinates(@darea.allocation.width + 0 * $OFFSET, -10)].flatten
  end

  # clamp to correct values, 0 <= value <= (@adjustment.upper - @adjustment.page_size), block calling on_adjustment_event()
  def update_val(adj, d)
    adj.signal_handler_block(adj.handler_ID)
    adj.set_value [0, [adj.value + d, adj.upper - adj.page_size].min].max 
    adj.signal_handler_unblock(adj.handler_ID)
  end

  def update_adjustments(dx, dy)

@hadjustment.signal_handler_block(@hadjustment.handler_ID)
@vadjustment.signal_handler_block(@vadjustment.handler_ID)



    @hadjustment.set_upper(@darea.allocation.width * @user_zoom)
    @vadjustment.set_upper(@darea.allocation.height * @user_zoom)
    @hadjustment.set_page_size(@darea.allocation.width)
    @vadjustment.set_page_size(@darea.allocation.height)
    update_val(@hadjustment, dx)
    update_val(@vadjustment, dy)

@hadjustment.signal_handler_unblock(@hadjustment.handler_ID)
@vadjustment.signal_handler_unblock(@vadjustment.handler_ID)



  end

  def update_adjustments_and_paint(dx, dy)

@schem.main_window.toolbar_top.zoom_out_button.sensitive = @schem.pda.user_zoom > 1

    update_adjustments(dx, dy)
    paint
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
  end


  def redraw
    paint(true)
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
  end


  def darea_new_box
    update_adjustments(0, 0)
    @data_x, @data_y, @data_width, @data_height = @schem.bbox()
puts 'mmm', @data_x, @data_y, @data_width, @data_height
    @full_scale = [@darea.allocation.width.to_f / @data_width, @darea.allocation.height.to_f / @data_height].min

    paint(true)
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
  end



  def darea_configure_callback
    update_adjustments(0, 0)
    @data_x, @data_y, @data_width, @data_height = @schem.bbox()
puts 'mmm', @data_x, @data_y, @data_width, @data_height
    @full_scale = [@darea.allocation.width.to_f / @data_width, @darea.allocation.height.to_f / @data_height].min

	# caution: for first call @darea.allocation.width == 1
	if @darea.allocation.width > 100
    paint(true)
	end
  end

  # copy content of @surf to darea, draw seletion rectangle
  def darea_expose_callback

#puts 'yyy', @cr7.background_pattern_offset_x, @cr7.background_pattern_offset_y


    cr = @darea.window.create_cairo_context
cr.set_source_rgb(0,1,0)
    cr.paint
    #cr.set_source(@cr7.background_pattern, -$OFFSET + @offx + @cr7.background_pattern_offset_x, -$OFFSET +  @offy + @cr7.background_pattern_offset_y)


ox = (@offx + @cr7.background_pattern_offset_x) % @cr7.device_grid_major
if ox > (@cr7.device_grid_major / 2) then ox -= @cr7.device_grid_major end

oy = (@offy + @cr7.background_pattern_offset_y) % @cr7.device_grid_major
if oy > (@cr7.device_grid_major / 2) then oy -= @cr7.device_grid_major end


puts 'yyy', @cr7.device_grid_major


cr.set_source(@cr7.background_pattern, -$OFFSET + ox, -$OFFSET +  oy)


    #cr.set_source(@cr7.background_pattern, 10,0)





#cr.set_source_rgb(0,1,0)
    cr.paint
#cr.save
#cr.set_operator(Cairo::OPERATOR_OVER)



    #p = Cairo::SolidPattern.new(1,1,1,0.7)



    cr.set_source(@surf, -$OFFSET + @offx, -$OFFSET +  @offy)


    #cr.mask(p)
    cr.paint(0.7)

    #cr.paint
#cr.restore
    if (@sx1 != @sx2) and  (@sy1 != @sy2)
      cr.rectangle(@sx1, @sy1, @sx2 - @sx1, @sy2 - @sy1)
      cr.set_source_rgba SELECT_RECT_COL # 0, 0, 1, 0.5
      cr.fill_preserve
      cr.set_source_rgb 0, 0, 0
      cr.set_line_width 2
      cr.stroke
    end
    cr.destroy
  end

  def button_press_event(area, event)
    if (event.button == 1) or (event.button == 2)
      x, y = get_user_coordinates(event.x, event.y)
      print 'User coordinates: ', x, ' ', y, "\n" # to verify get_user_coordinates()
      @last_mouse_pos_x = event.x
      @last_mouse_pos_y = event.y
      @last_button_down_pos_x = event.x
      @last_button_down_pos_y = event.y
@consuming = true
      return true
    else
      return false
    end
  end

  # zoom into selected rectangle and center it
  def button_release_event(area, event)
    if @consuming == true
      if event.button == 1
        @selecting = false
        z1 = [@darea.allocation.width.to_f / (@last_button_down_pos_x - event.x).abs, @darea.allocation.height.to_f / (@last_button_down_pos_y - event.y).abs].min
        if z1 < ZOOM_FACTOR_SELECT_MAX # else selection rectangle will persist, we may output a message... 
          @user_zoom *= z1
          update_adjustments_and_paint(
            ((2 * @hadjustment.value + event.x + @last_button_down_pos_x) * z1  - @darea.allocation.width) * 0.5 - @hadjustment.value,
            ((2 * @vadjustment.value + event.y + @last_button_down_pos_y) * z1  - @darea.allocation.height) * 0.5 - @vadjustment.value)
        end
      end
      @consuming = false
      return true
    else
      return false
    end
  end




  # zoom into selected rectangle and center it
  def zoom_into_select_rect()
	puts 'pofff'
    z1 = [@darea.allocation.width.to_f / (@sx1 - @sx2).abs, @darea.allocation.height.to_f / (@sy1 - @sy2).abs].min
    if z1 < ZOOM_FACTOR_SELECT_MAX # else selection rectangle will persist, we may output a message... 
      @user_zoom *= z1
      update_adjustments_and_paint(
        ((2 * @hadjustment.value + @sx1 + @sx2) * z1  - @darea.allocation.width) * 0.5 - @hadjustment.value,
        ((2 * @vadjustment.value + @sy1 + @sy2) * z1  - @darea.allocation.height) * 0.5 - @vadjustment.value)
    end
    @sx1, @sy1, @sx2, @sy2 = 0, 0, 0, 0
  end





  def draw_select_rect(x1, y1, x2, y2)
	puts 'puuuuuuh'
    @sx1, @sy1, @sx2, @sy2 = x1, y1, x2, y2
#if (@sx1 != @sx2) and  (@sy1 != @sy2)
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
#end
  end



  def pan(dx, dy)
    update_adjustments_and_paint(dx, dy)
      #event.request # request more motion events
  end





  def on_motion(area, event)
    if @consuming == true
      if (event.state & Gdk::Window::BUTTON1_MASK) != 0 # selecting
        @selecting = true
        @zoom_rect_x1 = event.x
        @zoom_rect_y1 = event.y
        @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
      elsif (event.state & Gdk::Window::BUTTON2_MASK) != 0 # panning
        update_adjustments_and_paint(@last_mouse_pos_x - event.x, @last_mouse_pos_y - event.y)
      end
      @last_mouse_pos_x = event.x
      @last_mouse_pos_y = event.y
      event.request # request more motion events
      return true
    else
      return false
    end
  end

  def on_adjustment_event
    paint
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
  end

  # zooming with mouse wheel -- data near mouse pointer should not move if possible!
  # @hadjustment.value + event.x is the position in our zoomed_in world, (@user_zoom / z0 - 1) is the relative movement caused by zooming
  def scroll_event(area, event)
    z0 = @user_zoom
    if event.direction == Gdk::ScrollDirection::UP
      @user_zoom *= ZOOM_FACTOR_MOUSE_WHEEL
    elsif event.direction == Gdk::ScrollDirection::DOWN
      @user_zoom /= ZOOM_FACTOR_MOUSE_WHEEL
      if (@user_zoom < 1) then
        @user_zoom = 1
      end
    end
    if @zoom_near_mousepointer == true
      update_adjustments_and_paint((@hadjustment.value + event.x) * (@user_zoom / z0 - 1),
                                   (@vadjustment.value + event.y) * (@user_zoom / z0 - 1))
    else # zoom to center
      update_adjustments_and_paint((@hadjustment.value + @darea.allocation.width * 0.5) * (@user_zoom / z0 - 1),
                                   (@vadjustment.value + @darea.allocation.height * 0.5) * (@user_zoom / z0 - 1))
    end
  end


	def zoom(factor)
		z0 = @user_zoom
		@user_zoom *= factor

		update_adjustments_and_paint((@hadjustment.value + @darea.allocation.width * 0.5) * (@user_zoom / z0 - 1),
                                 (@vadjustment.value + @darea.allocation.height * 0.5) * (@user_zoom / z0 - 1))
	end


  def get_strip_bboxes(ox, oy)
    boxes = Array.new
    [ox, oy].each_with_index{|o, i|
      x1 = y1 = - $OFFSET
      x2 = @darea.allocation.width + $OFFSET
      y2 = @darea.allocation.height + $OFFSET
      if i == 0
        if o == 0
          next
        elsif o < 0
          x1 = x2 + o
        else
          x2 = x1 + o
        end
      else
        if o == 0
          next
        elsif o < 0
          y1 = y2 + o
        else
          y2 = y1 + o
        end
      end
      boxes << Bounding::Box.new(*get_user_coordinates(x1, y1), *get_user_coordinates(x2, y2))
    }
    boxes
  end
$MyGlob = 0
  def paint(new_size = false) 
    @hadjustment.value = @hadjustment.value.round
    @vadjustment.value = @vadjustment.value.round
    @offx = (@adj_last_x - @hadjustment.value).round
    @offy = (@adj_last_y - @vadjustment.value).round
    new_size ||= ((@old_height != @darea.allocation.height) or (@old_width != @darea.allocation.width) or (@old_zoom != @user_zoom))
    @old_height = @darea.allocation.height
    @old_width = @darea.allocation.width
    @old_zoom = @user_zoom
    if new_size or !@cr7
		puts "paint newsize"
$MyGlob += 1
		#fail if $MyGlob == 2
      @box = [Bounding::Box.new(*get_user_bbox())]
      cr0 = @darea.window.create_cairo_context
      other = cr0.target
      cr0.destroy
      if @cr7 != nil then @cr7.destroy end
      if @surf != nil then @surf.destroy end
      @surf = other.create_similar(Cairo::CONTENT_COLOR_ALPHA, @darea.allocation.width + 2 * $OFFSET, @darea.allocation.height + 2 * $OFFSET)
      @cr7 = Cairo::Context.new(@surf)
      @cr7.bbox = @box[0].dup
    elsif ((@offx.abs < $OFFSET) and (@offy.abs < $OFFSET))
      return
    else
      @cr7.identity_matrix
      @box = get_strip_bboxes(@offx, @offy)
      t = @cr7.target
      @cr7.push_group
      @cr7.translate(@offx, @offy)
      @cr7.set_source(t)
      @cr7.paint
      p = @cr7.pop_group
      @cr7.set_operator(Cairo::OPERATOR_CLEAR)
      @cr7.set_source_rgba([0,1,1,0])
      @cr7.paint
      @cr7.set_operator(Cairo::OPERATOR_OVER)
      @cr7.set_source(p)
      @cr7.paint
    end
    @adj_last_x = @hadjustment.value
    @adj_last_y = @vadjustment.value
    @offx = 0
    @offy = 0
    @cr7.translate($OFFSET, $OFFSET)
    @cr7.translate(0, @darea.allocation.height) # horizontally mirror our display to be compatible with gEDA/gschem 
    @cr7.scale(1, -1)
    @cr7.translate(@hadjustment.upper * 0.5 - @hadjustment.value, # our origin is the center
                 @vadjustment.upper * 0.5 - (@vadjustment.upper - @vadjustment.page_size - @vadjustment.value))
    @cr7.scale(@full_scale * @user_zoom, @full_scale * @user_zoom)
    @cr7.translate(-@data_x - @data_width * 0.5, -@data_y - @data_height * 0.5)
    @cr7.bbox = Bounding::Box.new(*get_user_bbox())
    #@painter.call(@cr7, @box, new_size)
    @schem.write_to_context(@cr7, @box, new_size)

  end

  def update_canvas(damage_list)
#@painter.call(@cr7, damage_list, false)
    @schem.write_to_context(@cr7, damage_list, false)

#    paint
    @darea.queue_draw_area(0, 0, @darea.allocation.width, @darea.allocation.height)
  end


end # PDA

#class Canvas < Gtk::Window
#  def initialize
#    super
#    signal_connect('destroy') { Gtk.main_quit }
#    set_title 'PetEd'
#    set_size_request 200, 300
#    pda = PDA.new
#    add pda
#    show_all
#  end
#end # Peted

end # Pet_Canvas

# the user must provide only two funtions, get_world_extends() and draw_world()
# of course these may be defined in a separate file
module User_World
  # arbitrary bounding box of this small world, don't have to be constant
  Data_x = 150
  Data_y = 250
  Data_width = 200
  Data_height = 120

  # bounding box of user data -- x, y, w, h -- top left corner, width, height
  def self.get_world_extends()
    return Data_x, Data_y, Data_width, Data_height # current extents of our user world 
  end

  # draw to cairo context
  def self.draw_world(cr)
    cr.set_source_rgb 1, 1, 1
    cr.paint
    cr.set_source_rgb 0, 0, 0
    cr.set_line_width 2
    cr.rectangle(Data_x, Data_y, Data_width, Data_height)
    i = 10
    while true
      if [Data_width - 2 * i, Data_height - 2 * i].min <= 0 then break end
      cr.rectangle(Data_x + i, Data_y + i , Data_width - 2 * i, Data_height - 2 * i)
      i += 10
    end 
    cr.stroke
  end

end # User_World

#Gtk.init
#window = Pet_Canvas::Peted.new
#Gtk.main

