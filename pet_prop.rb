require 'gtk3'

module Property_Display

class SpinButtonLockable < Gtk::SpinButton
	attr_accessor :lock
	def set_value_silent(v)
		self.signal_handler_block(@lock)
		self.value = v
		self.signal_handler_unblock(@lock)
	end
end


class SmallRadioButton < Gtk::RadioButton
	Provider = Gtk::CssProvider.new
	#-GtkButton-inner-border : 0; deprecated
	#-GtkCheckButton-indicator-size : 16; default
	Provider.load(:data => ' * {
		-GtkCheckButton-indicator-spacing : 0;
		-GtkButton-default-border : 0;
		-GtkButton-default-outside-border : 0;
		-GtkWidget-focus-line-width : 0;
		-GtkWidget-focus-padding : 0;
		padding : 0;
	}')
	def initialize(w = nil)
		#super(w)
		super(:member => w)
		self.style_context.add_provider(Provider, GLib::MAXUINT) # minimal borders for dense layout
	end
end

# 2 5 8
# 1 4 7
# 0 3 6
class Text_Align < Gtk::Grid
	def initialize(pw) # property widget (parent)
		super()
		@position = 0 # initial
		self.margin_start = 2
		self.attach(Gtk::Label.new('Origin'), 0, 0, 3, 1)
		w = nil
		(0..8).each{|i|
			w = SmallRadioButton.new(w)
			#w.active = true if i == 0 # already default
			w.signal_connect("toggled"){|w|
				if w.active?
					pw.set_alignment(i)
					@position = i
				end
			}
			self.attach(w, i / 3, 3 - i % 3, 1, 1)
		}
	end
	def get_position
		@position
	end
	def set_position(i)
		self.get_child_at(i / 3, 3 - i % 3).active = true
	end
end

class ColBox < Gtk::ComboBox
	attr_accessor :lock
	Col_Name, Col_Pixbuf, Col_Full_Name = 0, 1, 2
	def initialize
		store = Gtk::ListStore.new(String, Gdk::Pixbuf, String)
		Pet_Config::get_default_config.get_colors(Pet_Config::SCR_S).each{|sym, b, c|
			next unless s = Pet_Config::Color_Name[sym] # some colors may have no name/index, i.e. pin hot end color
			iter = store.append
			iter[Col_Name] = "(#{s})"
			iter[Col_Pixbuf] = Gdk::Pixbuf.new(Gdk::Pixbuf::COLORSPACE_RGB, true, 8, 12, 12) # (colorspace, has_alpha, bits_per_sample, width, height)
			iter[Col_Full_Name] = sym.to_s
		}
		super(:model => store)
		self.margin = 0 
		self.id_column = Col_Full_Name
		renderer = Gtk::CellRendererPixbuf.new
		self.pack_start(renderer, false)
		self.add_attribute(renderer, "pixbuf", Col_Pixbuf)
		self.set_cell_data_func(renderer) do |w, renderer, model, iter| # Gtk::ComboBox, Gtk::CellRendererPixbuf, Gtk::ListStore, Gtk::TreeIter
			r, g, b, a = Pet_Config::get_default_config.get_conf(Pet_Config::SCR_S)[iter[Col_Full_Name].to_sym]
			renderer.pixbuf.fill!((r * 255).round * 16777216 + (g * 255).round * 65536 + (b * 255).round * 256 + (a * 255).round)
		end
		renderer = Gtk::CellRendererText.new
		self.pack_start(renderer, true)
		self.add_attribute(renderer, "text", Col_Name)
		self.has_frame = false
	end

	def set_active_silent(i)
		self.signal_handler_block(@lock)
		self.active = i
		self.signal_handler_unblock(@lock)
	end
	# TODO: update
end

class ColorBox < ColBox
	def initialize(pw) # property widget (parent)
		super()
		self.signal_connect("changed"){|w|
			pw.set_color(Pet_Config::RCIM[w.active_id.to_sym])
		}
	end
	def get_color
		Pet_Config::RCIM[self.active_id.to_sym]
	end
	def set_color(i)
		self.active = i
	end
	# TODO: update displayed color if configuration is changed by user
end

