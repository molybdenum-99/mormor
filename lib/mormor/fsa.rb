# frozen_string_literal: true

require_relative 'fsa/enumerator'

module MorMor
  class FSA
    MAGIC =
      ('\\'.ord << 24) |
      ('f'.ord  << 16) |
      ('s'.ord  << 8)  |
      'a'.ord

    # LanguageTool seems to use CFSA2
    VERSIONS = {
      5 => 'FSA5',
      0xC5 => 'CFSA',
      0xc6 => 'CFSA2'
    }.freeze

    NUMBERS = 1 << 8
    BIT_TARGET_NEXT = 1 << 7
    LABEL_INDEX_BITS = 5
    LABEL_INDEX_MASK = (1 << LABEL_INDEX_BITS) - 1
    BIT_LAST_ARC = 1 << 6
    BIT_FINAL_ARC = 1 << 5

    Match = Struct.new(:kind, :position, :node)

    attr_reader :file

    def initialize(path)
      @file = File.open(path, 'rb')
      read_header
      read_automaton
    end

    def read_header
      # FIXME: We are Ruby, we can just file.read(4) == '\fsa' ?..
      (file.getbyte == ((MAGIC >> 24))) &&
        (file.getbyte == ((MAGIC >> 16) & 0xff)) &&
        (file.getbyte == ((MAGIC >> 8) & 0xff)) &&
        (file.getbyte == (MAGIC & 0xff)) ||
        raise('Invalid file header, probably not an FSA.')

      version = file.getbyte
      VERSIONS.fetch(version)
    end

    def read_automaton
      # Java's short = "network (big-endian)"
      flag_bits = file.read(2).unpack1('n')

      @numbers = flag_bits.allbits?(NUMBERS)

      mapping_size = file.getbyte & 0xff
      @mapping = file.read(mapping_size).unpack('C*')
      @arcs = file.read.unpack('c*')
    end

    def first_arc(node)
      numbers? ? skip_v_int(node) : node
    end

    def next_arc(arc)
      last_arc?(arc) ? 0 : skip_arc(arc)
    end

    def each(node = root_node, &block)
      Enumerator.new(self, node).each(&block)
    end

    include Enumerable

    def root_node
      destination_node_offset(first_arc(0))
    end

    def terminal_arc?(arc)
      destination_node_offset(arc).zero?
    end

    def last_arc?(arc)
      arcs[arc].allbits?(BIT_LAST_ARC)
    end

    def final_arc?(arc)
      arcs[arc].allbits?(BIT_FINAL_ARC)
    end

    def arc_label(arc)
      index = arcs[arc] & LABEL_INDEX_MASK
      index.positive? ? mapping[index] : arcs[arc + 1]
    end

    def arc(node, label)
      # FIXME: It is some enumerable + detect, obviously
      arc = first_arc(node)
      until arc.zero?
        return arc if arc_label(arc) == label

        arc = next_arc(arc)
      end

      # An arc labeled with "label" not found.
      0
    end

    def end_node(arc)
      destination_node_offset(arc)
    end

    def skip_arc(offset)
      flag = arcs[offset]
      offset += 1

      # Explicit label?
      offset += 1 if flag.nobits?(LABEL_INDEX_MASK)

      # Explicit goto?
      offset = skip_v_int(offset) if flag.nobits?(BIT_TARGET_NEXT)

      offset
    end

    # NB: Funnil enough, dictionary is only ready for :sequence_is_a_prefix case...
    def match(sequence, node = root_node)
      return Match.new(:no) if node.zero?

      sequence.each_with_index do |byte, i|
        a = arc(node, byte)

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

    private

    attr_reader :arcs, :mapping

    def numbers?
      @numbers
    end

    def skip_v_int(offset)
      offset += 1 while arcs[offset].negative?
      offset + 1
    end

    def read_v_int(array, offset)
      b = array[offset]
      value = b & 0x7F
      shift = 7
      while b.negative?
        offset += 1
        b = array[offset]
        value |= (b & 0x7F) << shift
        shift += 7
      end

      value
    end

    def destination_node_offset(arc)
      if next_set?(arc)
        # Follow until the last arc of this state.
        arc = next_arc(arc) until last_arc?(arc)

        # And return the byte right after it.
        skip_arc(arc)
      else
        # The destination node address is v-coded. v-code starts either
        # at the next byte (label indexed) or after the next byte (label explicit).
        read_v_int(arcs, arc + (arcs[arc].anybits?(LABEL_INDEX_MASK) ? 1 : 2))
      end
    end

    def next_set?(arc)
      arcs[arc].allbits?(BIT_TARGET_NEXT)
    end
  end
end
