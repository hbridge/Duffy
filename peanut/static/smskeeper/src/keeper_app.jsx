
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
        <b>{this.props.fields.label}</b> {this.props.fields.text}
      </div>
    );
  }
});



var KeeperApp = React.createClass({
  getInitialState: function() {
    return {entries: [], selectedMessage: null };
  },

  processDataFromServer: function(data) {
    console.log("Got data from the server:");
    console.log(data);
    var entriesByList = {};
    for (entry of data) {
      var labelArr = []
      if ("fields" in entry) {
        if (entry.fields.label in entriesByList) {
          labelArr = entriesByList[entry.fields.label];
        }
        labelArr.push(entry);
      } else {
        console.error("fields not in obj");
        console.error(entry);
      }
      entriesByList[entry.fields.label] = labelArr;
    }
    console.log(entriesByList)

    this.setState({entries : data, entriesByList: entriesByList});
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
    setInterval(function () {loadFunc()}, 2000);
  },

	render: function() {
		var createEntry = function(entry, index) {
			return <EntryRow fields={ entry.fields }
        key= { entry.pk }
        />
		}.bind(this);

		return (
      <div>
  			<div id="entries">
  			   { this.state.entries.map(createEntry) }
        </div>
      </div>
		);
	},

  componentDidUpdate: function() {

  },
});

React.render(<KeeperApp />, document.getElementById("keeper_app"));