class Attr_Details < Gtk::Grid # x, y, size, angle, color and origin of an attribute
	def label(n, t = nil)
		l = Gtk::Label.new(n)
		l.xalign = 0
		l.tooltip_text = t
		return l
	end

	def initialize(pw) # property widget (parent)
		super()
		#self.column_homogeneous = false
		#self.row_homogeneous = true
		self.attach(label('C.', 'Color'), 0, 0, 1, 1)
		@color = ColorBox.new(pw)
		self.attach(@color, 1, 0, 3, 1)
		min, max, step = 0, 1000000, 1 # TODO: make grid sensitive
		t = "Horizontal\nCoordinate"
		self.attach(label('x', t), 0, 1, 1, 1)
		@x = Gtk::SpinButton.new(min, max, step)
		@x.has_frame = false
		@x.hexpand = true
		@x.width_chars = 6
		@x.tooltip_text = t
		@x.signal_connect("value_changed"){|w| pw.set_x(w.value)}
		self.attach(@x, 1, 1, 1, 1)
		t = 'Text Size'
		self.attach(label('S.', t), 2, 1, 1, 1)
		@size = Gtk::SpinButton.new(0, 32, 1)
		@size.has_frame = false
		@size.hexpand = true
		@size.width_chars = 3
		@size.tooltip_text = t
		@size.signal_connect("value_changed"){|w| pw.set_size(w.value)}
		self.attach(@size, 3, 1, 1, 1)
		t = "Vertical\nCoordinate"
		self.attach(label('y', t), 0, 2, 1, 1)
		@y = Gtk::SpinButton.new(min, max, step)
		@y.has_frame = false
		@y.hexpand = true
		@y.width_chars = 6
		@y.tooltip_text = t
		@y.signal_connect("value_changed"){|w| pw.set_y(w.value)}
		self.attach(@y, 1, 2, 1, 1)
		t = 'Text Angle'
		self.attach(label('A.', t), 2, 2, 1, 1)
		@angle = Gtk::SpinButton.new(0, 360, 90)
		@angle.has_frame = false
		@angle.hexpand = true
		@angle.width_chars = 3
		@angle.tooltip_text = t
		@angle.signal_connect("value_changed"){|w| pw.set_angle(w.value)}
		self.attach(@angle, 3, 2, 1, 1)
		@text_align = Text_Align.new(pw)
		self.attach(@text_align, 4, 0, 1, 3)
	end
	def set(x, y, s, a, c, p)
		@x.value = x
		@y.value = y
		@size.value = s
		@angle.value = a
		@text_align.set_position(p)
		@color.set_color(c)
	end

	def get
		[@x.value, @y.value, @size.value, @angle.value, @color.get_color, @text_align.get_position]
	end

end

# For each object on canvas we have a corresponding property widget
# All these widgets are contained in a Notebook, which hides all but the one
# corresponding to current users selection
class Properties_Widget < Gtk::Notebook
	attr_accessor :main_window # ask for redraw of object if property is changed
	def initialize(main_window)
		super()
		@main_window = main_window
		@grid_sensitive_spin_button_list = Array.new
		self.enable_popup = true
		self.add(w = Box_Widget.new(self), :tab_label => 'Box')
		self.set_tab_reorderable(w, true)
		self.add(w = Net_Widget.new(self), :tab_label => 'Net')
		self.set_tab_reorderable(w, true)
		self.add(w = Pin_Widget.new(self), :tab_label => 'Pin')
		self.set_tab_reorderable(w, true)
		self.add(w = Path_Widget.new(self), :tab_label => 'Path')
		self.set_tab_reorderable(w, true)
		self.add(w = Sym_Widget.new(self), :tab_label => 'Sym')
		self.set_tab_reorderable(w, true)
	end

	# find matching widget and ask it to display properties of obj
	# detach active widget from obj if obj == nil
	def show_properties(obj)
		unless obj # detach
			return if self.page < 0
			w = self.get_nth_page(self.page)
			w.update_widget_from_object(nil)
			return
		end
		i = 0
		while w = self.get_nth_page(i)
			if obj.is_a?(w.obj_class)
				w.update_widget_from_object(obj)
				self.page = i
				return
			end
			i += 1
		end
	end

	def set_page_from_name(n)
		i = 0
		while w = self.get_nth_page(i)
			puts self.get_tab_label(w).text , n
			if self.get_tab_label(w).text == n
				self.page = i
				break
			end
			i += 1
		end
		puts n
	end


	def init_object(obj)
		i = 0
		while w = self.get_nth_page(i)
			if obj.is_a?(w.obj_class)

	w.init_object_from_widget(obj)
				#w.update_widget_from_object(obj)
				self.page = i
				return
			end
			i += 1
		end



	end



	def org_update_coordinates(obj)
		i = 0
		while w = self.get_nth_page(i)
			if obj.is_a?(w.obj_class)
				w.update_widget_xy_from_object(obj)
				self.page = i
				return
			end
			i += 1
		end
	end


	def update_coordinates(obj)
		#i = 0
		w = self.get_nth_page(self.page)
			if obj.is_a?(w.obj_class)
				w.update_widget_xy_from_object(obj)
				#self.page = i
				return
			end
			#i += 1
		#end
	end





	def add_to_grid_sensitive_spin_button_list(w)
		@grid_sensitive_spin_button_list << w
	end
