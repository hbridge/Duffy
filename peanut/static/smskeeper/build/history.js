
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

var MessageListRow = React.createClass({displayName: "MessageListRow",
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
			React.createElement("div", {id:  this.getId(), className: "message"}, 
        React.createElement("div", {className: "messageHeader"}, 
          React.createElement("span", {className: "messageDate"},  formatDate(date) ), 
          React.createElement("span", null, " "), 
          React.createElement(ShowJSONView, {json:  JSON.stringify(this.props.message) }), 
          React.createElement("span", null, " "), 
          React.createElement(ShowActionsView, {message: this.props.message})
        ), 
        React.createElement("div", {className:  cssClasses }, 
           React.createElement(MessageBody, {text: body}), 
          React.createElement("div", null, 
            React.createElement(AttachmentView, {mediaUrl: mediaUrl, mediaType: message.MediaContentType0})
          )
        )
      )
    );
  },

  handleClick: function(e) {
		this.props.onMessageClicked(this.props.message, this.getId());
  }
});

var MessageBody = React.createClass({displayName: "MessageBody",
  render: function() {
    var lines = this.props.text.split("\n");
    var result = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var linekey = "l" + i;
      var brkey = "b" + i;
      result.push(React.createElement("span", {key:  linekey },  line ));
      result.push(React.createElement("br", {key:  brkey }));
    }
    return (
      React.createElement("span", null, " ", result, " ")
      );
  }
});

var AttachmentView = React.createClass({displayName: "AttachmentView",
  render: function() {
    var url = this.props.mediaUrl;
    var type = this.props.mediaType;

    if (url == null) return null;

    if (type == "image/jpeg" || url.match(".+\.jpeg")) return (
      React.createElement("a", {href: url}, React.createElement("img", {src: url, width: "300", height: "300"}))
    );

    return (
      React.createElement("a", {href: url}, url)
    )
  },
});

var ShowJSONView = React.createClass({displayName: "ShowJSONView",
  getInitialState: function() {
    return {expanded : false};
  },

  render: function() {
    if (!this.state.expanded) return (
      React.createElement("a", {href: "#", onClick: this.handleClick}, "Show JSON")
    );

    return (
      React.createElement("span", null, 
        React.createElement("a", {href: "#", onClick: this.handleClick}, "Hide JSON"), React.createElement("br", null), 
         this.props.json
      )
    );
  },

  handleClick: function(e) {
    e.preventDefault();
		this.setState({expanded : !this.state.expanded});
  }
});

var ShowActionsView = React.createClass({displayName: "ShowActionsView",
  getInitialState: function() {
    return {expanded : false};
  },

  render: function() {
    if (!this.state.expanded) return (
      React.createElement("a", {href: "#", onClick: this.handleClick}, "Show Actions")
    );

    return (
      React.createElement("span", null, 
        React.createElement("a", {href: "#", onClick: this.handleClick}, "Hide Actions"), React.createElement("br", null), 
        React.createElement(ResendMessageView, {message: this.props.message})
      )
    );
  },

  handleClick: function(e) {
    e.preventDefault();
    this.setState({expanded : !this.state.expanded});
  }
});

var ResendMessageView = React.createClass({displayName: "ResendMessageView",
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
      React.createElement("form", {onSubmit: this.handleSubmit}, 
        React.createElement("input", {type: "submit", value: "Resend"})
      )
    );
  }
});

var CommentForm = React.createClass({displayName: "CommentForm",
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
      React.createElement("span", null, 
      React.createElement("form", {className: "commentForm", onSubmit: this.handlePostMsgSubmit}, 
        React.createElement("input", {type: "text", placeholder: "Say something...", ref: "text", className: "commentBox"}), 
        React.createElement("input", {type: "submit", value: "Post", className: "largeButton"})
      ), 
      React.createElement("form", {onSubmit: this.handleTogglePause}, 
        React.createElement("input", {type: "submit", value: pausedText, className: "largeButton"})
      )
      )
    );
  }
});

var KeeperApp = React.createClass({displayName: "KeeperApp",
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
			return React.createElement(MessageListRow, {message:  item, 
        key:  index, 
        index:  index, 
        onMessageClicked:  this.onMessageClicked})
		}.bind(this);

		return (
      React.createElement("div", null, 
  			React.createElement("div", {id: "messages"}, 
  			    this.state.messages.map(createItem) 
        ), 
        React.createElement(CommentForm, {onCommentSubmit: this.handleCommentSubmit, onTogglePaused: this.handleTogglePause, paused: this.state.paused})
      )
		);
	},

  componentDidUpdate: function() {
    if (!this.props.firstLoadComplete) {
      $("html,body").scrollTop($(document).height());
      this.props.firstLoadComplete = true;
    }
  },

});

React.render(React.createElement(KeeperApp, null), document.getElementById("keeper_app"));
