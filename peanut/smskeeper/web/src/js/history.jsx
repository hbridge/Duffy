
var React = require('react')
var $ = require('jquery');
var JQueryUI = require('jquery-ui')
var classNames = require('classnames');
var emoji = require("node-emoji");
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

// our modules
var SendControl = require('./controls/send_controls.jsx');
var MessageListRow = require('./controls/message_row.jsx');
var UserInfo = require('./controls/user_info_view.jsx');
var MessageActions = require('./controls/message_actions.jsx');
var Model = require('./model/Model.jsx');
var HistoryStore = Model.HistoryStore;
var Message = Model.Message;
var MessageList = Model.MessageList;
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');

//Needed for onTouchTap
//Can go away when react 1.0 release
//Check this repo:
//https://github.com/zilverline/react-tap-event-plugin
injectTapEventPlugin();

var DevelopmentMode = (window['DEVELOPMENT'] != undefined);
var firstLoadComplete = false;

var KeeperApp = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {messages: [], selectedMessage: null, maxRowsToShow: 100};
  },

  componentDidMount: function() {
    //if (!DevelopmentMode) {
      setInterval(function () {this.getModel().fetch()}.bind(this), 2000);
    //}
  },

  handleCommentSubmit: function(data) {
    $.ajax({
      url: "/smskeeper/send_sms",
      dataType: 'json',
      type: 'POST',
      data: data,
      success: function(data) {
        // the data that comes back from the server is just success
        this.getModel().fetch();
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
    this.setState({selectedMessage: message});
    this.refs.messageActions.show(message);
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
        <MessageListRow model={ this.state.messages.at([i]) }
        key= { i }
        index= { i }
        onMessageClicked = { this.onMessageClicked }
        messageActionDialog={this.refs.messageActions}/>
      )
    }

		return (
      <div>
        { loading }
        { showAll }
        <MessageActions ref="messageActions" onClassificationChange={this.handleClassificationChange} />
  			<div id="messages">
  			   { messageRows }
        </div>
        <UserInfo />
        <SendControl onCommentSubmit={this.handleCommentSubmit} paused={this.state.paused}/>
      </div>
		);
	},

  componentDidUpdate: function() {
    if (!firstLoadComplete) {
      $("html,body").scrollTop($(document).height());
      firstLoadComplete = true;
    }
  },

  getChildContext: function() {
    return {
      muiTheme: ThemeManager.getCurrentTheme(),
    };
  },

  shouldComponentUpdate: function(nextProps, nextState) {
    console.log("should componnent update");
    if (this.state.messages.length > 0) {
      var lastSeenMessageId = this.state.messages.at(this.state.messages.length - 1).get("id");
      var newestRemoteMessageId = nextProps.model.messages.at(nextProps.model.messages.length - 1).get("id");
      if (lastSeenMessageId == newestRemoteMessageId
        && nextState.paused == nextProps.model.paused) {
          console.log('no new messages. not re-rendering.');
          return false
      }
    }
    return true;
  },

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");

    nextState.messages = nextProps.model.messages;
    nextState.paused = nextProps.model.paused;
  },
});

// Important!
KeeperApp.childContextTypes = {
  muiTheme: React.PropTypes.object,
  hasParentBackboneMixin: React.PropTypes.bool.isRequired, // have to repeat these from the mixin because we're using the muiTheme
  parentModel: React.PropTypes.any,
  parentCollection: React.PropTypes.any
};

var historyStore = new HistoryStore({userId: USER.id});
historyStore.fetch();
React.render(<KeeperApp model={ historyStore }/>, document.getElementById("keeper_app"));
