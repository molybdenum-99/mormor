require_relative '../lib/mormor'

d = MorMor::Dictionary.new('demo/russian')

pp d.lookup('кошками')