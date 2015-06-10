var React = require('react');
var $ = require('jquery');
var MasonryMixin = require('react-masonry-mixin');
var classNames = require('classnames');
var Timestamp = require('react-time');
var moment = require('moment');
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');
var PlainEditable = require("react-plain-editable");
var Mixpanel = require("mixpanel")
var NodeEmoji = require("node-emoji")

var DevelopmentMode = (window['DEVELOPMENT'] != undefined);

var mixpanelToken;
if (DevelopmentMode || USER.id <= 3) {
  mixpanelToken = "d309a366da36d3f897ad2772390d1679";
  console.log("In development, logging to dev stats");
} else {
  mixpanelToken = "165ffa12b4eac14005ec6d97872a9c63";
}
var mixpanel = Mixpanel.init(mixpanelToken);

var masonryOptions = {
    transitionDuration: 0
};

var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

SelectedEntryRow = null;
SubmitCommandToServer = null;

var PostToSlack = function(text, channel){
  if (DevelopmentMode) {
    console.log("In development, not posting to slack");
    return;
  }

  var params = {
    username: USER.name,
    icon_emoji: ':globe_with_meridians:',
    text: text + " (via web) | <http://prod.strand.duffyapp.com/smskeeper/history?user_id=" + USER.id + "|history>",
    channel: channel,
  };

  $.ajax({
    url: "https://hooks.slack.com/services/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",
    type: 'POST',
    data: JSON.stringify(params),
    success: function(response) {
      console.log("Posted to slack.")
    }.bind(this),
    error: function(xhr, status, err) {
      console.error("Error posting to slack:", status, err.toString());
    }.bind(this)
  });
}

var Entry = Backbone.Model.extend({
  defaults: function() {
      var dateString = (new Date()).toISOString();
      return {
        hidden: false,
        creator: USER.id,
        users: [USER.id],
        added: dateString,
        updated: dateString,
      };
    },

    urlRoot: function() {
      return "/smskeeper/entry/";
    },
});


var EntryList = Backbone.Collection.extend({
  model: Entry,
  url: "/smskeeper/entry_feed?user_id=" + USER.id,
  comparator: function(entry) {
    var date = new Date(entry.get("added"));
    var dval = (date - 0) * -1;
    return dval;
  },
  lists: function() {
    var entriesByList = [];
    this.forEach(function(entry){
      var hidden = entry.get('hidden');
      if (hidden) return;
      var labelName = entry.get('label').replace("#", "")

      var entriesForLabel = []
      if (labelName in entriesByList) {
        entriesForLabel = entriesByList[labelName];
      }
      entriesForLabel.push(entry);

      entriesByList[labelName] = entriesForLabel;
    });

    // pull out reminders
    if (entriesByList["reminders"]) {
      delete entriesByList["reminders"]
    }
    return entriesByList;
  },
  reminders: function() {
    var notHidden = this.where({label: "#reminders", hidden: false})
    var sorted = notHidden.sort(function(a, b){
      var dateA = new Date(a.get("remind_timestamp"));
      var dateB = new Date(b.get("remind_timestamp"));
      return dateB - dateA;
    });
    return(sorted);
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
    PostToSlack("Deleted " + entry.get("text") + " from " + entry.get('label'), "#livesmskeeperfeed");
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
      if (text.indexOf("#reminder") == -1) {
        text = "#reminder " + text;
        console.log("reminder command: " + text);
      }
      PostToSlack(text, "#livesmskeeperfeed");
      SubmitCommandToServer(text);

    } else {
      var entry = new Entry();
      entry.set('label', "#" + this.props.listName);
      entry.set('text', text);
      this.getCollection().add([entry]);
      entry.save();

      PostToSlack("Added " + text + " to " + entry.get('label'), "#livesmskeeperfeed");
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

var List = React.createClass({
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
          <span className="listTitle"> {this.props.label} </span>
        </div>
        <div className="entriesList">
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
      PostToSlack("Cleared " + this.props.label, "#livesmskeeperfeed");
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

var CreateListField = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
     return (
      <div className="grid-item createListControl stamp">
        <form className="createListForm" onSubmit={this.handleSave}>
          <input type="text" placeholder="New List..." ref="text" className="createListField listTitle"/>
          <input type="submit" value="Save" style={{display: "none"}} />
        </form>
      </div>
    );
  },

  handleSave: function(e) {
    e.preventDefault();
    console.log("create list");

    var text = React.findDOMNode(this.refs.text).value.trim();
    if (text == "") return;

    var entry = new Entry();
    entry.set('label', "#" + text);
    entry.set('text', "New item");
    this.getCollection().add([entry]);
    entry.save();

    PostToSlack("Created a list: " + entry.get('label'), "#livesmskeeperfeed");
    mixpanel.track("Created List", {
      distinct_id: USER.id,
      interface: "web",
      Label: entry.get('label'),
      "Share Count": 0,
      "Media Count": 0,
    });

    React.findDOMNode(this.refs.text).value = "";
  }
});

var HeaderBar = React.createClass({
  getDefaultProps: function() {
    return {
      header: NodeEmoji.get(":raising_hand:") +" Hi " + USER.name + ".",
      subheader: "Hope you're having a great day! " + NodeEmoji.get("smile"),
    };
  },

  render: function() {
    return (
      <div className="headerBar">
        <span className="greeting">
          {this.props.header}
        </span>
        <div className="userStats">
          {this.props.subheader}
        </div>
      </div>
    );
  }
});

var Footer = React.createClass({
  render: function(){
    return(
      <footer class="wrapper">

      <div id="footer_links">
        <a href='mailto:support@duffytech.co'>Contact</a> &middot; <a href="http://getkeeper.com/privacy.php">Privacy</a><br />
        &copy;2015 Duffy, Inc.<br />
        Made in NYC {NodeEmoji.get(":apple:")}
      </div>
      </footer>
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
      data: {msg: msg, user_id: USER.id, direction: "ToKeeper", response_data: "entries", from_num: "web"},
      success: function(entryData) {
        this.getCollection().fetch();
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
      setInterval(function () {this.getCollection().fetch()}.bind(this), 10000);
    } else {
      console.log("in development, not autorefreshing");
    }
    mixpanel.track("Webapp Load", {
      distinct_id: USER.id,
      interface: "web",
    });
  },

	render: function() {
    var listNodes = [];

    // put reminders on top
    if (this.state.reminders) {
      listNodes.push(
        <List label={NodeEmoji.get("bell") + "Reminders"}
          entries={ this.state.reminders }
          key= { "reminders" }
          isReminders= { true }/>
      );
    }

    // then the create list field
    listNodes.push(
      <CreateListField key="createList" />
    );

    // then add the rest of the lists
    for (key in this.state.lists) {
      listNodes.push(
        <List label={ key }
          entries={ this.state.lists[key] }
          key= { key } />
      );
    }

    return (
      <div>
        <HeaderBar />
        <div id="lists" className="grid" ref="masonryContainer">
           { listNodes }
        </div>
        <Footer />
      </div>
    );
  },

  componentWillUpdate: function(nextProps, nextState) {
    nextState.reminders = nextProps.collection.reminders();
    nextState.lists = nextProps.collection.lists();
  },

  componentDidUpdate: function() {

  },
});

var entryCollection = new EntryList();
entryCollection.fetch();
React.render(<KeeperApp collection={entryCollection} />, document.getElementById("keeper_app"));