end

# properties of an object (line, box, symbol...) are contained in
# a grid widget. A parent notebook widget contains all the grid widgets
# for the objects
#:x, :y, :width, :height, :color, :linewidth, :capstyle, :dashstyle, :dashlength, :dashspace, :filltype, :fillwidth, :angle1, :pitch1, :angle2, :pitch2
# base class
class Obj_Property_Widget < Gtk::Box # box contains grid in top area, and attributes area below
	attr_accessor :obj # corresponding object on canvas
	def initialize(parent_notebook)
		@row = 0 # attach widgets top to bottom in grid
		@obj = nil
		@parent_notebook = parent_notebook
		@grid = Gtk::Grid.new
		super(:vertical, 0)
		self.pack_start(@grid, :expand => false, :fill => false, :padding => 0)
		@grid.column_spacing = 8
	end

	def attach_label(name, tooltip_text = nil)
		l = Gtk::Label.new(name)
		l.tooltip_text = tooltip_text
		@grid.attach(l, 0, @row, 1, 1)
	end

	def attach_spin_button_grid_sensitive(name, ivar_name, tooltip_text = nil)
		self.attach_label(name, tooltip_text)
		i = Pet_Config::get_default_config.get_conf(Pet_Config::SCR_S)[:grid_size_major]
		w = SpinButtonLockable.new(-100000, 100000, i) # arbitrary bound for now
		w.hexpand = true
		w.width_chars = 8
		w.lock = w.signal_connect("value_changed"){self.update_object_from_widget_smart(ivar_name, w.value.to_i)}
		@grid.attach(w, 1, @row, 1, 1)
		@row += 1
		@parent_notebook.add_to_grid_sensitive_spin_button_list(w)
		return w
	end

	def attach_spin_button(name, ivar_name, min, max, step, tooltip_text = nil)
		self.attach_label(name, tooltip_text)
		w = Gtk::SpinButton.new(min, max, step)
		w.tooltip_text = tooltip_text
		w.hexpand = true
		w.width_chars = 8
		w.signal_connect("value_changed"){self.update_object_from_widget_smart(ivar_name, w.value)}
		@grid.attach(w, 1, @row, 1, 1)
		@row += 1
		return w
	end

	# put checkbox indicating mirroring beside spin button # TODO: fix checkbutton missing return value
	def attach_spin_button_angle(name, ivar_name, min, max, step, tooltip_text = nil)
		self.attach_label(name, tooltip_text)
		b = Gtk::Box.new(:horizontal, 0)
		w = Gtk::CheckButton.new
		w.signal_connect("toggled"){|w| self.update_object_from_widget_smart('mirror', w.active? ? 1 : 0)}
		b.pack_start(w, :expand => false, :fill => false, :padding => 0)
		w = Gtk::SpinButton.new(min, max, step)
		w.tooltip_text = tooltip_text
		w.hexpand = true
		w.width_chars = 8
		w.signal_connect("value_changed"){|w| self.update_object_from_widget_smart(ivar_name, w.value)}
		b.pack_start(w, :expand => true, :fill => true, :padding => 0)
		@grid.attach(b, 1, @row, 1, 1)
		@row += 1
		return w
	end

	# TODO: what to do when button is clicked?
	def attach_symname_button(name, ivar_name, tooltip_text = nil)
		self.attach_label('Name', tooltip_text)
		w = Gtk::Button.new #(:label => 'OpAmp.sym')
		w.tooltip_text = tooltip_text
		w.hexpand = true
		@grid.attach(w, 1, @row, 1, 1)
		@row += 1
		return w
	end

	def attach_combobox_cap(name, ivar_name)
		self.attach_label(name)
		w = Gtk::ComboBoxText.new
		GEDA::END_CAP.keys.each{|el| w.append_text(el.to_s)}
		w.signal_connect("changed"){|w| self.update_object_from_widget_smart(ivar_name, w.active)}
		@grid.attach(w, 1, @row, 1, 1)
		@row += 1
		return w
	end

	def attach_color_box(name, ivar_name)
		self.attach_label(name)
		box = ColBox.new
		box.lock = box.signal_connect("changed"){|w| self.update_object_from_widget_smart(ivar_name, Pet_Config::RCIM[w.active_id.to_sym])}
		@grid.attach(box, 1, @row, 1, 1)
		@row += 1
		return box
	end

	def attach_attr_details(tv) #treeview
		@attr_details_box = Attr_Details.new(self)
		self.pack_start(@attr_details_box, :expand => false, :fill => false, :padding => 0)
	end

	def attach_attr_add
		v =  Gtk::Box.new(:horizontal, 0)
		@name_visible_button = Gtk::CheckButton.new
		v.pack_start(@name_visible_button, :expand => false, :fill => false, :padding => 0)
		@name_combo_box = Gtk::ComboBoxText.new(:entry => true)
		@name_combo_box.child.width_chars = 6
		@name_combo_box.append_text('refdes') # TODO: fill in correct values
		@name_combo_box.append_text('footprint')
		v.pack_start(@name_combo_box, :expand => false, :fill => false, :padding => 0)
		@value_visible_button =Gtk::CheckButton.new
		v.pack_start(@value_visible_button, :expand => false, :fill => false, :padding => 0)
		@value_entry = Gtk::Entry.new
		@value_entry.width_chars = 6
		v.pack_start(@value_entry, :expand => true, :fill => true, :padding => 0)
		self.pack_start(v, :expand => false, :fill => false, :padding => 0)
	end

	def attach_attr_add2
		v = Gtk::Box.new(:horizontal, 0)
		w = Gtk::Button.new(:label => '+')
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		w.signal_connect('clicked'){
			if @obj
				x, y, s, a, c, p = @attr_details_box.get
				iter = @store.append
				iter[Col_ID] = 0
				iter[Col_Name_Vis] = @name_visible_button.active?
				iter[Col_Name] = @name_combo_box.active_text
				iter[Col_Value_Vis] = @value_visible_button.active?
				iter[Col_Value] = @value_entry.text
				iter[Col_X] = x
				iter[Col_Y] = y
				iter[Col_Color] = c 
				iter[Col_Size] = s
				iter[Col_Angle] = a
				iter[Col_Alignment] = p
			end
		}
		w = Gtk::Button.new(:label => '-') # TODO: make it work






		v.pack_start(w, :expand => true, :fill => true, :padding => 0)

		w.signal_connect('clicked'){
			if @obj
				if s = @tree_view.selection.selected

					##s[Col_Size] = i
					puts 'called  set_size'
					@store.remove(s)
					#@store.remove(s)
				end
			end
		}



		w = Gtk::Button.new(:label => '<>')
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		w = Gtk::SpinButton.new(-900, 900, 100)
		w.width_chars = 3
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		w = Gtk::SpinButton.new(-900, 900, 100)
		w.width_chars = 3
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		self.pack_start(v, :expand => false, :fill => false, :padding => 0)
	end

	def attach_attr_add3
		v =  Gtk::Box.new(:horizontal, 0)
		w = Gtk::Button.new(:mnemonic => "_ADD")#, :stock_id => Gtk::Stock::OPEN)
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		w = Gtk::Button.new(:mnemonic => '_DEL')#, :stock_id => Gtk::Stock::CLOSE)
		@obj_delete_button = w
		v.pack_start(w, :expand => true, :fill => true, :padding => 0)
		v.margin_top = 2
		self.pack_start(v, :expand => false, :fill => false, :padding => 0)
	end

