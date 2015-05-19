var DailyTable = React.createClass({displayName: "DailyTable",
  render: function() {
    headerValues = ["days", "users (in/out)", "msgs (in/out)"];
    var createRow = function(days, index) {
			return React.createElement(DailyStatsRow, {days: days, stats:  this.props.stats[days], index:  index })
		}.bind(this);

    if (this.props.stats) {
      day_keys = Object.keys(this.props.stats);
    } else {
      day_keys = [];
    }
    console.log(day_keys);

    return (
      React.createElement("div", null, 
        React.createElement("h1", null, "Daily Stats"), 
        React.createElement("table", null, 
          React.createElement(HeaderRow, {headerValues:  headerValues }), 
           day_keys.map(createRow) 
        )
      )
    );
  }
});

var DailyStatsRow = React.createClass({displayName: "DailyStatsRow",
  render: function() {
    var rowClasses = classNames({
      'oddrow' : this.props.index % 2 == 1,
		});
    return (
      React.createElement("tr", {className:  rowClasses }, 
        React.createElement("th", {className: "cell"}, " ", this.props.days, " "), 
        React.createElement("td", null, " ",  this.props.stats.incoming.user_count, "/",  this.props.stats.outgoing.user_count), 
        React.createElement("td", null, " ",  this.props.stats.incoming.messages, "/",  this.props.stats.outgoing.messages)
      )
    );
  }
});

var UserTable = React.createClass({displayName: "UserTable",
  render: function() {
    var createRows = function(users) {
      count = 0;
      result = [];
      for (index in users) {
        user = users[index];

        if ((this.props.showActivated && user.activated) ||
           (!this.props.showActivated && !user.activated)) {
          count++;
          result.push(React.createElement(UserRow, {user:  user, highlighted:  count % 2 == 0}))
        }
      }
      return result;
		}.bind(this);
    headerValues = ["user", "name", "fullname", "joined", "activated", "tutorial (src)", "msgs (in/out)", "last in", "history"];

		return (
      React.createElement("div", null, 
        React.createElement("h1", null,  this.props.title), 
        React.createElement("table", null, 
          React.createElement(HeaderRow, {headerValues:  headerValues }), 
           createRows(this.props.users) 
        )
      )
    );
  },
});

var HeaderRow = React.createClass({displayName: "HeaderRow",
  render: function() {
    var createHeaderCell = function(item, index){
      return (React.createElement("th", {className: "cell"}, " ",  item, " "));
    }.bind(this);

    return (
      React.createElement("tr", null, 
         this.props.headerValues.map(createHeaderCell)
      )
    );
  }
});

var UserRow = React.createClass({displayName: "UserRow",
  render: function() {
    accountAge = jQuery.timeago(new Date(this.props.user.created));
    tutorial_text = this.props.user.completed_tutorial ? "√ " + this.props.user.source : this.props.user.source;
    if (this.props.user.state === "paused")
      tutorial_text += " PAUSED"
    activated_text = null;
    if (this.props.user.activated)
      activated_text = jQuery.timeago(new Date(this.props.user.activated));
    in_date = new Date(this.props.user.message_stats.incoming.last);
    out_date = new Date(this.props.user.message_stats.outgoing.last);
    //last = in_date > out_date ? in_date : out_date;
    last = in_date
    timeago_text = jQuery.timeago(last);

    var rowClasses = classNames({
      'oddrow' : this.props.highlighted == true,
		});
		return (
      React.createElement("tr", {className: rowClasses}, 
        React.createElement("td", {className: "cell"}, " ",  this.props.user.id, " (",  this.props.user.phone_number, ")"), 
        React.createElement("td", {className: "cell"}, " ",  this.props.user.name), 
        React.createElement("td", {className: "cell", title:  this.props.user.full_name}, " ",  this.props.user.full_name[0] ), 
        React.createElement("td", {className: "cell"}, " ",  accountAge ), 
        React.createElement("td", {className: "cell"}, " ",  activated_text ), 
        React.createElement("td", {className: "cell"}, " ",  tutorial_text ), 
        React.createElement("td", {className: "cell"}, " ",  this.props.user.message_stats.incoming.count, "/",  this.props.user.message_stats.outgoing.count), 
        React.createElement("td", {className: "cell"}, " ",  timeago_text, " "), 
        React.createElement("td", {className: "cell"}, " ", React.createElement("a", {target: "_blank", href:  this.props.user.history}, "history"))
      )
    );
  },
});

var DashboardApp = React.createClass({displayName: "DashboardApp",
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
    var countActivated = function(users) {
      result = 0;
      for (i=0; i<users.length; i++) {
        if (users[i].activated) {
          result++;
        }
      }
      return result
    }.bind(this);

		return (
      React.createElement("div", null, 
        React.createElement(DailyTable, {stats:  this.state.daily_stats}), 
        React.createElement(UserTable, {users:  this.state.users, showActivated:  true, title: "Activated (" + countActivated(this.state.users) + ")"}), 
        React.createElement(UserTable, {users:  this.state.users, showActivated:  false, title:  "Not activated (" + (this.state.users.length - countActivated(this.state.users)) + ")"})
      )
		);
	},
});

React.render(React.createElement(DashboardApp, null), document.getElementById("app"));
