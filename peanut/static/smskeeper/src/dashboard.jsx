var HeaderRow = React.createClass({
  render: function() {
		return (
      <tr>
        <th className="cell"> user_id </th>
        <th className="cell"> name </th>
        <th className="cell"> created </th>
        <th className="cell"> activated </th>
        <th className="cell"> msgs (in/out) </th>
          <th className="cell"> last </th>
        <th className="cell"> history </th>
      </tr>
    );
  },
});

var UserRow = React.createClass({
  render: function() {
    activated_text = this.props.user.activated ? "√" : "";
    in_date = new Date(this.props.user.message_stats.incoming.last);
    out_date = new Date(this.props.user.message_stats.outgoing.last);
    last = in_date > out_date ? in_date : out_date;
    timeago_text = jQuery.timeago(last);

    var rowClasses = classNames({
      'oddrow' : this.props.index % 2 == 1,
		});
		return (
      <tr className= {rowClasses}>
        <td className="cell"> { this.props.user.id }</td>
        <td className="cell"> { this.props.user.name }</td>
        <td className="cell"> { this.props.user.created }</td>
        <td className="cell"> { activated_text }</td>
        <td className="cell"> { this.props.user.message_stats.incoming.count }/{ this.props.user.message_stats.outgoing.count }</td>
        <td className="cell"> { timeago_text } </td>
        <td className="cell"> <a href={ this.props.user.history }>history</a></td>
      </tr>
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
      <table>
        <HeaderRow />
		    { this.state.users.map(createRow) }
      </table>
		);
	},

  componentDidUpdate: function() {

  },

});

React.render(<DashboardApp />, document.getElementById("app"));
