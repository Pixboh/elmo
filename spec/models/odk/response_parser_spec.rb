require "spec_helper"

describe Odk::ResponseParser do
  #move XML submission specs over here one by one. For each one, change to use new answer hierarchy and expect_children. Then get it passing.

  let(:save_fixtures) { true }

  context "simple form" do
    let(:filename) { "simple_form_response.xml" }
    let(:form) { create(:form, :published, :with_version, question_types: %w[text text text]) }
    let(:values) { %w[A B C] }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }
    let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }

    context "valid input" do
      let(:xml) { prepare_odk_fixture(filename, form, {values: values}) }

      it "should produce a simple tree from a form with three children" do
        Odk::ResponseParser.new(response: response, files: files).populate_response

        expect_children(response.root_node, %w[Answer Answer Answer], form.c.map(&:id), values)
      end
    end

    context "outdated form" do
      let(:xml) { prepare_odk_fixture(filename, form, {values: values, formver: "wrong"}) }

      it "should error" do
        expect {
          Odk::ResponseParser.new(response: response, files: files).populate_response
        }.to raise_error(FormVersionError, "Form version is outdated")
      end
    end

    context "response contains form item not in form" do
      let(:xml) { prepare_odk_fixture(filename, form, {values: values}) }
      let(:other_form) {create(:form, :published, :with_version, question_types: %w[text])}

      it "should error" do
        xml #create xml before updating form's second question to have a different form id.
        form.c[1].update_attribute(:form_id,  other_form.id)
        expect {
          Odk::ResponseParser.new(response: response, files: files).populate_response
        }.to raise_error(SubmissionError, "Submission contains group or question not found in form.")
      end
    end
  end

  context "forms with a group" do
    let(:form) { create(:form, :published, :with_version, question_types: ["text", %w[text text], "text"]) }
    let(:filename) { "group_form_response.xml" }
    let(:values) { %w[A B C D] }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }
    let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
    let(:xml) { prepare_odk_fixture(filename, form, {values: values}) }

    it "should produce the correct tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      puts response.root_node.debug_tree
      expect_children(response.root_node, %w[Answer AnswerGroup Answer], form.c.map(&:id), ["A", nil, "D"])
      expect_children(response.root_node.c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
    end
  end

  context "repeat group forms" do
    let(:form) { create(:form, :published, :with_version, question_types: ["text", {repeating: {items: %w[text text]}}]) }
    let(:filename) { "repeat_group_form_response.xml" }
    let(:values) { %w[A B C D E] }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }
    let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
    let(:xml) { prepare_odk_fixture(filename, form, {values: values}) }

    it "should create the appropriate repeating group tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(response.root_node, %w[Answer AnswerGroupSet], form.c.map(&:id), ["A", nil])
      expect_children(response.root_node.c[1], %w[AnswerGroup AnswerGroup], [form.c[1].id, form.c[1].id], [nil, nil])
      expect_children(response.root_node.c[1].c[0], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
      expect_children(response.root_node.c[1].c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[D E])
    end
  end

  context "form with multilevel answer" do
    let(:form) do
      create(
        :form,
        :published,
        :with_version,
        question_types: %w[text multilevel_select_one text]
      )
    end
    let(:level1_opt) { form.c[1].option_set.sorted_children[1] }
    let(:level2_opt) { form.c[1].option_set.sorted_children[1].sorted_children[0] }
    let(:filename) { "multilevel_response.xml" }
    let(:xml_values) { ["A", "on#{level1_opt.id}", "on#{level2_opt.id}", "D"] }
    let(:expected_values) { ["A", level1_opt.option.name, level2_opt.option.name, "D"] }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }
    let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
    let(:xml) { prepare_odk_fixture(filename, form, values: xml_values) }

    it "should create the appropriate multilevel answer tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(
        response.root_node,
        %w[Answer AnswerSet Answer],
        form.c.map(&:id),
        [expected_values.first, nil, expected_values.last]
      )
      expect_children(
        response.root_node.c[1],
        %w[Answer Answer],
        [form.c[1].id, form.c[1].id],
        expected_values[1, 2]
      )
    end
  end

  context "response with select multiple" do
    let(:form) do
      create(
        :form,
        :published,
        :with_version,
        question_types: %w[select_multiple select_multiple]
      )
    end
    let(:opt1) {form.c[0].option_set.sorted_children[0]}
    let(:opt2) {form.c[0].option_set.sorted_children[1]}
    let(:filename) { "select_multiple_response.xml" }
    let(:xml_values) { ["on#{opt1.id} on#{opt2.id}", "none"] }
    let(:expected_values) { ["#{opt1.option.name};#{opt2.option.name}", nil] }
    let(:files) { {xml_submission_file: StringIO.new(xml)} }
    let(:response) { Response.new(form: form, mission: form.mission, user: create(:user)) }
    let(:xml) { prepare_odk_fixture(filename, form, values: xml_values) }

    it "should create the appropriate multilevel answer tree" do
      Odk::ResponseParser.new(response: response, files: files).populate_response
      expect_children(
        response.root_node,
        %w[Answer Answer],
        form.c.map(&:id),
        expected_values
      )
    end
  end

  def expect_children(node, types, qing_ids, values)
    children = node.children.sort_by(&:new_rank)
    expect(children.map(&:type)).to eq types
    expect(children.map(&:questioning_id)).to eq qing_ids
    expect(children.map(&:new_rank)).to eq((1..children.size).to_a)
    if values.present? #QUESTION: this is not a guard clause. format ok?
      expect(children.map(&:casted_value)).to eq values
    end
  end

  # TODO merge in helper w/ form_odk_rendering spec verson.
  # Accepts a fixture filename and form, and values array provided by a spec, and creates xml mimicking odk
  def prepare_odk_fixture(filename, form, options)
    items = form.preordered_items.map { |i| Odk::DecoratorFactory.decorate(i) }
    nodes = items.map(&:preordered_option_nodes).uniq.flatten
    xml = prepare_fixture("odk/responses/#{filename}",
      formname: [form.name],
      form: [form.id],
      formver: options[:formver].present? ? [options[:formver]] : [form.code],
      itemcode: items.map(&:odk_code),
      itemqcode: items.map(&:code),
      optcode: nodes.map(&:odk_code),
      optsetid: items.map(&:option_set_id).compact.uniq,
      value: options[:values])
    if save_fixtures
      dir = Rails.root.join("tmp", "odk_test_responses")
      FileUtils.mkdir_p(dir)
      File.open(dir.join(filename), "w") { |f| f.write(xml) }
    end
    xml
  end
end
