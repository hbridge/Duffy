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


var AdminEntryRow = React.createClass({
	mixins: [BackboneReactComponent],
	render: function(){
		var checkbox = <Checkbox
	      name={this.state.model.id}
	      value={this.state.model.id}
	      key={this.state.model.id}
	      defaultChecked={this.state.model.hidden}
	      onCheck={this.onEntryChecked}
    	/>
		return (

			<ListItem
				primaryText={ this.state.model.text }
				secondaryText={ moment(this.state.model.remind_timestamp).format('llll')}
				secondaryTextLines={1}
				leftCheckbox={ checkbox }
			/>
		)
	},
	onEntryChecked: function(e, checked) {
		var result = this.getModel().save({hidden: checked});
		console.log("onEntryChecked result " + result);
	},
});


module.exports = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
    var createEntry = function(entry, index) {
      return (
        <AdminEntryRow model={ entry } key={ entry.id } />
      );
    }.bind(this);

    return (
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
	        <List>
	      	  { this.props.collection.reminders().map(createEntry) }
	        </List>
      </Paper>
    );
  },
});