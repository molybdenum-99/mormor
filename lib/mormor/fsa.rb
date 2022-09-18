# frozen_string_literal: true

require_relative 'fsa/enumerator'
require_relative 'fsa/fsa5'
require_relative 'fsa/cfsa2'

module MorMor
  # @private
  #
  # This class and its subclasses contains a loose simplified port of the whole `morfologik-fsa`
  # package.
  # Original source at: https://github.com/morfologik/morfologik-stemming/tree/master/morfologik-fsa/src/main/java/morfologik/fsa
  #
  # NB: TBH, I don't always understand deeply what am I doing here. Just ported Java algorithms
  # statement-by-statement, then rubyfied a bit and debugged in parallel with original package to
  # make sure it produces the same result.
  #
  # Code contains some of my comments, original implementations referred where appropriate.
  # Also, in more straightforwardly ported code, original comments are left and marked with "OC:".
  #
  class FSA
    # LanguageTool seems to use CFSA2 and FSA5, so CFSA is not implemented.
    VERSIONS = {
      5 => 'FSA5',
      0xC5 => 'CFSA',
      0xc6 => 'CFSA2'
    }.freeze

    Match = Struct.new(:kind, :position, :node)

    class << self
      def read(path)
        io = File.open(path, 'rb')
        io.read(4) == '\\fsa' or fail ArgumentError, 'Invalid file header, probably not an FSA.'
        choose_impl(io.getbyte).new(io)
      end

      private

      def choose_impl(version_byte)
        VERSIONS
          .fetch(version_byte) { fail ArgumentError 'Unsupported version byte, probably not FSA' }
          .tap { |name|
            constants.include?(name.to_sym) or
              fail ArgumentError "Unsupported version: #{name}"
          }
          .then(&method(:const_get))
      end
    end

    def each_sequence(from: root_node, &block)
      Enumerator.new(self, from).then { block ? _1.each(&block) : _1 }
    end

    def next_arc(arc)
      last_arc?(arc) ? 0 : skip_arc(arc)
    end

    def each_arc(from:)
      return to_enum(__method__, from: from) unless block_given?

      arc = first_arc(from)
      until arc.zero?
        yield arc
        arc = next_arc(arc)
      end
    end

    def find_arc(node, label)
      each_arc(from: node).detect { arc_label(_1) == label } || 0
    end

    # Port of FSATraversal.java
    # Method is left unsplit to leave original algorithm recognizable, hence rubocop:disable's
    def match(sequence, node = root_node) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      return Match.new(:no) if node.zero?

      sequence.each_with_index do |byte, i|
        a = find_arc(node, byte)

        case
        when a.zero?
          return i.zero? ? Match.new(:no, i, node) : Match.new(:automaton_has_prefix, i, node)
        when i + 1 == sequence.size && final_arc?(a)
          return Match.new(:exact, i, node)
        when terminal_arc?(a)
          return Match.new(:automaton_has_prefix, i + 1, node)
        else
          node = end_node(a)
        end
      end

      Match.new(:sequence_is_a_prefix, 0, node)
    end
  end
end