Col_ID = 0
Col_Name_Vis = 1
Col_Name = 2
Col_Text = 2
Col_Value_Vis = 3
Col_Value = 4
Col_X = 5
Col_Y = 6
Col_Color = 7
Col_Size = 8
Col_Angle = 9
Col_Alignment = 10

	def set_alignment(i)
		if s = @tree_view.selection.selected
			s[Col_Alignment] = i
		end
	end

	def set_color(i)
		if s = @tree_view.selection.selected
			s[Col_Color] = i
		end
	end

	def set_size(i)
		if s = @tree_view.selection.selected
			s[Col_Size] = i
			puts 'called  set_size'
#@store.remove(s)
#@store.remove(s)
		end
	end

	def set_x(i)
		if s = @tree_view.selection.selected
			s[Col_X] = i
		end
	end

	def set_y(i)
		if s = @tree_view.selection.selected
			s[Col_Y] = i
		end
	end

	def set_angle(i)
		if s = @tree_view.selection.selected
			s[Col_Angle] = i
		end
	end

	def gen_ttl(n, t) # generate label with tooltip text
		w = Gtk::Label.new(n)
		w.tooltip_text = t
		w.show
		return w
	end

	def attach_attributes
	  @tree_view = tv = Gtk::TreeView.new
		tv.selection.mode = Gtk::SelectionMode::SINGLE
		tv.activate_on_single_click = true
		tv.reorderable = true
    tv.signal_connect('row-activated'){|tree_view, path, column|
			s = tree_view.selection.selected
			@attr_details_box.set(s[Col_X], s[Col_Y], s[Col_Size], s[Col_Angle], s[Col_Color], s[Col_Alignment])
		}

    tv.signal_connect('button-press-event'){|tree_view, event|
		if event.button == 3

			s = tree_view.selection.selected
			puts 'button-press-event'
			popup_menu = Gtk::Menu.new
			popup_menu.append(del_item = Gtk::MenuItem.new("Delete"))
			del_item.signal_connect('activate') {|w|
			
			if s = @tree_view.selection.selected

				@store.remove(s)
			end
			
			puts 'delete'}
			popup_menu.show_all
			popup_menu.popup(nil, nil, event.button, event.time)
false
		end
		}

    r = Gtk::CellRendererText.new
    c = Gtk::TreeViewColumn.new('', r, "text" => Col_ID)
	  c.set_cell_data_func(r) do |tvc, cell, model, iter| # TODO: map integer to nice characters
      t = iter[Col_ID]
      #if t[0..10] == 'color_geda_' then t = t[11..-1] end
      #cell.text = '*'
  #NEW, INHERITED, MODIFIED, REDEFINED

      cell.text = ['+', 'o', '*', '!'][t]
    end
		c.widget = gen_ttl('?', 'History')
    tv.append_column(c)


    r = Gtk::CellRendererToggle.new
    r.signal_connect(:toggled){|w, path|
			iter = @store.get_iter(path)
			iter[Col_Value_Vis] ^= true
		}
    c = Gtk::TreeViewColumn.new('', r, "active" => Col_Value_Vis)
		c.widget = gen_ttl('V', 'Value Visible?')
    tv.append_column(c)
    r = Gtk::CellRendererText.new
    r.editable = true
    r.signal_connect('edited') do |w, path, new_text|
			iter = @store.get_iter(path)
			if iter[Col_Value] != new_text # only update if changed!
				puts 'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm' if new_text[-1] == "\n"
				iter[Col_Value] = new_text
			end
		end
		c = Gtk::TreeViewColumn.new('', r, "text" => Col_Value)
		c.widget = gen_ttl('Value', 'Attribute Value')
		tv.append_column(c)


    r = Gtk::CellRendererToggle.new
    r.signal_connect(:toggled){|w, path|
			iter = @store.get_iter(path)
			iter[Col_Name_Vis] ^= true # !iter[Col_Name_Vis] 
		}
    c = Gtk::TreeViewColumn.new('', r, "active" => Col_Name_Vis)
		c.widget = gen_ttl('V', 'Name Visible?')
    tv.append_column(c)
    r = Gtk::CellRendererCombo.new
    r.editable = true
		m = Gtk::ListStore.new(String)
    iter = m.append
    iter[0] = 'refdes'
    iter = m.append
    iter[0] = 'footprint'
		r.model = m
		r.text_column = 0
    r.signal_connect('edited') do |w, path, new_text|
			iter = @store.get_iter(path)
			if iter[Col_Text] != new_text
				iter[Col_Text] = new_text
      end
    end
    c = Gtk::TreeViewColumn.new('', r, "text" => Col_Name)
		c.widget = gen_ttl('Name', 'Attribute Name')
    tv.append_column(c)








		@store = Gtk::ListStore.new(Integer, TrueClass, String, TrueClass, String, Integer, Integer, Integer, Integer, Integer, Integer)
		@row_inserted_handler_id = @store.signal_connect("row_inserted"){|tree_model, path, iter|
			if @obj
				@obj.add_empty_attribute
			end
		}
		@row_changed_handler_id = @store.signal_connect("row_changed"){|tree_model, path, iter|
		puts 'row_changed'
			if @obj
				puts "obj"
				a = Pet::Attr_Msg.new
				a.id = 0
				a.name_visible = iter[Col_Name_Vis]
				a.name = iter[Col_Name]
				a.value_visible = iter[Col_Value_Vis]
				a.value = iter[Col_Value]
				a.x = iter[Col_X]
				a.y = iter[Col_Y]
				a.color = iter[Col_Color]
				a.size = iter[Col_Size]
				a.angle = iter[Col_Angle]
				a.alignment = iter[Col_Alignment]
				@obj.full_set_attributes(a, path.indices[0])
				@parent_notebook.main_window.redraw_not_all(@obj) # TODO: we call it twice to ensure correct bounding box
				#@parent_notebook.main_window.redraw_not_all(@obj) # we may find a better fix to set text bbox 
			end
		}
		@row_deleted_handler_id = @store.signal_connect("row_deleted"){|tree_model, path|
		puts 'row_deleted'
if @obj

		puts 'obj row_deleted'
#@store.signal_handler_block(@row_changed_handler_id)

				@obj.xrem_attribute(path.indices[0])
				@parent_notebook.main_window.redraw_not_all(@obj) # TODO: we call it twice to ensure correct bounding box
				#@parent_notebook.main_window.redraw_not_all(@obj) # we may find a better fix to set text bbox 

#		puts 'deeleted'
#@store.signal_handler_unblock(@row_changed_handler_id)
end
		}
    tv.model = @store
		self.pack_start(tv, :expand => false, :fill => false, :padding => 0)
	end

	def update_attributes
		@store.signal_handler_block(@row_inserted_handler_id)
		@store.signal_handler_block(@row_changed_handler_id)
