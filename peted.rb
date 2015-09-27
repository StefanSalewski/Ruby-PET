module PetEd

require 'gtk3'
require 'gio2'
require 'cairo'
require 'pango'
require 'optparse'
require_relative 'pet'
require_relative 'pet_canvas'
require_relative 'pet_attr'
require_relative 'pet_prop'
require_relative 'pet_conf_ed'
require_relative 'pet_log'
require_relative 'pet_def'

SCSTOP = true

# add close button and check button for viewing attribute list
class PetedNotebookWidget < Gtk::Notebook
	def initialize(toolbar_top)
	  super()
		@toolbar_top = toolbar_top
	end

	def append_page(child, name)
		tab = Gtk::Box.new(:horizontal, 0)
		l = Gtk::Label.new(File.basename(name))
		l.tooltip_text = name
		###c = Gtk::CheckButton.new # for attributes view, currently unused 
		###c.focus_on_click = false
		###c.tooltip_text = 'Attribute View'
		b = Gtk::Button.new
		b.tooltip_text = 'Close'
		b.signal_connect('clicked'){
			self.remove_page(self.page)
			self.toplevel.destroy if self.page == -1
		}
		b.focus_on_click = false
		b.relief = Gtk::ReliefStyle::NONE
		# from gedit-close-button.c 3.10 (image and CSS code)
		icon = Gio::ThemedIcon.new("window-close-symbolic")
		b.always_show_image = true
		b.set_image(Gtk::Image.new(:gicon => icon, :size => Gtk::IconSize::MENU))
		provider = Gtk::CssProvider.new
		provider.load(:data => ' * {
			-GtkButton-default-border : 0;
			-GtkButton-default-outside-border : 0;
			-GtkButton-inner-border : 0;
			-GtkWidget-focus-line-width : 0;
			-GtkWidget-focus-padding : 0;
			padding : 0;
		}')
		b.style_context.add_provider(provider, GLib::MAXUINT) # minimal borders
		###c.style_context.add_provider(provider, GLib::MAXUINT)
		tab.pack_start(l, :expand => false, :fill => false, :padding => 4)
		###tab.pack_start(c, :expand => false, :fill => false, :padding => 0)
		tab.pack_start(b, :expand => false, :fill => false, :padding => 0)
		tab.show_all
		super(child, tab)
	end

	def update_label(child, name)
		if w = self.get_tab_label(child).children.find{|x| x.class == Gtk::Label}
			w.text = File.basename(name)
			w.tooltip_text = name
		end
	end

	def get_labeltext(child)
		if w = self.get_tab_label(child).children.find{|x| x.class == Gtk::Label}
			w.text
		else
			''
		end
	end
end # PetedNotebookWidget


# NOTE: Gtk::Stock.lookup is deprecated for GTK 3.10
# So we should fix this.
# Maybe plain text menu's with custom accelerators?
# Later we may use GMenu.

MenuWindowName = '<PetedMainWindow>'
#class PetedMenuItemStock < Gtk::ImageMenuItem
#	def initialize(menu, item, id)
#		super(:label => nil, :mnemonic => nil, :stock_id => id, :accel_group => nil)
#		self.accel_path = MenuWindowName + '/' + menu + '/' + item
#		self.always_show_image = true
#		modifier, keyval = Gtk::Stock.lookup(id)[2, 2]
#		Gtk::AccelMap.add_entry(self.accel_path, keyval, modifier)
#	end
#end

class PetedMenuItemText < Gtk::ImageMenuItem
	def initialize(menu, itemtext, keyval = nil, modifier = nil)
	#super(:label => itemtext, :mnemonic => nil, :stock_id => nil, :accel_group => nil)
	super(:label => itemtext, :mnemonic => nil, :accel_group => nil)
		self.accel_path = MenuWindowName + '/' + menu + '/' + itemtext
		if keyval and modifier
		  Gtk::AccelMap.add_entry(self.accel_path, keyval, modifier)
		end
	end
end

