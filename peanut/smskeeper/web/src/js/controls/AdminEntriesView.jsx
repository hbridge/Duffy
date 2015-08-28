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
  getInitialState() {
    return {expanded: this.props.defaultExpanded};
  },

  render: function() {
    var createEntry = function(entry, index) {
      return (
        <AdminEntryCard model={ entry } key={ entry.id } userTimezone={USER.timezone}/>
      );
    }.bind(this);

    var header = <div onClick={this.handleHeaderClicked}>
      <span className="panelTitle">{this.props.type == "hidden" ? "Recently Hidden" : "Active"} Reminders</span>
      <Button
        ref='refreshButton'
        onClick={this.refreshEntries}
        style={{float: "right"}}>
        <Glyphicon glyph='refresh'/>
      </Button>
    </div>

    var reminders = null;
    if (this.props.type == "hidden") {
      reminders = this.props.collection.hiddenReminders();
      var recentPast = moment().subtract(2, 'days');
      reminders = reminders.filter(function(reminder){
        var updated = moment(reminder.get('updated'));
        return updated.isAfter(recentPast);
      });
    } else {
      reminders = this.props.collection.reminders();
    }

    var createEntryInput = null;
    if (this.props.type != "hidden") {
      createEntryInput = <CreateEntryInput />
    }

    return (
    	<Panel
        header={header}
        bsStyle={this.props.type == "hidden" ? "default" : "primary"}
        className="controlPanel"
        collapsible
        expanded={this.state.expanded}
      >
        <ListGroup>
      		{ reminders.map(createEntry) }
        </ListGroup>
        { createEntryInput }
      </Panel>
    );
  },

  handleHeaderClicked(e) {
    e.preventDefault();
    console.log("handleHeaderClicked");
    this.setState({expanded: !this.state.expanded});
  },

  refreshEntries: function(e) {
    console.log("refreshing entries");
    e.preventDefault();
    e.stopPropagation(); // prevent propagation to the header click handler
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

  componentDidMount: function() {
    $(this.refs.text.getInputDOMNode()).keydown(function (e) {
        if (e.ctrlKey && (e.keyCode == 13 || e.keyCode == 10)) {
          if (!this.state.sendDisabled) {
            this.createEntry(e);
          }
      }
    }.bind(this));
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