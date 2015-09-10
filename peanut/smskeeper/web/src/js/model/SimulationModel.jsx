var $ = require('jquery');

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
