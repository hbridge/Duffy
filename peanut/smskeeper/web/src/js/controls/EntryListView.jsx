var React = require('react');
var $ = require('jquery');
var BackboneReactComponent = require('backbone-react-component');
var PlainEditable = require("react-plain-editable");
var classNames = require('classnames');
var Timestamp = require('react-time');
var moment = require('moment');
var Mixpanel = require("mixpanel");
var Utils = require("../utils");


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

    // create an attachment element if there's an attachment
    var entryAttachment = null;
    if (this.state.model.img_url) {
      entryAttachment = <EntryAttachment attachmentUrl={this.state.model.img_url} />
    }

    return (
      <div className="entry container" onMouseOver={this.selectRow}>
        {deleteElement}
        <EntryTextField text={text}
          handleClicked={this.handleChildClicked}
          ref="entryTextField" />
        {entryTimeField}
        {entryAttachment}
      </div>
    );
  },

  handleDelete: function(e) {
    e.preventDefault();
    var entry = this.getModel();
    var result = entry.save({hidden: true});
    console.log("delete result:");
    console.log(result);
    Utils.PostToSlack(USER.name, "Deleted " + entry.get("text") + " from " + entry.get('label'), "#livesmskeeperfeed");
    mixpanel.track("Deleted Entry", {
        distinct_id: USER.id,
        interface: "web",
        entryType: this.getModel().get("remind_timestamp") ? "reminder" : "text",
        result: result,
      });
  },

  selectRow: function() {
    if (SelectedEntryRow && SelectedEntryRow != this) {
      SelectedEntryRow.setState({isSelected: false});
    }
    SelectedEntryRow = this;
    this.setState({isSelected: true});
  },

  deselectRow: function() {
    if (SelectedEntryRow == this) {
      this.setState({isSelected: false});
      SelectedEntryRow = null;
    }
  },

  handleChildClicked: function(child) {
    // deselect the previously selected entry row
    this.selectRow();
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
   mixins: [BackboneReactComponent],
  render: function() {
    return (
      <PlainEditable onBlur={this.handleTextFinishedEditing}
        onClick={this.handleClicked}
        value={this.props.text}
        ref="editable"/>
    );
  },

  handleClicked: function(e) {
    this.props.handleClicked(this);
  },

  handleTextChanged: function(e) {
    console.log("text changed");
    this.setState({textChanged : true});
  },

  handleTextFinishedEditing: function(e, newValue) {
    var destination = e.nativeEvent.relatedTarget;
    if (destination && destination == React.findDOMNode(this.refs.deleteButton)) {
      // this isn't a cancel if the user is tapping another element in the form
      return;
    }

    var model = this.getModel();
    var oldValue = model.get("text");
    console.log("text finished editing old text: " + oldValue + " new text: "+ newValue);

    if (oldValue != newValue) {
      console.log("saving updated text: " + newValue);
      model.set("text", newValue);
      model.save();

      mixpanel.track("Changed Entry Text", {
        distinct_id: USER.id,
        interface: "web",
        entryType: this.getModel().get("remind_timestamp") ? "reminder" : "text"
      });
    }
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
    mixpanel.track("Changed Reminder Time", {
      distinct_id: USER.id,
      interface: "web",
      result: "not implemented",
    });
    this.props.handleClicked(this);

    return;
    // TODO actually make saving time work
    this.setState({expanded: true});

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

var EntryAttachment = React.createClass({
  getStyle: function() {
    return {
      background: "url(%SRC%)".replace("%SRC%", this.props.attachmentUrl),
      width: "100%",
      height: "200px",
      backgroundRepeat: "no-repeat",
      backgroundSize: "contain",
    };
  },

  render: function(){
    return (
      <div style={this.getStyle()}>
      </div>
    );
  }
});

var CreateEntryFooter = React.createClass({
  mixins: [BackboneReactComponent],
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
    if (text == "") return;

    if (this.props.isReminders) {
      if (text.indexOf("Remind me to") == -1) {
        text = "Remind me to " + text;
        console.log("reminder command: " + text);
      }
      Utils.PostToSlack(USER.name, text, "#livesmskeeperfeed");
      SubmitCommandToServer(text);

    } else {
      var entry = new Entry();
      entry.set('label', "#" + this.props.listName);
      entry.set('text', text);
      this.getCollection().add([entry]);
      entry.save();

      Utils.PostToSlack(USER.name, "Added " + text + " to " + entry.get('label'), "#livesmskeeperfeed");
      mixpanel.track("Added Entries", {
        distinct_id: USER.id,
        interface: "web",
        "Entry Count": 1,
        Label: entry.get('label'),
        "Share Count": 0,
        "Media Count": 0,
      });
    }
    React.findDOMNode(this.refs.text).value = "";
  },

  componentDidUpdate: function(){
    if (this.state.expanded) {
      this.refs.text.getDOMNode().focus();
    }
  },

});

module.exports = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
    var createEntry = function(entry, index) {
      return (
        <EntryRow model={ entry } key={ entry.get('id') } />
      );
    }.bind(this);

    var listClasses = classNames({
      'grid-item': true,
      'list': true,
      'textList': !this.props.isReminders,
      'reminderList': this.props.isReminders,
      'stamp': this.props.isReminders,
    });

    return (
      <div className={listClasses}>
        <div className="container">
          <span className="clearButton"><a href="#" onClick={this.handleClear}>X</a></span>
          <span className="title"> {this.props.label} </span>
        </div>
        <div className="entriesContainer">
           { this.props.entries.reverse().map(createEntry) }
        </div>
        <CreateEntryFooter isReminders={ this.props.isReminders }
          listName={this.props.label}/>
      </div>
    );
  },

  handleClear: function(e) {
    e.preventDefault();
    var deleteWord = this.props.isReminders ? "Clear" : "Delete";
    var result = confirm(deleteWord + " " + this.props.label + "?");
    var entryCount = this.props.entries.length;
    if (result) {
      this.props.entries.map(function(entry){
        entry.set("hidden", true);
        entry.save();
      });
      Utils.PostToSlack(USER.name, "Cleared " + this.props.label, "#livesmskeeperfeed");
    }

    mixpanel.track("Cleared Label", {
      distinct_id: USER.id,
      interface: "web",
      label: this.props.label,
      "Entry Count": entryCount,
      result: result
    });
  },
});
