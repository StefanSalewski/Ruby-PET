#!/usr/bin/env ruby

module Pet_Conf_Ed

require 'gtk3'
require_relative 'pet_conf'
require_relative 'pet_log'

class Gtk::Notebook
	def append_page_scrolled(w, l)
		h = Gtk::ScrolledWindow.new
		h.add(w)
		self.append_page(h, l)
	end
end

class Config_Notebook < Gtk::Notebook
  def initialize(conf)
    super()
    general = Conf_View.new(conf, Pet_Config::GUI_S)
    general.refresh
    display = Gtk::Notebook.new
    colors = Gtk::Notebook.new
    [display, colors].each{|dc|
      dc.signal_connect('switch-page') do |w, page, page_num|
        child = w.get_nth_page(page_num)
        if  (child.class == Color_View) # allow update of colors if DEF_S section may have been modified
          child.refresh
        end
      end
      [Pet_Config::COO_S, Pet_Config::SCR_S, Pet_Config::PDF_S, Pet_Config::SVG_S, Pet_Config::PNG_S, Pet_Config::DEF_S].each{|sec|
        if dc == display
          cv = Conf_View.new(conf, sec)
        else
          cv = Color_View.new(conf, sec)
        end
        cv.refresh
        if sec == Pet_Config::DEF_S
          table = Gtk::Table.new(2, 4, false)
          fll_shr = Gtk::AttachOptions::FILL | Gtk::AttachOptions::SHRINK
          fll_exp = Gtk::AttachOptions::FILL | Gtk::AttachOptions::EXPAND
          table.attach(cv, 0, 2, 0, 1, fll_exp, fll_exp, 0, 0)
          table.attach(Gtk::Label.new("Name:"), 0, 1, 1, 2, fll_shr, fll_shr, 0, 0)
          table.attach(Gtk::Label.new("Value:"), 0, 1, 2, 3, fll_shr, fll_shr, 0, 0)
          name_entry = Gtk::Entry.new
          value_entry = Gtk::Entry.new
          table.attach(name_entry, 1, 2, 1, 2, fll_exp, fll_shr, 0, 0)
          table.attach(value_entry, 1, 2, 2, 3, fll_exp, fll_shr, 0, 0)

          add = Gtk::Button.new(:label => 'Add')#, :mnemonic => nil, :stock_id => Gtk::Stock::ADD)
          remove = Gtk::Button.new(:label => 'Remove')#, :mnemonic => nil, :stock_id => Gtk::Stock::REMOVE)
          remove.signal_connect('clicked'){
            cv.remove_selected
          }
          if dc == display
            add.signal_connect('clicked'){
              h = value_entry.text.dup
              if conf.is_color?(h) then h = ?' + h + ?' end 
              conf.set(sec, name_entry.text, h)
              t, a, d = conf.get(sec, name_entry.text)
              cv.change(name_entry.text, t, d)
            }
          else
            add.signal_connect('clicked'){
              if conf.is_color?(value_entry.text)
                conf.set(sec, name_entry.text, value_entry.text)
                c, a, d = conf.get(sec, name_entry.text)
                cv.change(name_entry.text, c, d)
              else
                Log::err("'#{value_entry.text}' is no valid color value")
              end
            }
          end
          table.attach(remove, 0, 1, 3, 4, fll_shr, fll_shr, 0, 0)
          table.attach(add, 1, 2, 3, 4, fll_shr, fll_shr, 0, 0)
          dc.append_page_scrolled(table, Gtk::Label.new(sec.to_s))
        else
          if sec == Pet_Config::COO_S then s = 'All' else s =  sec.to_s end
          dc.append_page_scrolled(cv, Gtk::Label.new(s))
        end
      }
    }
    self.append_page_scrolled(general, Gtk::Label.new('General'))
    self.append_page_scrolled(display, Gtk::Label.new('Display'))
    self.append_page_scrolled(colors, Gtk::Label.new('Colors'))
  end
