#!/usr/bin/ruby -w

module Input_Mode
  %w[Net Line Pin Box Arc Circle Path Curve Text].each_with_index{|v, i| self.const_set(v, i)}
  def self.default; Net; end
end

module Def
  Major_Grid = [100, 50, 25, 10]
  Minor_Grid = [100, 50, 25, 10]
  Major_Grid_Default = 100
  Minor_Grid_Default = 25
end

