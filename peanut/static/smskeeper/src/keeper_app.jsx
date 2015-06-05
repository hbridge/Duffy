var React = require('react');
var $ = require('jquery');
var MasonryMixin = require('react-masonry-mixin');
var classNames = require('classnames');
var Timestamp = require('react-time');
var moment = require('moment');
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');

var masonryOptions = {
    transitionDuration: 0
};

var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

SelectedEntryRow = null;
SubmitCommandToServer = null;


var oldSync = Backbone.sync;
Backbone.sync = function(method, model, options){
    options.beforeSend = function(xhr){
        xhr.setRequestHeader('X-CSRFToken', $('meta[name="csrf-token"]').attr('content'));
    };
    return oldSync(method, model, options);
};

var Entry = Backbone.Model.extend({
  defaults: function() {
      return {
        hidden: false,
        creator: USER.id,
        users: [USER.id]
      };
    },

    urlRoot: function() {
      return "/smskeeper/entry";
    },
});


var EntryList = Backbone.Collection.extend({
  model: Entry,
  url: "/smskeeper/entry_feed?user_id=" + USER.id,
  lists: function() {
    var entriesByList = [];
    for (entry of this.models) {
      var hidden = entry.get('hidden');
      if (hidden) continue;
      var labelName = entry.get('label').replace("#", "")

      var entriesForLabel = []
      if (labelName in entriesByList) {
        entriesForLabel = entriesByList[labelName];
      }
      entriesForLabel.push(entry);

      entriesByList[labelName] = entriesForLabel;
    }

    // pull out reminders
    if (entriesByList["reminders"]) {
      delete entriesByList["reminders"]
    }
    return entriesByList;
  },
  reminders: function() {
    return(this.where({label: "#reminders"}));
  }
});

var EntryRow = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {isSelected: false};
  },

  render: function() {
    // create the delete X button if we're selected
    var text = this.state.model.text;
    if (!text) text = "";
    var remindDateText = this.state.model.remind_timestamp;

    var deleteElement = null;
    if (this.state.isSelected) {
      deleteElement = <div className="deleteButton">
        <a ref="deleteButton" onClick={this.handleDelete} href="#" > X </a>
      </div>;
    }

    // create the reminder element if this is a reminder
    var entryTimeField = null;
    if (remindDateText) {
      entryTimeField = <EntryTimeField date={new Date(remindDateText)}
      handleClicked={this.handleChildClicked}
      ref="entryTimeField"/>
    }

    return (
      <div className="entry container">
        {deleteElement}
        <EntryTextField text={text} handleClicked={this.handleChildClicked} ref="entryTextField" />
        {entryTimeField}
      </div>
    );
  },

  handleDelete: function(e) {
    e.preventDefault();
    var result = this.getModel().save({hidden: true});
    console.log("delete result:");
    console.log(result);
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
    if (destination && destination == React.findDOMNode(this.refs.deleteButton)) {
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
      return (
        <EntryRow model={ entry } key={ entry.get('id') } />
      );
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
  mixins: [
    MasonryMixin('masonryContainer', masonryOptions),
    BackboneReactComponent,
  ],
  getInitialState: function() {
    return { lists: [], reminders: [] };
  },

  submitCommandToServer: function(msg) {
    $.ajax({
      url: "/smskeeper/send_sms",
      dataType: 'json',
      type: 'POST',
      data: {msg: msg, user_id: USER.id, direction: "ToKeeper", silent: true, response_data: "entries"},
      success: function(entryData) {
        this.processDataFromServer(entryData);
      }.bind(this),
      error: function(xhr, status, err) {
        console.error("send_sms", status, err.toString());
      }.bind(this)
    });
  },

  componentDidMount: function() {
    SubmitCommandToServer = this.submitCommandToServer;
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
    if (this.props.reminders) {
      listNodes.push(
        <List label="Reminders"
          entries={ this.props.reminders }
          key= { "reminders" }
          isReminders= { true }/>
      );
    }

    // then add the rest of the lists
    for (key in this.props.lists) {
      listNodes.push(
        <List label={ key }
          entries={ this.props.lists[key] }
          key= { key }/>
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

  componentWillUpdate: function(nextProps, nextState) {
    this.props.reminders = nextProps.collection.reminders();
    this.props.lists = nextProps.collection.lists();
  },

  componentDidUpdate: function() {

  },
});

var entryCollection = new EntryList();
entryCollection.fetch();
React.render(<KeeperApp collection={entryCollection} />, document.getElementById("keeper_app"));