end

class Color_View < Gtk::TreeView

  Col_Name = 0
  Col_Str = 1
  Col_R = 2
  Col_G = 3
  Col_B = 4
  Col_A = 5
  Col_Def = 6
  Col_Com = 7

  def initialize(conf, sec)
    super()
    @conf = conf
    @sec = sec
    @store = Gtk::ListStore.new(String, String, Float, Float, Float, Float, TrueClass, String, Gdk::Pixbuf)
    self.set_tooltip_column(Col_Com) if conf.get_conf(Pet_Config::GUI_S)[:use_tooltips] # sorry, no imediate update now -- which event should we use?
#    self.signal_connect('query-tooltip') do |w, x, y, keyboard_mode, tooltip|
#      return false #@conf.get_conf(Pet_Config::GUI_S)[:use_tooltips]
#    end
    renderer = Gtk::CellRendererPixbuf.new
		#renderer.follow_state = true
    #renderer.pixbuf = Gdk::Pixbuf.new(Gdk::Pixbuf::COLORSPACE_RGB, true, 8, 10, 10) # (colorspace, has_alpha, bits_per_sample, width, height)
    #column = Gtk::TreeViewColumn.new('', renderer)
    column = Gtk::TreeViewColumn.new('', renderer, 'pixbuf' => 8)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      # we may use cairo, see http://stackoverflow.com/questions/7703087/pygtk-cellrendererpixbuf-and-transparency
      # pixmap = Gdk::Pixmap.new(nil, 8, 8, 24)
      # cr = pixmap.create_cairo_context
      # cr.set_source_rgb(0.9, 0.9, 0.9)
      # cr.paint
      # pixbuf =Gdk::Pixbuf.from_drawable(nil, pixmap, 0, 0, 8, 8)
      # but a plain pixbuf.fill!() should be good enough!
      # cell.pixbuf.fill!(cairo_color_to_pixbuf(iter[Col_R], iter[Col_G], iter[Col_B], iter[Col_A]))
			#cell.pixbuf = iter[8]
      cell.pixbuf.fill!((iter[Col_R] * 255).round * 16777216 + (iter[Col_G] * 255).round * 65536 + (iter[Col_B] * 255).round * 256 + (iter[Col_A] * 255).round)
    end
    self.append_column(column)
   
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new('Name', renderer, 'text' => Col_Name)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      t = iter[Col_Name]
      if t[0..10] == 'color_geda_' then t = t[11..-1] end
      cell.text = t
    end
    self.append_column(column)

    renderer = Gtk::CellRendererText.new
    renderer.editable = true
    column = Gtk::TreeViewColumn.new('Value', renderer, 'text' => Col_Str)
    self.append_column(column)
    renderer.signal_connect('edited') do |w, path, new_text|
      iter = @store.get_iter(path)
      if (iter[Col_Str] != new_text)
        if @conf.is_color?(new_text)
          @conf.set(@sec, iter[Col_Name], new_text)
          c, a, d = @conf.get(@sec, iter[Col_Name])
          iter[Col_Def] = d
          iter[Col_Str] = (a || c.join(', '))
          iter[Col_R], iter[Col_G], iter[Col_B], iter[Col_A] = c
        else
          Log::err("'#{new_text}' is no valid color value")
        end
      end
    end

    renderer = Gtk::CellRendererToggle.new
    renderer.xalign = 0
    column = Gtk::TreeViewColumn.new('RST', renderer, 'active' => Col_Def)
    renderer.signal_connect('toggled') do |w, path|
      iter = @store.get_iter(path)
      if not iter[Col_Def]
        @conf.set_default(@sec, iter[Col_Name])
        c, a, d = @conf.get(@sec, iter[Col_Name])
        iter[Col_Def] = d
        iter[Col_Str] = (a || c.join(', '))
        iter[Col_R], iter[Col_G], iter[Col_B], iter[Col_A] = c
      end
    end
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      cell.visible = (@sec != Pet_Config::DEF_S) || @conf.get_default(@sec, iter[Col_Name])
      cell.sensitive = cell.visible? && !iter[Col_Def]
    end
    self.append_column(column)

    self.model = @store
  end

  def remove_selected
    if iter = self.selection.selected
      if @conf.del_alias(iter[Col_Name])
        @store.remove(iter)
      else
        Log::err('Can\'t delete predefined aliases')
      end
    end
  end

  def refresh
    unless @conf.updated_sections.include?(@sec)
      @store.clear
      @conf.get_colors(@sec).each{|el|
        show(*el)
      }
      @conf.updated_sections << @sec
    end
  end

  def change(name, c, is_default)
    iter = nil
    @store.each{|model, path, i|
      if i[Col_Name] == name then iter = i; break end
    }
    unless iter
      iter = @store.append
      iter[Col_Name] = name
      iter[Col_Com] = nil 
    end
    iter[Col_Str] = c.join(', ')
    iter[Col_R], iter[Col_G], iter[Col_B], iter[Col_A] = c
    iter[Col_Def] = is_default
  end

  def show(name, alia, c, is_default, comment)
    iter = @store.append
    iter[Col_Name] = name.to_s
    iter[Col_Com] = comment
    iter[Col_Str] = (alia || c.join(', '))
    iter[Col_R], iter[Col_G], iter[Col_B], iter[Col_A] = c
    iter[Col_Def] = is_default
    iter[8] = Gdk::Pixbuf.new(Gdk::Pixbuf::COLORSPACE_RGB, true, 8, 10, 10)
  end

