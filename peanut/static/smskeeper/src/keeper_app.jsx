
var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

var MessageListRow = React.createClass({
  getInitialState: function() {
    return {raw: false};
  },

  getId: function(){
    return "message" + this.props.index;
  },

  render: function() {
    var message = this.props.message;
		var body = message.Body;
    var date = new Date(message.added);
		var cssclass = "outgoing";
		if (message.incoming === true) cssclass = "incoming";

		var cssClasses = classNames({
      'body' : true,
			'incoming': message.incoming,
			'outgoing': !message.incoming,
		});

		return (
			<div id={ this.getId() } className="message" onClick={ this.handleRowSelected }>
        <div className="messageDate">{ formatDate(date) }</div>
        <div className={ cssClasses }>{ body }</div>
      </div>
    );
  },

  handleRowSelected: function(e) {
    e.preventDefault();
		this.props.onMessageClicked(this.props.message, this.getId());
  }
});

var JsonView = React.createClass({
  render: function() {
    if (!this.props.message) return (<div></div>);
    var json = JSON.stringify(this.props.message);

    return (
      <div id="json_popup">
        { json }
      </div>
    );
  },
  componentDidUpdate: function() {
    if (!this.props.selectedRowId) return;
    target_element = "#" + this.props.selectedRowId;
    console.log("componentDidUpdate. positioning to " + target_element)
    $( "#json_popup" ).position({
      my: "left top",
      at: "right+4 top+18",
      of: target_element
    });
  }
});

var KeeperApp = React.createClass({
  getInitialState: function() {
    return {messages: [], selectedMessage: null };
  },

  componentWillMount: function() {
		$.getJSON("/smskeeper/message_feed?user_id=" + USER_ID, this.messagesDataCallback);
  },

	messagesDataCallback: function(data) {
	  console.log(data);
		console.log(this);
		this.setState({messages : data.messages});
	},

  onMessageClicked: function(message, rowId) {
    console.log("selectedRowId" + rowId);
    this.setState({selectedMessage : message, selectedRowId : rowId });
  },

	render: function() {
		var createItem = function(item, index) {
			return <MessageListRow message={ item }
        index= { index }
        onMessageClicked = { this.onMessageClicked }/>
		}.bind(this);

		return (
      <div>
  			<div id="messages">
  			   { this.state.messages.map(createItem) }
        </div>
          <JsonView message={ this.state.selectedMessage } selectedRowId={ this.state.selectedRowId } />
      </div>
		);
	},

  componentDidUpdate: function() {
    if (!this.props.firstLoadComplete) {
      $("html,body").scrollTop($(document).height());
      this.props.firstLoadComplete = true;
    }
  },

});

React.render(<KeeperApp />, document.getElementById("keeper_app"));
