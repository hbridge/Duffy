var MessageListRow = React.createClass({
  getInitialState: function() {
    return {raw: false};
  },
	
  render: function() {
    var message = this.props.message;
		var body = message.Body;
		if (this.state.raw) body = JSON.stringify(message);
		
		var cssclass = "outgoing";
		if (message.incoming == true) cssclass = "incoming";
		
		var cssClasses = classNames({
			'message': true,
			'preformatted': !this.state.raw,
			'incoming': message.incoming,
			'outgoing': !message.incoming,
		});
		
		
		return (
			<div id={ "message" + this.props.index } className={ cssClasses } onClick={ this.handleRowSelected }>
				{ body }
				<div className="clear"></div>
      </div>);   
    },
		
  handleRowSelected: function(e) {
    e.preventDefault();
		
		this.setState({raw: !this.state.raw});
  }
});


var KeeperApp = React.createClass({
  getInitialState: function() {
    return {messages: []};
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