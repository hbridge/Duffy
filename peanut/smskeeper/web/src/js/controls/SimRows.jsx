var React = require('react');
var _ = require('underscore');
var Model = require('../model/SimulationModel.jsx');
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  Table = Bootstrap.Table;
  Modal = Bootstrap.Modal;
  Accordion = Bootstrap.Accordion;
  Panel = Bootstrap.Panel;

var SimulationRow = React.createClass({
  render() {
    var simId = this.props.simRun.id;
    var numCorrect = this.props.simRun.numCorrect;
    var numWrong = this.props.simRun.numIncorrect;
    var simpleAccuracy = numCorrect / (numCorrect + numWrong);
    return (
      <tr onClick={this.handleClicked}>
        <td> { simId } ({this.props.simRun.sim_type} @ {this.props.simRun.git_revision})</td>
        <td> { simpleAccuracy ? simpleAccuracy.toFixed(2) : ""} {numCorrect}/{numCorrect+numWrong}</td>
        <td> </td>
        <td> </td>
        <td> </td>
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
        <td style={{textAlign: "right"}}> { this.props.classSummary.messageClass } </td>
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