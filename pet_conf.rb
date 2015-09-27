#!/usr/bin/ruby
module Pet_Config
require_relative 'pet_geda'
require_relative 'pet_log'
# pet_conf.rb -- managing configurations
# Copyright: S. Salewski, mail@ssalewski.de
# Version 0.01 (09-JAN-2012)
# License: GPL

=begin
Our configuration file may look like

# an arbitrary configuration
DEF:
red .8 0 0
myfont sans
GUI:
zoomfactor_mousewheel 1.1
OUTPUT:
text_font_name sans
textsize 10
pin_color 0.1, 0.2, 0.9 
SCR:
textsize 12
text_font_name serif
pin_color red
PNG:
textsize 8
PDF:
textsize 7
SVG:
PS:

Our configuration files can have different sections.
Section "DEF:" can be used to define custom constants, i.e. colors.
Colors are specified in RGB (red, green, blue) components, each component
ranging from 0 to 1. Color components are separated from each other by "," or
whitespace, and leading zeros can be ommited for color values.
An assignment of a value to a name can be done by "=" or ":=" or just whitespace.
For the various output devices SCR, PNG, PDF, SVG and PS a common section OUTPUT:
exists, which assigns common values for all output devices. These can be overwritten
for each device. Section GUI: is used for configuration of user interface and other
general parameters. Empty strings and strings containing spaces should be
included in single or double quotes. The same is true for strings
which looks like values already defined in the DEF: section, i.e. "red".   

Our internal configuration includes default values and min and max values
for integers and floats. For strings we can restrict the allowed values by specifying
them in Allowed_Strings. For each name-value conbination an optional
string parameter can contain a short description for this field. Longer optional
descripions are stored in a separate hash for strings. 
The configuration uses hashes, so for Ruby 1.8 order of entries is not preserved,
but Ruby 1.9 should again preserve order.
=end

# section symbols
DEF_S = :DEF # aliases
TMP_S = :TMP # hidden
GUI_S = :GUI # general user interface
OUTPUT_S = :OUTPUT # initial values for all output, with min, max, comment...
COO_S = :COO  # alterable copy of output, only values 
SCR_S = :SCR # Screen
PNG_S = :PNG # Portable Network Graphics
PDF_S = :PDF # Portable Document Format
SVG_S = :SVG # Scalable Vector Graphics
PS_S  = :PS  # PostScript

SEC_SURF_SYM = [SCR_S, PNG_S, PDF_S, SVG_S, PS_S, COO_S]
SEC_ALL_SYM = [TMP_S, GUI_S] + SEC_SURF_SYM
SEC_DEF_ALL_SYM = [DEF_S] + SEC_ALL_SYM

DEF_CON = Hash.new
SEC_DEF_ALL_SYM.each{|sym| if SEC_SURF_SYM.include?(sym) then DEF_CON[sym] = OUTPUT_S else DEF_CON[sym] = sym end}

Config_File_Name = 'Pet.conf' # default
DefaultSymDirs = ['/usr/share/gEDA/sym', "#{Dir.home}"]

