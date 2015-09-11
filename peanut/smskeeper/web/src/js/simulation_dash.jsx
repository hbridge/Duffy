
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
var SimRows= require('./controls/SimRows.jsx');
var SimulationRow = SimRows.SimulationRow;
var SimDetailsRow = SimRows.SimDetailsRow;
var SimClassModal = require('./controls/SimClassDetailsModal.jsx');


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
      if (simRun.recentComparableRuns.length > 0){
        var comparable = _.findWhere(this.state.simRuns, {id: simRun.recentComparableRuns[0]});
      }

      rows.push(<SimulationRow
        simRun={ simRun }
        compareTo={comparable}
        key={ simId }
        onRowClicked={this.handleRowClicked}
        onRowDeleted={this.handleRowDeleted}
      />);
      if (_.contains(this.state.expandedRows, simId)) {
        console.log("simId %s expanded, adding details rows", simId);
        rows = rows.concat(this.getDetailsRows(simId));
      }
    }.bind(this));

		return (
      <div>
        { loading }
        <SimClassModal
          simId={this.state.expandedSimId}
          compareRunId={this.state.compareRunId}
          messageClass={this.state.expandedMessageClass}
          onClose={this.handleModalClosed}
        />
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
          var simRun = this.simRunWithId(simId);
          if (simRun && simRun.recentComparableRuns && simRun.recentComparableRuns.length > 0) {
            var compRunId = simRun.recentComparableRuns[0];
            var compRunClassData = this.state.simRunClassData[compRunId];
            var compClassSummary = compRunClassData[className];
          }
          return (
            <SimDetailsRow
              classSummary={this.state.simRunClassData[simId][className]}
              compSummary={compClassSummary}
              simId={simId}
              key={className + simId}
              handleClicked={this.handleDetailRowClicked}
            />);
        }.bind(this);
        return classNames.map(createClassRow);
      } else {
        return ([
          <tr key="loading">
            loading...
          </tr>
        ]);
      }
  },

  handleRowClicked(simRun){
    var simId = simRun.id;
    var newExpanded = this.state.expandedRows;
    if (_.contains(this.state.expandedRows, simId)) {
      newExpanded = _.without(this.state.expandedRows, simId);
    } else {
      newExpanded.push(simId);
      if (!this.state.simRunClassData[simId]) {
        this.getSimRunClassData(simId);
      }
      if (simRun.recentComparableRuns.length > 0) {
        var compRunId = simRun.recentComparableRuns[0];
        if (!this.state.simRunClassData[compRunId]) {
          this.getSimRunClassData(compRunId);
        }
      }
    }
    console.log("row with simId clicked %s", simId, newExpanded);
    this.setState({expandedRows: newExpanded});
  },

  handleRowDeleted(simId){
    var newSimRuns = _.reject(this.state.simRuns, function(simRun){
      return simRun.id == simId
    });
    this.setState({simRuns: newSimRuns});
  },

  getSimRunClassData(simId) {
    Model.fetchSimulationClassSummary(simId, function(data){
      var simRunClassData = this.state.simRunClassData;
      console.log("old simRunClassData", simRunClassData);
      simRunClassData[simId] = data;
      console.log("newSimRunClassData", simRunClassData);
      this.setState({simRunClassData: simRunClassData});
    }.bind(this));
  },

  handleDetailRowClicked(simId, messageClass){
    console.log("expanding simId: %d messageClass:%s", simId, messageClass);
    var simRun = this.simRunWithId(simId);
    if (simRun.recentComparableRuns.length > 0) {
      var compareToId = simRun.recentComparableRuns[0];
    }
    this.setState({expandedSimId: simId, expandedMessageClass: messageClass, compareRunId: compareToId});
  },

  handleModalClosed() {
    this.setState({expandedSimId: null, expandedMessageClass: null, compareRunId: null});
  },

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },


  simRunWithId(simId) {
    return _.findWhere(this.state.simRuns, {id: simId});
  }

});

React.render(<SimulationDashboard />, document.getElementById("keeper_app"));
