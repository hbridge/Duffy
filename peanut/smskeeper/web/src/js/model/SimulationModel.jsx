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

  accurateClassifications(simId) {
    return this.filter(function(simResult){
      if (simResult.get('sim_id') != simId) return false;
      return (simResult.get('sim_classification') == simResult.get('message_classification'));
    });
  },

  inaccurateClassifications(simId) {
    return this.filter(function(simResult){
      return (simResult.get('sim_classification') != simResult.get('message_classification'));
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
      if (simResult.get('sim_classification') == simResult.get('message_classification')
        && simResult.get('sim_classification') == category){
          tps.push(simResult)
      } else if (simResult.get('sim_classification') != category
        && simResult.get('message_classification') != category) {
          tns.push(simResult);
      } else if (simResult.get('sim_classification') == category
        && simResult.get('message_classification') != category) {
          fps.push(simResult);
      } else if (simResult.get('sim_classification') != category
        && simResult.get('message_classification') == category) {
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
