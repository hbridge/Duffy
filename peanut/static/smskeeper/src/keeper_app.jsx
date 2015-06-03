
/*
Note this file is only used in its raw form if ?development=True is passed in
It should be compiled to js by running from the outer directory

from static/smskeeper:
jsx --watch --extension jsx src/ build/
or
jsx --extension jsx src/ build/

See: https://facebook.github.io/react/docs/tooling-integration.html for info on installing

*/

var masonryOptions = {
    transitionDuration: 0
};

var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}


var EntryRow = React.createClass({
  render: function() {
    return (
      <div className="entry container" onClick={ this.handleClick }>
        <span ref="textspan">{this.props.fields.text}</span>
      </div>
    );
  },

  handleClick: function(e) {
    e.preventDefault();
    console.log(this);
    this.getDOMNode().contentEditable = true;
  },

  componentDidUpdate: function() {
    console.log('updated')
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
    var listNodes = []

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
