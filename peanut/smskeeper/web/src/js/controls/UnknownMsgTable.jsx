var React = require('react')
var $ = require('jquery');
var classNames = require('classnames');
var moment = require('moment-timezone');
var BackboneReactComponent = require('backbone-react-component');
var Utils = require('../utils.js');
var _ = require('underscore');
var Bootstrap = require('react-bootstrap');
  Button = Bootstrap.Button;
  Input = Bootstrap.Input;
  ListGroup = Bootstrap.ListGroup;
  Table = Bootstrap.Table;
  Modal = Bootstrap.Modal;
  SplitButton = Bootstrap.SplitButton;
  MenuItem = Bootstrap.MenuItem;
  Popover = Bootstrap.Popover;
  OverlayTrigger = Bootstrap.OverlayTrigger;
AdminEntryCard = require('./AdminEntryCard.jsx');
var emoji = require('node-emoji');


var EntryRow = React.createClass({
  mixins: [BackboneReactComponent],
  render() {
    var approveButton = <Button
      bsStyle={this.state.model.manually_check ? 'danger' : 'success'}
      ref="approveButton"
      bsSize="xsmall"
      onClick={this.handleApproveToggled}
    >
      {this.state.model.manually_check ? "Unreviewed" : "Approved"}
    </Button>

    var dateFormat = "h:mm A ddd, MMM D";

    return (
      <tr>
            <td> { approveButton } </td>
            <td> <a href={'../history?user_id=' + this.state.model.user } target="_blank"> {this.state.model.user_name} </a></td>
            <td> { this.state.model.body } </td>
            <td> { this.state.model.followups } </td>
      </tr>
        );
  },

  handleApproveToggled(e) {
    e.preventDefault();
    e.stopPropagation();
    var newVal = !(this.state.model.manually_check);
    console.log("setting manually_check for %d to %s", this.state.model.id, newVal);
    var changes = {
      'manually_check': newVal,
      'manually_approved_timestamp': newVal ? null : moment().toISOString(),
    };
    var result = this.props.model.save(changes, {patch: true});
    console.log("save result:", result)
  },

});


module.exports = React.createClass({
  mixins: [BackboneReactComponent],

  render() {
    var createRow = function(entry, index) {
      return (
        <EntryRow model={ entry } key={ entry.id }/>
      );
    }.bind(this);

    return (
      <div>
      <Table striped bordered condensed hover>
      <thead>
        <tr>
          <th>Approval</th>
          <th>User</th>
          <th>Body</th>
          <th>Followups</th>
        </tr>
      </thead>
      <tbody>
        { this.props.collection.map(createRow) }
        </tbody>
      </Table>
      <p>Entries to review: <b>{ this.state.collection.length }</b></p>
      </div>
    );
  },

 });