# gEDA Color Index to hash-symbol Map
INDEX_COLORS = 24
COLOR_INDEX_RANGE = 0...INDEX_COLORS
CIM = Array.new(INDEX_COLORS)
CIM[Colorindex_geda_background         = 0 ]  = :color_geda_background
CIM[Colorindex_geda_pin                = 1 ]  = :color_geda_pin
CIM[Colorindex_geda_net_endpoint       = 2 ]  = :color_geda_net_endpoint
CIM[Colorindex_geda_graphic            = 3 ]  = :color_geda_graphic
CIM[Colorindex_geda_net                = 4 ]  = :color_geda_net
CIM[Colorindex_geda_attribute          = 5 ]  = :color_geda_attribute
CIM[Colorindex_geda_logic_bubble       = 6 ]  = :color_geda_logic_bubble
CIM[Colorindex_geda_dots_grid          = 7 ]  = :color_geda_dots_grid
CIM[Colorindex_geda_detached_attribute = 8 ]  = :color_geda_detached_attribute
CIM[Colorindex_geda_text               = 9 ]  = :color_geda_text
CIM[Colorindex_geda_bus                = 10 ] = :color_geda_bus
CIM[Colorindex_geda_select             = 11 ] = :color_geda_select
CIM[Colorindex_geda_boundingbox        = 12 ] = :color_geda_boundingbox
CIM[Colorindex_geda_zoom_box           = 13 ] = :color_geda_zoom_box
CIM[Colorindex_geda_stroke             = 14 ] = :color_geda_stroke
CIM[Colorindex_geda_lock               = 15 ] = :color_geda_lock
CIM[Colorindex_geda_output_background  = 16 ] = :color_geda_output_background
CIM[Colorindex_geda_freestyle1         = 17 ] = :color_geda_freestyle1
CIM[Colorindex_geda_freestyle2         = 18 ] = :color_geda_freestyle2
CIM[Colorindex_geda_freestyle3         = 19 ] = :color_geda_freestyle3
CIM[Colorindex_geda_freestyle4         = 20 ] = :color_geda_freestyle4
CIM[Colorindex_geda_junction           = 21 ] = :color_geda_junction
CIM[Colorindex_geda_mesh_grid_major    = 22 ] = :color_geda_mesh_grid_major
CIM[Colorindex_geda_mesh_grid_minor    = 23 ] = :color_geda_mesh_grid_minor



Color_Name = Hash.new
Color_Name[:color_geda_background] =               'background'
Color_Name[:color_geda_pin] =                      'pin'
Color_Name[:color_geda_net_endpoint] =             'net_endpoint'
Color_Name[:color_geda_graphic] =                  'graphic'
Color_Name[:color_geda_net] =                      'net'
Color_Name[:color_geda_attribute] =                'attribute'
Color_Name[:color_geda_logic_bubble] =             'logic_bubble'
Color_Name[:color_geda_dots_grid] =                'dots_grid'
Color_Name[:color_geda_detached_attribute] =       'detached_attribute'
Color_Name[:color_geda_text] =                     'text'
Color_Name[:color_geda_bus] =                      'bus'
Color_Name[:color_geda_select] =                   'select'
Color_Name[:color_geda_boundingbox] =              'boundingbox'
Color_Name[:color_geda_zoom_box] =                 'zoom_box'
Color_Name[:color_geda_stroke] =                   'stroke'
Color_Name[:color_geda_lock] =                     'lock'
Color_Name[:color_geda_output_background] =        'output_background'
Color_Name[:color_geda_freestyle1] =               'freestyle1'
Color_Name[:color_geda_freestyle2] =               'freestyle2'
Color_Name[:color_geda_freestyle3] =               'freestyle3'
Color_Name[:color_geda_freestyle4] =               'freestyle4'
Color_Name[:color_geda_junction] =                 'junction'
Color_Name[:color_geda_mesh_grid_major] =          'mesh_grid_major'
Color_Name[:color_geda_mesh_grid_minor] =          'mesh_grid_minor'




RCIM = Hash.new
RCIM[:color_geda_background] = 0
RCIM[:color_geda_pin] = 1
RCIM[:color_geda_net_endpoint] = 2
RCIM[:color_geda_graphic] = 3
RCIM[:color_geda_net] = 4
RCIM[:color_geda_attribute] = 5
RCIM[:color_geda_logic_bubble] = 6
RCIM[:color_geda_dots_grid] = 7
RCIM[:color_geda_detached_attribute] = 8
RCIM[:color_geda_text] = 9
RCIM[:color_geda_bus] = 10
RCIM[:color_geda_select] = 11
RCIM[:color_geda_boundingbox] = 12
RCIM[:color_geda_zoom_box] = 13
RCIM[:color_geda_stroke] = 14
RCIM[:color_geda_lock] = 15
RCIM[:color_geda_output_background] = 16
RCIM[:color_geda_freestyle1] = 17
RCIM[:color_geda_freestyle2] = 18
RCIM[:color_geda_freestyle3] = 19
RCIM[:color_geda_freestyle4] = 20
RCIM[:color_geda_junction] = 21
RCIM[:color_geda_mesh_grid_major] = 22
RCIM[:color_geda_mesh_grid_minor] = 23







