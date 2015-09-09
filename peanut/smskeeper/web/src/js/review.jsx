
var React = require('react')
React.initializeTouchEvents(true);

// Model
var Backbone = require('backbone');
var BackboneReactComponent = require('backbone-react-component');
var Model = require('./model/Model.jsx');
var ReviewList = Model.ReviewList;
var UnknownMsgList = Model.UnknownMsgList;

// Our UI components
var AdminReviewTable = require('./controls/AdminReviewTable.jsx');
var UnknownMsgTable = require('./controls/UnknownMsgTable.jsx');
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
      // setInterval(function () {this.getCollection().fetch()}.bind(this), 2000);
    }
  },

	render: function() {
    var loading = null;
    var showAll = null;
    if (this.props.reviewList.size == 0) {
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
        <AdminReviewTable collection={this.props.reviewList} />
        <div>
          <h2>Unknown messages</h2>
        </div>
        <UnknownMsgTable collection={this.props.unknownMsgList} />
      </div>
		);
	},

  componentWillUpdate: function(nextProps, nextState) {
    console.log("component will update");
  },
});

var reviewList = new ReviewList();
reviewList.fetch();

var unknownMsgList = new UnknownMsgList();
unknownMsgList.fetch();

React.render(<ReviewApp reviewList={ reviewList } unknownMsgList={ unknownMsgList }/>, document.getElementById("keeper_app"));