@store.signal_handler_block(@row_deleted_handler_id)
		@store.clear
		if @obj && @obj.respond_to?(:get_attributes)
			@obj.get_attributes{|el|
  	  	iter = @store.append
				iter[Col_ID] = el.id
				iter[Col_Name_Vis] = el.name_visible
				iter[Col_Name] = el.name
				iter[Col_Value_Vis] = el.value_visible
				if el.value[-1] == "\n" then el.value[-1] = '' end
				iter[Col_Value] = el.value
				iter[Col_X] = el.x
				iter[Col_Y] = el.y
				iter[Col_Color] = el.color
				iter[Col_Size] = el.size
				iter[Col_Angle] = el.angle
				iter[Col_Alignment] = el.alignment
			if el.show_details
			@tree_view.selection.select_iter(iter)

			s = @tree_view.selection.selected
			@attr_details_box.set(s[Col_X], s[Col_Y], s[Col_Size], s[Col_Angle], s[Col_Color], s[Col_Alignment])
			end
			}
			@store.signal_handler_unblock(@row_inserted_handler_id)
			@store.signal_handler_unblock(@row_changed_handler_id)
@store.signal_handler_unblock(@row_deleted_handler_id)

		end
	end
end

class Box_Widget < Obj_Property_Widget
	Sym = Pet::Box
	attr_accessor :obj_class

	def initialize(parent_notebook)
		super(parent_notebook)
		@obj_class = Pet::Box
		@x = attach_spin_button_grid_sensitive('x', 'x')
		@y = attach_spin_button_grid_sensitive('y', 'y')
		@width = attach_spin_button_grid_sensitive('Width', 'width')
		@height = attach_spin_button_grid_sensitive('Height', 'height')
		@linewidth = attach_spin_button('Line Width', 'linewidth', 0, 100, 1, 'Line Width')
		@capstyle = attach_combobox_cap('Cap Style', 'capstyle')
		attach_color_box('Color', 'color')
		attach_attributes
	end

	def update_object_from_widget_smart(ivar_name, value)
		if @obj
			@obj.instance_variable_set("@#{ivar_name}", value)
			@parent_notebook.main_window.redraw_not_all(@obj)
		end
	end

	def update_widget_from_object(obj)
		@obj = obj
		if obj
			@x.value = obj.x
			@y.value = obj.y
			@width.value = obj.width
			@height.value = obj.height
			@linewidth.value = obj.linewidth
			@capstyle.active = obj.capstyle
		end
	end

