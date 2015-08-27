var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var moment = require('moment-timezone');
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
		        <td> { this.state.model.id } </td>
		        <td> { this.state.model.text } </td>
		        <td> { this.state.model.orig_text } </td>
		        <td> { moment.tz(this.state.model.remind_timestamp).format('llll') } </td>
		        <td> { moment.tz(this.state.model.added).format('llll') } </td>
		        <td> { this.state.model.remind_recur } </td>
		        <td> { this.state.model.remind_last_notified } </td>
		        <td> { moment.tz(this.state.model.updated).format('llll') } </td>
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
  		<Table striped bordered condensed hover>
			<thead>
				<tr>
					<th>id</th>
					<th>Text</th>
					<th>Orig text</th>
					<th>Remind timestamp (tz aware)</th>
					<th>Time added (tz aware)</th>
					<th>Recur</th>
					<th>Sent</th>
					<th>Updated</th>
				</tr>
			</thead>
			<tbody>
  			{ this.props.collection.map(createRow) }
  			</tbody>
  		</Table>
  	);
  },
 });