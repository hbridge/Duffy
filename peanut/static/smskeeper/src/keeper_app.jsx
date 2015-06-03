
/*
Note this file is only used in its raw form if ?development=True is passed in
It should be compiled to js by running from the outer directory

from static/smskeeper:
jsx --watch --extension jsx src/ build/
or
jsx --extension jsx src/ build/

See: https://facebook.github.io/react/docs/tooling-integration.html for info on installing

*/


var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}


var EntryRow = React.createClass({
  render: function() {
    return (
      <div className="entry">
        {this.props.fields.text}
      </div>
    );
  }
});

var List = React.createClass({
  render: function() {
    var createEntry = function(entry, index) {
      return <EntryRow fields={ entry.fields }
        key= { entry.pk }
        />
    }.bind(this);

    return (
      <div className="list grid-item">
        <h2> {this.props.label} </h2>
        <div id="entries">
           { this.props.entries.map(createEntry) }
        </div>
      </div>
    );
  }
});

var KeeperApp = React.createClass({
  getInitialState: function() {
    return {entries: [], lists: [], reminders: [] };
  },

  processDataFromServer: function(data) {
    console.log("Got data from the server:");
    console.log(data);
    var entriesByList = [];
    for (entry of data) {
      var entriesForLabel = []
      if ("fields" in entry) {
        if (entry.fields.label in entriesByList) {
          entriesForLabel = entriesByList[entry.fields.label];
        }
        entriesForLabel.push(entry);
      } else {
        console.error("fields not in obj");
        console.error(entry);
      }
      entriesByList[entry.fields.label] = entriesForLabel;
    }
    console.log(entriesByList)

    // pull out reminders
    var reminderEntries = [];
    if (entriesByList["#reminders"]) {
      reminderEntries = entriesByList["#reminders"]
      delete entriesByList["#reminders"]
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
      <List label="#reminders"
        entries={ this.state.reminders }
        key= { "#reminders" }
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
        <div id="lists" className="grid">
           { listNodes }
        </div>
      </div>
    );
  },

  componentDidUpdate: function() {
    var elem = document.querySelector('.grid');
    var msnry = new Masonry( elem, {
      // options
      itemSelector: '.grid-item',
      columnWidth: 200
    });

    // element argument can be a selector string
    //   for an individual element
    var msnry = new Masonry( '.grid', {
      // options
    });
  },
});

React.render(<KeeperApp />, document.getElementById("keeper_app"));
