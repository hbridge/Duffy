var React = require('react')
var Bootstrap = require('react-bootstrap');
  DropdownButton = Bootstrap.DropdownButton;
  MenuItem = Bootstrap.MenuItem;
var Utils = require('../utils.js');

var cannedResponses = [
	":bulb: Pro tip: for faster responses, give me a day or a time :clock3: when you ask for a reminder. :sunglasses:",
	":bulb: Pro tip: you can say \"Done with all\" to check off all your tasks. :white_check_mark:",
	":bulb: Pro tip: you can say \"My zipcode is 12345\" to tell me when you move. :airplane:",
  ":hatching_chick: I don't know how to do that yet. I'll ask my minions to teach me. :smiley_cat:",
  "That's not very nice. Keep it up and I'll stop talking to you. :angry:",
  "Ok, gotta get back to work :information_desk_person: let me know if you need any reminders!",
];

module.exports = React.createClass({
	render: function(){
		return (<DropdownButton
        title='CR'
        ref='crselect'>
        {this.cannedResponseMenuItems()}
      </DropdownButton>
      );
	},

	crSelected: function(key) {
    	console.log("cr changed to key" + key);
    	this.props.onCannedResponseSelected(cannedResponses[key]);
  	},

  cannedResponseMenuItems: function() {
    var result = [];
    for (var i = 0; i < cannedResponses.length; i++) {
      result.push(
        <MenuItem
          eventKey={i}
          onSelect={this.crSelected}
        >
        {Utils.Emojize(cannedResponses[i])}
        </MenuItem>
      );
    }

    return result;
  }
});