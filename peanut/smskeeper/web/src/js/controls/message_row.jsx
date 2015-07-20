var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require('moment');

module.exports = React.createClass({
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
          <span className="messageDate">{ moment(date).format('llll') }</span>
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