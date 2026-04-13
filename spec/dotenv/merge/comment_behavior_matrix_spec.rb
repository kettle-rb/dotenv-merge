# frozen_string_literal: true

require "ast/merge/rspec/shared_examples"

RSpec.describe "dotenv comment behavior matrix" do
  extend Ast::Merge::RSpec::CommentBehaviorMatrixAdapters

  it_behaves_like "Ast::Merge::CommentBehaviorMatrix" do
    hash_comment_line_based_comment_matrix_adapter(
      analysis_class: Dotenv::Merge::FileAnalysis,
      merger_class: Dotenv::Merge::SmartMerger,
      structural_owners_reader: ->(analysis) { analysis.structural_owners.grep(Dotenv::Merge::EnvLine) },
      owner_value_reader: ->(owner) { owner.value },
      line_builder: lambda do |name, value, inline: nil|
        line = "#{name}=#{value}"
        inline ? "#{line} # #{inline}" : line
      end,
      capabilities: {
        quoted_hash_inline_literals: "quoted values with trailing inline comments are not parsed natively",
        template_only_attached_comment_additions: "template-only additions intentionally stay comment-free",
        template_only_floating_comment_additions: "template-only additions intentionally stay comment-free",
        template_only_preamble_additions: "template-only additions intentionally stay comment-free",
        template_only_trailing_comment_additions: "template-only additions intentionally stay comment-free",
      },
      expected_literal_hash_value: "literal # hash",
    )
  end
end
