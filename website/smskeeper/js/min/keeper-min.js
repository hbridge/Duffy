jQuery(document).ready(function($){function e(){n(),t(),$("#hp_signup_top").one("submit",function(){event.preventDefault(),u(s)}),$("#hp_signup_middle").one("submit",function(){event.preventDefault(),u(l)}),$("#hp_skip").one("click",function(){event.preventDefault(),r(),$("#hp_skip").hide()})}function t(){$(".user_msg").append('<div class="user_tab"><svg width="24px" height="19px" viewBox="0 0 24 19" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sketch="http://www.bohemiancoding.com/sketch/ns"><g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" sketch:type="MSPage"><g sketch:type="MSArtboardGroup" transform="translate(-757.000000, -414.000000)" fill="#4CD964"><path d="M759.04389,428.533517 C754.507813,426.445313 759.043889,427.259766 759.043889,427.259766 L766.575196,417.197266 C766.575196,417.197266 768.5,412.8125 768.5,415.001 C768.499998,427.935 780.72,433.001 780.501,433.001 C771.712381,433.001 763.579966,430.62172 759.04389,428.533517 Z" sketch:type="MSShapeGroup"></path></g></g></svg></div>')}function n(){$(".keeper_msg").append('<div class="keeper_tab"><svg width="28px" height="34px" viewBox="0 0 28 34" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sketch="http://www.bohemiancoding.com/sketch/ns"><g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" sketch:type="MSPage"><g sketch:type="MSArtboardGroup" transform="translate(-243.000000, -1103.000000)" fill="#E5E5EA"><path d="M269.203809,1129.10281 C272.230468,1126.68164 269.203809,1125.83762 269.203809,1124.71289 C269.203809,1124.71289 265.292511,1119.0236 264.950195,1118.501 C259.702349,1110.48933 255.501,1103.5 255.501,1103.5 L255.501,1118.501 C255.501,1131.434 243.283,1136.501 243.501,1136.501 C254.652721,1136.501 266.17715,1131.52397 269.203809,1129.10281 Z" sketch:type="MSShapeGroup"></path></g></g></svg></div>')}function o(){$("#hp_signup_top").append('<div class="form_error_msg">Uh oh, something’s wrong. Try that # again</div>'),$("#hp_signup_top").addClass("form_error")}function i(){$("#hp_signup_middle").append('<div class="form_error_msg">Uh oh, something’s wrong. Try that # again</div>'),$("#hp_signup_middle").addClass("form_error")}function s(){$("#hp_signup_top").addClass("form_success"),$("#hp_signup_top .submit_btn").prop("value","Check Your Phone!"),d()}function l(){$("#hp_signup_middle").addClass("form_success"),$("#hp_signup_middle .submit_btn").prop("value","Check Your Phone!"),d()}function r(){console.log("Showing all"),ShowAllClicked=!0,$(".msg").each(function(){$(this).show()})}function a(){$(".convo").each(function(e){return console.log("showall "+ShowAllClicked),$(this).is(":visible")||1==ShowAllClicked?void 0:($(this).find(".msg_text").parent().prepend('<div class="msg_text_preload">...</div>'),$(this).find(".msg_text").hide(),$(this).delay(500).fadeIn("fast",function(){p($(this)),animation_time=300,typing_time_multiplier=20,next_message_multiplier=200,html=$(this).find(".msg_text").html(),word_count=1,html&&(words=html.split(" "),word_count=words.length),typing_time=typing_time_multiplier*word_count,setTimeout(function(e){$(e).find(".msg_text_preload").delay(typing_time).html(html)},typing_time,this),setTimeout(function(){a()},typing_time+next_message_multiplier*word_count)}),!1)})}function p(e){if(!disable_autoscroll){var t=e.offset().top-20;$("html,body").animate({scrollTop:t},1e3)}}function d(){var e=window._fbq||(window._fbq=[]);if(!e.loaded){var t=document.createElement("script");t.async=!0,t.src="//connect.facebook.net/en_US/fbds.js";var n=document.getElementsByTagName("script")[0];n.parentNode.insertBefore(t,n),e.loaded=!0}window._fbq=window._fbq||[],window._fbq.push(["track","6027664081971",{value:"0.00",currency:"USD"}])}function u(e){value=$("#tel-number").val(),value.length<10||-1!=value.indexOf("5555")?alert("Please enter a valid 10-digit phone number"):(url="http://prod.strand.duffyapp.com/smskeeper/signup_from_website",sourceVal=c("source"),0==sourceVal.length&&(sourceVal="default"),$.ajax({url:url,type:"get",dataType:"jsonp",jsonpCallback:"jsonCallback",data:{phone_number:$("#tel-number").val(),source:sourceVal},success:function(t){e()}}))}function c(e){for(var t=window.location.search.substring(1),n=t.split("&"),o=0;o<n.length;o++){var i=n[o].split("=");if(i[0]==e)return i[1]}return""}e(),ShowAllClicked=!1,1==c("showall")&&r(),a(),disable_autoscroll=!0});