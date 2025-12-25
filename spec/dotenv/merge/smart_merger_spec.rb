# frozen_string_literal: true

RSpec.describe Dotenv::Merge::SmartMerger do
  describe "#initialize" do
    let(:template) { "API_KEY=template\n" }
    let(:destination) { "API_KEY=dest\n" }

    it "creates a merger" do
      merger = described_class.new(template, destination)
      expect(merger).to be_a(described_class)
    end

    it "has template_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.template_analysis).to be_a(Dotenv::Merge::FileAnalysis)
    end

    it "has dest_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.dest_analysis).to be_a(Dotenv::Merge::FileAnalysis)
    end
  end

  describe "#merge" do
    context "with identical files" do
      let(:content) do
        <<~DOTENV
          API_KEY=secret
          DATABASE_URL=postgres://localhost
        DOTENV
      end

      it "returns destination content" do
        merger = described_class.new(content, content)
        result = merger.merge_result
        expect(result.to_s).to include("API_KEY=secret")
        expect(result.to_s).to include("DATABASE_URL=postgres://localhost")
      end
    end

    context "with destination-only variables" do
      let(:template) { "API_KEY=template\n" }
      let(:destination) do
        <<~DOTENV
          API_KEY=dest
          CUSTOM_VAR=custom
        DOTENV
      end

      it "preserves destination-only variables" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.to_s).to include("CUSTOM_VAR=custom")
      end
    end

    context "with template-only variables" do
      let(:template) do
        <<~DOTENV
          API_KEY=template
          NEW_VAR=new_value
        DOTENV
      end
      let(:destination) { "API_KEY=dest\n" }

      context "when add_template_only_nodes is false (default)" do
        it "does not add template-only variables" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          expect(result.to_s).not_to include("NEW_VAR")
        end
      end

      context "when add_template_only_nodes is true" do
        it "adds template-only variables" do
          merger = described_class.new(template, destination, add_template_only_nodes: true)
          result = merger.merge_result
          expect(result.to_s).to include("NEW_VAR=new_value")
        end
      end
    end

    context "with matching variables" do
      let(:template) { "API_KEY=template_value\n" }
      let(:destination) { "API_KEY=dest_value\n" }

      context "when preference is :destination (default)" do
        it "uses destination version" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          expect(result.to_s).to include("API_KEY=dest_value")
          expect(result.to_s).not_to include("API_KEY=template_value")
        end
      end

      context "when preference is :template" do
        it "uses template version" do
          merger = described_class.new(template, destination, preference: :template)
          result = merger.merge_result
          expect(result.to_s).to include("API_KEY=template_value")
          expect(result.to_s).not_to include("API_KEY=dest_value")
        end
      end
    end

    context "with freeze blocks" do
      let(:template) do
        <<~DOTENV
          API_KEY=template_key
          SECRET=template_secret
        DOTENV
      end
      let(:destination) do
        <<~DOTENV
          API_KEY=dest_key
          # dotenv-merge:freeze
          SECRET=frozen_secret
          # dotenv-merge:unfreeze
        DOTENV
      end

      it "preserves freeze block content" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.to_s).to include("SECRET=frozen_secret")
        expect(result.to_s).to include("dotenv-merge:freeze")
        expect(result.to_s).to include("dotenv-merge:unfreeze")
      end

      it "respects destination preference for non-frozen variables" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.to_s).to include("API_KEY=dest_key")
      end
    end

    context "with comments and blank lines" do
      let(:template) do
        <<~DOTENV
          # Template comment
          API_KEY=template

          NEW_VAR=new
        DOTENV
      end
      let(:destination) do
        <<~DOTENV
          # Destination comment
          API_KEY=dest

          CUSTOM=custom
        DOTENV
      end

      it "preserves destination structure" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.to_s).to include("# Destination comment")
        expect(result.to_s).to include("CUSTOM=custom")
      end

      it "does not add template comments by default" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        # Template comments/blanks are skipped even with add_template_only_nodes
        expect(result.to_s).not_to include("# Template comment")
      end
    end

    context "with export statements" do
      let(:template) { "export API_KEY=template\n" }
      let(:destination) { "export API_KEY=dest\n" }

      it "matches exported variables" do
        merger = described_class.new(template, destination, preference: :template)
        result = merger.merge_result
        expect(result.to_s).to include("export API_KEY=template")
      end
    end

    context "complex merge scenario" do
      let(:template) do
        <<~DOTENV
          # Application config
          APP_NAME=MyApp
          APP_ENV=production
          DEBUG=false

          # Database
          DATABASE_URL=postgres://prod-server/myapp

          # New feature
          FEATURE_FLAG=enabled
        DOTENV
      end
      let(:destination) do
        <<~DOTENV
          # Application config
          APP_NAME=MyApp
          APP_ENV=development
          DEBUG=true

          # Database
          # dotenv-merge:freeze
          DATABASE_URL=postgres://localhost/myapp_dev
          # dotenv-merge:unfreeze

          # Custom local settings
          CUSTOM_PATH=/usr/local/custom
        DOTENV
      end

      it "produces correct merged output" do
        merger = described_class.new(
          template,
          destination,
          preference: :destination,
          add_template_only_nodes: true,
        )
        result = merger.merge_result

        # Destination values preserved
        expect(result.to_s).to include("APP_ENV=development")
        expect(result.to_s).to include("DEBUG=true")

        # Freeze block preserved
        expect(result.to_s).to include("DATABASE_URL=postgres://localhost/myapp_dev")
        expect(result.to_s).to include("dotenv-merge:freeze")

        # Destination-only preserved
        expect(result.to_s).to include("CUSTOM_PATH=/usr/local/custom")

        # Template-only added
        expect(result.to_s).to include("FEATURE_FLAG=enabled")
      end
    end
  end

  describe "custom freeze token" do
    let(:template) { "SECRET=template\n" }
    let(:destination) do
      <<~DOTENV
        # my-token:freeze
        SECRET=frozen
        # my-token:unfreeze
      DOTENV
    end

    it "uses custom freeze token" do
      merger = described_class.new(template, destination, freeze_token: "my-token")
      result = merger.merge_result
      expect(result.to_s).to include("SECRET=frozen")
      expect(result.to_s).to include("my-token:freeze")
    end

    it "ignores freeze with wrong token" do
      merger = described_class.new(template, destination, freeze_token: "other-token")
      result = merger.merge_result
      # Without recognizing freeze, it would match by key
      expect(result.to_s).to include("SECRET=")
    end
  end

  describe "merge result information" do
    let(:template) do
      <<~DOTENV
        API_KEY=template
        NEW_VAR=new
      DOTENV
    end
    let(:destination) do
      <<~DOTENV
        API_KEY=dest
        CUSTOM=custom
      DOTENV
    end

    it "provides summary" do
      merger = described_class.new(template, destination, add_template_only_nodes: true)
      result = merger.merge_result
      summary = result.summary

      expect(summary).to have_key(:total_decisions)
      expect(summary).to have_key(:total_lines)
      expect(summary).to have_key(:by_decision)
    end

    it "tracks decisions correctly" do
      merger = described_class.new(template, destination, add_template_only_nodes: true)
      result = merger.merge_result
      summary = result.summary

      # API_KEY matched (dest wins), CUSTOM is dest-only, NEW_VAR is template-only (added)
      expect(summary[:total_decisions]).to eq(3)
    end
  end

  describe "Hash preference with node_typing" do
    let(:template) do
      <<~DOTENV
        API_KEY=template_key
        SECRET=template_secret
      DOTENV
    end
    let(:destination) do
      <<~DOTENV
        API_KEY=dest_key
        SECRET=dest_secret
      DOTENV
    end

    context "with node_typing callable" do
      it "applies node_typing to resolve preference" do
        # Set up node_typing to mark API_KEY lines as :api_key type
        node_typing = {
          "EnvLine" => ->(stmt) {
            if stmt.key == "API_KEY"
              Ast::Merge::NodeTyping.with_merge_type(stmt, :api_key)
            else
              stmt
            end
          },
        }

        merger = described_class.new(
          template,
          destination,
          preference: {default: :destination, api_key: :template},
          node_typing: node_typing,
        )
        result = merger.merge_result

        # API_KEY should use template (node_typing marked it, preference[:api_key] = :template)
        expect(result.to_s).to include("API_KEY=template_key")
        # SECRET should use destination (default)
        expect(result.to_s).to include("SECRET=dest_secret")
      end
    end

    context "with Hash preference but no node_typing" do
      it "falls back to default preference" do
        merger = described_class.new(
          template,
          destination,
          preference: {default: :template},
        )
        result = merger.merge_result

        # All should use template (default)
        expect(result.to_s).to include("API_KEY=template_key")
        expect(result.to_s).to include("SECRET=template_secret")
      end
    end

    context "with Hash preference missing default" do
      it "falls back to :destination" do
        merger = described_class.new(
          template,
          destination,
          preference: {some_other_type: :template},
        )
        result = merger.merge_result

        # Should use destination (fallback when no match and no :default)
        expect(result.to_s).to include("API_KEY=dest_key")
        expect(result.to_s).to include("SECRET=dest_secret")
      end
    end
  end

  describe "freeze blocks in matched positions" do
    let(:template) do
      <<~DOTENV
        API_KEY=template_key
        SECRET=template_secret
      DOTENV
    end
    let(:destination) do
      <<~DOTENV
        # dotenv-merge:freeze
        API_KEY=frozen_key
        # dotenv-merge:unfreeze
        SECRET=dest_secret
      DOTENV
    end

    it "uses freeze block for matched entry" do
      merger = described_class.new(template, destination, preference: :template)
      result = merger.merge_result

      # Even with :template preference, freeze block content is preserved
      expect(result.to_s).to include("API_KEY=frozen_key")
      expect(result.to_s).to include("dotenv-merge:freeze")
      # Non-frozen matched variable uses preference
      expect(result.to_s).to include("SECRET=template_secret")
    end
  end

  describe "process_template_only with comments and blanks" do
    let(:template) do
      <<~DOTENV
        # Template comment
        API_KEY=template

        NEW_VAR=new_value
      DOTENV
    end
    let(:destination) { "OTHER_VAR=other\n" }

    it "adds only assignment lines from template" do
      merger = described_class.new(template, destination, add_template_only_nodes: true)
      result = merger.merge_result

      # API_KEY doesn't match anything in dest, so it's template-only
      expect(result.to_s).to include("API_KEY=template")
      expect(result.to_s).to include("NEW_VAR=new_value")
      # Comments and blank lines are skipped
      expect(result.to_s).not_to include("# Template comment")
    end
  end

  describe "process_dest_only with freeze blocks" do
    let(:template) { "API_KEY=template\n" }
    let(:destination) do
      <<~DOTENV
        API_KEY=dest
        # dotenv-merge:freeze
        FROZEN_VAR=frozen_value
        # dotenv-merge:unfreeze
        OTHER_VAR=other
      DOTENV
    end

    it "handles dest-only freeze blocks" do
      merger = described_class.new(template, destination)
      result = merger.merge_result

      # Freeze block (FROZEN_VAR) is dest-only and should be preserved with markers
      expect(result.to_s).to include("FROZEN_VAR=frozen_value")
      expect(result.to_s).to include("dotenv-merge:freeze")
      expect(result.to_s).to include("dotenv-merge:unfreeze")
      # Regular dest-only should also be preserved
      expect(result.to_s).to include("OTHER_VAR=other")
    end
  end
end
