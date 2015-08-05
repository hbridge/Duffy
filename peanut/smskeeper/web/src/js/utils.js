var $ = require('jquery');
var emoji = require("node-emoji");

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


var Emojize = function(str) {
  newstr = str;
  var matches = str.match(/[:]\S+[:]/g);
  if (!matches || matches.length == 0) {
    return str;
  }
  for (var i = 0; i < matches.length; i++) {
    var match = matches[i];
    var emoji_lookup = match.replace(/[:]/g, "");
    var emoji_char = emoji.get(emoji_lookup);
    if (emoji_char) {
      newstr = newstr.replace(match, emoji_char);
    } else {
      console.log("no match for %s", emoji_lookup);
    }
  }
  return newstr;
}

var emojiKeys = Object.keys(emoji.emoji);

var EmojiKeysMatchingSubstr = function(str) {
  var matches = str.match(/[:]\S+([\s]|$)/g);
  if (!matches || matches.length == 0) {
    console.log("no matches for emoji complete")
    return [];
  }

  var emojiPrefix = matches[0].slice(1); // still has the leading :, remove
  if (emojiPrefix.length < 2) return []; // don't match on < 2 chars

  console.log("emoji prefix ", emojiPrefix)
  matchingKeys = emojiKeys.filter(function(key, index, array){
    key = key.toString();
    if (key.match(new RegExp(emojiPrefix))) {
      return true;
    } else {
      return false;
    }
  });

  console.log("Prefix matches keys ", emojiPrefix, matchingKeys)
  return matchingKeys;
}

// from http://stackoverflow.com/questions/11381673/detecting-a-mobile-browser
var CachedMobile = null;
var IsClientMobile = function() {
  if (CachedMobile == true || CachedMobile == false) return CachedMobile;
  console.log(navigator.userAgent);
  var check = false;
  (function(a){if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino/i.test(a)||/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(a.substr(0,4)))check = true})(navigator.userAgent||navigator.vendor||window.opera);
  CachedMobile = check;
  return check;
}

module.exports.PostToSlack = PostToSlack;
module.exports.getUrlParameter = getUrlParameter;
module.exports.SubmitCommandToServer = SubmitCommandToServer;
module.exports.Emojize = Emojize;
module.exports.EmojiKeysMatchingSubstr = EmojiKeysMatchingSubstr;
module.exports.IsClientMobile = IsClientMobile;