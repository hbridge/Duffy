
var React = require('react')
React.initializeTouchEvents(true);

// Model
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');
var Model = require('./model/Model.jsx');
var SimResultList = Model.SimResultList;

// Our UI components
var AdminReviewTable = require('./controls/AdminReviewTable.jsx');
var DevelopmentMode = (window['DEVELOPMENT'] != undefined);
var firstLoadComplete = false;

var SimulationRow = React.createClass({
  mixins: [BackboneReactComponent],
  render() {
    var simId = parseInt(this.props.simulationId);
    console.log("rendering row for simId %d", simId, this.props, this.props.simulationId)
    var results = this.getCollection().where({sim_id: simId});
    var accurate = this.getCollection().accurateClassifications(simId);
    console.log("results, accurate", results, accurate);
    return (
      <tr>
        <td> { simId } </td>
        <td> { accurate.length } / { results.length } ({(accurate.length / results.length).toFixed(2)})</td>
      </tr>
    );
  }
});

var SimulationDashboard = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {results: []};
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

    var createRow = function(simId, index) {
      console.log("creating sim row with id", simId)
      return (
        <SimulationRow simulationId={ simId } key={ index } onRowClicked={this.handleRowClicked}/>
      );
    }.bind(this);
		return (
      <div>
        { loading }
        <Table striped bordered condensed hover>
        <thead>
          <tr>
            <th>Sim Id</th>
            <th>Accuracy</th>
          </tr>
        </thead>
        <tbody>
          { this.props.collection.uniqueSimIds().map(createRow) }
          </tbody>
        </Table>
      </div>
		);
	},

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },
});

var simResultList = new SimResultList();
simResultList.fetch();
React.render(<SimulationDashboard collection={ simResultList }/>, document.getElementById("keeper_app"));
