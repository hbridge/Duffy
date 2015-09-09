
var React = require('react')
React.initializeTouchEvents(true);

// Model
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');
var Model = require('./model/Model.jsx');
var SimResultList = Model.SimResultList;
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
  mixins: [BackboneReactComponent],
  render() {
    var simId = this.getSimId();
    var classNames = CLASSIFICATION_OPTIONS.map(function(dict){
      return dict.value;
    });
    var totalSummary = this.getCollection().totalSummary(simId, classNames);
    var totalMetrics = this.getCollection().metricsForSummary(totalSummary);
    return (

      <tr onClick={this.handleClicked}>
        <td> { simId } </td>
        <td> {totalMetrics.simpleAccuracy}</td>
        <td> {totalMetrics.precision}</td>
        <td> {totalMetrics.recall}</td>
        <td> {totalMetrics.f1}</td>
      </tr>

    );
  },

  handleClicked(e) {
    e.preventDefault();
    this.props.onRowClicked(this.getSimId());
  },

  getSimId(){
    return parseInt(this.props.simulationId);
  },
});

var SimDetailsRow = React.createClass({
  mixins: [BackboneReactComponent],
  render() {
    var numTps = this.props.summary.tps.length;
    var numFns = this.props.summary.fns.length;
    return (
      <tr onClick={this.handleClicked}>
        <td style={{textAlign: "right"}}> { this.props.classification } </td>
        <td> {this.props.stats.simpleAccuracy} ({numTps}/{numTps+numFns})</td>
        <td> {this.props.stats.precision}</td>
        <td> {this.props.stats.recall}</td>
        <td> {this.props.stats.f1}</td>
      </tr>
    );
  },

  handleClicked(e){
    this.props.handleClicked(this.props.summary);
  }
});

var SimulationDashboard = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {results: [], expandedRows: [],};
  },

  componentDidMount: function() {
    if (!DevelopmentMode) {
      // setInterval(function () {this.getCollection().fetch()}.bind(this), 2000);
    }
  },

	render: function() {
    var loading = null;
    var showAll = null;
    if (this.state.collection.size == 0) {
      loading =
      <div>
        <p>
        loading...
        </p>
      </div>
    }

    var simIds = this.props.collection.uniqueSimIds();
    var rows = [];
    for (var i = 0; i < simIds.length; i++) {
      var simId = simIds[i];
      rows.push(<SimulationRow simulationId={ simId } key={ i } onRowClicked={this.handleRowClicked}/>);
      console.log("simId, expandedRows", simId, this.state.expandedRows);
      if (_.contains(this.state.expandedRows, simId)) {
        console.log("simId %s expanded, adding details rows", simId);
        rows = rows.concat(this.getDetailsRows(simId));
      }
    }

		return (
      <div>
        { loading }
        { this.getModal() }
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
      var classNames = CLASSIFICATION_OPTIONS.map(function(dict){
        return dict.value;
      });
      var createClassRow = function(className, index) {
        var summary = this.getCollection().categorySummary(simId, className);
        var stats = this.getCollection().metricsForSummary(summary);
        // console.log("details row for %s summary", className, summary);
        return (<SimDetailsRow
          classification={className}
          stats={stats}
          summary={summary}
          key={className + index}
          handleClicked={this.handleDetailRowClicked}
        />);
      }.bind(this);

      return (
        classNames.map(createClassRow)
      );
  },

  handleRowClicked(simId){
    var newExpanded = this.state.expandedRows;
    if (_.contains(this.state.expandedRows, simId)) {
      newExpanded = _.without(this.state.expandedRows, simId);
    } else {
      newExpanded.push(simId);
    }
    console.log("row with simId clicked %s", simId, newExpanded);
    this.setState({expandedRows: newExpanded});
  },

  handleDetailRowClicked(summary){
    console.log("expanding summary", summary)
    this.setState({expandedSummary: summary});
  },

  getModal() {
    var createListItem = function(model) {
      return (
        <li>{model.get('message_body')} (sim: {model.get('sim_classification')} actual: {model.get('message_classification')})</li>
      );
    };
    var sum = this.state.expandedSummary;
    return (
      <Modal show={this.state.expandedSummary != null} onHide={this.close}>
        <Modal.Header closeButton>
            <Modal.Title>Details</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <strong>True Postives</strong>
          <ul>{sum ? sum.tps.map(createListItem) : null}</ul>
          <strong>False Positives</strong>
          <ul>{sum ? sum.fps.map(createListItem) : null}</ul>
          <strong>False Negatives</strong>
          <ul>{sum ? sum.fns.map(createListItem) : null}</ul>
        </Modal.Body>
      </Modal>
      );
  },

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },

  close(e) {
    this.setState({expandedSummary: null})
  }
});

var simResultList = new SimResultList();
simResultList.fetch();
React.render(<SimulationDashboard collection={ simResultList }/>, document.getElementById("keeper_app"));
