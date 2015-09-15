var $ = require('jquery');
var Backbone = require('backbone');

module.exports.bindSimulationRuns = function(reactObj, stateName) {
  var dataCallback = function(data){
    console.log("bindSimulationRuns callback with data ", data);
    var stateObj = {};
    stateObj[stateName] = data;
    reactObj.setState(stateObj);
  }
  $.getJSON("/smskeeper/simulation_run/list", dataCallback);
}

module.exports.fetchSimulationClassSummary = function(simRunId, callback) {
  $.getJSON("/smskeeper/simulation_classes_summary/" + simRunId, callback);
}

module.exports.bindSimulationClassDetails = function(simRunId, className, reactObj, stateName) {
  var dataCallback = function(data){
    console.log("bindSimulationClassDetails callback with data ", data);
    var stateObj = {};
    stateObj[stateName] = data;
    reactObj.setState(stateObj);
  }
  $.getJSON("/smskeeper/simulation_class_details/" + simRunId + "/" + className, dataCallback);
}

module.exports.bindSimulationCompareClassDetails = function(simRunId, compareRunId, reactObj, stateName) {
  var dataCallback = function(data){
    console.log("bindSimulationCompareClassDetails callback with data ", data);
    var stateObj = {};
    stateObj[stateName] = data;
    reactObj.setState(stateObj);
  }
  $.getJSON("/smskeeper/simulation_run_compare/" + simRunId + "/" + compareRunId, dataCallback);
}

module.exports.fetchSimulationResult = function(simResultId, callback) {
  $.getJSON("/smskeeper/simulation_result/" + simResultId, callback);
}

module.exports.deleteSimRun=function(simRunId, callback){
  $.ajax({
    url: '/smskeeper/simulation_run/' + simRunId,
    type: 'DELETE',
    success: function(result) {
        console.log("Deleted sim run %d", simRunId);
        callback(simRunId);
    }
});
}


var SimRun = Backbone.Model.extend({
  urlRoot: function() {
    return "/smskeeper/simulation_run/";
  },
});

var SimRunList = Backbone.Collection.extend({
  model: SimRun,
  url: "/smskeeper/simulation_run/",

  uniqueSimIds() {
    var results = {}
    this.forEach(function(simRun){
      simId = simResult.get("id");
      results[simId] = true;
    });
    return Object.keys(results).map(function(intStr){return parseInt(intStr)});
  },
});

var SimClassSummary = Backbone.Model.extend({
  urlRoot: function() {
    return "/smskeeper/simulation_classes_summary/";
  },
});

var SimResult = Backbone.Model.extend({
  urlRoot: function() {
    return "/smskeeper/simulation_result/";
  },

  simType: function() {
    var shortType = this.get('sim_type');
    if (shortType == 't') {
      return "test";
    } else if (shortType == 'dp') {
      return "Dev Push";
    } else if (shortType == 'pp') {
      return "Prod Push";
    }
    return "Unknown";
  }
});

var SimResultList = Backbone.Collection.extend({
  model: SimResult,
  url: "/smskeeper/simulation_result/",
});
