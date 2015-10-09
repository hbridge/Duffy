var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var emoji = require("node-emoji");
var moment = require('moment');

var BackboneReactComponent = require('backbone-react-component');

module.exports = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {};
  },

  getId: function(){
    return "message" + this.props.index;
  },

  render: function() {
    var message = this.state.model;
		var body = message.Body;

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
        model={ this.getModel() }
      />;
    }

		return (
			<div id={ this.getId() } className="message">
        <MessageHeader message={message} />
        <div className={ cssClasses }>
           <MessageBody text={body} isManual={message.manual} statementBounds={this.state.model.statement_bounds}/>
          <div>
            <AttachmentView mediaUrl={mediaUrl} mediaType={message.MediaContentType0} />
          </div>
        </div>
        <Button bsSize='xsmall' onClick={this.showActions} className="messageActionsButton">Actions</Button>
        {classificationChooser}

      </div>
    );
  },

  showActions: function(e) {
		this.props.onMessageClicked(this.getModel(), this.getId());
  },
});

var MessageHeader = React.createClass({
  render: function(){
    var date = new Date(this.props.message.added);

    var classificationElement = null;
    if (this.props.message.incoming) {
      var classificationClass = classNames({
        greenText: (this.props.message.classification != null)
      });
      classificationElement = <span>
        <span> • </span>
        <span className={classificationClass}>
          {this.props.message.classification ? this.props.message.classification : "Not classified"}
        </span>
      </span>;
    }

    return(
      <div className="messageHeader">
        <span className="messageDate">{ moment(date).format('llll') }</span>
        { classificationElement}
      </div>
    );
  }
});

var ClassificationChooser = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
    var createOption = function(option, index) {
      var br = null; // add a break every 3 options
      if (index > 1 && (index + 1) % 3 == 0) {
        br = <br />
      }
      return (
        <input
          type="radio"
          key={option.value}
          value={option.value}
          defaultChecked={this.state.model.classification == option.value}
        >
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
    var message = this.getModel()
    message.setClassification(selectedValue);
  }
});

var separator = "||";
var MessageBody = React.createClass({
  render: function() {
    // add a statement boundaries indicator where applicable
    var newText = this.props.text;
    var statementBounds = this.props.statementBounds ? this.props.statementBounds : [];
    for (var i = statementBounds.length-1; i >= 0; i--){
      var pos = this.props.statementBounds[i];
      console.log("splicing in at pos:%d", pos);
      newText = [newText.slice(0, pos), separator, newText.slice(pos)].join('');
    }

    // add (MANUAL) if the message is manual
    if (this.props.manual) {
      newText = "(MANUAL) " + newText;
    }

    // split up newlines so they render right in HTML
    var lines = newText.split("\n");
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
