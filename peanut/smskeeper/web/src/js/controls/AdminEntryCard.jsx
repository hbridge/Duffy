var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require("moment");
var BackboneReactComponent = require('backbone-react-component');

mui = require('material-ui'),
  SvgIcon = mui.SvgIcon;
  FlatButton = mui.FlatButton;
  RaisedButton = mui.RaisedButton;
  Dialog = mui.Dialog;
  Checkbox = mui.Checkbox;
  TextField = mui.TextField;
  DropDownMenu = mui.DropDownMenu;
  Card = mui.Card;
  CardTitle = mui.CardTitle;
  CardText = mui.CardText;
  CardActions = mui.CardActions;
  DatePicker = mui.DatePicker;
  TimePicker = mui.TimePicker;
  Checkbox = mui.Checkbox;

var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroupItem = Bootstrap.ListGroupItem;
TZDateTimePicker = require('./TimezoneAwareDatePicker.jsx');

var recurMenuItems = [
	{payload: "default", text: "none (default)"},
	{payload: "one-time", text: "one-time"},
	{payload: "daily", text: "daily"},
	{payload: "every-2-days", text: "every-2-days"},
	{payload: "weekdays", text: "weekdays"},
	{payload: "weekly", text: "weekly"},
	{payload: "monthly", text: "monthly"},
];


// <CardActions>
// 			    		<TextField
// 				            ref="text"
// 				            defaultValue={this.state.model.text}
// 				            hintText="Entry text"
// 				            multiLine={true}
// 				            style={{width: '80%'}}
// 		            	/>
// 		            	<DatePicker
// 		            		ref="date"
// 		            		defaultDate={this.getAdminLocalDate()}
// 		  					hintText="Reminder date"
// 		  					style={{width: "20%"}}
// 		  					autoOk={true}
// 		  					minDate={new Date()}
// 		  				/>
// 		  				<TimePicker
// 		  					ref="time"
// 		            		defaultTime={this.getAdminLocalDate()}
// 		  					hintText="Reminder date"
// 		  					format="24hr"
// 		  					style={{width: "20%"}}
// 		  				/>
// 		  				<DropDownMenu
// 							ref="recur"
// 							menuItems={recurMenuItems}
// 							selectedIndex={this.getSelectedRecurIndex()}
// 						/>
// 		  				<div style="height: 10px" className="smallVerticalSpacer"/>
// 		  				<Checkbox
// 		  					ref="hidden"
// 		  					label="Hidden"
// 		  				/>
// 		  				<div style="height: 10px" className="mediumVerticalSpacer"/>
// 		  				<RaisedButton
// 		  					label="Save"
// 		  					secondary={true}
// 		  					className="submitButton"
// 		  					onClick={this.onSave}
// 		  				/>
// 		    	</CardActions>

module.exports = React.createClass({
	mixins: [BackboneReactComponent],
	render: function() {
		var editText = <TextField
	            ref="text"
	            defaultValue={this.state.model.text}
	            hintText="Entry text"
	            multiLine={true}
	            style={{width: '100%'}}
	        />

	    var expandedElems = null;
	    if (this.state.expanded) {
	    	expandedElems = (
	    		<div>
	    			<div>
	    				<br />
	    				Original Messages: {this.state.model.orig_text} <br />
	    				Added Date: {moment.tz(this.state.model.added, USER.timezone).format('llll')}
	    			</div>
	    			<form className='inputElement' onSubmit={this.createEntry}>
		    			<Input
			    			type='text'
			    			ref='text'
			    			defaultValue={this.state.model.text}
			    			placeholder="Entry text"
		    			/>
		    			<TZDateTimePicker
		    				ref="date"
		    				initialMoment={moment.tz(this.state.model.remind_timestamp, USER.timezone)}
		    				timezone={USER.timezone}
		    			/>
		    			<Input ref="recur"
		    				type='select'
		    				label="Type"
		    				defaultValue={this.state.model.remind_recur}
		    			>
      						<option value='default'>Default Reminder</option>
      						<option value='one-time'>One-time Reminder</option>
      						<option value='daily'>Daily Reccurring</option>
      						<option value='every-2-days'>Every 2 days Reccurring</option>
      						<option value='weekdays'>Weekdays Reccurring</option>
      						<option value='weekly'>Weekly Reccurring</option>
      						<option value='monthly'>Monthly Reccurring</option>
    					</Input>
    					<Input ref="hidden" type='checkbox' label="Hidden" />
    					<Button
	    					onClick={this.onSave}
	    					bsStyle="primary"
	    				>
	    					Save
    					</Button>
    					<Button
	    					onClick={function(e){this.setState({expanded: false})}.bind(this)}
	    				>
	    					Cancel
    					</Button>
	    			</form>
	    	</div>
	    	);
	    }

	    var subtitle = moment.tz(this.state.model.remind_timestamp, USER.timezone).format('llll');
	    if (this.state.model.remind_recur && this.state.model.remind_recur != "default") {
	    	subtitle = subtitle + " (recurs " + this.state.model.remind_recur + ")";
	    }

    	return(
    		<ListGroupItem
    			header={ this.state.model.text }
    			onClick={ this.state.expanded ? null : this.onTapCardTitle }
    		>
    			{ subtitle }
	  			{ expandedElems }
	  		</ListGroupItem>
	  	);

	},

	onTapCardTitle: function(e) {
		this.setState({expanded: !this.state.expanded});
	},

	onSave: function(e) {
		e.preventDefault();
		var entryChanged = false;
		var changes = {};

		// check to see if text changed
		var newText = this.refs.text.getValue();
		if (newText != this.state.model.text) {
			console.log("text changed");
			entryChanged = true;
			changes.text = newText;
		}

		// see if the time for the entry changed
		var newMoment = this.refs.date.getTimezoneMoment();
		console.log("old moment: " + JSON.stringify(moment(this.state.model.remind_timestamp)));
		console.log("new moment: " + JSON.stringify(newMoment));
		if (newMoment.isSame(moment(this.state.model.remind_timestamp))) {
			console.log("date unchanged");
		} else {
			console.log("date changed");
			entryChanged = true;
			changes.remind_timestamp = newMoment.toISOString();
		}

		// se if recur has changed
		var newRecurValue = this.refs.recur.getValue();
		console.log("recur val: " + newRecurValue);
		if (this.refs.recur.getValue() != this.state.model.remind_recur) {
			console.log("recur changed");
			entryChanged = true;
			changes.remind_recur = newRecurValue;
		}

		// see if hidden toggle changed
		var newHiddenVal = this.refs.hidden.getInputDOMNode().checked;
		console.log("hidden val: " + newHiddenVal);
		if (newHiddenVal != this.state.model.hidden) {
			console.log("hidden changed");
			entryChanged = true;
			changes.hidden = newHiddenVal;
		}

		console.log("new values: ", newText, newMoment, newRecurValue, newHiddenVal);

		if (entryChanged) {
			changes.manually_updated = true;
			changes.manually_updated_timestamp = moment().toISOString();
			var result = this.props.model.save(changes);
			console.log("save result:", result)
			this.setState({expanded: false});
		}
	},
});