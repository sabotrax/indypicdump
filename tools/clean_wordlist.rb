#!/usr/bin/ruby -w

unless ARGV.length == 1
  puts "ARGUMENT ERROR, GIVE FILE"
  exit
end

filename = ARGV.shift

words = IO.readlines(filename)
words.each {|w| w.chomp! }
puts "WORDS " + words.length.to_s

unique_words = words.uniq
unique_words.sort! {|x, y| x <=> y }
puts "UNIQUE " + unique_words.length.to_s

File.open(filename + "-unique", 'w') {|f| f.write(unique_words.join("\n")) }
