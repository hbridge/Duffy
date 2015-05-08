var DailyTable = React.createClass({
  render: function() {
    headerValues = ["days", "users (in/out)", "msgs (in/out)"];
    var createRow = function(days, index) {
			return <DailyStatsRow days={days} stats={ this.props.stats[days] } index= { index } />
		}.bind(this);

    if (this.props.stats) {
      day_keys = Object.keys(this.props.stats);
    } else {
      day_keys = [];
    }
    console.log(day_keys);

    return (
      <div>
        <h1>Daily Stats</h1>
        <table>
          <HeaderRow headerValues={ headerValues } />
          { day_keys.map(createRow) }
        </table>
      </div>
    );
  }
});

var DailyStatsRow = React.createClass({
  render: function() {
    var rowClasses = classNames({
      'oddrow' : this.props.index % 2 == 1,
		});
    return (
      <tr className={ rowClasses }>
        <th className="cell"> {this.props.days} </th>
        <td> { this.props.stats.incoming.user_count }/{ this.props.stats.outgoing.user_count }</td>
        <td> { this.props.stats.incoming.messages }/{ this.props.stats.outgoing.messages }</td>
      </tr>
    );
  }
});

var UserTable = React.createClass({
  render: function() {
    var createRow = function(item, index) {
			return <UserRow user={ item } index= { index } />
		}.bind(this);
    headerValues = ["user", "name", "joined", "activated", "tutorial", "msgs (in/out)", "last in", "history"];

		return (
      <div>
        <h1>Users</h1>
        <table>
          <HeaderRow headerValues={ headerValues } />
          { this.props.users.map(createRow) }
        </table>
      </div>
    );
  },
});

var HeaderRow = React.createClass({
  render: function() {
    var createHeaderCell = function(item, index){
      return (<th className="cell"> { item } </th>);
    }.bind(this);

    return (
      <tr>
        { this.props.headerValues.map(createHeaderCell)}
      </tr>
    );
  }
});

var UserRow = React.createClass({
  render: function() {
    accountAge = jQuery.timeago(new Date(this.props.user.created));
    tutorial_text = this.props.user.tutorial_step.toString();
    if (this.props.user.completed_tutorial) tutorial_text += " √";
    activated_text = null;
    if (this.props.user.activated)
      activated_text = jQuery.timeago(new Date(this.props.user.activated));
    in_date = new Date(this.props.user.message_stats.incoming.last);
    out_date = new Date(this.props.user.message_stats.outgoing.last);
    //last = in_date > out_date ? in_date : out_date;
    last = in_date
    timeago_text = jQuery.timeago(last);

    console.log(tutorial_text);

    var rowClasses = classNames({
      'oddrow' : this.props.index % 2 == 1,
		});
		return (
      <tr className= {rowClasses}>
        <td className="cell"> { this.props.user.id } ({ this.props.user.phone_number })</td>
        <td className="cell"> { this.props.user.name }</td>
        <td className="cell"> { accountAge }</td>
        <td className="cell"> { activated_text }</td>
        <td className="cell"> { tutorial_text }</td>
        <td className="cell"> { this.props.user.message_stats.incoming.count }/{ this.props.user.message_stats.outgoing.count }</td>
        <td className="cell"> { timeago_text } </td>
        <td className="cell"> <a href={ this.props.user.history }>history</a></td>
      </tr>
    );
  },
});

var DashboardApp = React.createClass({
  getInitialState: function() {
    return {users: [], daily_stats: {}};
  },

  componentWillMount: function() {
		$.getJSON("/smskeeper/dashboard_feed", this.dataCallback);
  },

	dataCallback: function(data) {
	  console.log(data);
    this.setState( {
      users : data.users,
      daily_stats : data.daily_stats
    });
	},

	render: function() {
		return (
      <div>
        <DailyTable stats={ this.state.daily_stats} />
        <UserTable users={ this.state.users }/>
      </div>
		);
	},
});

React.render(<DashboardApp />, document.getElementById("app"));
