
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

//Needed for onTouchTap
//Can go away when react 1.0 release
//Check this repo:
//https://github.com/zilverline/react-tap-event-plugin
injectTapEventPlugin();

var DevelopmentMode = (window['DEVELOPMENT'] != undefined);

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
        <UserInfo />
        <SendControl onCommentSubmit={this.handleCommentSubmit} paused={this.state.paused}/>
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
