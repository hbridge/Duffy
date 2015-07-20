if (!$) {
    $ = django.jQuery;
}

Number.prototype.padLeft = function(base,chr){
    var  len = (String(base || 10).length - String(this).length)+1;
    return len > 0? new Array(len).join(chr || '0')+this : this;
}

function approveEntry(id){
	// All of this makes me cry. Please tell me thiere's a better way to do dates in js
	var now = new Date();
	var now_utc = new Date(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),  now.getUTCHours(), now.getUTCMinutes(), now.getUTCSeconds());
    nowString = [now_utc.getFullYear(),
    	    (now_utc.getMonth()+1).padLeft(),
             now_utc.getDate().padLeft(),
               ].join('-') +' ' +
              [now_utc.getHours().padLeft(),
               now_utc.getMinutes().padLeft(),
               now_utc.getSeconds().padLeft()].join(':');
	$.ajax({
		url : '/smskeeper/entry/' + id + '/',
		type : 'PATCH',
		data : {"manually_check": 0, 'manually_approved_timestamp': nowString},
		success : function(response, textStatus, jqXhr) {
		    console.log("Entry Successfully Updated");
		},
		error : function(jqXHR, textStatus, errorThrown) {
		    // log the error to the console
		    console.log("The following error occured: " + textStatus, errorThrown);
		},
		complete : function() {
		    location.reload();
		}
		});

}
