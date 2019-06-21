require_relative '../lib/mormor'

{
  english: %w[meowing cats],
  russian: %w[кричащих котиков],
}.each do |lang, words|
  dic = MorMor::Dictionary.new(File.expand_path(lang.to_s, __dir__))
  puts "#{lang}\n" + "-" * lang.length
  words.each do |word|
    found = dic.lookup(word)
    puts "#{word}:\n  #{found&.map(&:inspect)&.join("\n  ") || 'NOT FOUND'}"
  end
  puts
end