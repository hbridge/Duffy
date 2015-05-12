jQuery(document).ready(function ($){
	init();

	function init(){
		// display stuff
		add_msg_tab_keeper();
		add_msg_tab_user();
		$("#hp_signup_top").one('submit', function(){
			event.preventDefault();
			submitClicked(form_top_success);
		});
		$("#hp_signup_middle").one('submit', function(){
			event.preventDefault();
			submitClicked(form_middle_success);
		});
	}

	/* MESSAGE STYLE ================================== */
	function add_msg_tab_user(){
		$('.user_msg').append('<div class="user_tab"><svg width="24px" height="19px" viewBox="0 0 24 19" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sketch="http://www.bohemiancoding.com/sketch/ns"><g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" sketch:type="MSPage"><g sketch:type="MSArtboardGroup" transform="translate(-757.000000, -414.000000)" fill="#4CD964"><path d="M759.04389,428.533517 C754.507813,426.445313 759.043889,427.259766 759.043889,427.259766 L766.575196,417.197266 C766.575196,417.197266 768.5,412.8125 768.5,415.001 C768.499998,427.935 780.72,433.001 780.501,433.001 C771.712381,433.001 763.579966,430.62172 759.04389,428.533517 Z" sketch:type="MSShapeGroup"></path></g></g></svg></div>');
	}
	function add_msg_tab_keeper(){
		$('.keeper_msg').append('<div class="keeper_tab"><svg width="28px" height="34px" viewBox="0 0 28 34" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:sketch="http://www.bohemiancoding.com/sketch/ns"><g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" sketch:type="MSPage"><g sketch:type="MSArtboardGroup" transform="translate(-243.000000, -1103.000000)" fill="#E5E5EA"><path d="M269.203809,1129.10281 C272.230468,1126.68164 269.203809,1125.83762 269.203809,1124.71289 C269.203809,1124.71289 265.292511,1119.0236 264.950195,1118.501 C259.702349,1110.48933 255.501,1103.5 255.501,1103.5 L255.501,1118.501 C255.501,1131.434 243.283,1136.501 243.501,1136.501 C254.652721,1136.501 266.17715,1131.52397 269.203809,1129.10281 Z" sketch:type="MSShapeGroup"></path></g></g></svg></div>');
	}

	/* FORM APPEARANCE FUNCTIONS ================================== */
	function form_top_error(){
		$('#hp_signup_top').append('<div class="form_error_msg">Uh oh, something’s wrong. Try that # again</div>');
		$('#hp_signup_top').addClass('form_error');
	}
	function form_middle_error(){
		$('#hp_signup_middle').append('<div class="form_error_msg">Uh oh, something’s wrong. Try that # again</div>');
		$('#hp_signup_middle').addClass('form_error');
	}

	function form_top_success(){
		$('#hp_signup_top').addClass('form_success');
		$("#hp_signup_top .submit_btn").prop('value', 'Check Your Phone!');
		fbpixel();
	}
	function form_middle_success(){
		$('#hp_signup_middle').addClass('form_success');
		$("#hp_signup_middle .submit_btn").prop('value', 'Check Your Phone!');
		fbpixel();
	}


	if (!getUrlParameter("showall") == true) {
			$('.msg').each(function(){
			$(this).hide();
		});
	}


	showNextConvo();
	function showNextConvo() {
		$('.convo').each(function(i){
			if ($(this).is(":visible")) return;

			// first hide the text
			$(this).find('.msg_text').parent().prepend('<div class="msg_text_preload">...</div>');
			$(this).find('.msg_text').hide();

			$(this).delay(500).fadeIn("fast",function(){
				scrollToConvo($(this));
				//when fadeIn completes fadeOut the preloader elipses
				// show the text

				// calculate the typing time
				animation_time = 300;
				typing_time_multiplier = 20;
				next_message_multiplier = 200;
				html = $(this).find('.msg_text').html();
				word_count = 1;
				if (html)
					words = html.split(" ")
					word_count = words.length
					typing_time = typing_time_multiplier * word_count;

				//$(this).find('.msg_text_preload').delay(typing_time).fadeOut(300);

				setTimeout(function(convo){
					$(convo).find('.msg_text_preload').delay(typing_time).html(html);
				}, typing_time, this);


				setTimeout(function(){
					showNextConvo();
				}, typing_time + next_message_multiplier * word_count);
			});
			return false;
		});
	}


	disable_autoscroll = true;
	// $(window).scroll(function(e) {
	// 	console.log(e);
	//     if (e.offset < 0) {
	//     	console.log("scroll up");
	//     	disable_autoscroll = true;
	//     }
	// });

	function scrollToConvo(element){
		if (disable_autoscroll) return;
	    var offset = element.offset().top - 20;
	    $('html,body').animate({scrollTop: offset}, 1000);
	}

	function fbpixel() {
  		var _fbq = window._fbq || (window._fbq = []);
  		if (!_fbq.loaded) {
    		var fbds = document.createElement('script');
    		fbds.async = true;
    		fbds.src = '//connect.facebook.net/en_US/fbds.js';
    		var s = document.getElementsByTagName('script')[0];
    		s.parentNode.insertBefore(fbds, s);
    		_fbq.loaded = true;
  		}
  		window._fbq = window._fbq || [];
		window._fbq.push(['track', '6027664081971', {'value':'0.00','currency':'USD'}]);
  	}



	// SET COOKIE SO DON'T SHOW CONVO AGAIN

	function submitClicked(FuncOnSuccess){

		value = $('#tel-number').val();
		if (value.length < 10 || value.indexOf("5555") != -1) {
			alert("Please enter a valid 10-digit phone number");
		}
		else {
			url = 'http://prod.strand.duffyapp.com/smskeeper/signup_from_website';
			sourceVal = getUrlParameter('source');
			if (sourceVal.length == 0) {
				sourceVal = 'default';
			}
			$.ajax({
     			url: url,
     			type: 'get',
     			dataType: 'jsonp',
     			jsonpCallback: 'jsonCallback',
     			data: { phone_number: $('#tel-number').val(), source: sourceVal},
     			success: function(data) {
     				FuncOnSuccess();
     			}
 			});
		}
	}

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
}); // end jQuery

