var $ = require('jquery');

/* Gets parameters from URL */
function getUrlParameter(sParam){
    var sPageURL = window.location.search.substring(1);
    var sURLVariables = sPageURL.split('&');

    for (var i = 0; i < sURLVariables.length; i++){
        var sParameterName = sURLVariables[i].split('=');
        if (sParameterName[0] == sParam){
            return sParameterName[1];
        }
    }
    return ''
}

var PostToSlack = function(username, text, channel){
  if (DevelopmentMode) {
    console.log("In development, not posting to slack");
    return;
  }

  var params = {
    username: username,
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

module.exports.PostToSlack = PostToSlack;
module.exports.getUrlParameter = getUrlParameter;