var React = require('react')
var Bootstrap = require('react-bootstrap');
  DropdownButton = Bootstrap.DropdownButton;
  MenuItem = Bootstrap.MenuItem;
var Utils = require('../utils.js');

var cannedResponses = [
	"Psst:ear:... for faster responses, give me a day or a time :clock3: with every task that you enter. :sunglasses:",
	"Psst:ear:... you can tell me \"Done with all\" to check off all tasks. :sunglasses:",
	"Psst:ear:... you can say \"My zipcode is 12345\" to tell me when you move. :sunglasses:",
  "I don't know how to do that yet :frowning:. I'll ask my minions :smiley_cat: to teach me."
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