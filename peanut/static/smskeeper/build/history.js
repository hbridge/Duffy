
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
          React.createElement(ShowJSONView, {json:  JSON.stringify(this.props.message) })
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

var KeeperApp = React.createClass({displayName: "KeeperApp",
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
			return React.createElement(MessageListRow, {message:  item, 
        key:  index, 
        index:  index, 
        onMessageClicked:  this.onMessageClicked})
		}.bind(this);

		return (
      React.createElement("div", null, 
  			React.createElement("div", {id: "messages"}, 
  			    this.state.messages.map(createItem) 
        )
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
