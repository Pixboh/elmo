require "spec_helper"

describe Odk::ResponseParser do
  include_context "response tree"

  let(:save_fixtures) { true }
  let(:form) { create(:form, :published, :with_version, question_types: question_types) }
  let(:files) { {xml_submission_file: StringIO.new(xml)} }
  let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
  let(:xml) { prepare_odk_response_fixture(filename, form, values: xml_values) }

  context "simple form" do
    let(:filename) { "simple_response.xml" }

    context "text questions only" do
      let(:question_types) { %w[text text text] }
      let(:xml_values) { %w[A B C] }
      let(:expected_values) { xml_values }

      context "valid input" do
        it "should produce a simple tree from a form with three children" do
          Odk::ResponseParser.new(response: response, files: files).populate_response

          expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), expected_values)
        end
      end

      context "with earlier odk code style for questionings" do
        xit "should parse the response" do

        end
      end

      context "outdated form" do
        let(:xml) { prepare_odk_response_fixture(filename, form, values: xml_values, formver: "wrong") }

        it "should error" do
          expect do
            Odk::ResponseParser.new(response: response, files: files).populate_response
          end.to raise_error(FormVersionError, "Form version is outdated")
        end
      end

      context "response contains form item not in form" do
        let(:other_form) { create(:form) }

        it "should error" do
          xml # create xml before updating form's second question to have a different form id.
          form.c[1].update_attribute(:form_id, other_form.id) # skip validations with update_attribute
          expect do
            Odk::ResponseParser.new(response: response, files: files).populate_response
          end.to raise_error(SubmissionError, "Submission contains group or question not found in form.")
        end
      end
    end

    context "with other question types" do
      let(:xml_values) { ["Quick", "The quick brown fox jumps over the lazy dog", 9.6] }
      let(:expected_values) { xml_values }
      let(:question_types) { %w[text long_text decimal] }

      it "processes values correctly" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), expected_values)
      end
    end

    context "response with select multiple" do
      let(:question_types) { %w[select_multiple select_multiple text] }
      let(:opt1) { form.c[0].option_set.sorted_children[0] }
      let(:opt2) { form.c[0].option_set.sorted_children[1] }
      let(:xml_values) { ["on#{opt1.id} on#{opt2.id}", "none", "A"] }
      let(:expected_values) { ["#{opt1.option.name};#{opt2.option.name}", nil, "A"] }

      it "should create the appropriate multilevel answer tree" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_children(
          response.root_node,
          %w[Answer Answer Answer],
          form.c.map(&:id),
          expected_values
        )
      end
    end

    # Don't really need this spec; the hard work is in answer.rb and needs test coverage
    context "with location type" do
      let(:question_types) { %w[location location text] }
      let(:xml_values) { ["12.345600 -76.993880", "12.3456 -76.99388 123.456 20.0", "A"] }
      let(:expected_values) { xml_values }

      it "parses location answers correctly" do
        Odk::ResponseParser.new(response: response, files: files).populate_response
        expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), expected_values)
      end
    end

    context "with time-related questions" do
      around do |example|
        in_timezone("Saskatchewan") { example.run } # Saskatchewan is -06
      end

      context "with date, time, and datetime types" do
        let(:question_types) { %w[datetime date time] }
        let(:xml_values) { ["2017-07-12T16:40:00.000+03", "2017-07-01", "14:30:00.000+03"] }
        let(:expected_values) { ["2017-07-12 07:40:00 -0600", "2017-07-01", "2000-01-01 14:30:00 UTC"] }

        it "retains timezone information for datetime but not time" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), expected_values)
        end
      end

      context "with prefilled timestamps" do
        let(:question_types) { %w[formstart text formend] }
        let(:xml_values) { ["2017-07-12T16:40:12.000-06", "A", "2017-07-12T16:42:43.000-06"] }
        let(:expected_values) { ["2017-07-12 16:40:12 -06", "A", "2017-07-12 16:42:43 -06"] }

        it "accepts data normally" do
          Odk::ResponseParser.new(response: response, files: files).populate_response
          expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), expected_values)
        end
      end
    end
  end

  context "forms with a group" do
    let(:question_types) { ["text", %w[text text], "text"] }
    let(:filename) { "group_form_response.xml" }
    let(:xml_values) { %w[A B C D] }

    it "should produce the correct tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(response.root_node, %w[Answer AnswerGroup Answer], form.c.map(&:id), ["A", nil, "D"])
      expect_children(response.root_node.c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
    end
  end

  context "repeat group forms" do
    let(:question_types) { ["text", {repeating: {items: %w[text text]}}] }
    let(:filename) { "repeat_group_form_response.xml" }
    let(:xml_values) { %w[A B C D E] }

    it "should create the appropriate repeating group tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(response.root_node, %w[Answer AnswerGroupSet], form.c.map(&:id), ["A", nil])
      expect_children(response.root_node.c[1],
        %w[AnswerGroup AnswerGroup],
        [form.c[1].id, form.c[1].id],
        [nil, nil])
      expect_children(response.root_node.c[1].c[0], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
      expect_children(response.root_node.c[1].c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[D E])
    end
  end

  context "form with nexted groups" do
    let(:question_types) do
      [
        "integer",
        {repeating:
          {items: [
            "integer",
            {repeating: {items: %w[integer integer]}}
          ]}}
      ]
    end
    let(:filename) { "nested_group_form_response.xml" }
    let(:xml_values) { [*1..9] }

    it "should create nested tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(response.root_node,  %w[Answer AnswerGroupSet], form.c.map(&:id), [1, nil])
      expect_children(response.root_node.c[1],
        %w[AnswerGroup AnswerGroup],
        [form.c[1].id, form.c[1].id]
      )
      parent_group_set = response.root_node.c[1]
      child_group_set_1 = parent_group_set.c[0].c[1]
      expect_children(parent_group_set.c[0],
        %w[Answer AnswerGroupSet],
        form.c[1].c.map(&:id),
        [2, nil]
      )
      expect_children(child_group_set_1.c[0],
        %w[Answer Answer],
        form.c[1].c[1].c.map(&:id),
        [3, 4]
      )
      expect_children(child_group_set_1.c[1],
        %w[Answer Answer],
        form.c[1].c[1].c.map(&:id),
        [5, 6]
      )
      expect_children(child_group_set_1.c[1],
        %w[Answer Answer],
        form.c[1].c[1].c.map(&:id),
        [5, 6]
      )
      child_group_set_2 = parent_group_set.c[1].c[1]
      expect_children(parent_group_set.c[1],
        %w[Answer AnswerGroupSet],
        form.c[1].c.map(&:id),
        [7, nil]
      )
      expect_children(child_group_set_2.c[0],
        %w[Answer Answer],
        form.c[1].c[1].c.map(&:id),
        [8, 9]
      )
    end
  end

  context "form with multilevel answer" do
    let(:question_types) { %w[text multilevel_select_one multilevel_select_one multilevel_select_one] }
    let(:level1_opt) { form.c[1].option_set.sorted_children[1] }
    let(:level2_opt) { form.c[1].option_set.sorted_children[1].sorted_children[0] }
    let(:filename) { "multilevel_response.xml" }
    let(:xml_values) do
      ["A",
       "on#{level1_opt.id}",
       "on#{level2_opt.id}",
       "none",
       "none",
       "on#{level1_opt.id}",
       "none"]
    end
    let(:expected_values) do
      ["A",
       level1_opt.option.name,
       level2_opt.option.name,
       nil,
       nil,
       level1_opt.option.name,
       nil]
    end

    it "should create the appropriate multilevel answer tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(
        response.root_node,
        %w[Answer AnswerSet AnswerSet AnswerSet],
        form.c.map(&:id),
        [expected_values.first, nil, nil, nil]
      )
      expect_children(
        response.root_node.c[1],
        %w[Answer Answer],
        [form.c[1].id, form.c[1].id],
        expected_values[1, 2]
      )
      expect_children(
        response.root_node.c[2],
        %w[Answer Answer],
        [form.c[2].id, form.c[2].id],
        [nil, nil]
      )
      expect_children(
        response.root_node.c[3],
        %w[Answer Answer],
        [form.c[3].id, form.c[3].id],
        expected_values[5, 6]
      )
    end
  end

  def prepare_odk_response_fixture(filename, form, options = {})
    path = "odk/responses/#{filename}"
    prepare_odk_fixture(filename, path, form, options)
  end
end
