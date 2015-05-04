
var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

var MessageListRow = React.createClass({
  getInitialState: function() {
    return {};
  },

  getId: function(){
    return "message" + this.props.index;
  },

  render: function() {
    var message = this.props.message;
		var body = message.Body;
    var date = new Date(message.added);
    var mediaUrl = message.MediaUrls;
    if (!mediaUrl && message.MediaUrl0) {
      mediaUrl = message.MediaUrl0;
    }

		var cssClasses = classNames({
      'body' : true,
			'incoming': message.incoming,
			'outgoing': !message.incoming,
		});

		return (
			<div id={ this.getId() } className="message">
        <div className="messageHeader">
          <span className="messageDate">{ formatDate(date) }</span>
          <span> </span>
          <ShowJSONView json={ JSON.stringify(this.props.message) } />
        </div>
        <div className={ cssClasses }>
          { body }
          <div>
            <AttachmentView mediaUrl={mediaUrl} mediaType={message.MediaContentType0} />
          </div>
        </div>
      </div>
    );
  },

  handleClick: function(e) {
		this.props.onMessageClicked(this.props.message, this.getId());
  }
});

var AttachmentView = React.createClass({
  render: function() {
    var url = this.props.mediaUrl;
    var type = this.props.mediaType;

    if (url == null) return null;

    if (type == "image/jpeg" || url.endsWith(".jpeg")) return (
      <a href={url}><img src={url} width="300" height="300"></img></a>
    );

    return (
      <a href={url}>{url}</a>
    )
  },
});

var ShowJSONView = React.createClass({
  getInitialState: function() {
    return {expanded : false};
  },

  render: function() {
    if (!this.state.expanded) return (
      <a href="#" onClick={this.handleClick}>Show JSON</a>
    );

    return (
      <span>
        <a href="#" onClick={this.handleClick}>Hide JSON</a><br />
        { this.props.json }
      </span>
    );
  },

  handleClick: function(e) {
    e.preventDefault();
		this.setState({expanded : !this.state.expanded});
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
