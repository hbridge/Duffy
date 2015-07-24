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
  List = mui.List;
  ListItem = mui.ListItem;
  ListDivider = mui.ListDivider;
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

	     var expandedElems = <div></div>;
	    if (this.state.expanded) {
	    	expandedElems = (
	    		<Paper zDepth={0} className="controlPanel">
	    			<CardText>
	    				Original Messages: {this.state.model.orig_text} <br />
	    				Added Date: {moment.tz(this.state.model.added, USER.timezone).format('llll')}
	    			</CardText>
	    			<CardActions>
			    		<TextField
				            ref="text"
				            defaultValue={this.state.model.text}
				            hintText="Entry text"
				            multiLine={true}
				            style={{width: '80%'}}
		            	/>
		            	<DatePicker
		            		ref="date"
		            		defaultDate={this.getAdminLocalDate()}
		  					hintText="Reminder date"
		  					style={{width: "20%"}}
		  					autoOk={true}
		  					minDate={new Date()}
		  				/>
		  				<TimePicker
		  					ref="time"
		            		defaultTime={this.getAdminLocalDate()}
		  					hintText="Reminder date"
		  					format="24hr"
		  					style={{width: "20%"}}
		  				/>
		  				<div style="height: 10px" className="smallVerticalSpacer"/>
		  				<Checkbox
		  					ref="hidden"
		  					label="Hidden"
		  				/>
		  				<div style="height: 10px" className="mediumVerticalSpacer"/>
		  				<RaisedButton
		  					label="Save"
		  					secondary={true}
		  					className="submitButton"
		  					onClick={this.onSave}
		  				/>
		    	</CardActions>
	    	</Paper>
	    	);
	    }

    	return(
    		<Card>
	  			<CardTitle
		  			title={ this.state.model.text }
		  			subtitle={ moment.tz(this.state.model.remind_timestamp, USER.timezone).format('llll')}
		  			onTouchTap={ this.onTapCardTitle }
		  			style={{margin: "10px"}}
		  			titleStyle={{fontSize: "14pt"}}
	  			/>
	  			{ expandedElems }
	  		</Card>
	  	);

	},

	onTapCardTitle: function(e) {
		this.setState({expanded: !this.state.expanded});
	},

	// get the date of the reminder as if it were created in the Admin's local timezone
	getAdminLocalDate: function() {
		var usermoment = moment.tz(this.state.model.remind_timestamp, USER.timezone);
		console.log("user moment: " + JSON.stringify(usermoment));
		// get a the moment in the admin's TZ by parsing the date without TZ info
		var adminmoment = moment(usermoment.format('YYYY-MM-DD HH:mm'));
		console.log("admin moment: " + JSON.stringify(adminmoment));

		var adminLocalDate = adminmoment.toDate();
		console.log("adminLocalDate: "+ adminLocalDate);
		return adminLocalDate;
	},

	onSave: function(e) {
		e.preventDefault();
		var entryChanged = false;
		var changes = {};

		// check to see if text changed
		var newText = this.refs.text.getValue();
		if (newText != this.state.model.text) {
			console.log("text changed");
			changes.text = newText;
		}

		// create the new moment in the user's timezone, but set the absolute values
		// from the control so it gets converted
		var dateControlComponents = [
			this.refs.date.getDate().getFullYear(),
			this.refs.date.getDate().getMonth(),
			this.refs.date.getDate().getDate(),
		];
		var newMoment = moment.tz(dateControlComponents, USER.timezone);
		newMoment.set('hour', this.refs.time.getTime().getHours());
		newMoment.set('minute', this.refs.time.getTime().getMinutes());

		// see if the time for the entry changed
		console.log("old moment: " + JSON.stringify(moment(this.state.model.remind_timestamp)));
		console.log("new moment: " + JSON.stringify(newMoment));
		if (newMoment.isSame(moment(this.state.model.remind_timestamp))) {
			console.log("date unchanged");
		} else {
			console.log("date changed");
			entryChanged = true;
			changes.remind_timestamp = newMoment.toISOString();
		}

		// see if hidden toggle changed
		if (this.refs.hidden.isChecked() != this.state.model.hidden) {
			changed = true;
			changes.hidden = this.refs.hidden.isChecked();
		}


		if (entryChanged) {
			var result = this.props.model.save(changes);
			console.log("save result:")
			console.log(result);
		}
	},
});