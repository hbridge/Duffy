/* 
Duffy.js - common js functions used in duffy webviews 

Created by: Aseem Sood
Date: 6/11/2014
*/


/*
Processes our standard json format for type=photo
*/

function addPhoto(userId, photo, photoType, photosLength){
	// photoType = 0: regular photo
	// photoType = 1: clusterTop
	// photoType = 2: clusterBottom
	// photoType = 3: docStackTop
	if (photo) {
		thumbUrl = "/user_data/" + userId + "/" + photo.id + "-thumb-156.jpg";
		img = "<img class='l' height='78px' width='78px' src='" + thumbUrl + "'/>";
	}
	if (!photoType) {
		var photoType = 0; // means regular photo
	}
	if (!photosLength) {
		var photosLength = 1;
	}
	switch (photoType) {
		case 1:
			html = "<div class='image cluster'>" + img + "<div class='ui-arrow-down'></div><div class='ui-img-ct text'>" + photosLength + "</div></div>";
			break;
		case 2:
			html = "<div class='image hidden'>" + img + "</div>";
			break;
		case 3:
			img = "<img class='l' height='78px' width='78px' src='/static/docstack.png' />";
			html = "<div class='image cluster'>" + img + "<div class='ui-arrow-down'></div><div class='ui-img-ct text'>" + photosLength + "</div></div>";
			break;
		default: // covers case 0
			html = "<div class='image'>" + img + "</div>";
			break;
	}
	return html;
}

/*
Processes our standard json type=cluster
*/

function addCluster(userId, photos){
	html = "";
	$.each(photos, function(i, photo) {
		if (photo.type == 'photo'){
			if (i == 0) { // meaning clusterTop
				html += addPhoto(userId, photo, 1, photos.length);
			}
			else {
				html += addPhoto(userId, photo, 2);
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

function addDocstack(userId, photos){
	html = "";
	html += addPhoto(userId, null, 3, photos.length);
	$.each(photos, function(i, photo) {
		if (photo.type == 'photo'){
			html += addPhoto(userId, photo, 2);
		}
		else {
			console.log("unexpected type within docstack");
		}
	});
	return html;
}

/*
Gets a parameter in the URL
*/

function getURLParameter(name) {
	return decodeURI(
		(RegExp(name + '=' + '(.+?)(&|$)').exec(location.search)||[,null])[1]
	);
}