var MessageListRow = React.createClass({
  render: function() {
    var message = this.props.message;
		var body = message.Body;
		console.log(message);
		var classes = [];
		return (
			<div id={ "message" + this.props.index } className={ classes } onClick={ this.handleRowSelected }>
			<p>{ body }</p>
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
		$.getJSON("/smskeeper/message_feed?user_id=1", this.messagesDataCallback);
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
			<div className="message">
			{ this.state.messages.map(createItem) }  
			</div>
		);
	}
});

React.render(<KeeperApp />, document.getElementById("keeper_app"));