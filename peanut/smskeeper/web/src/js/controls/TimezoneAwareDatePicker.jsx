React = require('react');
DateTimePicker = require('react-bootstrap-datetimepicker');
moment = require('moment');

module.exports = React.createClass({
	getInitialState: function() {
		console.log("Initial moment: " + JSON.stringify(this.props.initialMoment));
		// get a the moment in the admin's TZ by parsing the date without TZ info
		var localMoment = moment(this.props.initialMoment.format('YYYY-MM-DD HH:mm'));
		console.log("Local moment: " + JSON.stringify(localMoment));
		return {localMoment: localMoment};
	},

	render: function() {
		return(
			<DateTimePicker
				ref="date"
				dateTime={this.state.localMoment.format('x')}
				onChange={this.pickedTimeChanged}
			/>
		);
	},

	pickedTimeChanged: function(timeString) {
		var localMoment = moment(timeString, "x");
		this.setState({localMoment: localMoment})
		console.log("pickedTimeChanged, local " + localMoment.format());
	},

	getLocalMoment: function(){
		return this.state.localMoment();
	},

	getTimezoneMoment: function(){
		// create the new moment in the user's timezone, but set the absolute values
		// from the control so it gets converted
		var timezoneMoment = moment.tz(this.state.localMoment.format('YYYY-MM-DD HH:mm'), this.props.timezone);
		console.log("localMoment: " + this.state.localMoment.format())
		console.log("timezoneMoment : " + timezoneMoment.format())
		return timezoneMoment;
	},

	shouldComponentUpdate: function(nextProps, nextState) {
		if (!this.props.initialMoment.isSame(nextProps.initialMoment)
			|| this.props.timezone != nextProps.timezone) {
			console.log("component updating");
			return true;
		}

		return false;
	}

});