class PetedMenuBar < Gtk::MenuBar
	def initialize(group, main_window, menu_hint_status_bar)
		super()
		@bar = menu_hint_status_bar
		@id = menu_hint_status_bar.get_context_id('Peted_Menu_Hint')
		title = 'File'
		filemenu = Gtk::Menu.new
		filemenu.set_accel_group(group)
		filemenu.set_accel_path(MenuWindowName + '/' + title + '/')
		file = Gtk::MenuItem.new(title)
		file.submenu = filemenu
		self.append(file)

		name = 'New'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::NEW)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_n, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.open_schematics([''])}
		set_menu_hint(i, 'Create a new sheet')
		filemenu.append(i)

		name = 'Open...'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::OPEN)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_o, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.open_schematics(nil)}
		set_menu_hint(i, 'Open a schematic')
		filemenu.append(i)

		i = Gtk::ImageMenuItem.new
		filemenu.append(i)

		name = 'Save'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::SAVE)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_s, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.save_schematic(false)}
		set_menu_hint(i, 'Save the current schematic')
		filemenu.append(i)

		name = 'Save As...'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::SAVE_AS)
		i = PetedMenuItemText.new(title, name)#, Gdk::Keyval::KEY_a, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.save_schematic(true)}
		set_menu_hint(i, 'Save the current schematic with a different name')
		filemenu.append(i)

		i = Gtk::ImageMenuItem.new
		filemenu.append(i)

		name = 'Close'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::CLOSE)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_c, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.close_schematic}
		set_menu_hint(i, 'Close the current sheet')
		filemenu.append(i)

		name = 'Quit'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::QUIT)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_q, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.destroy}
		set_menu_hint(i, 'Quit the program')
		filemenu.append(i)

		title = 'Edit'
		editmenu = Gtk::Menu.new
		editmenu.set_accel_group(group)
		editmenu.set_accel_path(MenuWindowName + '/' + title + '/')
		edit = Gtk::MenuItem.new(title)
		edit.submenu = editmenu
		self.append(edit)

		name = 'Undo'
		#i = PetedMenuItemStock.new(title, name, Gtk::Stock::UNDO)
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_u, Gdk::ModifierType::SHIFT_MASK)
		i.sensitive = false
		i.signal_connect('activate') {|w| puts title + name + ' selected'}
		set_menu_hint(i, 'Undo the last action')
		editmenu.append(i)

		title = 'Symbol'
		symmenu = Gtk::Menu.new
		symmenu.set_accel_group(group)
		symmenu.set_accel_path(MenuWindowName + '/' + title + '/')
		sym = Gtk::MenuItem.new(title)
		sym.submenu = symmenu
		self.append(sym)

		name = 'Add...'
		i = PetedMenuItemText.new(title, name, Gdk::Keyval::KEY_a, Gdk::ModifierType::SHIFT_MASK)
		i.signal_connect('activate') {|w| main_window.add_symbol}
		set_menu_hint(i, 'Add a symbol')
		symmenu.append(i)

		name = 'Create'
		i = PetedMenuItemText.new(title, name)
		i.signal_connect('activate') {|w| main_window.create_symbol}
		set_menu_hint(i, 'Group elements to new symbol')
		symmenu.append(i)

		name = 'Save...'
		i = PetedMenuItemText.new(title, name)
		i.signal_connect('activate') {|w| main_window.save_symbol(false)}
		set_menu_hint(i, 'Save symbol')
		symmenu.append(i)

		name = 'Explode'
		i = PetedMenuItemText.new(title, name)
		#i.signal_connect('activate') {|w| main_window.explode_symbol()}
		set_menu_hint(i, 'Release components')
		symmenu.append(i)

		name = '(Un)Embed'
		i = PetedMenuItemText.new(title, name)
		#i.signal_connect('activate') {|w| main_window.embed_symbol()}
		set_menu_hint(i, 'Embed or unembed symbol')
		symmenu.append(i)

	end
	
	def set_menu_hint(item, text)
		item.signal_connect('enter_notify_event') {|w, e| @bar.push(@id, text); false}
		item.signal_connect('leave_notify_event') {|w, e| @bar.pop(@id); false}
	end
