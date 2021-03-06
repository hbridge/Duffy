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
  Popover = Bootstrap.Popover;
  OverlayTrigger = Bootstrap.OverlayTrigger;
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
	getInitialState(){
		return({model: this.props.model.attributes});
	},
	componentDidMount(){
		this.props.model.on("change", function(eventName){
			if (this.state.model.manually_check != this.props.model.attributes.manually_check) {
				this.setState({model: this.props.model.attributes})
				console.log("change", this.props.model.attributes);
			} else {
				console.log("no change");
			}
		}.bind(this));
	},

	render() {
		var timezone = this.state.model.creator_timezone;
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
		        <td> <a href={'/smskeeper/history?user_id=' + this.state.model.creator } target="_blank"> {this.state.model.creator_name} </a></td>
		        <td>
		        	<a onClick={this.handleRowClicked} href="#" className="userText">{ this.state.model.text } </a><br />
		        	[{ _.map(JSON.parse(this.state.model.orig_text), this.getUnsquashLink) }]
		        </td>
		        <td> <div style={{minWidth: "52px"}}>{this.getCreateRemindDeltaText()} </div></td>
		        <td onClick={this.handleRowClicked}>
		        	<div style={{minWidth: "110px"}}>
		        		{ this.state.model.use_digest_time ? "\u00a0" + emoji.get("memo") : ""}
		        		{ moment.tz(this.state.model.remind_timestamp, timezone).format(dateFormat) }
		        		{ this.state.model.remind_to_be_sent ? "" : "\u00a0" + emoji.get("white_check_mark")}
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

	getUnsquashLink(text) {
		var popover = <Popover title='Unsquash'>
			Copy entry with text &ldquo;{text}&rdquo;?
			<br /><br />
			<Button onClick={function(e){
				this.handleUnsquashLinkClicked(text);
			}.bind(this)} bsSize="small">
				Create
			</Button>
		</Popover>;
		return (
			<OverlayTrigger ref="unsquashTrigger" trigger='click' placement='bottom' overlay={popover} rootClose={true}>
	      		<span>&ldquo;<a href="#" className="userText">{text}</a>&rdquo;</span>
    		</OverlayTrigger>
		);
	},

	handleUnsquashLinkClicked(text) {
		console.log("Unsquashing %s", text);
		var newModel = this.props.model.clone();
		newModel.set("text", text);
		newModel.set("id", null);
		this.props.collection.add(newModel);
		var saveResult = newModel.save();
		console.log("Save copy result: ", saveResult)
		this.refs.unsquashTrigger.dismiss();
	},
});


module.exports = React.createClass({
  mixins: [BackboneReactComponent],

  render() {
  	var createRow = function(entry, index) {
      return (
        <EntryRow model={ entry } collection={this.props.collection} key={ entry.id } onRowClicked={this.handleRowClicked}/>
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
  			creatorTimezone = this.state.expandedEntry.get('creator_timezone');
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