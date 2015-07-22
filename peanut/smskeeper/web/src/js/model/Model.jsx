var Backbone = require('backbone');


var HistoryStore = Backbone.Model.extend({
	constructor: function() {
    	this.messages = new MessageList();
    	Backbone.Model.apply(this, arguments);
  	},

	url: function() {
		return ("/smskeeper/message_feed?user_id=" + this.get("userId"));
	},

	parse: function(data) {
		this.paused = data.paused;
		this.messages.reset(data.messages);
	}
});

var Message = Backbone.Model.extend({
	defaults: function() {
		return {};
	},
    urlRoot: function() {
      return "/smskeeper/message/";
    },

    setClassification: function(newClassification) {
    	var result = this.save({classification: newClassification}, {patch: true});
    	console.log("update classification result: " + result);
    },
});

var MessageList = Backbone.Collection.extend({
  model: Message,
  url: function() {
	return ("/smskeeper/message_feed?user_id=" + this.get("userId"));
  },
  parse: function(data) {
  	return data.messages;
  },
});

exports.HistoryStore = HistoryStore;
exports.Message = Message;
exports.MessageList = MessageList;