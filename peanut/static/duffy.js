/* 
Duffy.js - common js functions used in duffy webviews 

Created by: Aseem Sood
Date: 6/11/2014
*/


/*
Processes our standard json format for type=photo
*/

function addPhoto(photo, userList, photoType, photosLength){
	// photoType = 0: regular photo
	// photoType = 1: clusterTop
	// photoType = 2: clusterBottom
	// photoType = 3: docStackTop
	if (photo) {
		thumbUrl = "/user_data/" + photo.user_id + "/" + photo.id + "-thumb-156.jpg";
		img = "<img class='l' height='78px' width='78px' src='" + thumbUrl + "'/>";
		fullUrl = "/strand/viz/images?user_id=" + photo.user_id + "&photo_id=" + photo.id;
		if (userList) {
			userList.push(photo.first_name);
		}
	}
	if (!photoType) {
		var photoType = 0; // means regular photo
	}
	if (!photosLength) {
		var photosLength = 1;
	}
	switch (photoType) {
		case 1:
			html = "<div class='image cluster' title='" + cleanName(photo.first_name) +"' r='" + fullUrl + "'>" + img + "<div class='ui-arrow-down'></div><div class='ui-img-ct text'>" + photosLength + "</div></div>";
			break;
		case 2:
			html = "<div class='image hidden' title='" + cleanName(photo.first_name) +"' r='" + fullUrl + "'>" + img + "</div>";
			break;
		case 3:
			img = "<img class='l' height='78px' width='78px' src='/static/docstack.png' />";
			html = "<div class='image cluster'>" + img + "<div class='ui-arrow-down'></div><div class='ui-img-ct text'>" + photosLength + "</div></div>";
			break;
		default: // covers case 0
			html = "<div class='image' title='" + cleanName(photo.first_name) +"' r='" + fullUrl + "'>" + img + "</div>";
			break;
	}
	return html;
}

/*
Processes our standard json type=cluster
*/

function addCluster(photos, userList){
	html = "";
	$.each(photos, function(i, photo) {
		if (photo.type == 'photo'){
			if (i == 0) { // meaning clusterTop
				html += addPhoto(photo, userList, 1, photos.length);
			}
			else {
				html += addPhoto(photo, userList, 2);
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
function clusterClickHandler(clusters){
	clusters.click(function() {
		if ($(this).hasClass('cluster')) {
			$(this).removeClass('cluster');
			$(this).children('div').addClass('hidden'); // hides white triangle and cluster size
			current = $(this).next();
			while (current.hasClass('hidden')){					
				current.show("fast");
				current.removeClass('hidden');
				current = current.next();
			}
		}
		else {
			window.location.href = $(this).attr('r'); //TODO: Need to update link
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
