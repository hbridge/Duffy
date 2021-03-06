var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var _ = require("underscore");
var Bootstrap = require('react-bootstrap');
  Modal = Bootstrap.Modal;
  Button = Bootstrap.Button;
  ButtonGroup = Bootstrap.ButtonGroup;
  Input = Bootstrap.Input;
  ListGroup = Bootstrap.ListGroup;
  ListGroupItem = Bootstrap.ListGroupItem;
  Well = Bootstrap.Well;
  Panel = Bootstrap.Panel;

var wordRegex = /[a-zA-Z0-9]+|[^ \n^a-z-A-Z0-9]+/g;


var getAllMatches = function(str, regex){
  var matches = [];
  while (match=regex.exec(str)) {
    matches.push(match);
  }
  return matches;
}


MessageSplitter = React.createClass({
  getInitialState(){
    var statementBounds = this.props.message.get("statement_bounds");
    statementBounds = statementBounds ? statementBounds : [];
    return ({statementBounds: statementBounds});
  },

  render(){
    console.log("Message", this.props.message);
    var wordMatches = getAllMatches(this.props.message.get("Body"), wordRegex);
    console.log("Word matches", wordMatches);
    var buttons = [];
    for (var i = 0; i < wordMatches.length; i++) {
      var wordIndex = wordMatches[i].index;
      var selected = _.contains(this.state.statementBounds, wordIndex);
      var style = selected ? 'primary' : 'default';
      var clickHandler = (function(idx, selected){
        return function(){this.setStatementBoundary(idx, !selected)}.bind(this)
      }.bind(this))(wordIndex, selected);
      buttons.push(
        <Button
            key={i}
            bsStyle={style}
            onClick={clickHandler}>
          {wordMatches[i][0]}
        </Button>
      );
    }

    return (
     <Panel collapsible defaultExpanded header="Split Message">
      <ButtonGroup>
        {buttons}
      </ButtonGroup>
     </Panel>
    );
  },

  setStatementBoundary(wordIndex, isBoundary){
    var newBoundaries = null;
    if (isBoundary) {
      newBoundaries = _.union([wordIndex], this.state.statementBounds);
    } else {
      newBoundaries = _.without(this.state.statementBounds, wordIndex);
    }
    newBoundaries.sort(function(a, b){return a-b});

    console.log("newBoundaries", newBoundaries);

    this.setState({statementBounds: newBoundaries});
    this.props.message.setStatementBoundaries(newBoundaries);
  }
});


module.exports = React.createClass({
  getInitialState: function(){
    return {showModal: false, selectedClassification: null};
  },

  show: function(message) {
    console.log("showing message actions for ", message);
    this.setState({
      showModal: true,
      message: message,
      selectedClassification: message.get("classification"),
      showJson: false,
    });
  },

  hide: function() {
    this.setState({showModal: false});
  },

  render: function() {
    // jsonElement for after show JSON is tapped
    var jsonElement = null;
    if (this.state.showJson) {
      jsonElement = <Well>{this.prettyPrintJson(JSON.stringify(this.state.message))}</Well>;
    }

    // categorization options
    var createCategoryOption = function(option, index) {
      var text = option.text;
      if (this.state.message && this.state.message.get("classification_scores")) {
        var score = this.state.message.get("classification_scores")[option.value];
        var smartScores = this.state.message.get("classification_scores")["smrt"];
        if (smartScores) {
          var smartScore = smartScores[option.value];
        }
        if (score != undefined) {
          text = text + " (" + score.toFixed(1);
          if (smartScore) text = text + ", smrt: " + smartScore.toFixed(2);
          text = text + ")";
        }
      }

      return(
        <ListGroupItem
          key={option.value}
          eventKey="hi"
          message={this.state.message}
          active={option.value == this.state.selectedClassification}
          onClick={function(e){this.categorizationSelected(e, option.value)}.bind(this)}
        >
          {text}
        </ListGroupItem>
      );
    }.bind(this);

    var categorizationActions = null;
    if (this.state.message && this.state.message.get("incoming")) {
      categorizationActions = (
      <div>
      Categorize
        <ListGroup>
          { CLASSIFICATION_OPTIONS.map(createCategoryOption) }
        </ListGroup>
      </div>
      );
    }

    return(
        <Modal show={this.state.showModal} onHide={this.hide}>
          <Modal.Header closeButton>
            <Modal.Title>Message Actions</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <ListGroup>
              <ListGroupItem onClick={this.onResendTapped}>Resend</ListGroupItem>
              <ListGroupItem onClick={this.onShowJSONTapped}>Show JSON</ListGroupItem>
            </ListGroup>
            {jsonElement}
            {categorizationActions}
            <MessageSplitter message={this.state.message} />
          </Modal.Body>
          <Modal.Footer>
            <Button onClick={this.onDialogSubmit}>Done</Button>
          </Modal.Footer>
        </Modal>
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
    this.hide();
  },

  onShowJSONTapped: function(e) {
    console.log("showJsonTapped");
    this.setState({showJson: !this.state.showJson})
  },

  onDialogSubmit: function(e) {
    console.log("Message actions submit");
    if (this.state.selectedClassification != this.state.message.get("classification")) {
      this.state.message.setClassification(this.state.selectedClassification);
    }
    this.hide();
  },

  categorizationSelected: function(e, value) {
    e.preventDefault();
    console.log("categorization selected", value);
    if (value != this.state.selectedClassification) {
      this.setState({selectedClassification: value})
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