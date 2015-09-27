#!/usr/bin/env ruby

require 'gtk3'

menu = Gtk::Menu.new
menu.append(mitem1 = Gtk::MenuItem.new("Test1"))
menu.append(mitem2 = Gtk::MenuItem.new("Test2"))
menu.show_all

mitem1.signal_connect('activate') { |w| puts "#{w.class} - Test2" }
mitem2.signal_connect('activate') { |w| puts "#{w.class} - Test2" }

window = Gtk::Window.new("Bare Bones Context Menu")
# Make window sensitive to Right-mouse-click, to open the pop-up menu.
window.add_events(Gdk::Event::BUTTON_PRESS_MASK)
window.signal_connect("button_press_event") do |widget, event|
  menu.popup(nil, nil, event.button, event.time) if (event.button == 3)
end
# Make window sensitive to <Shift+F10> accelerator keys. These
# accelerator keys generate the 'popup-menu' signal for window,
# which opens the popup-menu.
window.signal_connect("popup_menu") do |w|
  menu.popup(nil, nil, 0, Gdk::Event::CURRENT_TIME)
end

window.set_default_size(300, 100).show_all
window.signal_connect('destroy') { Gtk.main_quit }
window.add(Gtk::Label.new("Hello World\n" +
                          "You may 'right-click' me\n\n" +
                          "or use <Shift+F10>"))
window.show_all
Gtk.main
