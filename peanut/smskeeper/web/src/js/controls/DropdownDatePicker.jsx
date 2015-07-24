var DatePicker = React.createClass({
	getInitialState: function() {
		return {date: this.props.initialDate};
	},


	render: function() {
		return(
		<div>
			<DropDownMenu
				ref="monthMenu"
				menuItems={monthMenuItems}
				selectedIndex={moment(this.state.date).month()}
				onChange={this.onMonthChange}
			/>
			<DropDownMenu
				ref="dateMenu"
				menuItems={this.getDayMenuOptions()}
				selectedIndex={moment(this.state.date).date() - 2}
				onChange={this.onDayChange}
			/>
		</div>);
	},

	getDayMenuOptions: function() {
		var remindMoment = moment(this.state.entryDate);
		var originalMonth = remindMoment.month();
		var options = [];
		for (var i = 1; i < 32; i++) {
			remindMoment.date(i);
			if (remindMoment.month() == originalMonth) {
				options.push({payload: i, text: i + " - " + remindMoment.format('ddd')});
			}
		}
		return options;
	},

	onMonthChange: function(e, selectedIndex, menuItem){
		this.onDateChange(selectedIndex, 'month')
	},

	onDayChange: function(e, selectedIndex, menuItem){
		this.onDateChange(selectedIndex + 1, 'date')
	},

	onDateChange: function(value, type) {
		console.log("changing " + type + " to:" + value);
		var newMoment = moment(this.state.date);
		if (type == "month") {
			newMoment.month(value);
		} else if (type == 'date') {
			newMoment.date(value);
		}

		console.log(newMoment.format('llll'));
	}
});