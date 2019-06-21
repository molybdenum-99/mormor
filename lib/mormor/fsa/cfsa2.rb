# frozen_string_literal: true

module MorMor
  class FSA
    # Port of CFSA2.java
    #
    # See constant description and other docs there:
    # https://github.com/morfologik/morfologik-stemming/blob/master/morfologik-fsa/src/main/java/morfologik/fsa/CFSA2.java
    class CFSA2 < FSA
      NUMBERS = 1 << 8
      BIT_TARGET_NEXT = 1 << 7
      LABEL_INDEX_BITS = 5
      LABEL_INDEX_MASK = (1 << LABEL_INDEX_BITS) - 1
      BIT_LAST_ARC = 1 << 6
      BIT_FINAL_ARC = 1 << 5

      def initialize(io)
        # Java's short = "network (big-endian)"
        flag_bits = io.read(2).unpack('n').first # rubocop:disable Style/UnpackFirst -- doesn't work under 2.3
        @numbers = flag_bits.allbits?(NUMBERS)

        mapping_size = io.getbyte & 0xff
        @mapping = io.read(mapping_size).unpack('c*')

        @arcs = io.read.unpack('c*')
      end

      def root_node
        destination_node_offset(first_arc(0))
      end

      # Navigating through arcs
      def first_arc(node)
        numbers? ? skip_v_int(node) : node
      end

      def end_node(arc)
        destination_node_offset(arc)
      end

      # Examining arcs
      def arc_label(arc)
        index = arcs[arc] & LABEL_INDEX_MASK
        index.positive? ? mapping[index] : arcs[arc + 1]
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
          # OC: Follow until the last arc of this state.
          arc = next_arc(arc) until last_arc?(arc)

          # OC: And return the byte right after it.
          skip_arc(arc)
        else
          # OC: The destination node address is v-coded. v-code starts either
          # at the next byte (label indexed) or after the next byte (label explicit).
          read_v_int(arcs, arc + (arcs[arc].anybits?(LABEL_INDEX_MASK) ? 1 : 2))
        end
      end

      def next_set?(arc)
        arcs[arc].allbits?(BIT_TARGET_NEXT)
      end

      def skip_arc(offset)
        flag = arcs[offset]
        offset += 1

        # OC: Explicit label?
        offset += 1 if flag.nobits?(LABEL_INDEX_MASK)

        # OC: Explicit goto?
        offset = skip_v_int(offset) if flag.nobits?(BIT_TARGET_NEXT)

        offset
      end
    end
  end
end
