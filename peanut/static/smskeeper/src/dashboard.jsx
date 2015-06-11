var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var timeago = require('timeago');
var FixedDataTable = require('fixed-data-table');
var Table = FixedDataTable.Table;
var Column = FixedDataTable.Column;
var format = require('string-format')

var DailyTable = React.createClass({
  render: function() {
    headerValues = ["days", "users (in/out)", "msgs (in/out)"];
    var dayKeys = null;
    var createRow = function(days, index) {
			return <DailyStatsRow days={days} stats={ this.props.stats[days] } index= { index } />
		}.bind(this);

    if (this.props.stats) {
      day_keys = Object.keys(this.props.stats);
    } else {
      day_keys = [];
    }
    console.log(day_keys);

    var rowGetter = function rowGetter(rowIndex) {
      day_key = day_keys[rowIndex];
      stats = this.props.stats[day_key];
      return [
        day_key,
        stats.incoming.user_count + "/" + stats.outgoing.user_count,
        stats.incoming.messages + "/" + stats.outgoing.messages,
      ];
    }.bind(this);

    var rowCount = 0;
    if (this.props.stats) rowCount = day_keys.length;
    console.log("rowCount " + rowCount);

    return (
      <div>
        <h1>Daily Stats</h1>
        <Table
          rowHeight={40}
          rowGetter={rowGetter}
          rowsCount={rowCount}
          width={600}
          maxHeight={768}
          headerHeight={40}>
          <Column
            label="days"
            width={200}
            dataKey={0}
            />
          <Column
            label="users (in/out)"
            width={200}
            dataKey={1}
          />
          <Column
            label="msgs (in/out)"
            width={200}
            dataKey={2}
          />
        </Table>
      </div>
    );

  }
});

var UserTable = React.createClass({
  render: function(){
    var rowGetter = function rowGetter(rowIndex) {
      return this.rowForUser(this.props.users[rowIndex]);
    }.bind(this);

    var renderUsername = function(user) {
      return (<a href={"/"+user.key+"?internal=1"}>{ user.name }</a>);
    }
    var renderFullName = function(user) {
      return (<span title={ user.full_name }> { user.full_name[0] }</span>);
    }
    var renderHistory = function(user) {
      return (<a target="_blank" href={ user.history }>history</a>);
    }

    return (
      <div>
        <h1>{ this.props.title }</h1>
        <Table
          rowHeight={40}
          rowGetter={rowGetter}
          rowsCount={this.props.users.length}
          width={1200}
          maxHeight={768}
          headerHeight={40}>
          <Column label="user" width={180} dataKey={0} />
          <Column label="name" width={180} dataKey={1} cellRenderer={renderUsername} />
          <Column label="fullname" width={180} dataKey={2} cellRenderer={renderFullName}/>
          <Column label="joined" width={120} dataKey={3} flexgrow={1} />
          <Column label="activated" width={120} dataKey={4}  flexgrow={1}/>
          <Column label="tutorial (src)" width={100} dataKey={5} />
          <Column label="msgs (in/out)" width={80} dataKey={6} />
          <Column label="last in" width={120} dataKey={7} />
          <Column label="history" width={80} dataKey={8} cellRenderer={renderHistory}/>
        </Table>
      </div>
      );
  },


  rowForUser: function(user){
    accountAge = timeago(new Date(user.created));
    tutorial_text = user.completed_tutorial ? "√ " + user.source : user.source;
    if (user.paused)
      tutorial_text += " PAUSED"
    if (user.state === "stopped")
      tutorial_text += " STOPPED"
    activated_text = null;
    if (user.activated)
      activated_text = timeago(new Date(user.activated));
    in_date = new Date(user.message_stats.incoming.last);
    out_date = new Date(user.message_stats.outgoing.last);
    //last = in_date > out_date ? in_date : out_date;
    last = in_date
    timeago_text = timeago(last);

    var rowClasses = classNames({
      'oddrow' : this.props.highlighted == true,
    });
    return ([
      format("{id} ({phone_number})", user),
      //format("<a href=/{key}?internal=1>{name}</a>", user),
      user, // for user name
      user, // for full name
      accountAge,
      activated_text,
      tutorial_text,
      format("{message_stats.incoming.count}/{message_stats.outgoing.count}", user),
      timeago_text,
      user,
    ]);
  }
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

    var filterUsersByActivity = function(users, activeBefore, activeAfter) {
      var results = [];

      for (i=0; i<users.length; i++) {
        lastActiveDate =  new Date(users[i].message_stats.incoming.last);
        if (lastActiveDate > activeAfter && lastActiveDate < activeBefore) {
          results.push(users[i]);
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
    };

    var now = new Date();
    var yest = new Date();
    var twoweeks = new Date();
    yest.setDate(yest.getDate() - 1);
    twoweeks.setDate(twoweeks.getDate() - 14);

    var pausedUsers = getPausedUsers(this.state.users);
    var nonActivatedUsers = filterUsers(this.state.users, false, null, null);
    var recentlyActivatedUsers = filterUsers(this.state.users, true, now, yest);
    var allActivated = filterUsers(this.state.users, true, yest, new Date(0));
    var normalUsers = filterUsersByActivity(allActivated, now, twoweeks);
    var oldUsers = filterUsersByActivity(allActivated, twoweeks, new Date(0));

		return (
      <div>
        <DailyTable stats={ this.state.daily_stats} />
        <UserTable users={ pausedUsers } showActivated={ true } title={"Paused (" + pausedUsers.length  + ")"}/>
        <UserTable users={ normalUsers } showActivated={ true } title={"Active (" + normalUsers.length  + ")"}/>
        <div>{ oldUsers.length } users inactive for more than 2 weeks </div>
        <UserTable users={ recentlyActivatedUsers } showActivated={ true } title={"Recently Activated (" + recentlyActivatedUsers.length + ")"}/>
        <UserTable users={ nonActivatedUsers } showActivated={ false } title={ "Not activated (" + nonActivatedUsers.length + ")"}/>
      </div>
		);
	},
});

React.render(<DashboardApp />, document.getElementById("app"));