end

class Sym_Widget < Obj_Property_Widget
	Sym = Pet::Sym
	attr_accessor :obj_class

	def initialize(parent_notebook)
		super(parent_notebook)
		self.margin = 4
		@obj_class = Pet::Sym
		@name = attach_symname_button('x', 'x')
		@x = attach_spin_button_grid_sensitive('x', 'x')
		@y = attach_spin_button_grid_sensitive('y', 'y')
		@angle = attach_spin_button_angle('Orientation', 'angle', 0, 360, 1, 'Angle')
		attach_attributes
		attach_attr_details(@tree_view)
		attach_attr_add
		attach_attr_add2
		attach_attr_add3
	end

	def update_object_from_widget_smart(ivar_name, value)
		if @obj
			if ivar_name == 'x'
				@obj.translate(value - @obj.x, 0)
			elsif ivar_name == 'y'
				@obj.translate(0, value - @obj.y)
			elsif ivar_name == 'angle'
				@obj.rotate(@obj.x, @obj.y, value - @obj.angle)
			else
				puts ivar_name, value
				@obj.instance_variable_set("@#{ivar_name}", value)
			end
				@parent_notebook.main_window.redraw_not_all(@obj)
		end
	end

	def update_widget_from_object(obj)
		@obj = obj
		@obj_delete_button.sensitive = !!obj
		if obj
			@x.value = obj.x
			@y.value = obj.y
			@name.label = obj.basename
			self.update_attributes
		end
	end

	def update_widget_xy_from_object(obj)
		@obj = obj
		if obj

		@x.signal_handler_block(@x.lock)
		@y.signal_handler_block(@y.lock)

			@x.value = obj.x
			@y.value = obj.y
		@x.signal_handler_unblock(@x.lock)
		@y.signal_handler_unblock(@y.lock)

			#@name.label = obj.basename
			self.update_attributes
		end
	end




