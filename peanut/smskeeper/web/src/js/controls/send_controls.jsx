var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var Utils = require("../utils.js");
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

var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
var CannedResponseDropdown = require('./CannedResponseDropdown.jsx');

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
    var direction = this.state.simulateOn ? "ToKeeper" : "ToUser";
    if (!text) {
      return;
    }
    this.refs.text.getInputDOMNode().value = '';
    this.props.onCommentSubmit({msg: text, user_id: USER.id, direction: direction});
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

  handleSimulateToggled: function(e) {
    console.log(e);
    var value = e.target.checked;
    console.log("checkbox val" + value);
    if (this.state.simulateOn != value){
      this.setState({simulateOn: value})
    }
  },

  handleTextChanged: function(e) {
    e.preventDefault();
    var originalText = this.refs.text.getValue();
    var emojifiedText = Utils.Emojize(originalText);
    if (originalText != emojifiedText) {
      this.refs.text.getInputDOMNode().value = emojifiedText;
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

    // CR menu
    var crMenu = <CannedResponseDropdown onCannedResponseSelected={this.crSelected} />

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

        <form className='inputElement' onSubmit={this.createEntry}>
          <Input
            type='textarea'
            ref='text'
            placeholder="Text to send..."
            addonBefore={crMenu}
            onChange={this.handleTextChanged}
          />
          <Input
            type='checkbox'
            ref='simulateUserToggle'
            label='Simulate user'
            onChange={this.handleSimulateToggled}
          />
          <Button
            ref='sendButton'
            onClick={this.createEntry}
            bsStyle="primary"
            disabled={this.state.sendDisabled}
            onClick={this.handlePostMsgSubmit}>
            {sendText}
          </Button>
        </form>
      </Paper>
    );
  },

  crSelected: function(text){
    this.refs.text.getInputDOMNode().value = text;
  },
});

