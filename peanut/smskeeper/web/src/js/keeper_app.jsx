var React = require('react');
var $ = require('jquery');
var MasonryMixin = require('react-masonry-mixin');
var BackboneReactComponent = require('backbone-react-component');
var Mixpanel = require("mixpanel");
var NodeEmoji = require("node-emoji");
var Utils = require("./utils");
var Model = require("./model/Model.jsx");
var Entry = Model.Entry;
var EntryList = Model.EntryList;
var EntryListView = require("./controls/EntryListView.jsx");

DevelopmentMode = (window['DEVELOPMENT'] != undefined);

if (DevelopmentMode || USER.id <= 3 || Utils.getUrlParameter("internal")) {
  mixpanelToken = "d309a366da36d3f897ad2772390d1679";
  console.log("In development, logging to dev stats");
} else {
  mixpanelToken = "165ffa12b4eac14005ec6d97872a9c63";
}
mixpanel = Mixpanel.init(mixpanelToken);

var masonryOptions = {
    transitionDuration: 0
};

var formatDate = function(d){
  return d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
}

MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

SelectedEntryRow = null;
SubmitCommandToServer = null;

var CreateListField = React.createClass({
  mixins: [BackboneReactComponent],
  render: function() {
     return (
      <div className="grid-item createListControl stamp">
        <form className="createListForm" onSubmit={this.handleSave}>
          <input type="text" placeholder="New List..." ref="text" className="bigfield title"/>
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

    PostToSlack(USER.name, "Created a list: " + entry.get('label'), "#livesmskeeperfeed");
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
      <footer>
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
    Utils.SubmitCommandToServer(
      msg,
      function(entryData){
        this.getCollection().fetch();
      }.bind(this),
      null
    );
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
        <EntryListView
          label={NodeEmoji.get("bell") + "Reminders"}
          entries={ this.state.reminders }
          key= { "reminders" }
          isReminders= { true }/>
      );
    }

    // then add the rest of the lists
    keys = Object.keys(this.state.lists);
    console.log(keys);
    for (var i = 0; i < keys.length; i++) {
      key = keys[i];
      listNodes.push(
        <EntryListView label={ key }
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
});

var entryCollection = new EntryList();
entryCollection.fetch();
React.render(<KeeperApp collection={entryCollection} />, document.getElementById("keeper_app"));