# Aliases, defined in DEF: section
ALIAS_HASH = {
:RED => [0.8, 0.1, 0.1, 1],
:GREEN => [0.1, 0.8, 0.1, 1],
:BLUE => [0.1, 0.1, 0.8, 1],
#:myfont => 'serif',
#:hundred => '100'
}

CONFIG = Hash.new

CONFIG[DEF_S] = ALIAS_HASH

# CONFIG[TMP_S], CONFIG[GUI_S], CONFIG[OUTPUT_S]:
# default, min, max and optional comment. Or [r, g, b, a] array plus optional comment for colors. 

# Optional temporal/hidden parameters, i.e. window position and size. May be stored in an invisible .* file.
CONFIG[TMP_S] = {
#:DUMMY=> [1.1, 0.7, 1.5],
}

# General and GUI parameters 
CONFIG[GUI_S] = {
:use_tooltips => [true],
:zoomfactor_mousewheel => [110, 70, 150],
}

# defaults for SCR, PNG, PDF, SVG, PS
CONFIG[OUTPUT_S] = {
:color_geda_background =>         [[1, 1, 1, 0.95]],
:color_geda_pin =>                [[0.1, 0.1, 0.6, 1]],
:color_geda_net_endpoint =>       [[0.8, 0.1, 0.1, 1]],
:color_geda_graphic =>            [[0.1, 0.5, 0.1, 1]],
:color_geda_net =>                [[0.1, 0.1, 0.6, 1]],
:color_geda_attribute =>          [[0.1, 0.5, 0.1, 1]],
:color_geda_logic_bubble =>       [[0, 0, 0, 1]],
:color_geda_dots_grid =>          [[0, 0, 0, 1]],
:color_geda_detached_attribute => [[0, 0, 0, 1]],
:color_geda_text =>               [[0, 0, 0, 1]],
:color_geda_bus =>                [[0, 0, 0, 1], 'bus color'],
:color_geda_select =>             [[0, 0, 0, 1]],
:color_geda_boundingbox =>        [[0, 0, 0, 1]],
:color_geda_zoom_box =>           [[0, 0, 0, 1]],
:color_geda_stroke =>             [[0, 0, 0, 1]],
:color_geda_lock =>               [[0, 0, 0, 1]],
:color_geda_output_background =>  [[0, 0, 0, 1]],
:color_geda_freestyle1 =>         [[0, 0, 0, 1]],
:color_geda_freestyle2 =>         [[0, 0, 0, 1]],
:color_geda_freestyle3 =>         [[0, 0, 0, 1]],
:color_geda_freestyle4 =>         ['RED'],
:color_geda_junction =>           [[0, 0, 0, 0.7]],
:color_geda_mesh_grid_major =>    [[0, 0, 0, 0.20]],
:color_geda_mesh_grid_minor =>    [[0, 0, 0, 0.10]],
:grid_size_major  => [100, 1, 1000, 'active snap grid'],
:grid_size_minor  => [25, 0, 1000, 'passive grid, smaller or bigger than major grid; set to 0 to switch it off'],
:text_font_name => ['Sans'],
:text_size_user_scale => [1.0, 1.0, 10.0],#[1, 1, 1],
:text_size_sys_scale => [6, 4, 20],
:text_mark_size => [15, 10, 75],
:text_mark_width => [0, 0, 1],
:text_mark_visible_alw => [true],
:text_field_transparent => [true],
:line_width_user_scale => [1, 1, 4],
:line_width_sys_scale => [10, 10, 10],
:net_end_cap => [GEDA::END_CAP[:ROUND], GEDA::END_CAP.values.min, GEDA::END_CAP.values.max],
:pin_hot_end_cap => [GEDA::END_CAP[:ROUND], GEDA::END_CAP.values.min, GEDA::END_CAP.values.max],
:pin_end_cap => [GEDA::END_CAP[:ROUND], GEDA::END_CAP.values.min, GEDA::END_CAP.values.max],
:pin_hot_end_color => [[0.8, 0.1, 0.1, 1]],
:line_width_net => [10, 1, 25],
:line_width_pin => [10, 1, 25],
}

