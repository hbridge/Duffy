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

var SubmitCommandToServer = function(msg, onSuccess, onFailure) {
  $.ajax({
        url: "/smskeeper/send_sms",
        dataType: 'json',
        type: 'POST',
        data: {msg: msg, user_id: USER.id, direction: "ToKeeper", response_data: "entries", from_num: "web"},
        success: function(entryData) {
          onSuccess(entryData);
        },
        error: function(xhr, status, err) {
          if (onFailure) onFailure(xhr, status, err);
          console.error("SubmitCommandToServer ", status, err.toString());
        }
      });
}

module.exports.PostToSlack = PostToSlack;
module.exports.getUrlParameter = getUrlParameter;
module.exports.SubmitCommandToServer = SubmitCommandToServer;