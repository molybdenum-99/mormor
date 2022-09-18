# frozen_string_literal: true

require_relative 'fsa'

module MorMor
  # Morfologik dictionary client.
  #
  # @example
  #   dictionary = MorMor::Dictionary.new('path/to/english')
  #   dictionary.lookup('meowing')
  #   # => [#<struct MorMor::Dictionary::Word stem="meow", tags="VBG">]
  #
  class Dictionary
    # This class is simplified port of all `Dictionary*.java` classes (Dictionary, DictionaryMetadata,
    # DictionaryLookup etc) of `morfologik-stemming` package.
    # See original package to understand details and stuff:
    # https://github.com/morfologik/morfologik-stemming/tree/master/morfologik-stemming/src/main/java/morfologik/stemming

    # Result of {Dictionary#lookup}
    #
    # `stem` is base form of the looked up word, `tags` is dictionary-depended part of speech / word
    # form tags.
    Word = Struct.new(:stem, :tags)

    # @private
    DECODERS = {'SUFFIX' => :suffix, 'PREFIX' => :prefix_suffix}.freeze

    # @private
    ENCODING_ALIASES = {'utf8' => 'UTF-8'}.freeze

    # @private
    attr_reader :fsa
    # @return [Hash]
    attr_reader :info

    # @param path [String] Path to dictionary files. It is expected that `path + ".info"` and
    #   `path + ".dict"` files are existing and contain Morfologik dictionary
    def initialize(path)
      @path = path # Just for inspect

      read_info(path + '.info')

      @fsa = FSA.read(path + '.dict')
    end

    # @return [String]
    def inspect
      '#<%s %s>' % [self.class, @path]
    end

    # Finds all forms and POS tags of words in the dictionary.
    #
    # @param word [String] a word to lookup
    # @return [Array<Word>, nil]
    def lookup(word) # rubocop:disable Metrics/AbcSize
      # Method is left unsplit to leave original algorithm (DictionaryLookup.java#lookup) recognizable,
      # hence rubocop:disable

      bword = word.encode(@encoding).force_encoding('ASCII-8BIT')

      # TODO: there could be "input conversion pairs"

      # Note: not bword.bytes, because morfologik expects signed bytes, while String#bytes
      # is analog of unpack('C*'), returning unsigned
      m = fsa.match(bword.unpack('c*'))

      # OC: this case is somewhat confusing: we should have hit the separator
      # first... I don't really know how to deal with it at the time
      # being.
      return unless m.kind == :sequence_is_a_prefix

      # OC: The entire sequence exists in the dictionary. A separator should
      # be the next symbol.
      arc = fsa.find_arc(m.node, @sepbyte)

      # OC: The situation when the arc points to a final node should NEVER
      # happen. After all, we want the word to have SOME base form.
      return if arc.zero? || fsa.final_arc?(arc)

      # OC: There is such a word in the dictionary. Return its base forms.
      fsa.each_sequence(from: fsa.end_node(arc)).map do |encoded|
        # TODO: there could be "output conversion pairs"

        decoded = @decoder.call(bword, encoded).force_encoding(@encoding).encode('UTF-8')

        Word.new(*decoded.split(@separator, 2))
      end
    end

    private

    def read_info(path)
      @info = read_values(path)

      # NB: All possible values described in DictionaryAttribute.java

      # Cache it to be quickly accessible
      @encoding = @info.fetch('fsa.dict.encoding').then { ENCODING_ALIASES.fetch(_1, _1) }
      @separator = @info.fetch('fsa.dict.separator')
      @sepbyte = @separator.bytes.first

      @decoder = choose_decoder(@info.fetch('fsa.dict.encoder'))
    end

    def read_values(path)
      File.exist?(path) or fail ArgumentError, "#{path} does not exist"
      File.read(path).split("\n")
          .map { _1.sub(/\#.*$/, '').strip }.reject(&:empty?)
          .to_h { _1.split('=', 2) }
    end

    def choose_decoder(name)
      DECODERS.fetch(name.upcase) { fail ArgumentError, "Encoder #{name} is not supported yet" }
              .then(&method(:method))
    end

    def suffix(source, encoded)
      truncate_suf = encoded[0...1].bytes.first.-(65) & 0xff # 65 is 'A'
      # TODO: If remove == 255, means "remove all"
      source[0...source.size - truncate_suf] + encoded[1..]
    end

    def prefix_suffix(source, encoded)
      truncate_pref, truncate_suf = encoded[0...2].bytes.first(2).map { |b| (b - 65) & 0xff } # 65 is 'A'
      # TODO: If remove == 255, means "remove all"

      source[truncate_pref...source.size - truncate_suf] + encoded[2..]
    end
  end
end
