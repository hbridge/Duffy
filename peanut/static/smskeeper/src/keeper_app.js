var MessageListRow = React.createClass({
  render: function() {
    var message = this.props.message;
		var body = message.Body;
		console.log(message);
		var cssclass = "outgoing";
		if (message.incoming == true) cssclass = "incoming";
		
		var cssClasses = classNames({
			'message': true,
			'incoming': message.incoming,
			'outgoing': !message.incoming,
		});
		
		var createLine = function(item, index) {
			return <MessageLine body={ item }/>
		}.bind(this);
		
		return (
			<div id={ "message" + this.props.index } className={ cssClasses } onClick={ this.handleRowSelected }>
				{ body }
				<div className="clear"></div>
      </div>);   
    },

		
  handleRowSelected: function(e) {
    e.preventDefault();
  }
});


var KeeperApp = React.createClass({
  getInitialState: function() {
    return {messages: [], selectedPhoto: null, loggedIn: false};
  },

  componentWillMount: function() {
		$.getJSON("/smskeeper/message_feed?user_id=" + USER_ID, this.messagesDataCallback);
  },
	
	messagesDataCallback: function(data) {
	  console.log(data);
		console.log(this);
		this.setState({messages : data.messages});
	},
      
	render: function() {
		var createItem = function(item, index) {
			return <MessageListRow message={ item } index= { index } onRowSelected= { this.onRowSelected }/>
		}.bind(this);
		
		return (
			<div id="messages">
			{ this.state.messages.map(createItem) }  
			</div>
		);
	}
});

React.render(<KeeperApp />, document.getElementById("keeper_app"));