# overwrite special values
CONFIG[SCR_S] = {
#:TEXT_SIZE_USER_SCALE => 1.2
}

CONFIG[PNG_S] = {
#:TEXT_SIZE_USER_SCALE => 1
}

CONFIG[PDF_S] = {
:color_geda_pin => [0.9, 0.1, 0.6, 1],
#:TEXT_SIZE_USER_SCALE => 0.8
}

CONFIG[SVG_S] = {
#:TEXT_SIZE_USER_SCALE => 1
}

CONFIG[PS_S] = {
#:TEXT_SIZE_USER_SCALE => 0.8
}

#CONFIG[COO_S] = {}

# map small integers to symbolic names, so we can offer a combo box in treeview
Enum = {
:pin_end_cap => GEDA::END_CAP.keys.map!{|x| x.to_s},
:pin_hot_end_cap => GEDA::END_CAP.keys.map!{|x| x.to_s},
:net_end_cap => GEDA::END_CAP.keys.map!{|x| x.to_s},
}

# restrictions for special string values
Allowed_Strings = {
:text_font_name => ['Sans', 'Serif'],
#:TEXT_FONT_NAME => %w[sans serif],
}

# optional longer descriptions -- we should need only very few of these.
# split it in multiple lines each starting with "# " and terminated with "\n".
LONG_DESK = {
#:TEXT_MARK_SIZE => "# size of origin mark for text strings\n",
}

Name = '([a-zA-Z][-\w]*)'
Ass = '(=|:=|\s)'
Number = '(\d+(.\d+)?)'

Str = '(.+)'
OptSpace = '\s*'
Filename = '[a-zA-Z][-\w\.]*'
CommentLine = '(^\s*#)|(^\s*$)'
LineStart = '^\s*'
LineEnd = '\s*($|#)'

Assignment = LineStart + Name + OptSpace + Ass + OptSpace + Str + LineEnd

COL_VAL = '((?:\d)|(?:\d?\.\d+))'
COL_SEP = OptSpace + '[\s,]' + OptSpace
Opt_Alpha = '(?:' + COL_SEP + COL_VAL + ')?'
RGBA_COLOR = LineStart + COL_VAL + COL_SEP + COL_VAL + COL_SEP + COL_VAL + Opt_Alpha + LineEnd

NameIndex = 1
ValIndex = 3
ColorValueIndex1 = 1
ColorValueIndex2 = 2
ColorValueIndex3 = 3
ColorValueIndex4 = 4

