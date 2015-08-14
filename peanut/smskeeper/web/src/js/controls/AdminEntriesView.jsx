var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require('moment');
var BackboneReactComponent = require('backbone-react-component');
var moment = require('moment');
var Utils = require('../utils.js')
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroup = Bootstrap.ListGroup;
  Panel = Bootstrap.Panel;
  DropdownButton = Bootstrap.DropdownButton;
  Glyphicon = Bootstrap.Glyphicon;
AdminEntryCard = require('./AdminEntryCard.jsx');

module.exports = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
    var createEntry = function(entry, index) {
      return (
        <AdminEntryCard model={ entry } key={ entry.id } />
      );
    }.bind(this);

    var header = <div>
      <span className="panelTitle">Active Reminders</span>
      <Button
        ref='refreshButton'
        onClick={this.refreshEntries}
        style={{float: "right"}}>
        <Glyphicon glyph='refresh'/>
      </Button>
    </div>

    return (
    	<Panel
        header={header}
        bsStyle={this.state.paused ? 'danger' : 'primary'}
        className="controlPanel"
      >
        <ListGroup>
      		{ this.props.collection.reminders().map(createEntry) }
        </ListGroup>
          <CreateEntryInput />
      </Panel>
    );
  },

  refreshEntries: function() {
    console.log("refreshing entries");
    this.getCollection().fetch();
  },

  getElipsisMenuItems: function() {
    var elipsisMenuItems = [
      { payload: "refresh", text: 'Refresh' },
    ];
    return elipsisMenuItems;
  },

  handleMoreAction: function(e, selectedIndex, menuItem) {
    if (menuItem.payload == "refresh") {
      this.refreshEntries();
    } else {
      console.log("unrecognized more action");
    }
  }
});


var CreateEntryInput = React.createClass({
  mixins: [BackboneReactComponent],
  getInitialState: function(){
    return {sendDisabled: true}
  },
  render: function() {
    var createButton =
      <Button
        onClick={this.createEntry}
        bsStyle="primary"
        bsSize='large'
        disabled={this.state.sendDisabled}>
          Create
      </Button>;

    return (
      <form className='inputElement' onSubmit={this.createEntry}>
        <Input
          type='textarea'
          ref='text'
          buttonAfter={createButton}
          placeholder="poop tomorrow..."
          onChange={this.textChanged}
        />
      </form>
    );
  },

  textChanged: function(e) {
    if (this.refs.text.getValue().length > 0) {
      this.setState({sendDisabled: false});
    } else {
      this.setState({sendDisabled: true});
    }
  },

  createEntry: function(e) {
    e.preventDefault();
    var text = this.refs.text.getValue();
    console.log("create entry with text: " + text);
    Utils.SubmitCommandToServer(
      "Remind me to " + text,
      function(entryData){
        this.getCollection().fetch();
        this.refs.text.getInputDOMNode().value = "";
      }.bind(this),
      null
    );
  },
});