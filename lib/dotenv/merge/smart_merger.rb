# frozen_string_literal: true

module Dotenv
  module Merge
    # Smart merger for dotenv files.
    # Intelligently combines template and destination dotenv files by matching
    # environment variable names and preserving customizations.
    #
    # @example Basic merge
    #   merger = SmartMerger.new(template_content, dest_content)
    #   result = merger.merge
    #   puts result.to_s
    #
    # @example With options
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     preference: :template,
    #     add_template_only_nodes: true,
    #   )
    #   result = merger.merge
    class SmartMerger
      # @return [FileAnalysis] Analysis of template file
      attr_reader :template_analysis

      # @return [FileAnalysis] Analysis of destination file
      attr_reader :dest_analysis

      # Initialize a new SmartMerger
      #
      # @param template_content [String] Content of the template dotenv file
      # @param dest_content [String] Content of the destination dotenv file
      # @param preference [Symbol] Which version to prefer on match
      #   (:template or :destination, default: :destination)
      # @param add_template_only_nodes [Boolean] Whether to add template-only env vars
      #   (default: false)
      # @param freeze_token [String] Token for freeze block markers
      #   (default: "dotenv-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      def initialize(
        template_content,
        dest_content,
        preference: :destination,
        add_template_only_nodes: false,
        freeze_token: FileAnalysis::DEFAULT_FREEZE_TOKEN,
        signature_generator: nil
      )
        @preference = preference
        @add_template_only_nodes = add_template_only_nodes

        # Parse template
        @template_analysis = FileAnalysis.new(
          template_content,
          freeze_token: freeze_token,
          signature_generator: signature_generator,
        )

        # Parse destination
        @dest_analysis = FileAnalysis.new(
          dest_content,
          freeze_token: freeze_token,
          signature_generator: signature_generator,
        )

        @result = MergeResult.new(@template_analysis, @dest_analysis)
      end

      # Perform the merge operation
      #
      # @return [String] The merged content as a string
      def merge
        merge_result.to_s
      end

      # Perform the merge operation and return the full result object
      #
      # @return [MergeResult] The merge result containing merged content
      def merge_result
        return @merge_result if @merge_result

        @merge_result = DebugLogger.time("SmartMerger#merge") do
          alignment = align_statements

          DebugLogger.debug("Alignment complete", {
            total_entries: alignment.size,
            matches: alignment.count { |e| e[:type] == :match },
            template_only: alignment.count { |e| e[:type] == :template_only },
            dest_only: alignment.count { |e| e[:type] == :dest_only },
          })

          process_alignment(alignment)
          @result
        end
      end

      private

      # Align statements between template and destination
      # @return [Array<Hash>] Alignment entries
      def align_statements
        template_stmts = @template_analysis.statements
        dest_stmts = @dest_analysis.statements

        # Build signature maps
        _template_sigs = build_signature_map(template_stmts, @template_analysis)
        dest_sigs = build_signature_map(dest_stmts, @dest_analysis)

        alignment = []
        matched_dest_indices = Set.new

        # First pass: find matches for template statements
        template_stmts.each_with_index do |stmt, t_idx|
          sig = @template_analysis.generate_signature(stmt)

          if sig && dest_sigs.key?(sig)
            d_idx = dest_sigs[sig]
            alignment << {
              type: :match,
              template_stmt: stmt,
              dest_stmt: dest_stmts[d_idx],
              template_index: t_idx,
              dest_index: d_idx,
              signature: sig,
            }
            matched_dest_indices << d_idx
          else
            alignment << {
              type: :template_only,
              template_stmt: stmt,
              template_index: t_idx,
              signature: sig,
            }
          end
        end

        # Second pass: add destination-only statements
        dest_stmts.each_with_index do |stmt, d_idx|
          next if matched_dest_indices.include?(d_idx)

          alignment << {
            type: :dest_only,
            dest_stmt: stmt,
            dest_index: d_idx,
            signature: @dest_analysis.generate_signature(stmt),
          }
        end

        # Sort by destination order (preserve dest structure), then template order for additions
        sort_alignment(alignment, dest_stmts.size)
      end

      # Build a map of signature => statement index
      # @param statements [Array] Statements
      # @param analysis [FileAnalysis] Analysis for signature generation
      # @return [Hash]
      def build_signature_map(statements, analysis)
        map = {}
        statements.each_with_index do |stmt, idx|
          sig = analysis.generate_signature(stmt)
          # First occurrence wins
          map[sig] ||= idx if sig
        end
        map
      end

      # Sort alignment entries for output
      # @param alignment [Array<Hash>] Alignment entries
      # @param dest_size [Integer] Number of destination statements
      # @return [Array<Hash>]
      def sort_alignment(alignment, dest_size)
        alignment.sort_by do |entry|
          case entry[:type]
          when :match
            # Matches: use destination position
            [entry[:dest_index], 0]
          when :dest_only
            # Destination-only: use destination position
            [entry[:dest_index], 0]
          when :template_only
            # Template-only: add at end, in template order
            [dest_size + entry[:template_index], 1]
          end
        end
      end

      # Process alignment entries and build result
      # @param alignment [Array<Hash>] Alignment entries
      # @return [void]
      def process_alignment(alignment)
        alignment.each do |entry|
          case entry[:type]
          when :match
            process_match(entry)
          when :template_only
            process_template_only(entry)
          when :dest_only
            process_dest_only(entry)
          end
        end
      end

      # Process a matched entry
      # @param entry [Hash] Alignment entry
      # @return [void]
      def process_match(entry)
        dest_stmt = entry[:dest_stmt]

        # Freeze blocks always win
        if dest_stmt.is_a?(FreezeNode)
          @result.add_freeze_block(dest_stmt)
          return
        end

        # Apply preference
        case @preference
        when :template
          @result.add_from_template(entry[:template_index], decision: MergeResult::DECISION_TEMPLATE)
        when :destination
          @result.add_from_destination(entry[:dest_index], decision: MergeResult::DECISION_DESTINATION)
        else
          @result.add_from_destination(entry[:dest_index], decision: MergeResult::DECISION_DESTINATION)
        end
      end

      # Process a template-only entry
      # @param entry [Hash] Alignment entry
      # @return [void]
      def process_template_only(entry)
        return unless @add_template_only_nodes

        # Skip comments and blank lines from template
        stmt = entry[:template_stmt]
        return if stmt.is_a?(EnvLine) && (stmt.comment? || stmt.blank?)

        @result.add_from_template(entry[:template_index], decision: MergeResult::DECISION_ADDED)
      end

      # Process a destination-only entry
      # @param entry [Hash] Alignment entry
      # @return [void]
      def process_dest_only(entry)
        dest_stmt = entry[:dest_stmt]

        if dest_stmt.is_a?(FreezeNode)
          @result.add_freeze_block(dest_stmt)
        else
          @result.add_from_destination(entry[:dest_index], decision: MergeResult::DECISION_DESTINATION)
        end
      end
    end
  end
end
