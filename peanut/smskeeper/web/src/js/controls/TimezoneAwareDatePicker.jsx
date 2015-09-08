React = require('react');
DateTimePicker = require('react-bootstrap-datetimepicker');
moment = require('moment');
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  Row = Bootstrap.Row;
  Col = Bootstrap.Col;

module.exports = React.createClass({
	getInitialState: function() {
		console.log("Initial moment: " + JSON.stringify(this.props.initialMoment));
		// get a the moment in the admin's TZ by parsing the date without TZ info
		var localMoment = moment(this.props.initialMoment.format('YYYY-MM-DD HH:mm'));
		console.log("Local moment: " + JSON.stringify(localMoment));
		return {localMoment: localMoment, isDigestTime: this.props.isDigestTime};
	},

	render: function() {
		console.log("rendering with localMomentFormat: %s", this.state.localMoment.format('x'));
		var timeChangeFunction = function(timeString) {
			this.pickedTimeChanged(timeString, 'time');
		}.bind(this);
		var dateChangeFunction = function(timeString) {
			this.pickedTimeChanged(timeString, 'date');
		}.bind(this);
		return(
			<Input label='Time' wrapperClassName='wrapper'>
				<Row>
				<Col xs={12} sm={4} smOffset={0}>
					<DateTimePicker
						ref="date"
						dateTime={this.state.localMoment.format('x')}
						onChange={dateChangeFunction}
						showToday={true}
						minDate={moment.tz(this.props.timezone)}
						mode='date'
						inputFormat="MM/DD/YY"
					/>
				</Col>
				<Col xs={12} sm={4} smOffset={0}>
					<DateTimePicker
						ref="time"
						dateTime={this.state.localMoment.format('x')}
						onChange={timeChangeFunction}
						showToday={true}
						minDate={moment.tz(this.props.timezone)}
						mode='time'
						inputFormat="h:mm A"
					/>
				</Col>
				<Col xs={12} md={4}>
					{
						this.state.isDigestTime ?
							<Input
							ref="digestTime"
							type='checkbox'
							label="Digest Time"
							onChange={this.toggleDigestTime}
							checked/> :
							<Input
							ref="digestTime"
							type='checkbox'
							label="Digest Time"
							onChange={this.toggleDigestTime}/>
					}
				</Col>
				</Row>
			</Input>
		);
	},

	pickedTimeChanged: function(timeString, fieldType) {
		var changedMoment = moment(timeString, "x");
		if (!changedMoment.isValid()) {
			console.log("changed moment invalid");
			return;
		}

		var localMoment = this.state.localMoment;
		if (fieldType == 'date') {
			localMoment.year(changedMoment.year());
			localMoment.month(changedMoment.month());
			localMoment.date(changedMoment.date());
		} else if (fieldType == 'time') {
			localMoment.hour(changedMoment.hour());
			localMoment.minute(changedMoment.minute());
		}

		this.setState({localMoment: localMoment})
		if (localMoment.hour() != this.props.digestHour || localMoment.minute() != this.props.digestMinute){
			// this.refs.digestTime.getInputDOMNode().checked = false;
			this.setState({isDigestTime: false})
		}
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

	isDigestTime() {
		return this.state.isDigestTime;
	},

	toggleDigestTime(e){
		console.log("toggle digestTime");
		if (e.target.value) {
			localMoment = this.state.localMoment;
			localMoment.set('hour', this.props.digestHour);
			localMoment.set('minute', this.props.digestMinute);
			this.setState({localMoment: localMoment, isDigestTime: true});
		}
	}

});