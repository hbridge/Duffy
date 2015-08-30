var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var moment = require('moment-timezone');
var BackboneReactComponent = require('backbone-react-component');
var Utils = require('../utils.js');
var _ = require('underscore');
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroup = Bootstrap.ListGroup;
  Table = Bootstrap.Table;
  Modal = Bootstrap.Modal;
  SplitButton = Bootstrap.SplitButton;
  MenuItem = Bootstrap.MenuItem;
AdminEntryCard = require('./AdminEntryCard.jsx');
var emoji = require('node-emoji');

var RecurButton = React.createClass({
	mixins: [BackboneReactComponent],
	render() {
		var style = 'default';
		var title = "Default";
		var recurOptions = this.props.model.recurOptions();

		if (this.state.model) {
			var option = _.find(recurOptions, function(option){return option.value == this.state.model.remind_recur}.bind(this));
			title = option.shortText;
			if (this.state.model.remind_recur == 'default') {
				style = 'default';
			} else if (this.state.model.remind_recur == 'one-time') {
				style = 'info';
			} else {
				style = 'primary';
			}
		}

		return (
			<SplitButton bsStyle={style} title={title} key={title} bsSize='xsmall' pullRight onClick={this.handleMainButtonClicked}>
				{recurOptions.map(function(option){
					var handlerFunc = function(e){this.handleMenuItemClicked(option.value)}.bind(this);
			    	return (<MenuItem eventKey={option.value} onClick={handlerFunc}>{option.longText}</MenuItem>);
			   	}.bind(this))};
	    	</SplitButton>
    	);
	},

	handleMainButtonClicked(e){
		console.log("main button clicked");
		var newVal = 'default';
		if (this.state.model.remind_recur == 'default') {
			newVal = 'one-time';
		}

		this.props.model.save({remind_recur: newVal}, {patch: true});
	},

	handleMenuItemClicked(recurValue) {
		this.props.model.save({remind_recur: recurValue}, {patch: true});
	},
});


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

		var dateFormat = "h:mm A ddd, MMM D";

		return (
			<tr>
		        <td> { approveButton } </td>
		        <td> <a href={'../history?user_id=' + this.state.model.creator } target="_blank"> {this.state.model.creatorName} </a></td>
		        <td onClick={this.handleRowClicked}>
		        	{ this.state.model.text } <br />
		        	{ this.state.model.orig_text }
		        </td>
		        <td> <div style={{minWidth: "52px"}}>{this.getCreateRemindDeltaText()} </div></td>
		        <td onClick={this.handleRowClicked}>
		        	<div style={{minWidth: "110px"}}>
		        		{ moment.tz(this.state.model.remind_timestamp, timezone).format(dateFormat) }
		        		&nbsp;{ this.state.model.remind_last_notified ? emoji.get("white_check_mark") : ""}
		        	</div>
		        </td>
		        <td onClick={this.handleRowClicked}>
		        	<div style={{minWidth: "110px"}}> { moment.tz(this.state.model.added, timezone).format(dateFormat) }</div>
		        </td>
		        <td> <div style={{minWidth: "90px"}}><RecurButton model={this.props.model} /> </div></td>
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

	getCreateRemindDeltaText(){
		var millis = moment(this.state.model.remind_timestamp).diff(this.state.model.added);
		var duration = moment.duration(millis);
		return duration.days() + "d " + duration.hours() + "h";
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
					<th>User</th>
					<th>Text</th>
					<th>∆</th>
					<th>Remind time (tz aware)</th>
					<th>Time added (tz aware)</th>
					<th>Recur</th>
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