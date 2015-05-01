var HeaderRow = React.createClass({
  render: function() {
		return (
      <div>
        <div className="cell"> user_id </div>
        <div className="cell"> name </div>
        <div className="cell"> created </div>
        <div className="cell"> activated </div>
        <div className="cell"> incoming </div>
        <div className="cell"> outgoing </div>
        <div className="cell"> history </div>
      </div>
    );
  },
});

var UserRow = React.createClass({
  render: function() {
    activated_text = this.props.user.activated ? "active" : "inactive";
		return (
      <div>
        <div className="cell"> { this.props.user.id }</div>
        <div className="cell"> { this.props.user.name }</div>
        <div className="cell"> { this.props.user.created }</div>
        <div className="cell"> { activated_text }</div>
        <div className="cell"> { this.props.user.message_stats.incoming.count }</div>
        <div className="cell"> { this.props.user.message_stats.outgoing.count }</div>
        <div className="cell"> <a href={ this.props.user.history }>history</a></div>
      </div>
    );
  },
});

var DashboardApp = React.createClass({
  getInitialState: function() {
    return {users: [] };
  },

  componentWillMount: function() {
		$.getJSON("/smskeeper/dashboard_feed", this.dataCallback);
  },

	dataCallback: function(data) {
	  console.log(data);
    this.setState( {users : data.users});
	},

	render: function() {
		var createRow = function(item, index) {
			return <UserRow user={ item } index= { index } />
		}.bind(this);

		return (
      <div>
        <HeaderRow />
  			<div id="users">
  			   { this.state.users.map(createRow) }
        </div>
      </div>
		);
	},

  componentDidUpdate: function() {

  },

});

React.render(<DashboardApp />, document.getElementById("app"));
