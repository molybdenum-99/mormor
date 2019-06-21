# frozen_string_literal: true

module MorMor
  class FSA
    # Rubyfied port of ByteSequenceIterator.java
    #
    # See: https://github.com/morfologik/morfologik-stemming/blob/master/morfologik-fsa/src/main/java/morfologik/fsa/ByteSequenceIterator.java
    #
    # From some node of automaton, it iterates through all paths starting at that node to their end,
    # and yields each full path packed into original dictionary bytes string.
    class Enumerator
      def initialize(fsa, node)
        @fsa = fsa
        @arcs_stack = []
        @sequence = []

        unless (first = fsa.first_arc(node)).zero? # rubocop:disable Style/GuardClause
          arcs_stack << first
        end
      end

      def each
        return to_enum(__method__) unless block_given?

        while (el = advance)
          yield el.pack('C*')
        end
      end

      include Enumerable

      private

      attr_reader :fsa, :arcs_stack, :sequence

      # Method is left unsplit to leave original algorithm recognizable, hence rubocop:disable
      def advance # rubocop:disable Metrics/AbcSize
        until arcs_stack.empty?
          arc = arcs_stack.last

          if arc.zero?
            # OC: Remove the current node from the queue.
            arcs_stack.pop
            next
          end

          # OC: Go to the next arc, but leave it on the stack
          # so that we keep the recursion depth level accurate.
          arcs_stack[-1] = fsa.next_arc(arc)

          sequence[arcs_stack.count - 1] = fsa.arc_label(arc)

          # OC: Recursively descend into the arc's node.
          arcs_stack.push(fsa.end_node(arc)) unless fsa.terminal_arc?(arc)

          if fsa.final_arc?(arc)
            sequence.slice!(arcs_stack.count)
            return sequence
          end
        end

        nil
      end
    end
  end
end
