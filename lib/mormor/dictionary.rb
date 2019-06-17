require 'inifile'
require_relative 'fsa'

module MorMor
  class Dictionary
    Word = Struct.new(:stem, :tags)

    attr_reader :fsa

    def initialize(path)
      # Possible values described in DictionaryAttribute.java
      @info = IniFile.load(path + '.info').to_h.fetch('global')
        .map { |k, v| [k.sub(/^fsa\.dict\./, '').to_sym, v] }
        .to_h
      @fsa = FSA.new(path + '.dict')
      @encoding = @info.fetch(:encoding)
      @separator = @info.fetch(:separator)
      @sepbyte = @separator.bytes.first
    end

    def lookup(word)
      # TODO: there could be "input conversion pairs"
      bytes = word.encode(@encoding).bytes

      m = fsa.match(bytes)

      # this case is somewhat confusing: we should have hit the separator
      # first... I don't really know how to deal with it at the time
      # being.
      return unless m.kind == :sequence_is_a_prefix

      # The entire sequence exists in the dictionary. A separator should
      # be the next symbol.
      arc = fsa.arc(m.node, @sepbyte)

      # The situation when the arc points to a final node should NEVER
      # happen. After all, we want the word to have SOME base form.
      return if arc.zero? || fsa.final_arc?(arc)

      # There is such a word in the dictionary. Return its base forms.
      fsa.each(fsa.end_node(arc)).map { |encoded|
        # TODO: there could be "output conversion pairs"

        # Here, for "cats", we receive B+NNS, meaning remove 1 symbol, +NNS tag

        remove = encoded.split(@separator, 2).first.bytes.first.-(65) & 0xff # 65 is 'A'
        # TODO: If remove == 255, means "remove all"
        decoded = word[0...word.size - remove] + encoded[1..-1].force_encoding(@encoding).encode('UTF-8')
        Word.new(*decoded.split(@separator, 2))
      }
    end
  end
end