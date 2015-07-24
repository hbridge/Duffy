var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require('moment');
var BackboneReactComponent = require('backbone-react-component');
var moment = require('moment');

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

AdminEntryDialog = require('./AdminModifyEntryDialog.jsx');
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
			    	<DropDownIcon menuItems={[]} onChange={this.handleMoreAction}>
			    	<ToolbarTitle text="•••"/>
			    	</DropDownIcon>
		    	</ToolbarGroup>
	    	</Toolbar>

	      		{ this.props.collection.reminders().map(createEntry) }

	        <AdminEntryDialog ref="entryDialog" />
      	</Paper>
      	</div>
    );
  },
});