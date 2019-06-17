# frozen_string_literal: true

module MorMor
  class FSA
    class Enumerator
      def initialize(fsa, node)
        @fsa = fsa
        @arcs = []
        @buffer = []
        restart_from(node) unless fsa.first_arc(node).zero?
      end

      def each
        return to_enum(__method__) unless block_given?

        while (el = advance)
          yield el.pack('C*')
        end
      end

      include Enumerable

      private

      attr_reader :fsa, :arcs, :position, :buffer

      def advance
        return if position.zero?

        while position.positive?
          last_index = position - 1
          arc = arcs[last_index]

          if arc.zero?
            # Remove the current node from the queue.
            @position -= 1
            next
          end

          # Go to the next arc, but leave it on the stack
          # so that we keep the recursion depth level accurate.
          arcs[last_index] = fsa.next_arc(arc)
          arcs.map! { |e| e || 0 } # fill blanks with zeroes...

          buffer[last_index] = fsa.arc_label(arc)

          # Recursively descend into the arc's node.
          push_node(fsa.end_node(arc)) unless fsa.terminal_arc?(arc)

          if fsa.final_arc?(arc)
            @buffer = buffer[0..last_index]
            return buffer
          end
        end

        nil
      end

      def restart_from(node)
        @position = 0
        push_node(node)
      end

      def push_node(node)
        arcs[position] = fsa.first_arc(node)
        arcs.map! { |e| e || 0 } # fill blanks with zeroes...
        @position += 1
      end
    end
  end
end
