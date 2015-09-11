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


var WrongResultsGroup = React.createClass({
	render(){
		if (!this.props.wrongByClass) {
			return <span></span>;
		}
		var createClassPanel = function(messageClass) {
			var messages = this.props.wrongByClass[messageClass];
			return (
				<Panel
					header={messageClass + " (" + messages.length + "/" + this.props.totalWrong + ")"}
					eventKey={messageClass}>
				  <ul>
			      	{messages.map(function(message){
			      		return <li><a target="_blank" href={"/smskeeper/simulation_result/" + message.sim_result_id}> {message.body} </a></li>
			      	})}
			      </ul>
			    </Panel>
			);
		}.bind(this);

		var sortedKeys = _.sortBy(Object.keys(this.props.wrongByClass), function(classKey){
			return this.props.wrongByClass[classKey].length;
		}, this).reverse();

		return(
			<div>
			<h4>{this.props.title}</h4>
			<Accordion>
				{sortedKeys.map(createClassPanel)}
			</Accordion>
			</div>
		);
	}
});


module.exports = React.createClass({
  getInitialState(){
    return {summaryData: null}
  },

  componentWillReceiveProps(nextProps) {
    if (nextProps.simId && nextProps.messageClass) {
      console.log("Modal receiving new props", nextProps);
      this.setState({show: true});
      Model.bindSimulationClassDetails(nextProps.simId, nextProps.messageClass, this, 'summaryData');

      if (nextProps.compareRunId) {
        Model.bindSimulationCompareClassDetails(nextProps.simId, nextProps.compareRunId, this, 'compareData');
      } else {
        console.log("no compareRunId")
      }
    }
  },

  render(){
    if (this.state.summaryData) {
	    var fpsByCorrectClass = _.groupBy(this.state.summaryData.fpMessages, function(fpMessage){
	    	return fpMessage.class;
	    });

	    var fnsBySimClass = _.groupBy(this.state.summaryData.fnMessages, function(fnMessage){
	    	return fnMessage.sim_class;
	    });

	    var fpCount = this.state.summaryData.fpMessages.length;
	    var fnCount = this.state.summaryData.fnMessages.length;
	  }

    var summary = this.state.summaryData;

    return (
      <Modal show={this.state.show} onHide={this.close} dialogClassName='detailsModal'>
        <Modal.Header closeButton>
            <Modal.Title>Details for run #{this.props.simId}: {this.props.messageClass} </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {this.getComparisonGroups()}
        	<WrongResultsGroup
        		title="False Positives"
        		wrongByClass={fpsByCorrectClass}
        		totalWrong={fpCount}
        	/>
        	<WrongResultsGroup
        		title="False Negatives"
        		wrongByClass={fnsBySimClass}
        		totalWrong={fnCount}
        	/>
        </Modal.Body>
      </Modal>
      );
  },

  getComparisonGroups(){
    if (this.state.compareData) {
      var classCompareData = this.state.compareData[this.props.messageClass];
      var fpsByCorrectClass = _.groupBy(classCompareData.fpMessages, function(fpMessage){
        return fpMessage.class;
      });

      var fnsBySimClass = _.groupBy(classCompareData.fnMessages, function(fnMessage){
        return fnMessage.sim_class;
      });

      return (
        <div>
          <Panel
            header="New Successes"
            eventKey="newSuccesses"
            collapsable>
            <ul>
              {classCompareData.tpMessages.map(function(message){
                return <li><a target="_blank" href={"/smskeeper/simulation_result/" + message.sim_result_id}> {message.body} </a></li>
              })}
            </ul>
          </Panel>
          <WrongResultsGroup
            title="New False Positives"
            wrongByClass={fpsByCorrectClass}
            totalWrong={classCompareData.fpMessages.count}
          />
          <WrongResultsGroup
            title="New False Negatives"
            wrongByClass={fnsBySimClass}
            totalWrong={classCompareData.fnMessages.count}
          />
        </div>
      );
    }
    return <span></span>
  },

  close(e) {
    this.setState({show: false})
    this.props.onClose();
  }
})