var React = require('react')
var $ = require('jquery');
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

module.exports = React.createClass({
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

