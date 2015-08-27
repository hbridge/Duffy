
var React = require('react')
React.initializeTouchEvents(true);

// Model
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');
var Model = require('./model/Model.jsx');
var ReviewList = Model.ReviewList;

// Our UI components
var AdminReviewTable = require('./controls/AdminReviewTable.jsx');
var DevelopmentMode = (window['DEVELOPMENT'] != undefined);
var firstLoadComplete = false;

var ReviewApp = React.createClass({
  mixins: [BackboneReactComponent],

  getInitialState: function() {
    return {messages: [], selectedMessage: null, maxRowsToShow: 100};
  },

  componentDidMount: function() {
    this.lastSeenMessageId = 0;
    if (!DevelopmentMode) {
      setInterval(function () {this.getModel().fetch()}.bind(this), 2000);
    }
  },

	render: function() {
    var loading = null;
    var showAll = null;
    if (this.state.collection.size == 0) {
      loading =
      <div>
        <p>
        loading...
        </p>
      </div>
    }

		return (
      <div>
        { loading }
        <AdminReviewTable collection={this.props.collection} />
      </div>
		);
	},

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },
});

var reviewList = new ReviewList();
reviewList.fetch();
React.render(<ReviewApp collection={ reviewList }/>, document.getElementById("keeper_app"));
