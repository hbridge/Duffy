var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var moment = require('moment');
var BackboneReactComponent = require('backbone-react-component');
var Utils = require('../utils.js')
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroup = Bootstrap.ListGroup;
  Table = Bootstrap.Table;
AdminEntryCard = require('./AdminEntryCard.jsx');


var EntryRow = React.createClass({
	mixins: [BackboneReactComponent],
	render() {
		console.log(this.state);
		console.log(this.props);
		return (
			<tr>
		        <td> {this.state.model.id} </td>
		        <td> {this.state.model.text} </td>
      		</tr>
      	);
	}
});


module.exports = React.createClass({
  mixins: [BackboneReactComponent],

  render() {
  	var createRow = function(entry, index) {
  		console.log("map create row", entry, index);
      return (
        <EntryRow model={ entry } key={ entry.id } />
      );
    }.bind(this);

  	return (
  		<Table>
			<thead>
				<tr>
					<th>#</th>
					<th>Text</th>
				</tr>
			</thead>
  			{ this.props.collection.map(createRow) }
  		</Table>
  	);
  },
 });