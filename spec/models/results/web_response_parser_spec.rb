# frozen_string_literal: true

require "rails_helper"

describe Results::WebResponseParser do
  include_context "response tree"

  let(:form) { create(:form, question_types: question_types) } # form item ids have to actually exist
  let(:input) { ActionController::Parameters.new(data) }
  let(:tree) { Results::WebResponseParser.new.parse(input, response) }

  context "new response" do
    let(:response) { nil }
    let(:data) { {root: web_answer_group_hash(form.root_group.id, answers)} }

    context "simple response with three answers" do
      let(:question_types) { %w[text text text] }

      context "all relevant, none destroyed" do
        let(:answers) do
          {
            "0" => web_answer_hash(form.c[0].id, value: "A"),
            "1" => web_answer_hash(form.c[1].id, value: "B"),
            "2" => web_answer_hash(form.c[2].id, value: "C")
          }
        end

        it "builds tree with three answers" do
          expect_root(tree, form)
          expect_children(tree, %w[Answer Answer Answer], form.c.map(&:id), %w[A B C])
        end
      end

      context "with one irrelevant answer" do
        let(:answers) do
          {
            "0" => web_answer_hash(form.c[0].id, value: "A"),
            "1" => web_answer_hash(form.c[1].id, {value: "B"}, relevant: "false"),
            "2" => web_answer_hash(form.c[2].id, value: "C")
          }
        end

        it "builds tree with two answers" do
          expect_root(tree, form)
          expect_children(tree, %w[Answer Answer], [form.c[0].id, form.c[2].id], %w[A C])
        end
      end

      context "with one destroyed answer" do
        let(:answers) do
          {
            "0" => web_answer_hash(form.c[0].id, value: "A"),
            "1" => web_answer_hash(form.c[1].id, {value: "B"}, destroy: "true"),
            "2" => web_answer_hash(form.c[2].id, value: "C")
          }
        end

        it "builds tree with two answers" do
          expect_root(tree, form)
          expect_children(tree, %w[Answer Answer], [form.c[0].id, form.c[2].id], %w[A C])
        end
      end
    end

    context "response with an answer set" do
      let(:question_types) { %w[text multilevel_select_one text] }
      let(:data) { {root: web_answer_group_hash(form.root_group.id, answers)} }
      let(:plant) { form.c[1].option_set.sorted_children[1].id }
      let(:oak) { form.c[1].option_set.sorted_children[1].sorted_children[1].id }
      let(:answers) do
        {
          "0" => web_answer_hash(form.c[0].id, value: "A"),
          "1" => {
            id: "",
            type: "AnswerSet",
            questioning_id: form.c[1].id,
            relevant: "true",
            children: {
              "0" => web_answer_hash(form.c[1].id, option_node_id: plant),
              "1" => web_answer_hash(form.c[1].id, option_node_id: oak)
            }
          },
          "2" => web_answer_hash(form.c[2].id, value: "D")
        }
      end

      it "builds tree with answer set" do
        expect_root(tree, form)
        expect_children(tree, %w[Answer AnswerSet Answer], form.c.map(&:id), ["A", nil, "D"])
        expect_children(tree.c[1], %w[Answer Answer], [form.c[1].id, form.c[1].id], %w[Plant Oak])
      end
    end

    context "response with select multiple answer" do
      let(:question_types) { %w[text select_multiple text] }
      let(:data) { {root: web_answer_group_hash(form.root_group.id, answers)} }
      let(:dog) { form.c[1].option_set.sorted_children[0].id }
      let(:cat) { form.c[1].option_set.sorted_children[1].id }
      let(:answers) do
        {
          "0" => web_answer_hash(form.c[0].id, value: "A"),
          "1" => web_answer_hash(form.c[1].id,
            choices_attributes: {
              "0" => {option_node_id: dog, checked: "1"},
              "1" => {option_node_id: cat, checked: "1"}
            }),
          "2" => web_answer_hash(form.c[2].id, value: "D")
        }
      end

      it "builds tree with answer set" do
        expect_root(tree, form)
        expect_children(tree, %w[Answer Answer Answer], form.c.map(&:id), ["A", "Cat;Dog", "D"])
      end
    end

    context "response with a group" do
      let(:question_types) { ["text", %w[text text], "text"] }
      let(:answers) do
        {
          "0" => web_answer_hash(form.c[0].id, value: "A"),
          "1" => web_answer_group_hash(form.c[1].id,
            "0" => web_answer_hash(form.c[1].c[0].id, value: "B"),
            "1" => web_answer_hash(form.c[1].c[1].id, value: "C")),
          "2" => web_answer_hash(form.c[2].id, value: "D")
        }
      end

      it "should produce the correct tree" do
        expect_root(tree, form)
        expect_children(tree, %w[Answer AnswerGroup Answer], form.c.map(&:id), ["A", nil, "D"])
        expect_children(tree.c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
      end
    end

    context "response with an answer group set" do
      let(:question_types) { ["text", {repeating: {items: %w[text text]}}] }
      let(:answers) do
        {
          "0" => web_answer_hash(form.c[0].id, value: "A"),
          "1" => {
            id: "",
            type: "AnswerGroupSet",
            questioning_id: form.c[1].id,
            relevant: "true",
            children: {
              "0" => web_answer_group_hash(form.c[1].id, instance_one_answers),
              "1" => web_answer_group_hash(form.c[1].id, instance_two_answers)
            }
          }
        }
      end
      let(:instance_one_answers) do
        {
          "0" => web_answer_hash(form.c[1].c[0].id, value: "B"),
          "1" => web_answer_hash(form.c[1].c[1].id, value: "C")
        }
      end
      let(:instance_two_answers) do
        {
          "0" => web_answer_hash(form.c[1].c[0].id, value: "D"),
          "1" => web_answer_hash(form.c[1].c[1].id, value: "E")
        }
      end

      it "builds tree with answer group set" do
        expect_root(tree, form)
        expect_children(tree, %w[Answer AnswerGroupSet], form.c.map(&:id), ["A", nil])
        expect_children(tree.c[1], %w[AnswerGroup AnswerGroup], [form.c[1].id, form.c[1].id])
        expect_children(tree.c[1].c[0], %w[Answer Answer], form.c[1].c.map(&:id), %w[B C])
        expect_children(tree.c[1].c[1], %w[Answer Answer], form.c[1].c.map(&:id), %w[D E])
      end
    end

    context "response with nested group sets" do
      let(:question_types) { ["text", {repeating: {items: ["text", {repeating: {items: ["text"]}}]}}] }
      let(:outer_form_grp) { form.c[1] }
      let(:inner_form_grp) { outer_form_grp.c[1] }
      let(:answers) do
        {
          "0" => web_answer_hash(form.c[0].id, value: "A"),
          "1" => {
            id: "",
            type: "AnswerGroupSet",
            questioning_id: form.c[1].id,
            relevant: "true",
            children: {
              "0" => web_answer_group_hash(outer_form_grp.id, instance_one_answers),
              "1" => web_answer_group_hash(outer_form_grp.id, instance_two_answers)
            }
          }
        }
      end
      let(:instance_one_answers) do
        {
          "0" => web_answer_hash(form.c[1].c[0].id, value: "B"),
          "1" => {
            id: "",
            type: "AnswerGroupSet",
            questioning_id: form.c[1].c[1].id,
            relevant: "true",
            children: {
              "0" => web_answer_group_hash(inner_form_grp.id, answers_one_one),
              "1" => web_answer_group_hash(inner_form_grp.id, answers_one_two)
            }
          }
        }
      end
      let(:instance_two_answers) do
        {
          "0" => web_answer_hash(outer_form_grp.c[0].id, value: "E"),
          "1" => {
            id: "",
            type: "AnswerGroupSet",
            questioning_id: form.c[1].c[1].id,
            relevant: "true",
            children: {
              "0" => web_answer_group_hash(inner_form_grp.id, answers_two_one),
              "1" => web_answer_group_hash(inner_form_grp.id, answers_two_two)
            }
          }
        }
      end
      let(:answers_one_one) { {"0" => web_answer_hash(inner_form_grp.c[0].id, value: "C")} }
      let(:answers_one_two) { {"0" => web_answer_hash(inner_form_grp.c[0].id, value: "D")} }
      let(:answers_two_one) { {"0" => web_answer_hash(inner_form_grp.c[0].id, value: "F")} }
      let(:answers_two_two) { {"0" => web_answer_hash(inner_form_grp.c[0].id, value: "G")} }

      it "builds tree with answer group set" do
        expect_root(tree, form)
        expect_children(tree, %w[Answer AnswerGroupSet], form.c.map(&:id), ["A", nil])
        expect_children(tree.c[1], %w[AnswerGroup AnswerGroup], [form.c[1].id, form.c[1].id])
        answer_grp_one = tree.c[1].c[0]
        answer_grp_two = tree.c[1].c[1]

        expect_children(answer_grp_one, %w[Answer AnswerGroupSet], outer_form_grp.c.map(&:id), ["B", nil])
        expect_children(answer_grp_one.c[1], %w[AnswerGroup AnswerGroup], Array.new(2, inner_form_grp.id))
        expect_children(answer_grp_one.c[1].c[0], %w[Answer], [inner_form_grp.c[0].id], %w[C])
        expect_children(answer_grp_one.c[1].c[1], %w[Answer], [inner_form_grp.c[0].id], %w[D])
        expect_children(answer_grp_two, %w[Answer AnswerGroupSet], outer_form_grp.c.map(&:id), ["E", nil])
        expect_children(answer_grp_two.c[1], %w[AnswerGroup AnswerGroup], Array.new(2, inner_form_grp.id))
        expect_children(answer_grp_two.c[1].c[0], %w[Answer], [inner_form_grp.c[0].id], %w[F])
        expect_children(answer_grp_two.c[1].c[1], %w[Answer], [inner_form_grp.c[0].id], %w[G])
      end
    end
  end

  context "updating response" do
    let(:response) { create(:response, form: form, answer_values: answer_values) }

    context "simple form" do
      let(:question_types) { %w[text text text] }
      let(:answer_values) { %w[A B C] }
      let(:data) do
        {root: {
          id: response.root_node.id,
          type: "Answer",
          questioning_id: form.root_group.id,
          relevant: "true",
          children: {
            "0" => web_answer_hash(form.c[0].id, value: "A", id: response.root_node.c[0].id),
            "1" => web_answer_hash(form.c[1].id, value: "B", id: response.root_node.c[1].id),
            "2" => web_answer_hash(form.c[2].id, value: "Z", id: response.root_node.c[2].id)
          }
        }}
      end

      it "updates value appropriately" do
        pp "tree: "
        pp response.root_node.debug_tree
        expect_root(tree, form)
        expect_children(tree.reload, %w[Answer Answer Answer], form.sorted_children.map(&:id), %w[A B Z])
      end
    end
  end
end
