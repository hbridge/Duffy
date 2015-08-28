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

var Entry = Backbone.Model.extend({
  defaults: function() {
      var dateString = (new Date()).toISOString();
      return {
        hidden: false,
        creator: USER.id,
        users: [USER.id],
        added: dateString,
        updated: dateString,
      };
    },

    urlRoot: function() {
      return "/smskeeper/entry/";
    },

    recurOptions: function() {
      return ([
        {value: "default", shortText: "Default", longText: "Default Reminder"},
        {value: "one-time", shortText: "One-time", longText: "One-time Reminder"},
        {value: "daily", shortText: "Daily", longText: "Daily Recurring"},
        {value: "every-2-days", shortText: "Every other", longText: "Every Other Day"},
        {value: "weekdays", shortText: "Weekdays", longText: "Weekday Recurring"},
        {value: "weekly", shortText: "Weekly", longText: "Weekly Recurring"},
        {value: "monthly", shortText: "Monthly", longText: "Monthly Recurring"},
      ]);
    }
});

var EntryList = Backbone.Collection.extend({
  model: Entry,
  url: "/smskeeper/entry_feed?user_id=" + USER.id,
  comparator: function(entry) {
    var date = new Date(entry.get("added"));
    var dval = (date - 0) * -1;
    return dval;
  },
  lists: function() {
    var entriesByList = [];
    this.forEach(function(entry){
      var hidden = entry.get('hidden');
      if (hidden) return;
      var labelName = entry.get('label').replace("#", "")

      var entriesForLabel = []
      if (labelName in entriesByList) {
        entriesForLabel = entriesByList[labelName];
      }
      entriesForLabel.push(entry);

      entriesByList[labelName] = entriesForLabel;
    });

    // pull out reminders
    if (entriesByList["reminders"]) {
      delete entriesByList["reminders"]
    }
    return entriesByList;
  },
  reminders: function() {
    var notHidden = this.where({label: "#reminders", hidden: false})
    var sorted = notHidden.sort(function(a, b){
      var dateA = new Date(a.get("remind_timestamp"));
      var dateB = new Date(b.get("remind_timestamp"));
      return dateA - dateB; // soonest reminder first
    });
    return(sorted);
  },

  hiddenReminders: function() {
    var hidden = this.where({label: "#reminders", hidden: true})
    var sorted = hidden.sort(function(a, b){
      var dateA = new Date(a.get("updated"));
      var dateB = new Date(b.get("updated"));
      return dateB - dateA; // most recently updated decending
    });
    return(sorted);
  }
});

var ReviewList = Backbone.Collection.extend({
  model: Entry,
  url: "/smskeeper/review_feed",
  comparator: function(entry) {
    var date = new Date(entry.get("remind_timestamp"));
    var dval = (date - 0);
    return dval;
  },
});

exports.HistoryStore = HistoryStore;
exports.Message = Message;
exports.MessageList = MessageList;
exports.EntryList = EntryList;
exports.Entry = Entry;
exports.ReviewList = ReviewList;