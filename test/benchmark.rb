require 'benchmark/ips'
require_relative '../lib/mormor'

pl = MorMor::Dictionary.new(File.expand_path('polish', __dir__))
ru = MorMor::Dictionary.new(File.expand_path('russian', __dir__))

Benchmark.ips do |b|
  b.report('polish') { pl.lookup('bobów') }
  b.report('russian') { ru.lookup('людских') }
end