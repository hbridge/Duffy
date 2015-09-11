var React = require('react');
var Bootstrap = require('react-bootstrap');
	Label = Bootstrap.Label;

module.exports = React.createClass({
	render(){
		var value = this.props.value;
			if (value) {
			var style = 'default';
			if (Math.abs(value) >= 0.01) {
				style = value < 0 ? 'danger' : 'success';
			}

			return (<Label bsStyle={style} bsSize ='xsmall'>{value.toFixed(3)}</Label>);
		}

		return (<span></span>);
	}
});