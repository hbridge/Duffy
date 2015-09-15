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


var ClassificationScoresView = React.createClass({
  render(){
    var byScore = _.groupBy(Object.keys(this.props.scores), function(category){
      return this.props.scores[category];
    }, this);

    var createScoreItem = function(score) {
      var style = 'default';
      if (score > 0.0 && score < 0.5) {
        style = 'info';
      } else if (score >= 0.5) {
        style = 'primary';
      }

      formattedScore = parseFloat(score).toFixed(1);

      return (
        <div>
          <Label bsStyle={style} bsSize="xsmall">{formattedScore}</Label>&nbsp;&nbsp;{byScore[score].join(", ")}
        </div>
      );
    }

    return (
      <div>
        <strong>Classification Scores</strong>
        {Object.keys(byScore).sort().reverse().map(createScoreItem)}
      </div>
    );
  }
});

var ResultPanel = React.createClass({
  render(){
    if (!this.props.simResult) {
      return (<span>loading...</span>);
    }
    var simResult = this.props.simResult;
    var isCorrect = (simResult.message_classification == simResult.sim_classification);
    var scores = JSON.parse(simResult.sim_classification_scores_json);

    return (
    <Panel>
      Run: {simResult.run} <br />
      Sim classification: {simResult.sim_classification} &nbsp;
      <Label bsStyle={isCorrect ? "success" : "danger"} bsSize="large">
        {isCorrect ? "CORRECT" : "WRONG"}
      </Label>
      <br />
      Correct classification: {simResult.message_classification} <br />
      <br />
      <ClassificationScoresView scores={scores} />
    </Panel>
    );
  }
});


module.exports = React.createClass({
  getInitialState(){
    return {simResult: null, show: true}
  },

  componentDidMount(){
    Model.fetchSimulationResult(this.props.simResultId, function(simResult){
      this.setState({simResult: simResult});
      // now get the data for each of the comparable results
      _.forEach(simResult.recentComparableResults, function(resultId){
        Model.fetchSimulationResult(resultId, function(comparableResult){
          var comparableResults = this.state.comparableResults;
          if (!comparableResults) comparableResults = {};
          comparableResults[comparableResult.id] = comparableResult;
          this.setState({comparableResults: comparableResults});
        }.bind(this));
      }, this);
    }.bind(this));
  },

  render(){
    if (!this.state.simResult) return (<span>loading...</span>);

    var createComparableResult = function(comparableResultId) {
      return (
        <ResultPanel simResult={this.state.comparableResults[comparableResultId]} />
      );
    }.bind(this);

    return (
      <Modal show={this.state.show} onHide={this.close} dialogClassName='simResultModal' animation={false}>
        <Modal.Header closeButton>
            <Modal.Title>Details for result #{this.props.simResultId}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p><strong>Message:</strong> &ldquo;{this.state.simResult.message_body}&rdquo;</p>
          <ResultPanel simResult={this.state.simResult} />
          <h5>Comparable recent results</h5>
          {this.state.comparableResults ? Object.keys(this.state.comparableResults).map(createComparableResult) : "None"}
        </Modal.Body>
      </Modal>
      );
  },

  close(e) {
    this.setState({show: false})
    this.props.onClose();
  }
})