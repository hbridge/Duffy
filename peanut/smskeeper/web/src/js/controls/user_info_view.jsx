var React = require('react')
var moment = require('moment-timezone');


module.exports = React.createClass({
	getInitialState: function(){
		return {currentDate: new Date()}
	},

	setTime: function(){
		this.setState({currentDate: new Date()});
	    setTimeout(this.setTime, 1000);
	},

	componentDidMount: function(){
		this.setTime();
	},

	render: function() {
		console.log(USER.timezone)

		localmoment = moment(this.state.currentDate).tz(USER.timezone)
		return (
			<div className="topLevel">
			<p><b>Name: {USER.name}</b> | Local Time (non-DST aware): {localmoment.format('dddd h:mm:ss a')} | Zip: {USER.postal_code} </p>
			</div>
			);
	}
});