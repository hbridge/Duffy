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

var UnknownMsgList = Backbone.Collection.extend({
  model: Message,
  url: function() {
  return ("/smskeeper/unknown_messages_feed");
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
  url: "/smskeeper/review_feed/",
  comparator: function(entry) {
    var date = new Date(entry.get("remind_timestamp"));
    var dval = (date - 0);
    return dval;
  },
});

var SimResult = Backbone.Model.extend({
  urlRoot: function() {
    return "/smskeeper/simulation_result/";
  },
});

function SimulationRun (simResults) {
    this.simResults = simResults;
}

SimulationRun.prototype.sim_id = function() {
  return this.simResults[0].get('sim_id');
};

var SimResultList = Backbone.Collection.extend({
  model: SimResult,
  url: "/smskeeper/simulation_result/",

  simulationRuns(){
    var resultsById = {};
    this.forEach(function(simResult){
      simId = simResult.get("sim_id");
      resultsForId = resultsById[simId];
      if (!resultsForId) {
        resultsForId = []
      }
      resultsForId.push(simResult);
      resultsById[simId] = resultsForId;
    });

    var simRuns = [];
    for (key of Object.keys(resultsById)) {
      console.log("Creating sim run for %s with %d objs", key, resultsById[key].length);
      simRun = new SimulationRun(resultsById[key]);
      simRuns.push(simRun);
    }
    return simRuns;
  },

  uniqueSimIds() {
    var results = {}
    this.forEach(function(simResult){
      simId = simResult.get("sim_id");
      results[simId] = true;
    });
    return Object.keys(results).map(function(intStr){return parseInt(intStr)});
  },

  accurateClassifications(simId) {
    return this.filter(function(simResult){
      if (simResult.get('sim_id') != simId) return false;
      return (simResult.get('sim_classification') == simResult.get('correctClassification'));
    });
  },

  inaccurateClassifications(simId) {
    return this.filter(function(simResult){
      return (simResult.get('sim_classification') != simResult.get('correctClassification'));
    });
  },

  totalSummary(simId, categories) {
    var totalTps = [], totalTns = [], totalFps = [], totalFns = [];
    for (category of categories) {
      var categorySummary = this.categorySummary(simId, category);
      totalTps = totalTps.concat(categorySummary['tps']);
      totalTns = totalTns.concat(categorySummary['tns']);
      totalFps = totalFps.concat(categorySummary['fps']);
      totalFns = totalFns.concat(categorySummary['fns']);
    }
    return {
      tps: totalTps,
      tns: totalTns,
      fps: totalFps,
      fns: totalFns,
    }
  },

  categorySummary(simId, category) {
    var tps = [], tns = [], fps = [], fns = [];
    this.forEach(function(simResult){
      if (simResult.get('sim_id') != simId) return;
      if (simResult.get('sim_classification')
          == simResult.get('correctClassification')
        && simResult.get('sim_classification')
          == category){
        tps.push(simResult)
      } else if (simResult.get('sim_classification')
          != category
        && simResult.get('correctClassification')
          != category
      ) {
        tns.push(simResult);
      } else if (simResult.get('sim_classification')
          == category
        && simResult.get('correctClassification')
          != category
      ) {
        fps.push(simResult);
      } else if (simResult.get('sim_classification')
          != category
        && simResult.get('correctClassification')
          == category
      ) {
        fns.push(simResult);
      }
    });

    var summary = {
      tps: tps,
      tns: tns,
      fps: fps,
      fns: fns
    }

    console.log("summary for %s ", category, summary);

    return summary;
  },

  metricsForSummary(summary) {
    /*
      Metric      Formula
      Accuracy    (TP + TN) / (TP + TN + FP + FN)
      Precision TP / (TP + FP)
      Recall      TP / (TP + FN)
      F1-score  2 x P x R / (P + R)
    */
    var tp = summary.tps.length;
    var tn = summary.tns.length;
    var fp = summary.fps.length;
    var fn = summary.fns.length;
    var precision = tp / (tp + fp);
    var recall = tp / (tp + fn);
    var f1 = (2 * precision * recall) / (precision + recall);
    return {
      simpleAccuracy: (tp / (tp + fn)).toFixed(2),
      accuracy: ((tp + tn) / (tp+tn+fp+fn)).toFixed(2),
      precision: isFinite(precision) ? precision.toFixed(2) : 'NA',
      recall: isFinite(recall) ? recall.toFixed(2) : 'NA',
      f1: isFinite(f1) ? f1.toFixed(2) : 'NA'
    }
  }
});

exports.HistoryStore = HistoryStore;
exports.Message = Message;
exports.MessageList = MessageList;
exports.EntryList = EntryList;
exports.Entry = Entry;
exports.ReviewList = ReviewList;
exports.SimResult = SimResult;
exports.SimResultList = SimResultList;
exports.UnknownMsgList = UnknownMsgList;