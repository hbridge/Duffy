var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
mui = require('material-ui'),
  SvgIcon = mui.SvgIcon;
  FlatButton = mui.FlatButton;
  Dialog = mui.Dialog;
  List = mui.List;
  ListItem = mui.ListItem;
  ListDivider = mui.ListDivider;
  Checkbox = mui.Checkbox;

module.exports = React.createClass({
  getInitialState: function(){
    return {selectedClassification: null};
  },

  show: function(message) {
    console.log("showing message actions for");
    console.log(message);
    this.setState({message: message, selectedClassification: message.get("classification")})
    this.refs.dialog.show();
  },
  hide: function() {
    this.refs.dialog.hide();
  },

  render: function() {
    // jsonElement for after show JSON is tapped
    var jsonElement = null;
    if (this.state.showJson) {
      jsonElement = <div>{this.prettyPrintJson(JSON.stringify(this.state.message))}</div>;
    }

    // categorization options
    var createOption = function(option, index) {
      var checkbox = <Checkbox
        name={option.value}
        value={option.value}
        defaultChecked={option.value == this.state.selectedClassification}
        onCheck={this.categorizationChecked}
      />
      return (
        <ListItem primaryText={option.text} leftCheckbox={checkbox}/>
      );
    }.bind(this);


    // dialog buttons
    standardActions = [
      { text: 'Cancel' },
      { text: 'Submit', onTouchTap: this.onDialogSubmit, ref: 'submit' }
    ];

    return(
      <Dialog
        ref="dialog"
        className="dialog"
        title="Message Actions"
        actions={standardActions}
        autoDetectWindowHeight={true}
        autoScrollBodyContent={true}
        contentStyle={{width: "90%", height: "90%"}}
        contentInnerStyle={{maxHeight: "80vh"}}
      >
      <List>
        <ListItem primaryText="Resend" onTouchTap={this.onResendTapped}/>
        <ListItem primaryText="Show JSON" onTouchTap={this.onShowJSONTapped}/>
      </List>
      {jsonElement}
      <ListDivider />
      <List subheader="Categorize" ref="categoriesList">
        { CLASSIFICATION_OPTIONS.map(createOption) }
      </List>
      </Dialog>
    );
  },

  onResendTapped: function(e) {
    console.log("resend tapped, msg_id: " + this.state.message.get("id"));
    $.ajax({
      url: "/smskeeper/resend_msg",
      dataType: 'json',
      type: 'POST',
      data: {msg_id: this.state.message.get("id")},
      success: function(data) {
      }.bind(this),
      error: function(xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
    this.refs.dialog.dismiss();
  },

  onShowJSONTapped: function(e) {
    console.log("showJsonTapped");
    this.setState({showJson: true})
  },

  onDialogSubmit: function(e) {
    console.log("submit");
    if (this.state.selectedClassification != this.state.message.get("classification")) {
      this.state.message.setClassification(this.state.selectedClassification);
    }
    this.refs.dialog.dismiss();
  },

  categorizationChecked: function(e, checked) {
    var checkedValue = e.target.value;
    console.log("categorization " + checkedValue + " checked: " + checked);
    if (checkedValue != this.state.selectedClassification) {
      this.setState({selectedClassification: checkedValue})
    }  else {
      this.setState({selectedClassification: null})
    }
  },

  prettyPrintJson: function(json){
    var result = json.replace(/,"/g, ",\n\"");
    result = result.replace(/":/g, "\": ");
    return result;
  },
});