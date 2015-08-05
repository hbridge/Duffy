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
  Overlay = Bootstrap.Overlay;
  Glyphicon = Bootstrap.Glyphicon;


var EmojiOverlay = React.createClass({
	getInitialState: function(){
		return { show: true };
	},

	render: function(){
		const style = {
	      position: 'absolute',
	      backgroundColor: '#EEE',
	      boxShadow: '0 5px 10px rgba(0, 0, 0, 0.2)',
	      border: '1px solid #CCC',
	      borderRadius: 3,
	      marginLeft: -5,
	      marginTop: 5,
	      padding: 10,
	      zIndex: 10,
	      maxWidth: "70%"

	    };

	    var createEmojiOption = function(emojiKey){
	    	var handler = function(e){
				e.preventDefault();
				this.props.onEmojiClicked(emojiKey)
			}.bind(this);

	    	return (
	    		<a key={emojiKey}
	    			href='#'
	    			onClick={handler}
	    		>
	    			{emoji.get(emojiKey)}{emojiKey}&nbsp;&nbsp;<wbr />
	    		</a>
	    	);
	    }.bind(this);

		return (
			<Overlay
	      		show={this.state.show}
	      		onHide={function(){this.setState({ show: false })}}
	      		placement="top"
	      		container={this}
	      		target={ function(props){return React.findDOMNode(this.props.overlayTarget)}.bind(this)}
    		>
	      		<div style={style}>
	        		{this.props.emojiKeys.map(createEmojiOption)}
	      		</div>
	    	</Overlay>
		);
	},
});

module.exports = React.createClass({
	getInitialState: function(){
		return {};
	},

	getValue: function(){
		return this.refs.text.getValue();
	},

	setValue: function(text){
		this.refs.text.getInputDOMNode().value = text;
	},

	handleTextChanged: function(e) {
	    e.preventDefault();
	    var originalText = this.refs.text.getValue();

	    if (!Utils.IsClientMobile()) {
		    var newAutocompleteKeys = Utils.EmojiKeysMatchingSubstr(originalText);
		    if (newAutocompleteKeys != this.state.autocompleteKeys) {
		    	this.setState({autocompleteKeys: newAutocompleteKeys});
		    }
		}

	    var emojifiedText = Utils.Emojize(originalText);
	    if (originalText != emojifiedText) {
	      this.refs.text.getInputDOMNode().value = emojifiedText;
	    }
  	},

  	handleEmojiClicked: function(emojiKey) {
  		console.log(emojiKey);
  		this.setState({autocompleteKeys: []})
  	},

	render: function(){
		var overlay = null;
		if (this.state.autocompleteKeys && this.state.autocompleteKeys.length > 0) {
			overlay = <EmojiOverlay
				ref='overlay'
				overlayTarget={this.refs.text}
				emojiKeys={this.state.autocompleteKeys}
				onEmojiClicked={this.handleEmojiClicked}
			/>
		}

		return (<div>
			<Input
	            type='textarea'
	            ref='text'
	            placeholder="Text to send..."
	            addonBefore={this.props.addonBefore}
	            onChange={this.handleTextChanged}
          	/>
			{overlay}
	    </div>);
	},
});