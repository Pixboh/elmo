class SkipRuleSetFormField extends React.Component {
  constructor(props) {
    super();
    this.state = props;
    this.addRule = this.addRule.bind(this);
  }

  // If about to show the set and it's empty, add a blank one.
  componentWillReceiveProps(newProps) {
    if (!newProps.hide && this.props.hide && this.state.skip_rules.length == 0) {
      this.addRule();
    }
  }

  addRule() {
    let later_items_exist = this.state.later_items.length > 0;
    this.setState({skip_rules:
      this.state.skip_rules.concat([{
        destination: later_items_exist ? "item" : "end",
        dest_item_id: later_items_exist ? this.state.later_items[0] : null,
        skip_if: "always",
        conditions: []
      }])});
  }

  render() {
    return (
      <div
        className="skip-rule-set"
        style={{display: this.props.hide ? "none" : ""}}>
        {this.state.skip_rules.map((props, index) => (<SkipRuleFormField
          form_id={this.state.form_id}
          hide={this.props.hide}
          key={index}
          later_items={this.state.later_items}
          name_prefix={`questioning[skip_rules_attributes][${index}]`}
          refable_qings={this.state.refable_qings}
          {...props} />))}
        <div
          className="skip-rule-add-link-wrapper">
          <a
            onClick={this.addRule}
            tabIndex="0">
            <i className="fa fa-plus" />
            {" "}
            {I18n.t("form_item.add_rule")}
          </a>
        </div>
      </div>
    );
  }
}
