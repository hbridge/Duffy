var React = require('react');
var _ = require('underscore');
var Model = require('../model/SimulationModel.jsx');
var moment = require('moment');
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  Table = Bootstrap.Table;
  Modal = Bootstrap.Modal;
  Accordion = Bootstrap.Accordion;
  Panel = Bootstrap.Panel;
  DropdownButton = Bootstrap.DropdownButton;
  MenuItem = Bootstrap.MenuItem;

var SimulationRow = React.createClass({
  render() {
    var simId = this.props.simRun.id;
    var numCorrect = this.props.simRun.numCorrect;
    var numWrong = this.props.simRun.numIncorrect;
    var simpleAccuracy = numCorrect / (numCorrect + numWrong);
    console.log("compare to", this.props.compareTo);
    if (this.props.compareTo) {
	    var compareCorrect = this.props.compareTo.numCorrect;
	    var compareWrong = this.props.compareTo.numIncorrect;
	    var compareAccuracy = compareCorrect / (compareCorrect + compareWrong);
	}
    return (
      <tr>
        <td onClick={this.handleClicked}> { simId }, {this.getSimType()}, @{this.props.simRun.git_revision}, {moment(this.props.simRun.added).fromNow()}</td>
        <td> { simpleAccuracy ? simpleAccuracy.toFixed(2) : ""} ({numCorrect}/{numCorrect+numWrong}) ∆ {(simpleAccuracy - compareAccuracy).toFixed(3)}</td>
        <td> </td>
        <td> </td>
        <td> {this.getMoreActions()}</td>
      </tr>
    );
  },

  handleClicked(e) {
    e.preventDefault();
    this.props.onRowClicked(this.props.simRun.id);
  },

  getSimId(){
    return parseInt(this.props.simulationId);
  },

  getSimType(){
  	var type = this.props.simRun.sim_type;
  	if (type == "t") {
  		return "Test";
  	} else if (type == "pp") {
  		return "Prod Push";
  	} else if (type == "dp") {
  		return "Dev Push";
  	}

  	return "Unknown";
  },

  handleDelete(e){
  	Model.deleteSimRun(this.props.simRun.id, function(simRunId){
  		this.props.onRowDeleted(simRunId);
  	}.bind(this));
  },

  getMoreActions(){
  	return (
	  	<DropdownButton
	          title='•••'
	          ref='crselect'
	          bsSize='xsmall'
	          pullRight
	        >
	        	<MenuItem eventKey="delete" onSelect={this.handleDelete}>Delete</MenuItem>
	    </DropdownButton>
    );
  }
});

var SimDetailsRow = React.createClass({
  render() {
    var tp = this.props.classSummary.tp;
    var fn = this.props.classSummary.fn;
    var simpleAccuracy = this.props.classSummary.simpleAccuracy;
    var precision = this.props.classSummary.precision;
    var recall = this.props.classSummary.recall;
    var f1 = this.props.classSummary.f1;
    return (
      <tr onClick={this.handleClicked}>
        <td style={{textAlign: "right"}}> <strong>{ this.props.classSummary.messageClass }</strong> </td>
        <td> {simpleAccuracy ? simpleAccuracy.toFixed(2) : ""} ({tp}/{tp+fn})</td>
        <td> {precision ? precision.toFixed(2) : ""}</td>
        <td> {recall ? recall.toFixed(2) : ""}</td>
        <td> {f1 ? f1.toFixed(2) : ""}</td>
      </tr>
    );
  },

  handleClicked(e){
    this.props.handleClicked(this.props.simId, this.props.classSummary.messageClass);
  }
});

module.exports.SimulationRow = SimulationRow;
module.exports.SimDetailsRow = SimDetailsRow;