module Activity
  class EventContractCoverage
    ASSERTION_HELPERS = {
      assert_activity_event: :action,
      assert_backfill: :action,
      assert_activity_events: :actions
    }.freeze

    def self.actions_in(source)
      new(source).actions
    end

    def initialize(source)
      @source = source
    end

    def actions
      walk(RubyVM::AbstractSyntaxTree.parse(source)).filter_map do |node|
        actions_from_assertion(node) if activity_assertion?(node)
      end.flatten.uniq
    end

    private
      attr_reader :source

      def walk(node, &block)
        return enum_for(__method__, node) unless block
        return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

        yield node
        node.children.each { |child| walk(child, &block) }
      end

      def activity_assertion?(node)
        node.type == :FCALL && ASSERTION_HELPERS.key?(node.children.first)
      end

      def actions_from_assertion(node)
        expected_key = ASSERTION_HELPERS.fetch(node.children.first)
        keyword_pairs(node.children[1]).each do |key, value|
          next unless key == expected_key

          return literal_strings(value)
        end
        []
      end

      def literal_strings(node)
        return [ node.children.first ] if node&.type == :STR
        return [] unless node&.type == :LIST

        values = node.children.compact
        return [] unless values.all? { |value| value.type == :STR }

        values.map { |value| value.children.first }
      end

      def keyword_pairs(arguments)
        hash = find_hash(arguments)
        return [] unless hash

        pairs = hash.children.first
        return [] unless pairs&.type == :LIST

        pairs.children.each_slice(2).filter_map do |key, value|
          [ key.children.first, value ] if key&.type == :LIT
        end
      end

      def find_hash(node)
        return node if node.is_a?(RubyVM::AbstractSyntaxTree::Node) && node.type == :HASH
        return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

        node.children.each do |child|
          found = find_hash(child)
          return found if found
        end
        nil
      end
  end
end