end



class Pin_Widget < Obj_Property_Widget
	Sym = Pet::Pin

	attr_accessor :obj_class

	def initialize(parent_notebook)
		super(parent_notebook)
		@obj_class = Pet::Pin
		@x1 = attach_spin_button_grid_sensitive('x1', 'x1')
		@y1 = attach_spin_button_grid_sensitive('y1', 'y1')
		@x2 = attach_spin_button_grid_sensitive('x2', 'x2')
		@y2 = attach_spin_button_grid_sensitive('y2', 'y2')
		@gen_number = attach_spin_button('N++', 'gen_number', 0, 1024, 1, 'Incrementing pin generation number')
		@gen_number.value = 1
		@color = attach_color_box('Color', 'color')
		@color.active = Pet_Config::Colorindex_geda_pin
		attach_attributes
		attach_attr_details(@tree_view)
		attach_attr_add
		attach_attr_add2
		attach_attr_add3
	end

	def update_object_from_widget_smart(ivar_name, value)
		if @obj
		puts 'update_object_from_widget_smart'
			@obj.instance_variable_set("@#{ivar_name}", value)
			@parent_notebook.main_window.redraw_not_all(@obj)
		end
	end


	def init_object_from_widget(obj)
		obj.color = @color.active
		obj.gen_num = @gen_number.value.round
		@gen_number.value = obj.gen_num + 1
	end

#TODO: lock the handlers --currently  update_object_from_widget_smart is called!
	def update_widget_from_object(obj)
		@obj = obj
		if obj
			@x1.set_value_silent(obj.x1)
			@y1.set_value_silent(obj.y1)
			@x2.set_value_silent(obj.x2)
			@y2.set_value_silent(obj.y2)
			@color.set_active_silent(obj.color)
			self.update_attributes
		end
	end

	def update_widget_xy_from_object(obj)
		@obj = obj
		if obj
			@x1.signal_handler_block(@x1.lock)
			@y1.signal_handler_block(@y1.lock)
			@x2.signal_handler_block(@x2.lock)
			@y2.signal_handler_block(@y2.lock)
			@x1.value = obj.x1
			@y1.value = obj.y1
			@x2.value = obj.x2
			@y2.value = obj.y2
			@x1.signal_handler_unblock(@x1.lock)
			@y1.signal_handler_unblock(@y1.lock)
			@x2.signal_handler_unblock(@x2.lock)
			@y2.signal_handler_unblock(@y2.lock)
			self.update_attributes

		end
	end
end


