#!/usr/bin/ruby -w

require 'sqlite3'
require './ipdconfig'

rn = 1000000
max = 25
more = 0.5 # %

# create random array
a = []
(1..rn).each do
  a.push(rand(max))
end
#puts "INHALT VOR MERGE"
#puts a.to_s

# count
r = {}
(0..max - 1).each do |i|
  r[i] = 0
  a.each do |j|
    if j == i
      r[i] += 1
    end
  end
end
x = {}
r.each_key do |k|
  x[k] = (r[k].to_f / rn.to_f).to_f * 100
end
puts "VERTEILUNG URSPRUNG"
puts x.to_s

yd = Time.now.to_i - 200000
result = IPDConfig::DB_HANDLE.execute("SELECT (SELECT count(0) - 1 FROM picture p1 WHERE p1.id <= p2.id) as 'rownum', filename FROM picture p2 WHERE time_send > ?", [yd])
#puts result.to_s

result.each do |row|
o = row[0]
puts "#{o} DAZU"

# second array menge
a2 = []
(1..(rn / max * more)).each do |i|
  a2.push(rand(max))
end
#puts "OEFTER ZU ZEIGEND AN POSITIONEN"
#puts a2.to_s

# arrays mergen
#puts "vor merge a1.length " + a.length.to_s
a2.each do |p|
  a.insert(p, o)
end
#puts "nach merge a1.length " + a.length.to_s
end

# count
r = {}
(0..max - 1).each do |i|
  r[i] = 0
  a.each do |j|
    if j == i
      r[i] += 1
    end
  end
end
x = {}
r.each_key do |k|
  x[k] = (r[k].to_f / rn.to_f).to_f * 100
end
puts "VERTEILUNG NACH MERGE"
puts x.to_s

#puts "INHALT NACH MERGE"
#puts a.to_s

#yd = Time.now.to_i - 86400
#result = IPDConfig::DB_HANDLE.execute("SELECT (SELECT count(0) - 1 FROM picture p1 WHERE p1.id <= p2.id) as 'rownum', filename FROM picture p2 WHERE time_send > ?", [yd])
#puts result.to_s
