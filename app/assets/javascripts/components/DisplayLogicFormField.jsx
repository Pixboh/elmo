class DisplayLogicFormField extends React.Component {
  constructor(props) {
    super();
    this.state = props;
    this.changeDisplayOption = this.changeDisplayOption.bind(this);
  }

  changeDisplayOption(event) {
    let value = event.target.value

    this.setState({display_if: value})
  }

  render() {
    let select_props = {
      className: "form-control",
      name: "questioning[display_if]",
      id: "questioning_display_if",
      value: this.state.display_if,
      onChange: this.changeDisplayOption
    }

    let condition_set_props = {
      conditions: this.state.display_conditions,
      conditionable_id: this.state.id,
      refable_qings: this.state.refable_qings,
      form_id: this.state.form_id,
      show: this.state.display_if != "always",
      name_prefix: "questioning[display_conditions_attributes]"
    };

    return (
      <div>
        <select {...select_props}>
          <option value="always">{I18n.t("form_item.display_if_options.always")}</option>
          <option value="all_met">{I18n.t("form_item.display_if_options.all_met")}</option>
          <option value="any_met">{I18n.t("form_item.display_if_options.any_met")}</option>
        </select>
        <ConditionSetFormField {...condition_set_props} />
      </div>
    );
  }
}
