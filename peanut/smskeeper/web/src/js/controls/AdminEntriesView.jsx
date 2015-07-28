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

mui = require('material-ui'),
 List = mui.List;
 ListItem = mui.ListItem;
 ListDivider = mui.ListDivider;
 DropDownIcon = mui.DropDownIcon;
 Toolbar = mui.Toolbar;
 ToolbarGroup = mui.ToolbarGroup;
 ToolbarTitle = mui.ToolbarTitle;
 Paper = mui.Paper;
 Card = mui.Card;
 CardTitle = mui.CardTitle;



AdminEntryCard = require('./AdminEntryCard.jsx');

module.exports = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
    var createEntry = function(entry, index) {
      return (
        <AdminEntryCard model={ entry } key={ entry.id } />
      );
    }.bind(this);

    return (
		<div>

    	<Paper zDepth={1} className="controlPanel">
	    	<Toolbar>
		    	<ToolbarGroup key={0} float="left">
		    		<ToolbarTitle text="Active Reminders" />
		    	</ToolbarGroup>
		    	<ToolbarGroup key={1} float="right">
			    	<DropDownIcon menuItems={this.getElipsisMenuItems()} onChange={this.handleMoreAction}>
			    	<ToolbarTitle text="•••"/>
			    	</DropDownIcon>
		    	</ToolbarGroup>
	    	</Toolbar>
        <ListGroup>
      		{ this.props.collection.reminders().map(createEntry) }
        </ListGroup>
          <CreateEntryInput />
      	</Paper>

      	</div>
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
        disabled={this.state.sendDisabled}>
          Create
      </Button>;

    return (
      <form className='inputElement' onSubmit={this.createEntry}>
        <Input
          type='text'
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