end

class GridSelectBox < Gtk::ComboBoxText
	PAT = /^\s*\d{1,3}\s*$/
	def initialize(radio_button, grid, major)
		super(:entry => true)
		@major = major
		@adds = 0
		self.child.width_chars = 5
		self.tooltip_text = (@major ? 'Major grid' : 'Minor grid')
		default = grid[-1]
		@s = grid.uniq.sort
		default = @s.index(default)
		@s.map!{|el| el.to_s}
		@s.each{|g| self.append_text(g)}
		self.active = default
		self.child.signal_connect('populate_popup'){|w, menu|
			t = w.text
			item = Gtk::MenuItem.new
			item.show
			menu.append(item)
			item = Gtk::MenuItem.new('_Add to List')
			item.show
			item.signal_connect('activate'){|i|
				if i.sensitive? # should be true always -- see below
					self.prepend_text(t)
					@s << t
					@adds += 1
				end
			}
			menu.append(item)
			item.sensitive = (w.text_length > 0) && PAT.match(t) && !@s.include?(t)
			item = Gtk::MenuItem.new('_Remove Top')
			item.show
			item.signal_connect('activate'){|i|
				if @adds > 0
					self.remove(0)
					@s.pop
					@adds -= 1
				end
			}
			menu.append(item)
			item.sensitive = (@adds > 0)
		}
		self.child.signal_connect('activate'){|w|
			if @pda
				if PAT.match(w.text)
					i = w.text.to_i
					if i != (@major ? @pda.schem.major_grid : @pda.schem.minor_grid)
						if @major then @pda.schem.major_grid = i else @pda.schem.minor_grid = i end
						@pda.schem.active_grid = i if radio_button.active?
						@pda.redraw
					end
				else
					w.text = (@major ? @pda.schem.major_grid : @pda.schem.minor_grid).to_s
				end
			end
		}
		@changed_handler_id = self.signal_connect('changed') {|w|
			if @pda
				if w.active != -1
					i = w.active_text.to_i
					if i != (@major ? @pda.schem.major_grid : @pda.schem.minor_grid)
						if @major then @pda.schem.major_grid = i else @pda.schem.minor_grid = i end
						@pda.schem.active_grid = i if radio_button.active?
						@pda.redraw
					end
				end
			end
		}
	end

	def switch(pda)
		if self.sensitive = !!(@pda = pda) # maybe always sensitive
			self.signal_handler_block(@changed_handler_id)
			self.child.text = (@major ? @pda.schem.major_grid : @pda.schem.minor_grid).to_s
			self.signal_handler_unblock(@changed_handler_id)
		end
	end
end

