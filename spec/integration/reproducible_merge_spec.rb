# frozen_string_literal: true

require "dotenv/merge"
require "ast/merge/rspec/shared_examples"

RSpec.describe "Dotenv reproducible merge" do
  let(:fixtures_path) { File.expand_path("../fixtures/reproducible", __dir__) }
  let(:merger_class) { Dotenv::Merge::SmartMerger }
  let(:file_extension) { "env" }

  describe "basic merge scenarios (destination wins by default)" do
    context "when an environment variable is removed in destination" do
      it_behaves_like "a reproducible merge", "01_var_removed"
    end

    context "when an environment variable is added in destination" do
      it_behaves_like "a reproducible merge", "02_var_added"
    end

    context "when a value is changed in destination" do
      it_behaves_like "a reproducible merge", "03_value_changed"
    end
  end
end
