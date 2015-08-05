var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var Utils = require("../utils.js");
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  ButtonGroup = Bootstrap.ButtonGroup;
  Input = Bootstrap.Input;
  Panel = Bootstrap.Panel;
  Glyphicon = Bootstrap.Glyphicon;
var CannedResponseDropdown = require('./CannedResponseDropdown.jsx');
var EmojiTextInput = require('./EmojiTextInput.jsx');

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
    this.refs.text.setValue('');
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

  handleMoreAction: function(url) {
    console.log("more action selected: %s", url);
    window.open(url, '_blank');
  },

  handleSimulateToggled: function(e) {
    console.log(e);
    var value = e.target.checked;
    console.log("checkbox val" + value);
    if (this.state.simulateOn != value){
      this.setState({simulateOn: value})
    }
  },

  render: function() {
    var sendText = "Send";
    if (this.state.simulateOn) {
      sendText = this.state.paused ? "Unpause & Simulate" : "Simulate";
    }
    var userPausedText = this.state.paused ? "Paused" : "Normal";
    var pauseButtonText = this.state.paused ? "Unpause" : "Pause";

    if (this.state.loading) {
      pauseElement = <Glyphicon glyph='refresh' style={{float: "right"}}/>;
    } else {
      pauseElement =
      <ButtonGroup style={{float: "right"}}>
        <Button
            ref='pauseButton'
            onClick={this.handleTogglePause}
            bsStyle={this.state.paused ? 'success' : 'danger'}
        >
            {pauseButtonText}
        </Button>
        <DropdownButton
          title='•••'
          ref='crselect'
          pullRight
        >
            <MenuItem eventKey="/admin/smskeeper/reminder/?q=" onSelect={this.handleMoreAction}>Reminders</MenuItem>
            <MenuItem eventKey={'/' + USER.key + '?internal=1'} onSelect={this.handleMoreAction}>KeeperApp</MenuItem>
        </DropdownButton>
      </ButtonGroup>
    }

    // CR menu
    var crMenu = <CannedResponseDropdown onCannedResponseSelected={this.crSelected} />


    var header = <div>
      <span className="panelTitle">{userPausedText}</span>
      {pauseElement}
    </div>

    return (

      <Panel
        header={header}
        bsStyle={this.state.paused ? 'danger' : 'primary'}
        className="controlPanel"
      >
        <form className='inputElement' onSubmit={this.createEntry}>
          <EmojiTextInput ref='text' addonBefore={crMenu}/>
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
      </Panel>
    );
  },

  crSelected: function(text){
    this.refs.text.setValue(text);
  },
});