Zoom_Factor = 0.9
Enlarge_Factor = 0.1
class PetToolbar < Gtk::Toolbar
	attr_accessor :entry, :text_obj, :zoom_out_button
	def initialize(main_window, conf)
		super()
		@S1 = nil # only for startup, later we have at least one active shematic, so @S1 is never nil
		@open_button = Gtk::ToolButton.new
		@open_button.set_icon_name('document-open')
		@open_button.signal_connect('clicked') {main_window.open_schematics(nil)}
		@open_button.tooltip_text = 'Open a sheet'

		@save_button = Gtk::ToolButton.new
		@save_button.set_icon_name('document-save')
		@save_button.signal_connect('clicked') {main_window.save_schematic(false)}
		@save_button.tooltip_text = 'Save the current sheet'

		@zoom_in_button = Gtk::ToolButton.new
		@zoom_in_button.set_icon_name('zoom-in')
		@zoom_in_button.signal_connect('clicked') {@S1.pda.zoom(1 / Zoom_Factor); @zoom_out_button.sensitive = true}
		@zoom_in_button.tooltip_text = 'Zoom in'

		@zoom_out_button = Gtk::ToolButton.new
		@zoom_out_button.set_icon_name('zoom-out')
		@zoom_out_button.signal_connect('clicked') {|w| @S1.pda.zoom(Zoom_Factor); w.sensitive = @S1.pda.user_zoom > 1}
		@zoom_out_button.tooltip_text = 'Zoom out'

		@zoom_best_fit_button = Gtk::ToolButton.new
		@zoom_best_fit_button.set_icon_name('zoom-fit-best')
		@zoom_best_fit_button.signal_connect('clicked') {@S1.pda.user_zoom = 1; @S1.enlarge(Enlarge_Factor); @zoom_out_button.sensitive = false}
		@zoom_best_fit_button.tooltip_text = '[ Sheet ]'

		@zoom_original_button = Gtk::ToolButton.new
		@zoom_original_button.set_icon_name('zoom-original')
		@zoom_original_button.signal_connect('clicked') {@S1.zoom_original; @S1.pda.user_zoom = 1; @S1.pda.darea_new_box; @zoom_out_button.sensitive = false}
		@zoom_original_button.tooltip_text = 'Zoom 100 %'

		@grid_snap = Gtk::ToggleButton.new(:label => '->|')
		@grid_snap.signal_connect('toggled') {|w| @S1.grid_snap = w.active?}
		@grid_snap.tooltip_text = 'Snap to grid'

		@major_grid_select = Gtk::RadioButton.new # Gtk::RadioToolButton.new seems not to work, no icon!
		@major_grid_select.signal_connect('toggled') {|w| @S1.active_grid = (w.active? ? @S1.major_grid : @S1.minor_grid)}
		@minor_grid_select = Gtk::RadioButton.new(:member => @major_grid_select)

		@combo_box_major_grid = GridSelectBox.new(@major_grid_select, Def::Major_Grid << conf.get_conf(Pet_Config::SCR_S)[:grid_size_major], true)
		@combo_box_minor_grid = GridSelectBox.new(@minor_grid_select, Def::Minor_Grid << conf.get_conf(Pet_Config::SCR_S)[:grid_size_minor], false)

		@combo_box_mode = Gtk::ComboBoxText.new
		Input_Mode.constants.each{|c| @combo_box_mode.append_text(c.to_s)}
 		@combo_box_mode.active = Input_Mode::default
		@combo_box_mode.signal_connect('changed') {|w, event| @S1.set_input_mode(w.active_text); @S1.prop_box.set_page_from_name(w.active_text)}

		@entry = Gtk::Entry.new
		@entry.signal_connect_after('event_after') {|w, e|
			cu = -2
			if e.event_type == Gdk::EventType::FOCUS_CHANGE && !@entry.focus?
				cu = -1
			elsif e.event_type == Gdk::EventType::KEY_RELEASE && e.keyval == Gdk::Keyval::KEY_Return
				cu = -1
			elsif e.event_type == Gdk::EventType::KEY_RELEASE
				cu = @entry.cursor_position
			end
			if 	cu > -2 && @text_obj # TODO: what when it is deleted?
				@text_obj.set_text(@entry.text, cu)
				main_window.redraw_not_all(@text_obj)
			end
			false
		}

		self.insert(@open_button, -1)
		self.insert(@save_button, -1)
		self.insert(@zoom_out_button, -1)
		self.insert(@zoom_in_button, -1)
		self.insert(@zoom_original_button, -1)
		self.insert(@zoom_best_fit_button, -1)
		@entry_item = Gtk::ToolItem.new
		@entry_item.add(@entry)
		self.insert(@entry_item, -1)
		@modes_item = Gtk::ToolItem.new
		@modes_item.add(@combo_box_mode)
		self.insert(@modes_item, -1)


		@major_grid_select_item = Gtk::ToolItem.new
		@major_grid_select_item.add(@major_grid_select)
		self.insert(@major_grid_select_item, -1)


		@major_grid_item = Gtk::ToolItem.new
		@major_grid_item.add(@combo_box_major_grid)
		self.insert(@major_grid_item, -1)


		@minor_grid_select_item = Gtk::ToolItem.new
		@minor_grid_select_item.add(@minor_grid_select)
		self.insert(@minor_grid_select_item, -1)

		@minor_grid_item = Gtk::ToolItem.new
		@minor_grid_item.add(@combo_box_minor_grid)
		self.insert(@minor_grid_item, -1)




		@grid_snap_item = Gtk::ToolItem.new
		@grid_snap_item.add(@grid_snap)
		self.insert(@grid_snap_item, -1)
	end

	# this is called when first sheet is added to notebook, so @S1 is never nil
	def switch(pda)
		fail unless pda
		@pda = pda
		@S1 = @pda.schem
		@combo_box_major_grid.switch(pda)
		@combo_box_minor_grid.switch(pda)
		if @pda.schem.major_grid == @pda.schem.active_grid
			@major_grid_select.active = true
		else
			@minor_grid_select.active = true
		end
		@zoom_out_button.sensitive = @S1.pda.user_zoom > 1
	end

	def init_grid(pda)
		pda.schem.major_grid = @combo_box_major_grid.child.text.to_i
		pda.schem.minor_grid = @combo_box_minor_grid.child.text.to_i
		pda.schem.active_grid = (@major_grid_select.active? ? pda.schem.major_grid : pda.schem.minor_grid)
	end
