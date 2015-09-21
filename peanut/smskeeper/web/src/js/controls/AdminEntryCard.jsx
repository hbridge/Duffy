var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require("moment-timezone");
var BackboneReactComponent = require('backbone-react-component');

var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroupItem = Bootstrap.ListGroupItem;
  Well = Bootstrap.Well;
var TZDateTimePicker = require('./TimezoneAwareDatePicker.jsx');


module.exports = React.createClass({
	mixins: [BackboneReactComponent],

	componentDidMount(){
		if (this.props.expanded) {
			this.setState({expanded: true});
		}
	},

	render: function() {
	    var expandedElems = null;
	    if (this.state.expanded) {
	    	expandedElems = (
	    		<div>
	    			<br/>
	    			<Well>
	    				Entry ID: <a href={'/admin/smskeeper/entry/' + this.state.model.id} target="_blank">{this.state.model.id}</a><br/>
	    				Original Messages: {this.state.model.orig_text} <br />
	    				Added: {moment.tz(this.state.model.added, this.props.userTimezone).format('llll')} <br />
	    				User IDs: {this.state.model.users.join(", ")}
	    			</Well>
	    			<form className='inputElement' onSubmit={this.createEntry}>
		    			<Input
			    			type='text'
			    			ref='text'
			    			defaultValue={this.state.model.text}
			    			placeholder="Entry text"
		    			/>
		    			<TZDateTimePicker
		    				ref="date"
		    				initialMoment={moment.tz(this.state.model.remind_timestamp, this.props.userTimezone)}
		    				timezone={this.props.userTimezone}
		    				isDigestTime={this.state.model.use_digest_time}
		    				digestHour={this.state.model.creator_digest_hour}
		    				digestMinute={this.state.model.creator_digest_minute}
		    			/>
		    			<Input ref="recur"
		    				type='select'
		    				label="Type"
		    				defaultValue={this.state.model.remind_recur}
		    			>
		    				{this.props.model.recurOptions().map(function(option){
		    					return (<option value={option.value}>{option.longText}</option>);
		    				})};
    					</Input>
    					<Input ref="hidden" type='checkbox' label="Hidden" defaultChecked={this.state.model.hidden}/>
    					<Button
	    					onClick={this.onSave}
	    					bsStyle="primary"
	    				>
	    					Save
    					</Button>
    					<Button
	    					onClick={this.handleCancel}
	    				>
	    					Cancel
    					</Button>
	    			</form>
	    	</div>
	    	);
	    }

	    var subtitle = moment.tz(this.state.model.remind_timestamp, this.props.userTimezone).format('llll');
	    var qualifiers = [];
	    if (this.state.model.remind_recur && this.state.model.remind_recur != "default") {
	    	qualifiers.push("recurs " + this.state.model.remind_recur);
	    }
	    if (this.state.model.users.length > 1) {
	    	qualifiers.push(" shared");
	    }
	    if (qualifiers.length > 0) {
	    	subtitle = subtitle + " (" + qualifiers.join(", ") + ")"
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

	handleCancel(e){
		e.preventDefault();
		if (this.props.onCancel) {
			this.props.onCancel();
		} else {
			this.setState({expanded: false});
		}
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
			changes.remind_to_be_sent = true;
		}

		if (this.state.model.use_digest_time != this.refs.date.isDigestTime()) {
			changes.use_digest_time = this.refs.date.isDigestTime();
			entryChanged = true;
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
			if (this.state.model.manually_check) {
				// the entry was marked as needing review, mark it off as approved since we're manually updating
				changes.manually_check = false;
				changes.manually_approved_timestamp = moment().toISOString();
			}

			changes.manually_updated = true;
			changes.manually_updated_timestamp = moment().toISOString();
			var result = this.props.model.save(changes);
			console.log("save result:", result)
			if (this.props.onSave) {
				this.props.onSave();
			} else {
				this.setState({expanded: false});
			}
		}
	},
});