require 'benchmark'

#array = (1..1000000).map { rand }

#Benchmark.bmbm do |x|
#  x.report("sort!") { array.dup.sort! }
#  x.report("sort")  { array.dup.sort  }
#end

def sss(i,o)
i*i+o
end

class Tst
  attr_accessor :x1, :x2
end

module Mom 
  H = 4
end

t = Tst.new
t.x1 = rand

x1 = t.x1
x2 = 0
#Range.new(yi1, yi2).step(grid){|j|

y = 0
a=0; b = 1e6.to_i; c = 3
Benchmark.bmbm do |x|
  #x.report("Range") {Range.new(a, b).step(c){|j| y += sss(j,8)}; puts y}

  #j = a
#  x.report("While")  {j = a;while j < b do; j+= c; y += sss(j,8); end; puts y}

  t = :dump
  y= -1
  x.report("sym")  {b.times{if t == :smart then y = 0; end}}
  t = 7
  y= -1
  x.report("int")  {b.times{if t == 13 then y = 0; end}}
  t = 7
  y= -1
  x.report("mod")  {b.times{if t == Mom::H then y = 0; end}}


  
  y= 7
	z = 0
  x.report(" * *")  {b.times{z = y * (256 * 256)}}


  y= 7
	z = 0
  x.report("*")  {b.times{z = y * 64536}}

  y= 7
	z = 0
  x.report("*")  {b.times{z = y << 16}}

end
