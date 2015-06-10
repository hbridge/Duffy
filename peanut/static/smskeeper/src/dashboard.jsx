var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var timeago = require('timeago');

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
    var createRows = function(users) {
      count = 0;
      result = [];
      for (index in users) {
        user = users[index];

        count++;
        result.push(<UserRow user={ user } highlighted={ count % 2 == 0 } />)
      }
      return result;
		}.bind(this);
    headerValues = ["user", "name", "fullname", "joined", "activated", "tutorial (src)", "msgs (in/out)", "last in", "history"];

    if (this.props.users.length > 0) {
      return (
        <div>
          <h1>{ this.props.title }</h1>
          <table>
            <HeaderRow headerValues={ headerValues } />
            { createRows(this.props.users) }
          </table>
        </div>
      );
    } else {
      return (<div></div>);
    }

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
    accountAge = timeago(new Date(this.props.user.created));
    tutorial_text = this.props.user.completed_tutorial ? "√ " + this.props.user.source : this.props.user.source;
    if (this.props.user.paused)
      tutorial_text += " PAUSED"
    if (this.props.user.state === "stopped")
      tutorial_text += " STOPPED"
    activated_text = null;
    if (this.props.user.activated)
      activated_text = timeago(new Date(this.props.user.activated));
    in_date = new Date(this.props.user.message_stats.incoming.last);
    out_date = new Date(this.props.user.message_stats.outgoing.last);
    //last = in_date > out_date ? in_date : out_date;
    last = in_date
    timeago_text = timeago(last);

    var rowClasses = classNames({
      'oddrow' : this.props.highlighted == true,
		});
		return (
      <tr className= {rowClasses}>
        <td className="cell"> { this.props.user.id } ({ this.props.user.phone_number })</td>
        <td className="cell"> <a href={"/"+this.props.user.key}>{ this.props.user.name }</a></td>
        <td className="cell" title={ this.props.user.full_name }> { this.props.user.full_name[0] }</td>
        <td className="cell"> { accountAge }</td>
        <td className="cell"> { activated_text }</td>
        <td className="cell"> { tutorial_text }</td>
        <td className="cell"> { this.props.user.message_stats.incoming.count }/{ this.props.user.message_stats.outgoing.count }</td>
        <td className="cell"> { timeago_text } </td>
        <td className="cell"> <a target="_blank" href={ this.props.user.history }>history</a></td>
      </tr>
    );
  },
});

var DashboardApp = React.createClass({
  getInitialState: function() {
    return {users: [], daily_stats: {}};
  },
  loadDataFromServer: function() {
    $.getJSON("/smskeeper/dashboard_feed", this.dataCallback);
  },
  componentDidMount: function() {
		this.loadDataFromServer();
    var loadFunc = this.loadDataFromServer;
    setInterval(function () {loadFunc()}, 10000);
  },

	dataCallback: function(data) {
	  console.log(data);
    this.setState( {
      users : data.users,
      daily_stats : data.daily_stats
    });
	},

	render: function() {
    var countActivated = function(users) {
      result = 0;
      for (i=0; i<users.length; i++) {
        if (users[i].activated) {
          result++;
        }
      }
      return result
    }.bind(this);

    var filterUsers = function(users, wantActivated, activatedBefore, activatedAfter) {
      var results = [];

      for (i=0; i<users.length; i++) {
        if (!wantActivated && !users[i].activated) {
          results.push(users[i]);
        } else if (wantActivated && users[i].activated){
          activatedDate = new Date(users[i].activated);
          if (activatedDate > activatedAfter && activatedDate < activatedBefore) {
            results.push(users[i]);
          }
        }
      }
      return results;
    };

    var getPausedUsers = function(users) {
      var results = [];
      for (i=0; i<users.length; i++) {
        if (users[i].paused) {
          results.push(users[i]);
        }
      }
      return results;
    }

    var now = new Date();
    var yest = new Date();
    var twoweeks = new Date();
    yest.setDate(yest.getDate() - 1);
    twoweeks.setDate(twoweeks.getDate() - 14);

    var pausedUsers = getPausedUsers(this.state.users);
    var nonActivatedUsers = filterUsers(this.state.users, false, null, null);
    var recentlyActivatedUsers = filterUsers(this.state.users, true, now, yest);
    var normalUsers = filterUsers(this.state.users, true, yest, twoweeks);

		return (
      <div>
        <DailyTable stats={ this.state.daily_stats} />
        <UserTable users={ pausedUsers } showActivated={ true } title={"Paused (" + pausedUsers.length  + ")"}/>
        <UserTable users={ normalUsers } showActivated={ true } title={"Active (" + normalUsers.length  + ")"}/>
        <UserTable users={ recentlyActivatedUsers } showActivated={ true } title={"Recently Activated (" + recentlyActivatedUsers.length + ")"}/>
        <UserTable users={ nonActivatedUsers } showActivated={ false } title={ "Not activated (" + nonActivatedUsers.length + ")"}/>
      </div>
		);
	},
});

React.render(<DashboardApp />, document.getElementById("app"));