end

COB = [['_Cancel', Gtk::ResponseType::CANCEL], ['_Open', Gtk::ResponseType::ACCEPT]]
CSB = [['_Cancel', Gtk::ResponseType::CANCEL], ['_Save', Gtk::ResponseType::ACCEPT]]
class Main_Window < Gtk::Window
	attr_accessor :prop_box, :toolbar_top
	def initialize
		super
		#@grid_sensitive_spin_button_list = Array.new # for what is this?
		self.title = 'PetEd'
		self.set_size_request(800, 600)
		self.signal_connect('destroy') {Gtk.main_quit}
		@conf = Pet_Config::get_default_config
		@conf.main_window = self
		group = Gtk::AccelGroup.new
		@statusbar1 = Gtk::Statusbar.new
		@statusbar1.set_size_request(200, -1)
		@statusbar2 = Gtk::Statusbar.new
		@statusbar2.set_size_request(400, -1)
		@msg2_id = @statusbar2.get_context_id('Msg2ID')
		@status_box = Gtk::Box.new(:horizontal, 0)
		@status_box.homogeneous = true
		@status_box.pack_start(@statusbar1, :expand => true, :fill => true, :padding => 0)
		@status_box.pack_end(@statusbar2, :expand => true, :fill => true, :padding => 0)
		@attr_box = Pet_Attr::Attr_Win.new
		@prop_box = Property_Display::Properties_Widget.new(self)
		@prop_box_scr = Gtk::ScrolledWindow.new
		@prop_box_scr.add(@prop_box)
		@cnb = Pet_Conf_Ed::Config_Notebook.new(@conf)
		@notebook = Gtk::Notebook.new
		@notebook.append_page(@prop_box_scr, Gtk::Label.new('Properties'))
		@notebook.append_page(@cnb, Gtk::Label.new('Conf'))
		@menubar = PetedMenuBar.new(group, self, @statusbar1)
		@toolbar_top = PetToolbar.new(self, @conf)
		@logview = Log::Log_View.new(Gtk::PolicyType::ALWAYS, Gtk::PolicyType::ALWAYS)
		@logview.set_size_request(-1, 100)
		@schematics = PetedNotebookWidget.new(@toolbar_top)
		@schematics.signal_connect('switch-page') do |w, page, page_num|
				child = w.get_nth_page(page_num)
				fail unless child == page
				@toolbar_top.switch(child)
		end
		@vpaned = Gtk::Paned.new(:vertical)
		@vpaned.pack1(@schematics, :resize => true, :shrink => true)
		@vpaned.pack2(@logview, :resize => false, :shrink => true)
		@hpaned = Gtk::Paned.new(:horizontal)
		@hpaned.pack1(@notebook, :resize => false, :shrink => true)
		@hpaned.pack2(@vpaned, :resize => true, :shrink => true)
		#@hpaned.position = 300
		@vbox = Gtk::Box.new(:vertical, 0)
		@vbox.pack_start(@menubar, :expand => false, :fill => false, :padding => 0)
		@vbox.pack_start(@toolbar_top, :expand => false, :fill => false, :padding => 0)
		@vbox.pack_start(@hpaned, :expand => true, :fill => true, :padding => 0)
		@vbox.pack_start(@status_box, :expand => false, :fill => false, :padding => 0)
		self.add(@vbox)
		self.add_accel_group(group)
		self.show_all
	end

