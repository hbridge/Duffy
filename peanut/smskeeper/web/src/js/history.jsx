
var React = require('react')
React.initializeTouchEvents(true);
var $ = require('jquery');
var JQueryUI = require('jquery-ui')
var classNames = require('classnames');
var emoji = require("node-emoji");

var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;

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
var AdminEntriesView = require('./controls/AdminEntriesView.jsx');
var EntryList = Model.EntryList;

var DevelopmentMode = (window['DEVELOPMENT'] != undefined);
var firstLoadComplete = false;

var KeeperApp = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {messages: [], selectedMessage: null, maxRowsToShow: 100};
  },

  componentDidMount: function() {
    this.lastSeenMessageId = 0;
    if (!DevelopmentMode) {
      setInterval(function () {this.getModel().fetch()}.bind(this), 2000);
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
      </div>
    } else if (this.state.maxRowsToShow < this.state.messages.length) {
      showAll = <Button
        ref='showAll'
        bsStyle="primary"
        onClick={this.handleShowAll}
        className="showAllButton">
        Show All
      </Button>
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
        <div id="adminControls">
          <SendControl onCommentSubmit={this.handleCommentSubmit} paused={this.state.paused} user={USER}/>
          <AdminEntriesView type="active" collection={entryList} defaultExpanded={true}/>
          <AdminEntriesView type="hidden" collection={entryList} defaultExpanded={false}/>
        </div>
      </div>
		);
	},

  componentDidUpdate: function() {
    if (!firstLoadComplete) {
      $("html,body").scrollTop($("#adminControls").offset().top);
      firstLoadComplete = true;
    }
  },

  shouldComponentUpdate: function(nextProps, nextState) {
    // console.log("this.state.messages");
    // console.log(this.state.messages)
    // console.log("this.props.model");
    // console.log(this.props.model)
    // console.log("nextState.messages");
    // console.log(nextState.messages)
    // console.log("nextProps.model");
    // console.log(nextProps.model)

    var shouldUpdate = false;
    var newestRemoteMessageId = nextProps.model.messages.last().get("id");

    if (this.state.messages.length == 0) {
      shouldUpdate = true;
    } else {
      console.log("last: " + this.lastSeenMessageId + " newesst:" + newestRemoteMessageId);
      if (this.lastSeenMessageId != newestRemoteMessageId) {
        shouldUpdate = true;
        console.log('new messages. re-rendering.');
      }
    }
    this.lastSeenMessageId = newestRemoteMessageId;

    if (nextState.paused != nextProps.model.paused) {
      shouldUpdate = true;
      console.log('max rows changed, re-rendering');
    }
    if (this.state.maxRowsToShow != nextState.maxRowsToShow) {
      shouldUpdate = true;
      console.log('max rows changed, re-rendering');
    }

    return shouldUpdate;
  },

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");

    nextState.messages = nextProps.model.messages;
    nextState.paused = nextProps.model.paused;
  },
});

var entryList = new EntryList();
entryList.fetch();
var historyStore = new HistoryStore({userId: USER.id});
historyStore.fetch();
React.render(<KeeperApp model={ historyStore }/>, document.getElementById("keeper_app"));
