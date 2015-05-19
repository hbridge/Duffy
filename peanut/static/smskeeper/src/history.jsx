
/*
Note this file is only used in its raw form if ?development=True is passed in
It should be compiled to js by running from the outer directory

from static/smskeeper:
jsx --watch --extension jsx src/ build/

See: https://facebook.github.io/react/docs/tooling-integration.html for info on installing

*/


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
          <span> </span>
          <ShowActionsView message = {this.props.message} />
        </div>
        <div className={ cssClasses }>
           <MessageBody text={body} />
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

var MessageBody = React.createClass({
  render: function() {
    var lines = this.props.text.split("\n");
    var result = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var linekey = "l" + i;
      var brkey = "b" + i;
      result.push(<span key= { linekey }>{ line }</span>);
      result.push(<br key={ brkey } />);
    }
    return (
      <span> {result} </span>
      );
  }
});

var AttachmentView = React.createClass({
  render: function() {
    var url = this.props.mediaUrl;
    var type = this.props.mediaType;

    if (url == null) return null;

    if (type == "image/jpeg" || url.match(".+\.jpeg")) return (
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

var ShowActionsView = React.createClass({
  getInitialState: function() {
    return {expanded : false};
  },

  render: function() {
    if (!this.state.expanded) return (
      <a href="#" onClick={this.handleClick}>Show Actions</a>
    );

    return (
      <span>
        <a href="#" onClick={this.handleClick}>Hide Actions</a><br />
        <ResendMessageView message = {this.props.message} />
      </span>
    );
  },

  handleClick: function(e) {
    e.preventDefault();
    this.setState({expanded : !this.state.expanded});
  }
});

var ResendMessageView = React.createClass({
  handleResendMessage: function(data) {
    $.ajax({
      url: "/smskeeper/resend_msg",
      dataType: 'json',
      type: 'POST',
      data: data,
      success: function(data) {
      }.bind(this),
      error: function(xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  },
  handleSubmit: function(e) {
    e.preventDefault();
    this.handleResendMessage({msg_id: this.props.message.id});
    return;
  },
  render: function() {
    return (
      <form onSubmit={this.handleSubmit}>
        <input type="submit" value="Resend" />
      </form>
    );
  }
});

var CommentForm = React.createClass({
  handlePostMsgSubmit: function(e) {
    e.preventDefault();
    var text = React.findDOMNode(this.refs.text).value.trim();
    if (!text) {
      return;
    }
    this.props.onCommentSubmit({msg: text, user_id: USER_ID});
    React.findDOMNode(this.refs.text).value = '';
    return;
  },
  handleTogglePause: function(e) {
    e.preventDefault();
    this.props.onTogglePaused({user_id: USER_ID});
    return;
  },
  render: function() {
    var pausedText = this.props.paused ? "Unpause" : "Pause"
    return (
      <span>
      <form className="commentForm" onSubmit={this.handlePostMsgSubmit}>
        <input type="text" placeholder="Say something..." ref="text" className="commentBox"/>
        <input type="submit" value="Post" className="largeButton" />
      </form>
      <form onSubmit={this.handleTogglePause}>
        <input type="submit" value={pausedText} className="largeButton" />
      </form>
      </span>
    );
  }
});

var KeeperApp = React.createClass({
  getInitialState: function() {
    return {messages: [], selectedMessage: null };
  },

  processDataFromServer: function(data) {
    console.log("Got data from the server:");
    console.log(data);
    this.setState({messages : data.messages, paused : data.paused});
  },

  loadDataFromServer: function() {
    $.ajax({
      url: "/smskeeper/message_feed?user_id=" + USER_ID,
      dataType: 'json',
      cache: false,
      success: function(data) {
        this.processDataFromServer(data);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("message_feed", status, err.toString());
      }.bind(this)
    });
  },

  componentDidMount: function() {
    this.loadDataFromServer();
  },

  handleCommentSubmit: function(data) {
    $.ajax({
      url: "/smskeeper/send_sms",
      dataType: 'json',
      type: 'POST',
      data: data,
      success: function(data) {
        this.processDataFromServer(data);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("send_sms", status, err.toString());
      }.bind(this)
    });
  },

  handleTogglePause: function(data) {
    $.ajax({
      url: "/smskeeper/toggle_paused",
      dataType: 'json',
      type: 'POST',
      data: data,
      success: function(data) {
        this.processDataFromServer(data);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("toggle_paused", status, err.toString());
      }.bind(this)
    });
  },

  onMessageClicked: function(message, rowId) {
    console.log("selectedRowId" + rowId);
  },

	render: function() {
		var createItem = function(item, index) {
			return <MessageListRow message={ item }
        key= { index }
        index= { index }
        onMessageClicked = { this.onMessageClicked }/>
		}.bind(this);

		return (
      <div>
  			<div id="messages">
  			   { this.state.messages.map(createItem) }
        </div>
        <CommentForm onCommentSubmit={this.handleCommentSubmit} onTogglePaused={this.handleTogglePause} paused={this.state.paused}/>
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