def set_increments(i, j)
# TODO: check, why is grid_sensitive_spin_button_list not available?
#@prop_box.grid_sensitive_spin_button_list.each{|w| w.set_increments(i, j)}
end

	def activate_entry(obj)
		@toolbar_top.text_obj = obj
		@toolbar_top.entry.text = obj.get_text
		@toolbar_top.entry.grab_focus
		return @toolbar_top.entry.cursor_position
	end

  def refresh_all
		i = 0
		while page = @schematics.get_nth_page(i)
			page.redraw
			i += 1
		end
	end

	def push_msg(text)
		@statusbar2.push(@msg2_id, text)
	end

	def pop_msg
		@statusbar2.pop(@msg2_id)
	end

	def run_schematics_open_dialog
		dialog = Gtk::FileChooserDialog.new(:title => 'Open Files', :parent => self, :action => Gtk::FileChooserAction::OPEN, :buttons => COB)
		[['Schematics', '*.sch'], ['All Files', '*']].each{|n, p|
			filter = Gtk::FileFilter.new
			filter.name = n
			filter.add_pattern(p)
			dialog.add_filter(filter)
		}
		###dialog.select_multiple = true
		names = nil
		if dialog.run == Gtk::ResponseType::ACCEPT
			names = [dialog.filename]
		end
		dialog.destroy
		names
	end

	def run_schematic_save_dialog(name)
		dialog = Gtk::FileChooserDialog.new(:title => 'Save Schematic', :parent => self, :action => Gtk::FileChooserAction::SAVE, :buttons => CSB)
		[['Schematics', '*.sch'], ['All Files', '*']].each{|n, p|
			filter = Gtk::FileFilter.new
			filter.name = n
			filter.add_pattern(p)
			dialog.add_filter(filter)
		}
		dialog.filename = name
		if dialog.run == Gtk::ResponseType::ACCEPT
			name = dialog.filename
		else
			name = nil
		end
		dialog.destroy
		name
	end

	def run_symbol_save_dialog(name)
		dialog = Gtk::FileChooserDialog.new(:title => 'Save Symbol', :parent => self, :action => Gtk::FileChooserAction::SAVE, :buttons => CSB)
		[['Symbols', '*.sym'], ['All Files', '*']].each{|n, p|
			filter = Gtk::FileFilter.new
			filter.name = n
			filter.add_pattern(p)
			dialog.add_filter(filter)
		}
		dialog.filename = name
		if dialog.run == Gtk::ResponseType::ACCEPT
			name = dialog.filename
		else
			name = nil
		end
