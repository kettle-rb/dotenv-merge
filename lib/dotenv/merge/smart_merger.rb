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
    #
    # @example With node_typing for per-node-type preferences
    #   merger = SmartMerger.new(template, dest,
    #     node_typing: { "EnvLine" => ->(n) { NodeTyping.with_merge_type(n, :secret) } },
    #     preference: { default: :destination, secret: :template })
    class SmartMerger < ::Ast::Merge::SmartMergerBase
      # Initialize a new SmartMerger
      #
      # @param template_content [String] Content of the template dotenv file
      # @param dest_content [String] Content of the destination dotenv file
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param preference [Symbol, Hash] :destination, :template, or per-type Hash
      # @param add_template_only_nodes [Boolean] Whether to add template-only env vars
      #   (default: false)
      # @param freeze_token [String] Token for freeze block markers
      #   (default: "dotenv-merge")
      # @param match_refiner [#call, nil] Match refiner for fuzzy matching
      # @param regions [Array<Hash>, nil] Region configurations for nested merging
      # @param region_placeholder [String, nil] Custom placeholder for regions
      # @param node_typing [Hash{Symbol,String => #call}, nil] Node typing configuration
      #   for per-node-type merge preferences
      # @param options [Hash] Additional options for forward compatibility
      def initialize(
        template_content,
        dest_content,
        signature_generator: nil,
        preference: :destination,
        add_template_only_nodes: false,
        freeze_token: nil,
        match_refiner: nil,
        regions: nil,
        region_placeholder: nil,
        node_typing: nil,
        **options
      )
        super(
          template_content,
          dest_content,
          signature_generator: signature_generator,
          preference: preference,
          add_template_only_nodes: add_template_only_nodes,
          freeze_token: freeze_token,
          match_refiner: match_refiner,
          regions: regions,
          region_placeholder: region_placeholder,
          node_typing: node_typing,
          **options
        )
      end

      protected

      # @return [Class] The analysis class for dotenv files
      def analysis_class
        FileAnalysis
      end

      # @return [String] The default freeze token
      def default_freeze_token
        "dotenv-merge"
      end

      # @return [Class, nil] No separate resolver class for dotenv
      def resolver_class
        nil
      end

      # @return [Class, nil] Result class (built with analysis args)
      def result_class
        nil
      end

      # Build the result with required analysis arguments
      def build_result
        MergeResult.new(@template_analysis, @dest_analysis)
      end

      # @return [Class] The template parse error class for dotenv
      def template_parse_error_class
        ParseError
      end

      # @return [Class] The destination parse error class for dotenv
      def destination_parse_error_class
        ParseError
      end

      # Perform the dotenv-specific merge with custom alignment logic
      #
      # @return [MergeResult] The merge result
      def perform_merge
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

        # Resolve preference (handles both Symbol and Hash preferences)
        resolved_pref = resolve_preference(entry[:template_stmt], entry[:dest_stmt])

        case resolved_pref
        when :template
          @result.add_from_template(entry[:template_index], decision: MergeResult::DECISION_TEMPLATE)
        when :destination
          @result.add_from_destination(entry[:dest_index], decision: MergeResult::DECISION_DESTINATION)
        else
          @result.add_from_destination(entry[:dest_index], decision: MergeResult::DECISION_DESTINATION)
        end
      end

      # Resolve preference for a matched pair
      # @param template_stmt [Object] Template statement
      # @param dest_stmt [Object] Destination statement
      # @return [Symbol] :template or :destination
      def resolve_preference(template_stmt, dest_stmt)
        return @preference if @preference.is_a?(Symbol)

        # Hash preference - check for node_typing-based merge_types
        if @preference.is_a?(Hash)
          # Apply node_typing if configured
          typed_template = apply_node_typing(template_stmt)
          apply_node_typing(dest_stmt)

          # Check template merge_type first
          if Ast::Merge::NodeTyping.typed_node?(typed_template)
            merge_type = typed_template.merge_type
            return @preference[merge_type] if @preference.key?(merge_type)
          end

          # Fall back to default
          return @preference[:default] || :destination
        end

        :destination
      end

      # Apply node typing to a statement if node_typing is configured
      # @param stmt [Object] The statement
      # @return [Object] The statement, possibly wrapped with merge_type
      def apply_node_typing(stmt)
        return stmt unless @node_typing
        return stmt unless stmt

        # Check by class name
        type_key = stmt.class.name&.split("::")&.last
        callable = @node_typing[type_key] || @node_typing[type_key&.to_sym]
        return callable.call(stmt) if callable

        stmt
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
