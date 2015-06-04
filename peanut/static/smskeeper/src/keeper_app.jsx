
var React = require('react')
var $ = require('jquery');
var MasonryMixin = require('react-masonry-mixin');
var classNames = require('classnames');
var Timestamp = require('react-time');
var moment = require('moment');

var masonryOptions = {
    transitionDuration: 0
};

var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

SelectedEntryRow = null;

var EntryRow = React.createClass({
  getInitialState: function() {
    return {isSelected: false};
  },

  render: function() {
    // create the clear X button if we're selected
    var deleteElement = null;
    if (this.state.isSelected) {
      deleteElement = <div className="clearButton">
        <a ref="clearButton" onClick={this.handleClear} href="#" > X </a>
      </div>;
    }

    // create the reminder element if this is a reminder
    var entryTimeField = null;
    if (this.props.fields.remind_timestamp) {
      entryTimeField = <EntryTimeField date={new Date(this.props.fields.remind_timestamp)}
      handleClicked={this.handleChildClicked}
      ref="entryTimeField"/>
    }

    return (
      <div className="entry container">
        {deleteElement}
        <EntryTextField text={this.props.fields.text} handleClicked={this.handleChildClicked} ref="entryTextField" />
        {entryTimeField}
      </div>
    );
  },

  handleClear: function(e) {
    e.preventDefault();
    alert('mock clear');
  },

  handleChildClicked: function(child) {
    // deselect the previously selected entry row
    if (SelectedEntryRow && SelectedEntryRow != this) {
      SelectedEntryRow.setState({isSelected: false});
    }
    SelectedEntryRow = this;
    this.setState({isSelected: true});
  },

  componentWillUpdate: function(nextProps, nextState) {
    if (!nextState.isSelected) {
      this.refs.entryTextField.setState({expanded: false});
      if (this.refs.entryTimeField) {
        this.refs.entryTimeField.setState({expanded: false});
      }
    }
  }
});

var EntryTextField = React.createClass({
  render: function() {
    return (<div
        onClick = { this.handleClicked }
        onBlur = { this.handleTextFinishedEditing }
        onInput= { this.handleTextChanged}
        contentEditable={true}>
          <span ref="textspan">{this.props.text}</span>
        </div>
    );
  },

  handleClicked: function(e) {
    this.props.handleClicked(this);
  },

  handleTextChanged: function(e) {

  },

  handleTextFinishedEditing: function(e) {
    var destination = e.nativeEvent.relatedTarget;
    if (destination && destination == React.findDOMNode(this.refs.clearButton)) {
      // this isn't a cancel if the user is tapping another element in the form
      return;
    }

    console.log("finished with text: " + this.refs.textspan.props.children);
    this.setState({expanded: false});
  },
});


var EntryTimeField = React.createClass({
  getInitialState: function() {
    return {expanded: false};
  },

  render: function() {
    if (this.state.expanded) {
        return (
          <div >
            <form className="itemForm" ref="timeForm" onSubmit={this.handleSaveTime} onBlur={this.handleTimeEditCancelled}>
            <input type="text" placeholder="New time" ref="timeInput" className="textInput" />
            <input type="submit" value="Save" ref="timeSave" className="button" />
          </form>
          </div>
        );
      } else {
        var reminderDate = new Date(this.props.date);
        var reminderClasses = classNames({
          "reminderTime" : true,
          "overdue": moment(reminderDate).isBefore(moment()),
          "upcoming": moment(reminderDate).isBetween(moment(), moment().add(1, 'days'))
        });
        return (
          <div>
            <a onClick={this.handleClicked} href="#">
              <Timestamp value={reminderDate} format="MMM Do [at] LT" titleFormat="YYYY/MM/DD HH:mm" className={reminderClasses}/>
            </a>
          </div>
        );
      }
  },

  // deal with time events
  handleClicked: function(e) {
    e.preventDefault();
    this.setState({expanded: true});
    this.props.handleClicked(this);
  },

  handleTimeEditCancelled: function(e) {
    var destination = e.nativeEvent.relatedTarget;
    if (destination && destination.form == React.findDOMNode(this.refs.timeForm)) {
      // this isn't a cancel if the user is tapping another element in the form
      return;
    }

    this.setState({expanded: false});
  },

  handleSaveTime: function(e) {
    e.preventDefault();
    console.log('save time');
    this.setState({expanded: false});
  },

  componentDidUpdate: function() {
    if (this.state.expanded) {
      React.findDOMNode(this.refs.timeInput).focus();
    }
  }
});

