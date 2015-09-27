#!/usr/bin/ruby

module Log

require 'gtk3'

$verbosity = 1 # 0..4 for logging all, messages, warnings, errors, nothing
$textbuffer = Gtk::TextBuffer.new # one single buffer for all Log_Views
$max_lines = 5 # positive default -- use 0 to suppress output, or negative (-1) integer for infinite length
$log_to_console = true

class Log_View < Gtk::ScrolledWindow
  def initialize(hscrollbar_policy, vscrollbar_policy) # Gtk::POLICY_ALWAYS, Gtk::POLICY_AUTOMATIC, Gtk::POLICY_NEVER
    #fail unless ([hscrollbar_policy, vscrollbar_policy] - [Gtk::POLICY_ALWAYS, Gtk::POLICY_AUTOMATIC, Gtk::POLICY_NEVER]).empty?
    fail unless ([hscrollbar_policy, vscrollbar_policy] - [Gtk::PolicyType::ALWAYS, Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::NEVER]).empty?
    super()
    self.set_policy(hscrollbar_policy, vscrollbar_policy)
    @logview = Gtk::TextView.new($textbuffer)
    self.add(@logview)
    $textbuffer.signal_connect('changed') {
      @logview.scroll_to_iter($textbuffer.end_iter, 0.0, true, 0.0, 1.0) # (iter, within_margin, use_align, xalign, yalign)
    }
  end
end

def self.log(t, v = 1)
  return if ($max_lines == 0) || (v < $verbosity)
  if $max_lines > 0
    if (d = $textbuffer.line_count - $max_lines) > 0
      $textbuffer.delete($textbuffer.start_iter, $textbuffer.get_iter_at_line(d))
    end
  end
  m = ((if v < 2 then '' elsif v == 2 then 'W: ' else 'E: ' end) + t.to_s)
  $textbuffer.insert($textbuffer.end_iter, m)
  Kernel::print(m) if $log_to_console
end

def self.print(*t)
  self.log(t.join, 1)
end

def self.puts(*t)
  self.log(t.join + "\n", 1)
end

def self.warn(*t)
  self.log(t.join + "!\n", 2)
end

def self.err(*t)
  self.log(t.join + "!\n", 3)
end

def self.debug(*t)
  self.log(t.join + "\n", 0)
end

end # Log

