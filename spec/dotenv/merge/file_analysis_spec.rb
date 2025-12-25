# frozen_string_literal: true

RSpec.describe Dotenv::Merge::FileAnalysis do
  describe "#initialize" do
    context "with simple dotenv file" do
      let(:source) do
        <<~DOTENV
          API_KEY=secret123
          DATABASE_URL=postgres://localhost/mydb
        DOTENV
      end

      it "parses successfully" do
        analysis = described_class.new(source)
        expect(analysis.valid?).to be true
      end

      it "extracts lines" do
        analysis = described_class.new(source)
        expect(analysis.lines.size).to eq(2)
      end

      it "extracts assignments" do
        analysis = described_class.new(source)
        expect(analysis.assignment_lines.size).to eq(2)
      end
    end

    context "with comments and blank lines" do
      let(:source) do
        <<~DOTENV
          # Database configuration
          DATABASE_URL=postgres://localhost

          # API settings
          API_KEY=secret
        DOTENV
      end

      it "parses all lines" do
        analysis = described_class.new(source)
        expect(analysis.lines.size).to eq(5)
      end

      it "identifies assignment lines only" do
        analysis = described_class.new(source)
        expect(analysis.assignment_lines.size).to eq(2)
      end
    end

    context "with freeze blocks" do
      let(:source) do
        <<~DOTENV
          PUBLIC_KEY=public

          # dotenv-merge:freeze Custom settings
          API_KEY=my_custom_key
          API_SECRET=my_custom_secret
          # dotenv-merge:unfreeze

          DEBUG=false
        DOTENV
      end

      it "detects freeze blocks" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks.size).to eq(1)
      end

      it "has correct freeze block line numbers" do
        analysis = described_class.new(source)
        freeze_node = analysis.freeze_blocks.first
        expect(freeze_node.start_line).to eq(3)
        expect(freeze_node.end_line).to eq(6)
      end

      it "excludes frozen lines from assignment_lines" do
        analysis = described_class.new(source)
        # Only PUBLIC_KEY and DEBUG should be in assignment_lines
        keys = analysis.assignment_lines.map(&:key)
        expect(keys).to contain_exactly("PUBLIC_KEY", "DEBUG")
      end
    end

    context "with custom freeze token" do
      let(:source) do
        <<~DOTENV
          KEY1=value1
          # my-token:freeze
          KEY2=value2
          # my-token:unfreeze
        DOTENV
      end

      it "detects custom freeze blocks" do
        analysis = described_class.new(source, freeze_token: "my-token")
        expect(analysis.freeze_blocks.size).to eq(1)
      end

      it "ignores default freeze token" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end
  end

  describe "#line_at" do
    let(:source) { "KEY1=value1\nKEY2=value2\n" }
    let(:analysis) { described_class.new(source) }

    it "returns correct line (1-indexed)" do
      expect(analysis.line_at(1).key).to eq("KEY1")
      expect(analysis.line_at(2).key).to eq("KEY2")
    end

    it "returns nil for out of range" do
      expect(analysis.line_at(0)).to be_nil
      expect(analysis.line_at(100)).to be_nil
    end
  end

  describe "#signature_at" do
    let(:source) do
      <<~DOTENV
        API_KEY=secret
        DATABASE_URL=postgres://localhost
      DOTENV
    end
    let(:analysis) { described_class.new(source) }

    it "returns signature for statement" do
      expect(analysis.signature_at(0)).to eq([:env, "API_KEY"])
      expect(analysis.signature_at(1)).to eq([:env, "DATABASE_URL"])
    end

    it "returns nil for out of range" do
      expect(analysis.signature_at(-1)).to be_nil
      expect(analysis.signature_at(100)).to be_nil
    end
  end

  describe "#env_var" do
    let(:source) do
      <<~DOTENV
        API_KEY=secret
        DATABASE_URL=postgres://localhost
      DOTENV
    end
    let(:analysis) { described_class.new(source) }

    it "finds env var by key" do
      line = analysis.env_var("API_KEY")
      expect(line).not_to be_nil
      expect(line.value).to eq("secret")
    end

    it "returns nil for unknown key" do
      expect(analysis.env_var("UNKNOWN")).to be_nil
    end
  end

  describe "#keys" do
    let(:source) do
      <<~DOTENV
        # Comment
        API_KEY=secret
        DATABASE_URL=postgres://localhost

        DEBUG=true
      DOTENV
    end
    let(:analysis) { described_class.new(source) }

    it "returns all env var keys" do
      expect(analysis.keys).to contain_exactly("API_KEY", "DATABASE_URL", "DEBUG")
    end
  end

  describe "#generate_signature with custom generator" do
    let(:source) do
      <<~DOTENV
        API_KEY=secret
        DATABASE_URL=postgres://localhost
      DOTENV
    end

    it "uses custom generator when provided" do
      custom_generator = ->(node) { [:custom, node.key&.downcase] }
      analysis = described_class.new(source, signature_generator: custom_generator)

      expect(analysis.signature_at(0)).to eq([:custom, "api_key"])
    end

    it "falls through when generator returns node" do
      custom_generator = ->(node) { node }
      analysis = described_class.new(source, signature_generator: custom_generator)

      expect(analysis.signature_at(0)).to eq([:env, "API_KEY"])
    end

    it "returns nil when generator returns nil" do
      custom_generator = ->(_node) { nil }
      analysis = described_class.new(source, signature_generator: custom_generator)

      expect(analysis.signature_at(0)).to be_nil
    end
  end

  describe "freeze block edge cases" do
    context "with unclosed freeze block" do
      let(:source) do
        <<~DOTENV
          KEY1=value1
          # dotenv-merge:freeze
          KEY2=value2
        DOTENV
      end

      it "handles gracefully (warns but doesn't crash)" do
        expect { described_class.new(source) }.not_to raise_error
      end
    end

    context "with unfreeze without freeze" do
      let(:source) do
        <<~DOTENV
          KEY1=value1
          # dotenv-merge:unfreeze
          KEY2=value2
        DOTENV
      end

      it "handles gracefully" do
        expect { described_class.new(source) }.not_to raise_error
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end

    context "with nested freeze blocks" do
      let(:source) do
        <<~DOTENV
          # dotenv-merge:freeze
          KEY1=value1
          # dotenv-merge:freeze
          KEY2=value2
          # dotenv-merge:unfreeze
        DOTENV
      end

      it "handles gracefully (ignores nested)" do
        expect { described_class.new(source) }.not_to raise_error
      end
    end
  end

  describe "#compute_node_signature" do
    let(:source) { "KEY=value\n" }
    let(:analysis) { described_class.new(source) }

    it "returns nil for unknown node types" do
      unknown_node = Object.new
      result = analysis.send(:compute_node_signature, unknown_node)
      expect(result).to be_nil
    end

    it "returns signature for EnvLine" do
      env_line = analysis.statements.first
      result = analysis.send(:compute_node_signature, env_line)
      expect(result).to be_an(Array)
    end

    it "returns signature for FreezeNode" do
      freeze_source = <<~DOTENV
        # dotenv-merge:freeze
        KEY=value
        # dotenv-merge:unfreeze
      DOTENV
      freeze_analysis = described_class.new(freeze_source)
      freeze_node = freeze_analysis.freeze_blocks.first

      result = freeze_analysis.send(:compute_node_signature, freeze_node)
      expect(result).to be_an(Array)
      expect(result.first).to eq(:FreezeNode)
    end
  end
end