#		dialog.run do |response|
#			if response == Gtk::ResponseType::ACCEPT
#				name = dialog.filename
#			else
#				name = nil
#			end
#		end
		dialog.destroy
		name
	end

	def run_add_symbol_dialog
		dialog = Gtk::FileChooserDialog.new(:title => 'Select Symbol', :parent => self, :action => Gtk::FileChooserAction::OPEN, :buttons => COB)
		[['Symbols', '*.sym'], ['All Files', '*']].each{|n, p|
			filter = Gtk::FileFilter.new
			filter.name = n
			filter.add_pattern(p)
			dialog.add_filter(filter)
		}
		dialog.current_folder	= '/usr/share/gEDA/sym'
		if dialog.run == Gtk::ResponseType::ACCEPT
			name = dialog.filename
		else
			name = nil
		end
		dialog.destroy
		name
	end

  Unnamed = 'Unsaved Document'
	UNAME_PAT = Regexp.new(Unnamed + '\s*(\d+)\s*$')
	def open_schematics(names)
		names ||= run_schematics_open_dialog
		return unless names
		names.each{|n|
			s = Pet::Schem.new
			pda = Pet_Canvas::PDA.new(s)
			s.pda = pda
			s.set_dialog_widget(@attr_box, @prop_box)
			s.init_popup_menu
			unless n.empty?
				if File.exist?(n)
					if s.ProcessInputFile(n) # method will log failure
						Log::puts("Read file #{n}")
					end
				else
					Log::puts("File #{n} does not exist -- using new sheet")
				end
			end
			s.filename = n
			s.main_window = self
			pda.darea.add_events(Gdk::EventMask::BUTTON_PRESS_MASK | Gdk::EventMask::BUTTON_RELEASE_MASK | Gdk::EventMask::SCROLL_MASK |
				Gdk::EventMask::BUTTON1_MOTION_MASK | Gdk::EventMask::BUTTON2_MOTION_MASK | Gdk::EventMask::POINTER_MOTION_HINT_MASK|
				Gdk::EventMask::POINTER_MOTION_MASK | Gdk::EventMask::KEY_PRESS_MASK | Gdk::EventMask::ENTER_NOTIFY_MASK | Gdk::EventMask::LEAVE_NOTIFY_MASK)
			pda.darea.signal_connect('scroll-event')  			 {|w, e| distribute_events(pda, e); SCSTOP}
			pda.darea.signal_connect('motion-notify-event')  {|w, e| distribute_events(pda, e); SCSTOP}
			pda.darea.signal_connect('button_press_event')   {|w, e| distribute_events(pda, e); SCSTOP}
			pda.darea.signal_connect('button_release_event') {|w, e| distribute_events(pda, e); SCSTOP}
			pda.darea.signal_connect('key_press_event')      {|w, e| distribute_events(pda, e); SCSTOP}
			pda.darea.signal_connect('enter-notify-event')   {|w, e| pda.window.cursor = pda.cursor; SCSTOP}
			pda.darea.signal_connect('leave-notify-event')   {|w, e| pda.window.cursor = nil; SCSTOP}
			pda.darea.can_focus = true
			@toolbar_top.init_grid(pda)
			pda.show_all
			if n.empty?
			  busy = [0]
				i = 0
				while page = @schematics.get_nth_page(i)
					t = @schematics.get_labeltext(page)
					if m = UNAME_PAT.match(t)
					  busy << m[1].to_i
					end
					i += 1
				end
				busy.sort!
				busy << 1e4.to_i
				i = 0
				until i < busy[i]; i += 1; end
				n = "#{Unnamed} #{i}"
			end
			@schematics.append_page(pda, n)
			@schematics.page = -1
			pda.darea.grab_focus
		}
	end

	def save_symbol(as_shown)
		if (i = @schematics.page) != -1
			pda = @schematics.get_nth_page(i)
			name = pda.schem.can_save_symbol
			if name
				name = run_symbol_save_dialog(name)
				if name and !name.empty?
					pda.schem.save_symbol(name, as_shown)
				end
			end
		end
	end

	def save_schematic(save_as)
		if (i = @schematics.page) != -1
			pda = @schematics.get_nth_page(i)
			name = pda.schem.filename
			name = run_schematic_save_dialog(name) if save_as or name.empty?
			if name and !name.empty?
 				pda.schem.filename = name
			  pda.schem.write(name)
				@schematics.update_label(pda, name)
			end
		end
	end

	def close_schematic
		@schematics.remove_page(@schematics.page)
		@schematics.toplevel.destroy if @schematics.page == -1
	end

	def get_cur_pda
		@schematics.get_nth_page(@schematics.page)
	end

	def add_symbol
		name = run_add_symbol_dialog
		pda = @schematics.get_nth_page(@schematics.page)
		pda.schem.ProcessSymFile(name)
	end

	def create_symbol
		pda = @schematics.get_nth_page(@schematics.page)
		pda.schem.create_symbol
	end