var CreateEntryFooter = React.createClass({
  getInitialState: function() {
    return {expanded: false};
  },

  render: function() {
    var mainElement;
    if (this.state.expanded) {
      mainElement =
      <form className="itemForm" onSubmit={this.handleSave}>
        <input type="text" placeholder="New item" ref="text" className="textInput"/>
        <input type="submit" value="Save" className="button" />
      </form>
    } else {
      if (this.props.isReminders) {
        mainElement = <a href="#" onClick={this.handleAddClicked}>+ Add Reminder</a>;
      } else {
        mainElement = <a href="#" onClick={this.handleAddClicked}>+ Add Item</a>;
      }
    }

    return (
      <div className="container createEntryFooter">
        { mainElement }
      </div>
    );
  },

  handleAddClicked: function(e) {
    e.preventDefault();
    this.setState({expanded : !this.state.expanded});
  },

  handleSave: function(e) {
    e.preventDefault();
    var text = React.findDOMNode(this.refs.text).value.trim();
    window.alert("mock save: " + text);
  },

});

var List = React.createClass({
  render: function() {
    var createEntry = function(entry, index) {
      return <EntryRow fields={ entry.fields }
        key= { entry.pk }
        />
    }.bind(this);

    var listClasses = classNames({
      'list': true,
      'grid-item': true,
      'reminderList': this.props.isReminders,
    });

    return (
      <div className={listClasses}>
        <div className="container">
          <h2> {this.props.label} </h2>
        </div>
        <div className="entriesList">
           { this.props.entries.map(createEntry) }
        </div>
        <CreateEntryFooter isReminders={ this.props.isReminders }/>
      </div>
    );
  }
});

var HeaderBar = React.createClass({
  render: function() {
    return (
      <div className="headerBar">
        <span className="greeting">Hi {USER.name}.</span>
        <div className="userStats">
          Last week you rocked it.
        </div>
      </div>
    );
  }
});

var KeeperApp = React.createClass({
  mixins: [MasonryMixin('masonryContainer', masonryOptions)],
  getInitialState: function() {
    return {entries: [], lists: [], reminders: [] };
  },

  processDataFromServer: function(data) {
    console.log("Got data from the server:");
    console.log(data);
    var entriesByList = [];
    for (entry of data) {
      var labelName = entry.fields.label.replace("#", "")

      var entriesForLabel = []
      if ("fields" in entry) {
        if (labelName in entriesByList) {
          entriesForLabel = entriesByList[labelName];
        }
        entriesForLabel.push(entry);
      } else {
        console.error("fields not in obj");
        console.error(entry);
      }

      entriesByList[labelName] = entriesForLabel;
    }
    console.log(entriesByList)

    // pull out reminders
    var reminderEntries = [];
    if (entriesByList["reminders"]) {
      reminderEntries = entriesByList["reminders"]
      delete entriesByList["reminders"]
    }
    this.setState({entries : data, lists: entriesByList, reminders: reminderEntries});
  },

  loadDataFromServer: function() {
    $.ajax({
      url: "/smskeeper/entry_feed?user_id=" + USER.id,
      dataType: 'json',
      cache: false,
      success: function(data) {
        this.processDataFromServer(data);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("lists_feed", status, err.toString());
      }.bind(this)
    });
  },

  componentDidMount: function() {
    this.loadDataFromServer();
    var loadFunc = this.loadDataFromServer;
    if (window['DEVELOPMENT'] == undefined) {
      setInterval(function () {loadFunc()}, 2000);
    } else {
      console.log("in development, not autorefreshing");
    }
  },

	render: function() {
    var listNodes = [];

    // put reminders on top
    listNodes.push(
      <List label="Reminders"
        entries={ this.state.reminders }
        key= { "reminders" }
        isReminders= { true }
      />
    );

    // then add the rest of the lists
    for (key in this.state.lists) {
      listNodes.push(
        <List label={ key }
          entries={ this.state.lists[key] }
          key= { key }
        />
      );
    }

    return (
      <div>
        <HeaderBar />
        <div id="lists" className="grid" ref="masonryContainer">
           { listNodes }
        </div>
      </div>
    );
  },

  componentDidUpdate: function() {

  },
});

React.render(<KeeperApp />, document.getElementById("keeper_app"));