class PC
  attr_accessor :main_window
  attr_accessor :updated_sections
  def initialize
    #@canvas = nil
		@main_window = nil
    @updated_sections = Array.new
    @alias_hash = ALIAS_HASH.dup
    @conf = Hash.new
    @conf[DEF_S] = @alias_hash
    SEC_ALL_SYM.each{|sym|
      @conf[sym] = Hash.new
      CONFIG[DEF_CON[sym]].each_pair{|n, v| @conf[sym][n] = v[0]}
    }
    (SEC_SURF_SYM - [COO_S]).each{|sym| @conf[sym].merge(CONFIG[sym])}
    @alias_ref = Hash.new
    @alias_ref[DEF_S] = Hash.new # dummy, always empty
    SEC_ALL_SYM.each{|sym|
      @alias_ref[sym] = Hash.new
      @conf[sym].each_pair{|n, v|
        if v.class == String
          if a = @alias_hash[v.to_sym]
            @alias_ref[sym][n] = v
            @conf[sym][n] = a # maybe we should check types for compatibility!
          end
        end
      }
    }
  end

  def get_conf(sec)
    fail unless (SEC_ALL_SYM - [COO_S]).include?(sec)
    @conf[sec]
  end

  def get_default(sec, k)
    k = k.to_sym
    fail unless SEC_DEF_ALL_SYM.include?(sec)
    if sec == COO_S
      CONFIG[OUTPUT_S][k][0]
    elsif sec == DEF_S
      CONFIG[DEF_S][k] # can return nil!
    elsif SEC_SURF_SYM.include?(sec)
      @alias_ref[COO_S][k] || @conf[COO_S][k]
    else
      CONFIG[sec][k][0]
    end
  end

  def set_default(sec, key)
    key = key.to_sym
    return unless (d = get_default(sec, key)) 
    # set(sec, key, d); return should do it also
    if sec == DEF_S
      if @alias_hash.has_key?(key) and (@alias_hash[key] != d)
        SEC_ALL_SYM.each{|s|
          @alias_ref[s].each_pair{|k, v|
            if v.to_sym == key
              @conf[s][k] = d
            end 
          } 
        }
      end
    else
      if sec == COO_S
        sections = SEC_SURF_SYM
      elsif SEC_ALL_SYM.include?(sec)
        sections = [sec]
      else
        fail
      end
      sections.each{|s|
        @conf[s][key] = d
        @alias_ref[s].delete(key)
        if d.class == String
          if v = @alias_hash[d.to_sym]
            @alias_ref[s][key] = d
            @conf[s][key] = v
          end
        end
      }
    end
    if @main_window and ((sec == SCR_S) or (sec == COO_S) or (sec == DEF_S)) then @main_window.refresh_all end
  end

  def get_colors(section)
    c = Array.new
    return c unless SEC_DEF_ALL_SYM.include?(section) # maybe halt
    @conf[section].each_pair{|k, v|
      if v.class == Array
        a = @alias_ref[section][k]
        x = CONFIG[DEF_CON[section]][k]
        if x.length > 1
          comment = x[-1]
          if comment.class != String then comment = nil end
        else
          comment = nil
        end
        d = ((a || v) == get_default(section, k))
        c << [k, a, v, d, comment]
      end
    }
    return c 
  end

  def get_non_colors(section)
    c = Array.new
    return c unless SEC_DEF_ALL_SYM.include?(section)
    @conf[section].each_pair{|k, v|
      if v.class != Array
        a = @alias_ref[section][k]
        x = CONFIG[DEF_CON[section]][k]
        if x.length > 1
          comment = x[-1]
          if comment.class != String then comment = nil end
        else
          comment = nil
        end
        d = ((a || v) == get_default(section, k))
        if (v.class == Fixnum) or (v.class == Float)
          if supp = Enum[k]
            v = supp[v]
          else
            supp = CONFIG[DEF_CON[section]][k][1..2]
          end
        else
          supp = Allowed_Strings[k]
        end
        c << [k, a, v, d, supp, comment]
      end
    }
    return c 
  end

  def get(section, k)
    return nil unless SEC_DEF_ALL_SYM.include?(section) # maybe halt
    k = k.to_sym
    a = @alias_ref[section][k]
    v = @conf[section][k] 
    d = ((a || v) == get_default(section, k))
    if Enum[k]
      min = CONFIG[DEF_CON[section]][k][1]
      v = Enum[k][v - min]
    end
    return [v, a, d]
  end

  def del_alias(name)
    name = name.to_sym
    if ALIAS_HASH.has_key?(name)
      return false
    else
      SEC_ALL_SYM.each{|sec|
        @alias_ref[sec].delete_if{|k, v| v.to_sym == name}
      }
      @alias_hash.delete(name)
      return true
    end
  end

  def is_color?(value)
    if v = @alias_hash[value.to_sym]
      v.class == Array
    else
      (value.class == String) and Regexp.new(RGBA_COLOR).match(value)
    end
  end

  def is_alias?(name)
    @alias_hash.has_key?(name.to_sym)
  end

  # section: one symbol from SEC_DEF_ALL_SYM, see above
  # name: string or symbol
  # value: string, integer, float, boolean or array of rgb(a) color values 
  def set(section, name, value, keep_old_alias_values = false)
    if section == COO_S
      sections = SEC_SURF_SYM
    elsif SEC_DEF_ALL_SYM.include?(section)
      sections = [section]
    else
      Log.err("invalid section: #{section}"); return false
    end
    name = name.to_sym
    if section != DEF_S
      d = CONFIG[DEF_CON[section]][name]
      c = @conf[section][name]
      if (v = Enum[name])
        if (v = v.index(value))
          value = v + d[1]
        end
      end
    end
    if (value.class == String) and ((section == DEF_S) or (c.class == Array))
      if match = Regexp.new(RGBA_COLOR).match(value)
        value = match.values_at(ColorValueIndex1, ColorValueIndex2, ColorValueIndex3, ColorValueIndex4)
        value[-1] ||= '1'
        value.map!{|x| Float(x)}
        unless value.min >= 0 and value.max <= 1
          Log.err("allowed color range is 0..1 for each rgba component"); return false
        end
      end
    end
    if section == DEF_S
      old_alias_value = @alias_hash[name]
      @alias_hash[name] = value
      if old_alias_value and (old_alias_value != value)
        uds = @updated_sections.dup
        SEC_ALL_SYM.each{|sec|
          if keep_old_alias_values
            if @alias_ref[sec].delete(name) then @updated_sections.delete(sec) end
          else
            @alias_ref[sec].each_pair{|k, v|
              if v == name.to_s
                if not set(sec, k, v) # set() will check new alias value
                  @alias_hash[name] = old_alias_value
                  SEC_ALL_SYM.each{|sc| # undo all changes if invalid
                    @alias_ref[sc].each_pair{|k, v|
                      if v == name.to_s
                        @conf[sc][k] = old_alias_value
                      end
                    }
                  }
                  @updated_sections = uds
                  return false
                else
                  @updated_sections.delete(sec)
                end
              end
            }
          end
        }
      end
      return true
    end
    ar = nil
    if value.class == String
      if (v = @alias_hash[value.to_sym])
        ar = value
        value = v
      else
        value.gsub!(/^(["'])(.*)\1$/,'\2')
      end
      if (c.class == TrueClass) or (c.class == FalseClass)
        if value.downcase == 'true'
          value = true
        elsif value.downcase == 'false'
          value = false
        end
      elsif ((c.class == Float) or (c.class == Fixnum)) and Regexp.new(Number).match(value)
        value = eval(value)
      end
    end
    if not @conf[section].has_key?(name)
      Log.err('assignment of unused value'); return false
    end
    newclass = value.class
    oldclass = c.class
    if newclass == FalseClass then newclass = TrueClass end # map to boolean
    if oldclass == FalseClass then oldclass = TrueClass end
    if (newclass != oldclass) and (oldclass != Float) and (newclass != Fixnum)
      Log.err("value for assignment has wrong type: #{name} (#{c.class}) = #{value} (#{value.class})"); return false
    end
    if (oldclass == Fixnum) or (oldclass == Float)
      if value < d[1]
        Log.err("value for assignment too small: #{name} = #{value}, allowed range is #{d[1]} to #{d[2]}"); return false
      elsif value > d[2]
        Log.err("value for assignment too large: #{name} = #{value}, allowed range is #{d[1]} to #{d[2]}"); return false
      end
    elsif oldclass == String
      if (v = Allowed_Strings[name]) and v.include?(value)
      #if Allowed_Strings.has_key?(name) and not Allowed_Strings[name].include?(value)
        Log.err("assigment #{name} = #{value}, only allowed values: #{v.join(', ')}"); return false
      end
    elsif oldclass == Array
      if value.length == 3
        value << 1
      elsif value.length != 4
        Log.err('only arrays with 3 or 4 components are valid rgb(a) colors'); return false
      end
    elsif oldclass == TrueClass
    else
      Log.err('invalid data type "#{oldclass}", ignored'); return false
    end
    if oldclass == Float then value = value.to_f end
    sections.each{|sec|
      @conf[sec][name] = value
      if ar
        @alias_ref[sec][name] = ar
      elsif @alias_ref[sec]
         @alias_ref[sec].delete(name)
      end
    }
    if section == COO_S then @updated_sections -= (SEC_SURF_SYM - [COO_S]) end
    if @main_window then @main_window.refresh_all end
    return true
  end

  # read and write are corrupted by design -- we will fix it later when we really employ it, should be easy...
  def read(filename = Config_File_Name)
    sec = nil
    begin
      File.open(filename, 'r') do |f|
        while line = f.gets
          line.chop!
          if Regexp.new(CommentLine).match(line)
          elsif (SEC_ALL_SYM + [DEF_S, OUTPUT_S]).include?(line.chop.to_sym)
            sec = line.chop.to_sym
          elsif match = Regexp.new(Assignment).match(line)
            if sec == nil
              Log.err("Error in configuration file #{filename} line #{f.lineno}")
              Log.err('=> ' + line)
              Log.err('   assignment before a section is selected')
            end
            name = match[NameIndex].to_sym
            value = match[ValIndex]
            if e = set(sec, name, value)
              Log.err("Error in configuration file #{filename} line #{f.lineno}")
              Log.err('=> ' + line)
              Log.err('   ' + e)
              #break
            end
          else
            Log.err("Error in configuration file #{filename} line #{f.lineno}")
            Log.err('=> ' + line)
            Log.err('   invalid line, ignored')
            #break
          end
        end
      end
    rescue => e
      Log.err e.message
    end
  end

  def write(filename = Config_File_Name, sections = SEC_DEF_ALL_SYM, all = true, minmax = true)
    if sections.empty? then sections = SEC_DEF_ALL_SYM end
    if not (sections - SEC_DEF_ALL_SYM).empty?
      Log.err('Pet_Config::write(): unknown sections:')
      (sections - SEC_DEF_ALL_SYM).each{|sym| Log.err('  ' + sym.to_s)}
    else
      begin
        File.open(filename, 'w') do |f|
          if sections.delete(DEF_S)
            f.puts 'DEF:'
            @alias_hash.each_pair{|n, v| f.print n, ' := ', v, "\n"}
          end
          sections.each{|sym|
            f.print sym.to_s, ":\n" 
            @conf[sym].each_pair do |n, v|
              is_default = (CONFIG[DEF_CON[sym]][n][0] == v)
              if (all == true) or not is_default
                if LONG_DESK.has_key?(n)
                  f.print LONG_DESK[n]
                end
                f.print '# ' if is_default == true 
                f.print n, ' = '
                if @alias_ref[sym].has_key?(n)
                  f.print(@alias_ref[sym][n])
                else
                  if v.class == Array
                    f.print v.join(', ')
                  else
                    f.print(v)
                  end
                end
                defaults = CONFIG[DEF_CON[sym]]
                if (minmax == true) and ((defaults[n][0].class == Fixnum) or (defaults[n][0].class == Float))
                  f.print " \# (#{defaults[n][1]}..#{defaults[n][2]})"
                end
                if (defaults[n].length > 1) and (defaults[n][-1].class == String)
                  f.print ' # ', defaults[n][-1]
                end
                f.puts
              end
            end
          }
        end
      rescue => e
        Log.err e.message
      end
    end
  end

end # class PC

Default_Config = Pet_Config::PC.new

def self.get_default_config()
  Default_Config
end

end # module Pet_Config


#Pet_Config::get_default_config().get_colors(Pet_Config::PDF_S).each{|el| puts el }

