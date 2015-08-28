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
  Modal = Bootstrap.Modal;
AdminEntryCard = require('./AdminEntryCard.jsx');


var EntryRow = React.createClass({
	mixins: [BackboneReactComponent],
	render() {
		var timezone = this.state.model.creatorTimezone;
		var approveButton = <Button
			bsStyle={this.state.model.manually_check ? 'danger' : 'success'}
			ref="approveButton"
			bsSize="xsmall"
			onClick={this.handleApproveToggled}
		>
			{this.state.model.manually_check ? "Unreviewed" : "Approved"}
		</Button>

		return (
			<tr onClick={this.handleRowClicked}>
		        <td> { approveButton } </td>
		        <td> { this.state.model.text } </td>
		        <td> { this.state.model.orig_text } </td>
		        <td> { moment.tz(this.state.model.remind_timestamp, timezone).format('llll') } </td>
		        <td> { moment.tz(this.state.model.added, timezone).format('llll') } </td>
		        <td> { this.state.model.remind_recur } </td>
		        <td> { this.state.model.remind_last_notified ? "√" : ""} </td>
		        <td> { moment.tz(this.state.model.updated, timezone).format('llll') } </td>
      		</tr>
      	);
	},

	handleApproveToggled(e) {
		e.preventDefault();
		e.stopPropagation();
		var newVal = !(this.state.model.manually_check);
		console.log("setting manually_check for %d to %s", this.state.model.id, newVal);
		var changes = {
			'manually_check': newVal,
			'manually_approved_timestamp': newVal ? null : moment().toISOString(),
		};
		var result = this.props.model.save(changes, {patch: true});
		console.log("save result:", result)
	},

	handleRowClicked(e) {
		e.preventDefault();
		this.props.onRowClicked(this.props.model);
	},



});


module.exports = React.createClass({
  mixins: [BackboneReactComponent],

  render() {
  	var createRow = function(entry, index) {
      return (
        <EntryRow model={ entry } key={ entry.id } onRowClicked={this.handleRowClicked}/>
      );
    }.bind(this);

    var modal = this.getModal();

  	return (
  		<div>
  		<Table striped bordered condensed hover>
			<thead>
				<tr>
					<th>Approval</th>
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
  		{ modal }
  		<p>Entries to review: <b>{ this.state.collection.length }</b></p>
  		</div>
  	);
  },

  handleRowClicked(entry){
  	this.setState({expandedEntry: entry});
  },

  getModal() {
  		creatorTimezone = null;
  		if (this.state.expandedEntry) {
  			creatorTimezone = this.state.expandedEntry.get('creatorTimezone');
  		}
		return (
			<Modal show={this.state.expandedEntry != null} onHide={this.close}>
	          <Modal.Body>
	           	<AdminEntryCard model={this.state.expandedEntry} expanded
	           		userTimezone={creatorTimezone}
	           		onSave={this.close}
	           		onCancel={this.close}
	           	/>
	          </Modal.Body>
	        </Modal>
        );
	},

	close(e) {
		this.setState({expandedEntry: null})
	}

 });