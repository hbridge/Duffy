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

    var renderFullName = function(user) {
      var fullName = "";
      if (user.full_name && user.full_name.length > 0) {
        fullName = format("({})", user.full_name[0]);
      }
      return (<span title={ user.full_name }> {user.name} { fullName }</span>);
    }
    var renderLinks = function(user) {
      return (
        <span>
        <a target="_blank" href={ user.history }>history</a> | <a target="_blank" href={"/"+user.key+"?internal=1"}>app</a>
        </span>
      );
    }

    var rowHeight = 40;

    return (
      <div>
        <h1>{ this.props.title }</h1>
        <Table
          rowHeight={rowHeight}
          rowGetter={rowGetter}
          rowsCount={this.props.users.length}
          width={1200}
          maxHeight={rowHeight * 10}
          headerHeight={60}
          >
          <Column label="user" width={180} dataKey={0}/>
          <Column label="name" width={240} dataKey={1} cellRenderer={renderFullName} />
          <Column label="links" width={110} dataKey={2} cellRenderer={renderLinks}/>
          <Column label="joined" width={130} dataKey={3} />
          <Column label="activated" width={130} dataKey={4} />
          <Column label="tutorial (src)" width={100} dataKey={5} />
          <Column label="msgs (in/out)" width={80} dataKey={6} />
          <Column label="last in" width={130} dataKey={7} />
          <Column label="product id" width={80} dataKey={8} />
        </Table>
      </div>
      );
  },


  rowForUser: function(user){
    accountAge = timeago(new Date(user.created)).replace("about ", "");;
    var sourceObj = JSON.parse(user.source);
    var sourceString = "";
    if (sourceObj.source && sourceObj.ref) {
      sourceString = sourceObj.source + ", " + sourceObj.ref;
    }
    else if (sourceObj.source) {
      sourceString = sourceObj.source;
    }
    else if (sourceObj.ref) {
      sourceString = sourceObj.ref;
    }
    tutorial_text = user.completed_tutorial ? "√ " + sourceString : sourceString;
    if (user.paused)
      tutorial_text += " PAUSED"
    if (user.state === "stopped")
      tutorial_text += " STOPPED"
    activated_text = null;
    if (user.activated)
      activated_text = timeago(new Date(user.activated)).replace("about ", "");
    in_date = new Date(user.message_stats.incoming.last);
    out_date = new Date(user.message_stats.outgoing.last);
    //last = in_date > out_date ? in_date : out_date;
    last = in_date
    timeago_text = timeago(last).replace("about ", "");

    var rowClasses = classNames({
      'oddrow' : this.props.highlighted == true,
    });
    console.log("HERE");
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
      user.product_id,
      user,
    ]);
  },
});

var FilterForm = React.createClass({
  render: function() {
    var options = this.props.filterFields.map(function(field){
      return (<option value={field}>{field}</option>);
    });

    return (
      <div className="filterControl">
      <select onChange={this._onFilterChange} ref="select">
        {options}
      </select>
      <input onChange={this._onFilterChange} placeholder='Value' ref="text"/>
      </div>
    );
  },

  _onFilterChange: function(e) {
    this.props.onChange(this.refs.select.getDOMNode().value,
      this.refs.text.getDOMNode().value);
  }
});


var DashboardApp = React.createClass({
  getInitialState: function() {
    return {users: [], daily_stats: {}, filter:{}};
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
    if (JSON.stringify(this.state.users) == JSON.stringify(data.users)
      && JSON.stringify(this.state.daily_stats) == JSON.stringify(data.daily_stats)) {
      console.log("no data change");
      return;
    }

    // var manyUsers = [];
    // while (manyUsers.length < 1000) {
    //   manyUsers.push(data.users[0]);
    // }
    // console.log(data.users);
    // console.log(manyUsers);


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
    var oneweek = new Date();
    yest.setDate(yest.getDate() - 1);
    oneweek.setDate(oneweek.getDate() - 7);

    var users = this.state.users;
    var filter = this.state.filter;
    if (Object.keys(filter).length > 0) {
      var filterKey = Object.keys(this.state.filter)[0];
      var filterVal = filter[filterKey];
      if (filterVal && filterVal != "") {
        console.log("Applying filter: " + filterKey + ":" + filter[filterKey]);
        console.log(filter);
        users = users.filter(function(user){
          if (filterKey == "id") {
            if (user[filterKey] == filter[filterKey]) return true;
          } else {
            if (user[filterKey].match(new RegExp(filter[filterKey], "ig"))) return true;
          }
          return false;
        });
      }
    }
    console.log(users);

    var pausedUsers = getPausedUsers(users);
    var nonActivatedUsers = filterUsers(users, false, null, null);
    var recentlyActivatedUsers = filterUsers(users, true, now, yest);
    var allActivated = filterUsers(users, true, yest, new Date(0));
    var normalUsers = filterUsersByActivity(allActivated, now, oneweek);
    var oldUsers = filterUsersByActivity(allActivated, oneweek, new Date(0));

		return (
      <div>
        <FilterForm filterFields={["name", "id", "source"]} onChange={this._onFilterChange} />
        <DailyTable stats={ this.state.daily_stats} />
        <UserTable users={ pausedUsers } showActivated={ true } title={"Paused (" + pausedUsers.length  + ")"}/>
        <UserTable users={ normalUsers } showActivated={ true } title={"Active (" + normalUsers.length  + ")"}/>
        <div>{ oldUsers.length } users inactive for more than 1 week </div>
        <UserTable users={ recentlyActivatedUsers } showActivated={ true } title={"Recently Activated (" + recentlyActivatedUsers.length + ")"}/>
        <UserTable users={ nonActivatedUsers } showActivated={ false } title={ "Not activated (" + nonActivatedUsers.length + ")"}/>
      </div>
		);
	},

  _onFilterChange: function(key, value) {
    console.log(format("{} {}", key, value));
    var filter = {}
    filter[key] = value
    this.setState({filter: filter});
  }
});

React.render(<DashboardApp />, document.getElementById("app"));
