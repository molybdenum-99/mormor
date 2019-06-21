# frozen_string_literal: true

module MorMor
  class FSA
    # Port of FSA5.java
    #
    # See constant description and other docs there:
    # https://github.com/morfologik/morfologik-stemming/blob/master/morfologik-fsa/src/main/java/morfologik/fsa/FSA5.java
    class FSA5 < FSA
      BIT_FINAL_ARC = 1 << 0
      BIT_LAST_ARC = 1 << 1
      BIT_TARGET_NEXT = 1 << 2
      ADDRESS_OFFSET = 1

      def initialize(io)
        @filler = io.getbyte
        @annotation = io.getbyte
        hgtl = io.getbyte

        # OC: Determine if the automaton was compiled with NUMBERS. If so, modify
        # ctl and goto fields accordingly.

        # zverok: ???? This variables/flags doesn't used at all
        # flags = [FLEXIBLE, STOPBIT, NEXTBIT]
        # flags << NUMBERS if hgtl.anybits?(0xf0)

        @node_data_length = (hgtl >> 4) & 0x0f
        @gtl = hgtl & 0x0f

        @arcs = io.read.unpack('c*')
      end

      def root_node
        # OC: Skip dummy node marking terminating state.
        epsilon_node = skip_arc(first_arc(0))

        # OC: And follow the epsilon node's first (and only) arc.
        destination_node_offset(first_arc(epsilon_node))
      end

      # Navigating through arcs
      def first_arc(node)
        @node_data_length + node
      end

      def end_node(arc)
        destination_node_offset(arc)
      end

      # Examining arcs
      def arc_label(arc)
        arcs[arc]
      end

      def final_arc?(arc)
        arcs[arc + ADDRESS_OFFSET].allbits?(BIT_FINAL_ARC)
      end

      def last_arc?(arc)
        arcs[arc + ADDRESS_OFFSET].allbits?(BIT_LAST_ARC)
      end

      def terminal_arc?(arc)
        destination_node_offset(arc).zero?
      end

      private

      attr_reader :arcs, :gtl

      def decode_from_bytes(arcs, start, n)
        (n - 1).downto(0).inject(0) { |r, i| r << 8 | (arcs[start + i] & 0xff) }
      end

      def destination_node_offset(arc)
        if next_set?(arc)
          # OC: The destination node follows this arc in the array.
          skip_arc(arc)
        else
          # OC: The destination node address has to be extracted from the arc's
          # goto field.
          decode_from_bytes(arcs, arc + ADDRESS_OFFSET, gtl) >> 3
        end
      end

      def next_set?(arc)
        arcs[arc + ADDRESS_OFFSET].allbits?(BIT_TARGET_NEXT)
      end

      # OC: Read the arc's layout and skip as many bytes, as needed.
      def skip_arc(offset)
        offset + if next_set?(offset)
                   1 + 1   # OC: label + flags
                 else
                   1 + gtl # OC: label + flags/address
                 end
      end
    end
  end
end
