/*
	General js functions used across bunch of pages
*/


function getCode(){
	pathname = window.location.pathname;
	lastToken = pathname.substr(pathname.lastIndexOf('/'));
	if (lastToken.indexOf('html') == -1 && lastToken.length > 5) {
		return lastToken.substr(1);
	}
	// Otherwise, return a new code
	return genCode()
}

/* 
Generates a 6 character code
*/
function genCode()
{
    var text = "";
    var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    for( var i=0; i < 6; i++ )
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
}	

function detectiPhone(){
	var ua = navigator.userAgent;
	if(ua.match(/iPhone/i)){
		return true;
	}
	return false;
}