end

class Conf_View < Gtk::TreeView

  Col_Name = 0
  Col_Text = 1
  Col_Bool = 2
  Col_Int  = 3
  Col_Float= 4
  Col_Min  = 5
  Col_Max  = 6
  Col_Def  = 7
  Col_Tag  = 8
  Col_Com  = 9

  def initialize(conf, sec)
    super()
    @conf = conf
    @sec = sec
    @combo_list = Array.new
    @store = Gtk::ListStore.new(String, String, TrueClass, Integer, Float, Integer, Integer, TrueClass, Integer, String)
    self.set_tooltip_column(Col_Com) if conf.get_conf(Pet_Config::GUI_S)[:use_tooltips]
    renderer = Gtk::CellRendererText.new
    self.append_column(Gtk::TreeViewColumn.new('Name', renderer, 'text' => Col_Name))

    column = Gtk::TreeViewColumn.new
    column.set_title('Value ')
    column.set_min_width(100)
    column.set_alignment(0)


    renderer = Gtk::CellRendererText.new
    column.pack_start(renderer, false) # (cell, expand)
    column.set_attributes(renderer, 'text' => Col_Text)
    #column.set_attributes(renderer, 'width-chars' => 9)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      if cell.visible = cell.editable = (iter[Col_Tag] == Col_Text)
        if @conf.is_alias?(iter[Col_Text])
          cell.weight = 900
        else
          cell.weight = 400
        end
      end
    end
    renderer.signal_connect('edited') do |w, path, new_text|
      iter = @store.get_iter(path)
      if iter[Col_Text] != new_text
        if (@sec == Pet_Config::DEF_S) and @conf.is_color?(new_text)
          @conf.set(@sec, iter[Col_Name], ?' + new_text + ?')
        else
          @conf.set(@sec, iter[Col_Name], new_text)
        end
        v, a, d = @conf.get(@sec, iter[Col_Name])
        if a
          iter[Col_Text] = a
        else
          if v.is_a?(Integer)
            iter[Col_Tag] = Col_Int
            iter[Col_Int] = v
          elsif v.class == Float
            iter[Col_Tag] = Col_Float
            iter[Col_Float] = v
          elsif (v.class == TrueClass) or (v.class == FalseClass)
            iter[Col_Tag] = Col_Bool
            iter[Col_Bool] = v
          else
            iter[Col_Text] = v
          end
        end
        iter[Col_Def] = d
      end
    end

    renderer = Gtk::CellRendererToggle.new
    renderer.xalign = 0
    column.pack_start(renderer, false)
    column.set_attributes(renderer, 'active' => Col_Bool)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      cell.visible = cell.sensitive = (iter[Col_Tag] == Col_Bool)
    end
    renderer.signal_connect('toggled') do |w, path|
      iter = @store.get_iter(path)
      @conf.set(@sec, iter[Col_Name], !iter[Col_Bool])
      b, a, d = @conf.get(@sec, iter[Col_Name])
      iter[Col_Bool] = b
      iter[Col_Def] = d
    end

    # float
    renderer = Gtk::CellRendererSpin.new
    adjustment = Gtk::Adjustment.new(0.0, 0.0, 100.0, 0.1, 1.0, 0.0) # (value, lower, upper, step_inc, page_inc, page_size)
    renderer.adjustment = adjustment
    renderer.digits = 1
    column.pack_start(renderer, false)
    #column.set_attributes(renderer, "text" => Col_Float)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      if cell.visible = cell.editable = (iter[Col_Tag] == Col_Float)
        cell.text = iter[Col_Float].to_s
      end
    end
    renderer.signal_connect('editing-started') do |cell, editable, path|
      iter = @store.get_iter(path)
      cell.adjustment.lower = iter[Col_Min]
      cell.adjustment.upper = iter[Col_Max]
      cell.adjustment.value = iter[Col_Float]
    end
    renderer.signal_connect('edited') do |w, path, new_text|
      iter = @store.get_iter(path)
      if (f = Float(new_text) rescue false)
        f = [iter[Col_Min], f, iter[Col_Max]].sort[1] # improve when we have Ruby > 1.93
        @conf.set(@sec, iter[Col_Name], f)
      else
        @conf.set(@sec, iter[Col_Name], new_text)
      end
      i, a, d = @conf.get(@sec, iter[Col_Name])
      if a
        iter[Col_Tag] = Col_Text
        iter[Col_Text] = a
      end
      iter[Col_Float] = i
      iter[Col_Def] = d
    end

    # integer
    renderer = Gtk::CellRendererSpin.new
    adjustment = Gtk::Adjustment.new(0.0, 0.0, 100.0, 1.0, 2.0, 0.0) # (value, lower, upper, step_inc, page_inc, page_size)
    renderer.adjustment = adjustment
    column.pack_start(renderer, false)
    column.set_attributes(renderer, "text" => Col_Int)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      cell.visible = cell.editable = (iter[Col_Tag] == Col_Int)
    end
    renderer.signal_connect('editing-started') do |cell, editable, path|
      iter = @store.get_iter(path)
      cell.adjustment.lower = iter[Col_Min]
      cell.adjustment.upper = iter[Col_Max]
      cell.adjustment.value = iter[Col_Int]
    end
    renderer.signal_connect('edited') do |w, path, new_text|
      iter = @store.get_iter(path)
      if Regexp.new('\d+').match(new_text)
        f = [iter[Col_Min], new_text.to_i, iter[Col_Max]].sort[1] # improve when we have Ruby > 1.93
        @conf.set(@sec, iter[Col_Name], f)
      else
        @conf.set(@sec, iter[Col_Name], new_text)
      end
      i, a, d = @conf.get(@sec, iter[Col_Name])
      if a
        iter[Col_Tag] = Col_Text
        iter[Col_Text] = a
      end
      iter[Col_Int] = i
      iter[Col_Def] = d
    end

    renderer = Gtk::CellRendererCombo.new
    #renderer.editable = true
    renderer.has_entry = false
    renderer.text_column = 0
    column.pack_start(renderer, false)
    column.set_attributes(renderer, "text" => Col_Text)
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      tag = iter[Col_Tag]
      if cell.visible = cell.editable = (tag < 0)
        cell.model = @combo_list[-tag - 1] 
      end
    end
    renderer.signal_connect('edited') do |w, path, new_text|
      iter = @store.get_iter(path)
      if iter[Col_Text] != new_text
        @conf.set(@sec, iter[Col_Name], new_text)
        t, a, d = @conf.get(@sec, iter[Col_Name])
        iter[Col_Text] = t#new_text
        iter[Col_Def] = d
      end
    end

    self.append_column(column)

    renderer = Gtk::CellRendererToggle.new
    renderer.xalign = 0
    #renderer.alignment(0, 0)
    column = Gtk::TreeViewColumn.new("RST", renderer, 'active' => Col_Def)
    renderer.signal_connect('toggled') do |w, path|
      iter = @store.get_iter(path)
      if not iter[Col_Def]
        @conf.set_default(@sec, iter[Col_Name])
        v, a, d = @conf.get(@sec, iter[Col_Name])
        if iter[Col_Tag] < 0
          iter[Col_Text] = v
        elsif a
          iter[Col_Tag] = Col_Text
          iter[Col_Text] = a
        else
          if v.is_a?(Integer)
            a = Col_Int
          elsif v.class == Float
            a = Col_Float
          elsif (v.class == TrueClass) or (v.class == FalseClass)
            a = Col_Bool
          elsif v.class == String
            a = Col_Text
          else
            fail
          end
          iter[Col_Tag] = a
          iter[a] = v
        end
        iter[Col_Def] = d
      end
    end
    column.set_cell_data_func(renderer) do |tvc, cell, model, iter|
      cell.visible = (@sec != Pet_Config::DEF_S) || @conf.get_default(@sec, iter[Col_Name])
      cell.sensitive = cell.visible? && !iter[Col_Def]
			#cell.xalign = 0
    end

    self.append_column(column)

    self.model = @store
  end

  def refresh
    @store.clear
    @combo_list.clear
    @conf.get_non_colors(@sec).each{|el|
      show(*el)
    }
  end

  def show(name, al, val, is_default, supp = nil, comment = nil)
    iter = @store.append
    iter[Col_Name] = name
    iter[Col_Com] = comment
    iter[Col_Def] = is_default
    if al or ((val.class == String) and (supp == nil))
      iter[Col_Text] = al || val
      iter[Col_Tag] = Col_Text
    elsif val.is_a?(TrueClass) or val.is_a?(FalseClass)
      iter[Col_Bool] = val
      iter[Col_Tag] = Col_Bool
    elsif val.is_a?(Integer)
      iter[Col_Int] = val
      iter[Col_Min] = supp[0]
      iter[Col_Max] = supp[1]
      iter[Col_Tag] = Col_Int
    elsif val.class == Float
      iter[Col_Float] = val
      iter[Col_Min] = supp[0]
      iter[Col_Max] = supp[1]
      iter[Col_Tag] = Col_Float
    elsif supp != nil
      s = Gtk::ListStore.new(String)
      supp.each{|el| s.append[0] = el}
      @combo_list << s
      iter[Col_Text] = val
      iter[Col_Tag] = -@combo_list.length
    end
  end

  def change(name, t, is_default)
    iter = nil
    @store.each{|model, path, i|
      if i[Col_Name] == name then iter = i; break end
    }
    unless iter
      iter = @store.append
      iter[Col_Name] = name
      iter[Col_Com] = nil
      iter[Col_Tag] = Col_Text
    end
    iter[Col_Text] = t
    iter[Col_Def] = is_default
  end

  def remove_selected
    if iter = self.selection.selected
      if @conf.del_alias(iter[Col_Name])
        @store.remove(iter)
      else
        Log::err('Can\'t delete predefined aliases')
      end
    end
  end

end # Config_Notebook

end # module Pet_Conf_Ed