class Net_Widget < Obj_Property_Widget
	Sym = Pet::NetSegment

	attr_accessor :obj_class

	def initialize(parent_notebook)
		super(parent_notebook)
		@obj_class = Pet::NetSegment
		@x1 = attach_spin_button_grid_sensitive('x1', 'x1')
		@y1 = attach_spin_button_grid_sensitive('y1', 'y1')
		@x2 = attach_spin_button_grid_sensitive('x2', 'x2')
		@y2 = attach_spin_button_grid_sensitive('y2', 'y2')
		@color = attach_color_box('Color', 'color')
		@color.active = Pet_Config::Colorindex_geda_net
		attach_attributes
		attach_attr_details(@tree_view)
		attach_attr_add
		attach_attr_add2
		attach_attr_add3
	end

	def update_object_from_widget_smart(ivar_name, value)
		if @obj
		puts 'update_object_from_widget_smart'
			@obj.instance_variable_set("@#{ivar_name}", value)
			@parent_notebook.main_window.redraw_not_all(@obj)
		end
	end


	def init_object_from_widget(obj)
		obj.color = @color.active
	end

#TODO: lock the handlers --currently  update_object_from_widget_smart is called!
	def update_widget_from_object(obj)
		@obj = obj
		if obj
			#@x1.value = obj.x1 #- obj.origin_x
			@x1.set_value_silent(obj.x1)
			@y1.set_value_silent(obj.y1)
			@x2.set_value_silent(obj.x2)
			@y2.set_value_silent(obj.y2)
			#@y1.value = obj.y1 #- obj.origin_y
			#@x2.value = obj.x2 #- obj.origin_x
			#@y2.value = obj.y2 #- obj.origin_y
			#@color.active_id = obj.color.to_s
			#@color.active = obj.color
			@color.set_active_silent(obj.color)
			self.update_attributes
		end
	end

	def update_widget_xy_from_object(obj)
		@obj = obj
		if obj
			@x1.signal_handler_block(@x1.lock)
			@y1.signal_handler_block(@y1.lock)
			@x2.signal_handler_block(@x2.lock)
			@y2.signal_handler_block(@y2.lock)
			@x1.value = obj.x1
			@y1.value = obj.y1
			@x2.value = obj.x2
			@y2.value = obj.y2
			@x1.signal_handler_unblock(@x1.lock)
			@y1.signal_handler_unblock(@y1.lock)
			@x2.signal_handler_unblock(@x2.lock)
			@y2.signal_handler_unblock(@y2.lock)
			self.update_attributes

		end
	end
end





class Path_Widget < Obj_Property_Widget
	Sym = Pet::Path

	attr_accessor :obj_class

	def initialize(parent_notebook)
		super(parent_notebook)
		@obj_class = Pet::Path
		#@x1 = attach_spin_button_grid_sensitive('x1', 'x1')
		#@y1 = attach_spin_button_grid_sensitive('y1', 'y1')
		#@x2 = attach_spin_button_grid_sensitive('x2', 'x2')
		#@y2 = attach_spin_button_grid_sensitive('y2', 'y2')
		@color = attach_color_box('Color', 'color')
		@color.active = Pet_Config::Colorindex_geda_net
		@linewidth = attach_spin_button('Line Width', 'linewidth', 0, 100, 1, 'Line Width')
		@capstyle = attach_combobox_cap('Cap Style', 'capstyle')
		attach_attributes
		attach_attr_details(@tree_view)
		attach_attr_add
		attach_attr_add2
		attach_attr_add3
	end

	def update_object_from_widget_smart(ivar_name, value)
		if @obj
		puts 'update_object_from_widget_smart'
			@obj.instance_variable_set("@#{ivar_name}", value)
			@parent_notebook.main_window.redraw_not_all(@obj)
		end
	end


	def init_object_from_widget(obj)
		obj.color = @color.active
	end

#TODO: lock the handlers --currently  update_object_from_widget_smart is called!
	def update_widget_from_object(obj)
		@obj = obj
		if obj
			#@x1.set_value_silent(obj.x1)
			#@y1.set_value_silent(obj.y1)
			#@x2.set_value_silent(obj.x2)
			#@y2.set_value_silent(obj.y2)
			@color.set_active_silent(obj.color)
			self.update_attributes
		end
	end

	def update_widget_xy_from_object(obj)
		@obj = obj
		if obj
			#@x1.signal_handler_block(@x1.lock)
			#@y1.signal_handler_block(@y1.lock)
			#@x2.signal_handler_block(@x2.lock)
			#@y2.signal_handler_block(@y2.lock)
			#@x1.value = obj.x1
			#@y1.value = obj.y1
			#@x2.value = obj.x2
			#@y2.value = obj.y2
			#@x1.signal_handler_unblock(@x1.lock)
			#@y1.signal_handler_unblock(@y1.lock)
			#@x2.signal_handler_unblock(@x2.lock)
			#@y2.signal_handler_unblock(@y2.lock)
			#self.update_attributes

		end
	end
end





end

