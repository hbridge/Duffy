
var React = require('react')
React.initializeTouchEvents(true);

// Model
var Model = require('./model/SimulationModel.jsx');
var _ = require('underscore');

// Bootstrap
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  Table = Bootstrap.Table;
  Modal = Bootstrap.Modal;

// Our UI components
var DevelopmentMode = (window['DEVELOPMENT'] != undefined);
var firstLoadComplete = false;

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


var SimClassModal = React.createClass({
  getInitialState(){
    return {summaryData: null}
  },

  componentWillReceiveProps(nextProps) {
    if (nextProps.simId && nextProps.messageClass) {
      console.log("Modal receiving new props", nextProps);
      this.setState({show: true});
      Model.bindSimulationClassDetails(nextProps.simId, nextProps.messageClass, this, 'summaryData');
    }
  },

  render(){
    var createListItem = function(message) {
      return (
        <li>{message.body}</li>
      );
    };
    var summary = this.state.summaryData;
    return (
      <Modal show={this.state.show} onHide={this.close}>
        <Modal.Header closeButton>
            <Modal.Title>Details</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <strong>False Positives</strong>
          <ul>{summary ? summary.fpMessages.map(createListItem) : null}</ul>
          <strong>False Negatives</strong>
          <ul>{summary ? summary.fnMessages.map(createListItem) : null}</ul>
        </Modal.Body>
      </Modal>
      );
  },

  close(e) {
    this.setState({show: false})
  }
})

var SimulationDashboard = React.createClass({
  getInitialState: function() {
    return {simRuns: [], expandedRows: [], simRunClassData: {}};
  },

  componentDidMount: function() {
    Model.bindSimulationRuns(this, 'simRuns');
    if (!DevelopmentMode) {
      // setInterval(function () {this.getCollection().fetch()}.bind(this), 2000);
    }
  },

	render: function() {
    var loading = null;
    var showAll = null;
    if (this.state.simRuns.size == 0) {
      loading =
      <div>
        <p>
        loading...
        </p>
      </div>
    }

    console.log("simRuns", this.state.simRuns);
    var rows = [];
    _.forEach(this.state.simRuns, function(simRun){
      var simId = simRun.id;
      rows.push(<SimulationRow simRun={ simRun } key={ simId } onRowClicked={this.handleRowClicked}/>);
      console.log("simId, expandedRows", simId, this.state.expandedRows);
      if (_.contains(this.state.expandedRows, simId)) {
        console.log("simId %s expanded, adding details rows", simId);
        rows = rows.concat(this.getDetailsRows(simId));
      }
    }.bind(this));

		return (
      <div>
        { loading }
        <SimClassModal simId={this.state.expandedSimId} messageClass={this.state.expandedMessageClass}/>
        <Table striped bordered condensed hover>
          <thead>
            <tr>
              <th>Sim Id</th>
              <th>Accuracy</th>
              <th>Precision</th>
              <th>Recall</th>
              <th>F1</th>
            </tr>
          </thead>
          <tbody>
            { rows }
          </tbody>
        </Table>
      </div>
		);
	},

  getDetailsRows(simId) {
      // see if there's data
      if (this.state.simRunClassData && this.state.simRunClassData[simId]) {
        var classNames = CLASSIFICATION_OPTIONS.map(function(dict){
          return dict.value;
        });

        var createClassRow = function(className, index) {
          return (<SimDetailsRow
            classSummary={this.state.simRunClassData[simId][className]}
            simId={simId}
            key={className + index}
            handleClicked={this.handleDetailRowClicked}
          />);
        }.bind(this);
        return classNames.map(createClassRow);
      } else {
        return ([
          <tr>
            loading...
          </tr>
        ]);
      }
  },

  handleRowClicked(simId){
    var newExpanded = this.state.expandedRows;
    if (_.contains(this.state.expandedRows, simId)) {
      newExpanded = _.without(this.state.expandedRows, simId);
    } else {
      newExpanded.push(simId);
      if (!this.state.simRunClassData[simId]) {
        this.getSimRunClassData(simId);
      }
    }
    console.log("row with simId clicked %s", simId, newExpanded);
    this.setState({expandedRows: newExpanded});
  },

  getSimRunClassData(simId) {
    Model.fetchSimulationClassSummary(simId, function(data){
      console.log("setting simrunClass data for %d", simId, data);
      var simRunClassData = this.state.simRunClassData;
      simRunClassData[simId] = data;
      this.setState({simRunClassData: simRunClassData});
    }.bind(this));
  },

  handleDetailRowClicked(simId, messageClass){
    console.log("expanding simId: %d messageClass:%s", simId, messageClass);
    this.setState({expandedSimId: simId, expandedMessageClass: messageClass});
  },

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },
});

React.render(<SimulationDashboard />, document.getElementById("keeper_app"));
