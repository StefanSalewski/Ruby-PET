#!/usr/bin/env ruby
module Pet_Attr
require 'gtk3'

# NameVis. Name ValVis. Value X
# X is '+' for new, 'i' for inherited or '-' for overwritten


class Attr_Win < Gtk::Box
  #attr_accessor :aa
  def initialize
    super(:vertical, 0)
    #set_size_request(200, 100)
    tv = Gtk::TreeView.new
    #tv.set_size_request(200, -1)

    r = Gtk::CellRendererText.new
    c = Gtk::TreeViewColumn.new('', r, "text" => 0)
    tv.append_column(c)


    r = Gtk::CellRendererToggle.new
    c = Gtk::TreeViewColumn.new('', r, "active" => 1)
    tv.append_column(c)



    r = Gtk::CellRendererText.new
    c = Gtk::TreeViewColumn.new("Name", r, "text" => 2)
    tv.append_column(c)



    r = Gtk::CellRendererToggle.new
    c = Gtk::TreeViewColumn.new('', r, "active" => 3)
    tv.append_column(c)



    r = Gtk::CellRendererText.new
    c = Gtk::TreeViewColumn.new("Value", r, "text" => 4)
    tv.append_column(c)






    @store = Gtk::ListStore.new(String, TrueClass, String, TrueClass, String)
#    iter = @store.append
#    iter[0] = '+'
#    iter[1] = FALSE
#    iter[2] = 'ref_desjljlkjkjljlk'
#    iter[3] = TRUE
#    iter[4] = 'R0jlkjlkjlkjlkjlkjkl'

    tv.model = @store
    #tv.unselect_all
    pack_start(tv)
    #tv.unselect_all
  end
  def refresh(el)



if el
@store.clear
    #puts el unless el == nil
    l = el.get_attributes
    l.each{|el|


    iter = @store.append
    iter[0] = '+'
    iter[1] = FALSE
    iter[2] = el.name
    iter[3] = TRUE
    if el.value[-1] == "\n" then el.value[-1] = '' end
#h[-1] = ""
#el.value[-1] = ''
    iter[4] = el.value


#puts h[0], h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]
#h[-1] = ""
#puts h[0], h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]

    #iter = @store.append
#    iter[0] = '+'
#    iter[1] = FALSE
#    iter[2] = 'ref_desjjlj'
#    iter[3] = TRUE
#    iter[4] = 'R0kököjjljjh'

puts el.name.class, el.value.class
    }
end
  end
end
end # module Pet_Attr
#w = Gtk::Window.new(Gtk::Window::TOPLEVEL)
#w.signal_connect('delete_event') { Gtk.main_quit }
#box = Attr_Win.new
#w.add(box)
#w.show_all
#Gtk.main

