jQuery(document).ready(function ($){
	init();

	function init(){
		// display stuff	
		add_msg_tab_keeper();
		add_msg_tab_user();
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
	}
	function form_middle_success(){
		$('#hp_signup_middle').addClass('form_success');	
		$("#hp_signup_middle .submit_btn").prop('value', 'Check Your Phone!');	

	}


	// ANIMATE THE CONVERSATION
	$('.convo').each(function(i){
		// first hide the text
		
		$(this).find('.msg_text').parent().prepend('<div class="msg_text_preload">...</div>');
		$(this).find('.msg_text').hide();



		// then fade in the message
		$(this).delay((i++) * 1800).fadeIn("fast",function(){
			// when fadeIn completes fadeOut the preloader elipses 
			// show the text
			$(this).find('.msg_text_preload').delay(300).fadeOut(10);
			//$(this).find('.msg_text').delay(300).typewriter({'speed':300});

			$(this).find('.msg_text').delay(0).delay(300).slideDown(300);
		});


	});

	// SET COOKIE SO DON'T SHOW CONVO AGAIN



}); // end jQuery

