
var React = require('react')
var $ = require('jquery');
var JQueryUI = require('jquery-ui')
var classNames = require('classnames');
var emoji = require("node-emoji");
console.log(emoji);
mui = require('material-ui'),
  ThemeManager = new mui.Styles.ThemeManager(),
  RaisedButton = mui.RaisedButton;
  CircularProgress = mui.CircularProgress;
  TextField = mui.TextField;
  RadioButtonGroup = mui.RadioButtonGroup;
  RadioButton = mui.RadioButton;
  Toggle = mui.Toggle;
  Paper = mui.Paper;
  Toolbar = mui.Toolbar;
  ToolbarGroup = mui.ToolbarGroup;
  ToolbarTitle = mui.ToolbarTitle;
  DropDownIcon = mui.DropDownIcon;
  ToolbarSeparator = mui.ToolbarSeparator;
  SvgIcon = mui.SvgIcon;
var injectTapEventPlugin = require("react-tap-event-plugin");

//Needed for onTouchTap
//Can go away when react 1.0 release
//Check this repo:
//https://github.com/zilverline/react-tap-event-plugin
injectTapEventPlugin();

var DevelopmentMode = (window['DEVELOPMENT'] != undefined);

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
    if (message.manual) {
      body = "(MANUAL) " + body;
    }
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


    var classificationChooser = null;
    if (message.incoming) {
      classificationChooser = <ClassificationChooser
        selectedValue={message.classification}
        onClassificationChange={this.handleClassificationChange}
      />;
    }

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
        {classificationChooser}

      </div>
    );
  },

  handleClick: function(e) {
		this.props.onMessageClicked(this.props.message, this.getId());
  },

  handleClassificationChange: function(newClassification) {
    $.ajax({
      url: "/smskeeper/message/" + this.props.message.id + "/",
      dataType: 'json',
      type: 'PATCH',
      data: {classification: newClassification},
      success: function(data) {
        console.log("successfully updated classification");
      }.bind(this),
      error: function(xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  }

});

var ClassificationChooser = React.createClass({
  getInitialState: function() {
    return {selectedValue: this.props.selectedValue}
  },

  componentDidMount: function() {
    this.setState({selectedValue: this.props.selectedValue});
  },

  render: function() {
    var createOption = function(option, index) {
      var br = null; // add a break every 3 options
      if (index > 1 && (index + 1) % 3 == 0) {
        br = <br />
      }
      return (
        <input type="radio" value={option.value} checked={this.state.selectedValue == option.value}>
          {option.text} {br}
        </input>);
    }.bind(this);

    var classifierClasses = classNames({
      "classifier": true,
    });

    return (
      <div className={classifierClasses}>
        <form onChange={this.handleChange} action="">
        { CLASSIFICATION_OPTIONS.map(createOption) }
        </form>
      </div>
    );
  },

  handleChange: function(e) {
    //e.preventDefault();
    var selectedValue = e.target.value;
    console.log("classification changed to: " + selectedValue);
    this.setState({selectedValue: selectedValue})
    this.props.onClassificationChange(selectedValue);
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
  componentWillReceiveProps: function(nextProps) {
    this.setState({paused: nextProps.paused});
  },

  getInitialState: function() {
    return {loading: false, simulateOn: false};
  },

  handlePostMsgSubmit: function(e) {
    e.preventDefault();
    var text = this.refs.text.getValue().trim();
    var direction = this.refs.simulateUserToggle.isToggled() ? "ToKeeper" : "ToUser";
    if (!text) {
      return;
    }
    this.props.onCommentSubmit({msg: text, user_id: USER.id, direction: direction});
    this.refs.text.setValue('');
  },

  handleTogglePause: function(e) {
    e.preventDefault();
    this.setState({loading:true});
    $.ajax({
      url: "/smskeeper/toggle_paused",
      dataType: 'json',
      type: 'POST',
      data: {user_id: USER.id},
      success: function(data) {
        console.log("toggle paused: " + data.paused);
        this.setState({paused: data.paused, loading:false});
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("toggle_paused", status, err.toString());
        this.setState({loading: false});
      }.bind(this)
    });
  },

  handleMoreAction: function(e, selectedIndex, menuItem) {
    console.log("more action selected: %d: %s", selectedIndex, menuItem.payload);
    window.open(menuItem.payload, '_blank');
  },

  handleSimulateToggled: function(e, toggled) {
    this.setState({simulateOn:toggled})
  },

  emojize: function(str) {
    newstr = str;
    var matches = str.match(/[:]\S+[:]/g);
    if (!matches) return str;
    for (var i = 0; i < matches.count; i++) {
      var match = matches[i];
      var emoji_lookup = match.replace(/[:]/g, "");
      var emoji_char = emoji.get(emoji_lookup);
      if (emoji_char) {
        newstr = newstr.replace(match, emoji_char);
        console.log("replaced %s with %s", match, emoji_char);
      } else {
        console.log("no match for %s", emoji_lookup);
      }
    }
    return newstr;
  },

  handleTextChanged: function(e) {
    var originalText = this.refs.text.getValue();
    var emojifiedText = this.emojize(originalText);
    if (originalText != emojifiedText) {
      this.refs.text.setValue(emojifiedText);
    }
  },

  render: function() {
    var sendText = "Send";
    if (this.state.simulateOn) {
      sendText = this.state.paused ? "Unpause & Simulate" : "Simulate";
    }
    var userPausedText = this.state.paused ? "Paused" : "Normal";
    var pausedText = this.state.paused ? "Unpause" : "Pause";
    var pauseElement = <RaisedButton
      ref='pauseButton'
      label={ pausedText }
      primary={ !this.state.paused }
      secondary= { this.state.paused }
      onClick={this.handleTogglePause}
    />;
    if (this.state.loading) {
      pauseElement = <CircularProgress mode="indeterminate" />;
    }

    var toolbarBackround = this.state.paused ? "#F5CFCF" : "#DBDBDB";
    var iconMenuItems = [
      { payload: "/admin/smskeeper/reminder/?q=" + USER.id, text: 'Reminders' },
      { payload: '/' + USER.key + '?internal=1', text: 'KeeperApp' }
    ];

    return (
      <Paper zDepth={1} className="controlPanel">
        <Toolbar style={{backgroundColor: toolbarBackround, padding: "0px 10px"}}>
          <ToolbarGroup key={0} float="left">
            <ToolbarTitle text={userPausedText} />
          </ToolbarGroup>
          <ToolbarGroup key={1} float="right">
            { pauseElement }
            <DropDownIcon menuItems={iconMenuItems} onChange={this.handleMoreAction}>
              <ToolbarTitle text="•••"/>
            </DropDownIcon>
          </ToolbarGroup>
        </Toolbar>

        <div className="sendForm">
          <TextField
            ref="text"
            hintText="Text to send..."
            multiLine={true}
            style={{width: '100%'}}
            onChange={this.handleTextChanged}
            />
          <Toggle
            ref='simulateUserToggle'
            name="SimulateUser"
            label="Simulate user"
            style={{width: '10em'}}
            onToggle={this.handleSimulateToggled}
            />
          <br />

          <RaisedButton
            ref='sendButton'
            label={ sendText }
            secondary={true}
            onClick={this.handlePostMsgSubmit}
            className="submitButton"
          />
        </div>
      </Paper>
    );
  }
});

var KeeperApp = React.createClass({
  getInitialState: function() {
    return {messages: [], selectedMessage: null, maxRowsToShow: 100 };
  },

  processDataFromServer: function(data) {
    console.log("Got data from the server:");
    console.log(data);
    this.setState({messages : data.messages, paused : data.paused});
  },

  loadDataFromServer: function() {
    $.ajax({
      url: "/smskeeper/message_feed?user_id=" + USER.id,
      dataType: 'json',
      cache: false,
      success: function(data) {
        this.processDataFromServer(data);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("message_feed error %s %s", status, err.toString());
      }.bind(this)
    });
  },

  componentDidMount: function() {
    this.loadDataFromServer();
    var loadFunc = this.loadDataFromServer;
    if (!DevelopmentMode) {
      setInterval(function () {loadFunc()}, 2000);
    }
  },

  handleCommentSubmit: function(data) {
    $.ajax({
      url: "/smskeeper/send_sms",
      dataType: 'json',
      type: 'POST',
      data: data,
      success: function(data) {
        // the data that comes back from the server is just success
        this.loadDataFromServer();
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("send_sms", status, err.toString());
      }.bind(this)
    });
  },

  handleShowAll: function(e) {
    e.preventDefault();
    this.setState({maxRowsToShow: 100000});
  },

  onMessageClicked: function(message, rowId) {
    console.log("selectedRowId" + rowId);
  },

	render: function() {
    var loading = null;
    var showAll = null;
    if (this.state.messages.length == 0) {
      loading =
      <div>
        <p>
        loading...
        </p>
        <CircularProgress mode="indeterminate" size={2.0} style={{textAlign: "center"}}/>
      </div>
    } else if (this.state.maxRowsToShow < this.state.messages.length) {
      showAll = <RaisedButton
                  ref='showAll'
                  label="Show All"
                  secondary={true}
                  onClick={this.handleShowAll}
                  className="showAllButton"
                />
    }

    var messageRows = [];
    for (var i = Math.max(0, this.state.messages.length - this.state.maxRowsToShow); i < this.state.messages.length; i++) {
      messageRows.push(
        <MessageListRow message={ this.state.messages[i] }
        key= { i }
        index= { i }
        onMessageClicked = { this.onMessageClicked }/>
      )
    }

		return (
      <div>
        { loading }
        { showAll }
  			<div id="messages">
  			   { messageRows }
        </div>
        <CommentForm onCommentSubmit={this.handleCommentSubmit} paused={this.state.paused}/>
      </div>
		);
	},

  componentDidUpdate: function() {
    if (!this.props.firstLoadComplete) {
      $("html,body").scrollTop($(document).height());
      this.props.firstLoadComplete = true;
    }
  },

  getChildContext: function() {
    return {
      muiTheme: ThemeManager.getCurrentTheme()
    };
  },

});

// Important!
KeeperApp.childContextTypes = {
  muiTheme: React.PropTypes.object
};


React.render(<KeeperApp />, document.getElementById("keeper_app"));
