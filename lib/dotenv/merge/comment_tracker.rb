# frozen_string_literal: true

module Dotenv
  module Merge
    # Extracts and tracks dotenv comments with their line numbers from source.
    #
    # Dotenv supports hash-style comments as either:
    # - full-line comments (`# comment`)
    # - safe inline comments on unquoted assignments (`KEY=value # comment`)
    #
    # Slice 1 intentionally stays conservative around quoted values. `#` inside
    # quoted values is not treated as a comment, and quoted assignments with
    # trailing comment-like text are left for later slices.
    class CommentTracker
      FULL_LINE_COMMENT_REGEX = /\A(?<indent>\s*)#\s?(?<text>.*)\z/
      INLINE_COMMENT_REGEX = /\s+#\s?(?<text>.*)\z/

      attr_reader :comments, :lines

      def initialize(source_or_lines)
        @line_objects = normalize_line_objects(source_or_lines)
        @lines = @line_objects.map(&:raw)
        @comments = extract_comments
        @comments_by_line = @comments.group_by { |comment| comment[:line] }
      end

      def comment_at(line_num)
        @comments_by_line[line_num]&.first
      end

      def comment_nodes
        @comment_nodes ||= @comments.map do |comment|
          Ast::Merge::Comment::TrackedHashAdapter.node(comment, style: :hash_comment)
        end
      end

      def comment_node_at(line_num)
        comment = comment_at(line_num)
        return unless comment

        Ast::Merge::Comment::TrackedHashAdapter.node(comment, style: :hash_comment)
      end

      def comments_in_range(range)
        @comments.select { |comment| range.cover?(comment[:line]) }
      end

      def comment_region_for_range(range, kind:, full_line_only: false)
        selected = comments_in_range(range)
        selected = selected.select { |comment| comment[:full_line] } if full_line_only

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: kind,
          comments: selected,
          style: :hash_comment,
          metadata: {
            range: range,
            full_line_only: full_line_only,
            source: :comment_tracker,
          },
        )
      end

      def leading_comment_region_before(line_num, comments: nil)
        selected = comments || leading_comments_before(line_num)
        selected = selected.select { |comment| comment[:full_line] }
        return if selected.empty?

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: :leading,
          comments: selected,
          style: :hash_comment,
          metadata: {
            line_num: line_num,
            source: :comment_tracker,
          },
        )
      end

      def inline_comment_region_at(line_num, comment: nil)
        selected = [comment || inline_comment_at(line_num)].compact
        return if selected.empty?

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: :inline,
          comments: selected,
          style: :hash_comment,
          metadata: {
            line_num: line_num,
            source: :comment_tracker,
          },
        )
      end

      def comment_attachment_for(owner, line_num: nil, leading_comments: nil, inline_comment: nil, **metadata)
        resolved_line_num = line_num || owner_line_num(owner)
        leading_region = if resolved_line_num
          leading_comment_region_before(resolved_line_num, comments: leading_comments)
        end
        inline_region = if resolved_line_num
          inline_comment_region_at(resolved_line_num, comment: inline_comment)
        end

        Ast::Merge::Comment::Attachment.new(
          owner: owner,
          leading_region: leading_region,
          inline_region: inline_region,
          metadata: metadata.merge(
            line_num: resolved_line_num,
            source: :comment_tracker,
          ),
        )
      end

      def leading_comments_before(line_num)
        leading = []
        current = line_num - 1

        current -= 1 while current >= 1 && blank_line?(current)

        while current >= 1
          comment = comment_at(current)
          break unless comment && comment[:full_line]

          leading.unshift(comment)
          current -= 1
          current -= 1 while current >= 1 && blank_line?(current)
        end

        leading
      end

      def inline_comment_at(line_num)
        comment = comment_at(line_num)
        comment if comment && !comment[:full_line]
      end

      def full_line_comment?(line_num)
        comment = comment_at(line_num)
        comment&.dig(:full_line) || false
      end

      def blank_line?(line_num)
        return false if line_num < 1 || line_num > @lines.length

        @lines[line_num - 1].to_s.strip.empty?
      end

      def line_at(line_num)
        return if line_num < 1 || line_num > @lines.length

        @lines[line_num - 1]
      end

      def augment(owners: [], **options)
        Ast::Merge::Comment::Augmenter.new(
          lines: @lines,
          comments: @comments,
          owners: owners,
          style: :hash_comment,
          total_comment_count: @comments.size,
          inline_comment_count: @comments.count { |comment| !comment[:full_line] },
          **options,
        )
      end

      private

      def normalize_line_objects(source_or_lines)
        case source_or_lines
        when String
          source_or_lines.lines.each_with_index.map do |line, index|
            EnvLine.new(line.chomp, index + 1)
          end
        else
          Array(source_or_lines)
        end
      end

      def extract_comments
        @line_objects.filter_map do |line|
          if line.comment?
            build_full_line_comment(line)
          elsif line.assignment?
            build_inline_comment(line)
          end
        end
      end

      def build_full_line_comment(line)
        match = line.raw.match(FULL_LINE_COMMENT_REGEX)
        return unless match

        {
          line: line.line_number,
          indent: match[:indent].length,
          text: match[:text].to_s,
          full_line: true,
          raw: line.raw,
        }
      end

      def build_inline_comment(line)
        value_part = raw_value_part(line)
        return if value_part.nil?

        stripped_value = value_part.lstrip
        return if stripped_value.start_with?("\"", "'")

        match = value_part.match(INLINE_COMMENT_REGEX)
        return unless match

        text = match[:text].to_s
        raw = text.empty? ? "#" : "# #{text}"

        {
          line: line.line_number,
          indent: leading_indent(line.raw),
          text: text,
          full_line: false,
          raw: raw,
        }
      end

      def raw_value_part(line)
        raw = line.raw.sub(/\A\s*export\s+/, "")
        _key_part, value_part = raw.split("=", 2)
        value_part
      end

      def leading_indent(raw)
        raw[/\A\s*/].to_s.length
      end

      def owner_line_num(owner)
        return owner.start_line if owner.respond_to?(:start_line) && owner.start_line
        return owner.line_number if owner.respond_to?(:line_number)

        nil
      end
    end
  end
end