# first stage of user input analysis
# our basic task here is to draw selection rectangles when user performs a drag action (press
# mouse button, move mouse, release button) and to do panning.
# Drag starts over a void area (hover == false) -- button 1 generates a selection rectangle, button 2
# generates a zoom-into rectangle. If action starts with button 2 over an item, then this is panning.
# Generally we pass the event to pda.schem.investigate_event() method.
# SHIFT and CONTROL keyboard modifier can be used to invert hover state, or to force it to true or false.
# pda: instance of pet drawing area
# event: Gdk::event
# px, py: current mouse pointer position in user coordinates
# no return value
# TODO: maybe we should block actions where multiple buttons are activated at the same time
	def distribute_events(pda, event)
		if event.event_type == Gdk::EventType::KEY_PRESS # maybe add some global magic keys here, i.e zoom full view?
			#pda.schem.enlarge(0.1) if event.keyval == Gdk::Keyval::KEY_p
			#pda.darea_configure_callback
			px, py = pda.get_user_coordinates(pda.raw_x, pda.raw_y)
		else
			px, py = pda.get_user_coordinates(event.x, event.y)
			if event.event_type == Gdk::EventType::MOTION_NOTIFY
				pda.raw_x, pda.raw_y = event.x, event.y
				@non_jitter_move ||= (pda.ebdx - event.x) ** 2 + (pda.ebdy - event.y) ** 2 > 10 # TODO: use named constant
				return unless @non_jitter_move
				if (event.state & Gdk::ModifierType::BUTTON1_MASK) != 0
				if !pda.hit || (event.state & Gdk::ModifierType::SHIFT_MASK) != 0
					pda.hit = false
					pda.draw_select_rect(pda.ebdx, pda.ebdy, event.x, event.y) #unless pda.hit
				end
				elsif (event.state & Gdk::ModifierType::BUTTON2_MASK) != 0
					if pda.hit
						pda.pan(pda.ebdx - event.x, pda.ebdy - event.y)
						pda.ebdx, pda.ebdy = event.x, event.y
					else
						pda.draw_select_rect(pda.ebdx, pda.ebdy, event.x, event.y)
					end
				end
			elsif event.event_type == Gdk::EventType::BUTTON_PRESS && (event.button == 1 || event.button == 2)
				pda.darea.grab_focus
				pda.ebdx ,pda.ebdy = event.x, event.y
				@non_jitter_move = false 
				pda.hit = pda.schem.hoovering?
				if event.button == 2
				if (event.state & Gdk::ModifierType::SHIFT_MASK) != 0
					if (event.state & Gdk::ModifierType::CONTROL_MASK) != 0
						pda.hit = !pda.hit
					else
						pda.hit = false
					end
				elsif (event.state & Gdk::ModifierType::CONTROL_MASK) != 0
					pda.hit = true
				end
				end
			elsif event.event_type == Gdk::EventType::BUTTON_RELEASE
				if !pda.hit && @non_jitter_move
					if event.button == 2
						pda.zoom_into_select_rect
					elsif event.button == 1
						pda.draw_select_rect(0, 0, 0, 0)
					end
				end
			end
		end
		boxlist = Array.new # list of bounding boxes which require redraw # TODO: maybe reuse boxlist, i.e. only one pda.boxlist
		pda.schem.investigate_event(boxlist, event, px, py)
		pda.update_canvas(boxlist)
	end

	def redraw_not_all(obj)
		get_cur_pda.update_canvas([obj.bbox])
	end


end # module PetEd

options = Hash.new
optparse = OptionParser.new do |opts|
	opts.banner = "Usage: peted.rb [options] file1 file2 ..."
	options[:verbose] = false
	opts.on('-v', '--verbose', 'Output more information') do
		 options[:verbose] = true
	end
	options[:logfile] = nil
	opts.on( '-l', '--logfile FILE', 'Write log to FILE' ) do|file|
		options[:logfile] = file
	end

	opts.on('-h', '--help', 'Display this screen') do
		 puts opts
		 exit
	end
end
optparse.parse!

main_window = Main_Window.new
if ARGV.empty? # so we have always at least one sheet -- no need to make all the widgets insensitive
	main_window.open_schematics([''])
else
	main_window.open_schematics(ARGV)
end

Gtk.main

end # module PetEd # 810

