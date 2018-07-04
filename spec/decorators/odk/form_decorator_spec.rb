# frozen_string_literal: true

require "rails_helper"

describe Odk::FormDecorator, :odk do
  include_context "odk rendering"

  describe "needs_manifest?" do
    let(:decorated_form) { decorate(form) }
    subject(:needs_manifest?) { decorated_form.needs_manifest? }

    context "multilevel option sets" do
      describe "for form with single level option sets only" do
        let(:form) { create(:form, question_types: %w[select_one]) }
        it { is_expected.to be false }
      end

      describe "for form with multi level option set" do
        let(:form) { create(:form, question_types: %w[select_one multilevel_select_one]) }
        it { is_expected.to be true }
      end
    end

    context "audio prompts" do
      context "visible questions" do
        let(:form) { create(:form, question_types: %w[text]) }

        describe "for form with audio prompt in question" do
          before do
            form.c[0].question.update!(audio_prompt: audio_fixture("powerup.mp3"))
          end

          it { is_expected.to be true }
        end
      end
    end
  end
end