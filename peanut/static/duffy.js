/* 
Duffy.js - common js functions used in duffy webviews 

Created by: Aseem Sood
Date: 6/11/2014
*/


/*
Processes our standard json format for type=photo
*/

function addPhoto(photo, userList, photoType, isLocked, isThird){
	// photoType = 0: regular photo
	// photoType = 1: clusterBottom

	thumbUrl = "/user_data/" + photo.user_id + "/" + photo.id + "-thumb-156.jpg";
	fullUrl = "/user_data/" + photo.user_id + "/" + photo.id+ ".jpg";
	onErrorStr='this.onerror=null;this.src="' + thumbUrl +'";';
	lockedStr = isLocked ? 'ui-locked' : 'ui-notlocked';

	if (isLocked){
		photoType = 1;
	}

	if (userList) {
		if (getURLParameter("user_id") != photo.user_id) {
			userList.push(photo.display_name);
		}
	}
	if (!photoType) {
		var photoType = 0; // means regular photo
	}
	if (!isThird) {
		var thirdStr = '';
	}
	else {
		var thirdStr = 'is-third';
	}	
	if (photo.display_name) {
		title = cleanName(photo.display_name);
	}
	else {
		title = photo.dist;
	}

	switch (photoType) {
		case 1:
			img = "<img class='l " + lockedStr + "' width='78.5px' src='" + thumbUrl + "'/>";		
			html = "<div class='image image-thumb " + thirdStr + "' title='" + title +"' r='" + fullUrl + "'>" + img + "</div>";
			break;
		default: // covers case 0
			img = "<img class='l " + lockedStr + "' width='320px' onError='" + onErrorStr + "' src='" + fullUrl + "'/>";		
			html = "<div class='image' title='" + title +"' r='" + fullUrl + "'>" + img + "</div>";
			break;
	}
	return html;
}

/*
Processes our standard json type=cluster
*/

function addCluster(photos, userList, isLocked){
	html = "";
	$.each(photos, function(i, photo) {
		if (photo.type == 'photo'){
			if (i == 0 && !isLocked) { // meaning first one in a cluster
				html += addPhoto(photo, userList, 0, isLocked);
			}
			else {
				if (i % 4 == 0) {
					html += addPhoto(photo, userList, 1, isLocked, true);					
				}
				else {
					html += addPhoto(photo, userList, 1, isLocked, false);
				}
			}
		}
		else {
			console.log("unexpected type within cluster");
		}
	});
	return html;
}

/*
Processes our standard json type=docstack
*/

function addDocstack(photos){
	html = "";
	html += addPhoto(null, 3, photos.length);
	$.each(photos, function(i, photo) {
		if (photo.type == 'photo'){
			html += addPhoto(photo, 2);
		}
		else {
			console.log("unexpected type within docstack");
		}
	});
	return html;
}

/*
	click handler for clusters and images
*/
function imageClickHandler(clusters){
	clusters.click(function() {
		if (!($(this).children('img').hasClass('ui-locked'))){
			window.location.href = $(this).attr('r')+'?photoList='+photoList($(this)).toString(); //TODO: Need to update link
		}
	});
}

/*
Cleans names of apostrophes and if multiple words, picks the first one
*/
function cleanName(str) {
	if (str.indexOf(' ') > -1) {
		str = str.substr(0, str.indexOf(' '));
	}
	if (str.indexOf("'") > -1) {
		str = str.substr(0, str.indexOf("'"));
	}
	if (str.indexOf("’") > -1) {
		str = str.substr(0, str.indexOf("’"));
	}
	return str;
}


/*
Gets a parameter in the URL
*/

function getURLParameter(name) {
	return decodeURI(
		(RegExp(name + '=' + '(.+?)(&|$)').exec(location.search)||[,null])[1]
	);
}

/*
Gives an array of other photos in this section
*/

function photoList(photo) {
	var pArray = [];
	// find the section
	parent = photo.parent();
	parent.find('div.image').each(function(){
		if (!($(this).hasClass('hidden'))) {
			pArray.push($(this).attr('r').replace('/user_data/', ''));
		}
	});
	return pArray;
}	