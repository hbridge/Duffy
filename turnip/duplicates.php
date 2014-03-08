<?

// $output[$num] = array($filename1, $filename2)
function loadFile($filename) {

	$output = array();
	// Open the file
	$fp = @fopen($filename, 'r');
	// Add each line to an array
	if ($fp) {
		$file = explode("\n", fread($fp, filesize($filename)));

		$lines = array();
	   	foreach ($file as $line) {
	       	array_push($lines, explode(",", $line));
	   	}

	   	foreach ($lines as $line) {
	   		$num = $line[0];
	   		$filename1 = $line[1];
	   		$filename2 = $line[2];

	   		$output[$num] = array($filename1, $filename2);
	   	}
	} else {
		echo "Couldn't find " . $filename;
	}
	return $output;

}

function findPhotoArrays($lowNum, $highNum, $dupsData) {
	$output = array();
	foreach($dupsData as $num => $filenameArray) {
		if ($num > $lowNum) {
			$output[$num] = $filenameArray;
		}

		if ($num > $highNum) {
			return $output;
		}
	}
	return false;
}

function getImageUrl($filename) {
	$thumb = substr(trim($filename), 0, -4) . "_thumb.jpg";
	return "henry/" . $thumb;
}

function getDupRowHtml($num, $filenameArray) {
	$html = "";

	$html .= "<table width='100%'><tr>";
	$html .= "<td width='100px'>" . $num . "</td>";
	$html .= "<td width='200px'><img src='" . getImageUrl($filenameArray[0]) . "'/></td>";
	$html .= "<td><img src='" . getImageUrl($filenameArray[1]) . "'/></td>";
	$html .= "</tr></table>";

	return $html;
}

$dupData = loadFile("henry_dups.csv");

// -------------------------

$userQuery = strtolower(trim(urldecode($_GET["q"])));

if ($userQuery != "") {
	header('Content-Type: application/json; charset=UTF-8');

	$output = array();

	$userNumbers = explode(" ", $userQuery);

	if (count($userNumbers) > 1 && is_numeric($userNumbers[0]) && is_numeric($userNumbers[1])) {
		$lowNum = $userNumbers[0];
		$highNum = $userNumbers[1];

		$dupDataFiltered = findPhotoArrays($lowNum, $highNum, $dupData);

		foreach ($dupDataFiltered as $num => $filenameArray) {
			array_push($output, getDupRowHtml($num, $filenameArray));
		}
	}

	echo json_encode($output);
} else {
//  --------------------------
?>


<!DOCTYPE html> 
<html> 

<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1"> 
	<title>Auto-categorized photo viewer</title> 
	<link rel="stylesheet" href="//code.jquery.com/mobile/1.4.0/jquery.mobile-1.4.0.min.css" />
	<script src="//code.jquery.com/jquery-1.10.2.min.js"></script>
	<script src="//code.jquery.com/mobile/1.4.0/jquery.mobile-1.4.0.min.js"></script>
	

	<script>
		$( document ).on( "pageinit", "#browseDups", function() {
			$( "#autocomplete" ).on( "filterablebeforefilter", function ( e, data ) {
				var $ul = $( this ),
					$input = $( data.input ),
					value = $input.val(),
					html = "";
				$ul.html( "" );
				if ( value  ) {
					$ul.html( "<li><div class='ui-loader'><span class='ui-icon ui-icon-loading'></span></div></li>" );
					$ul.listview( "refresh" );
					console.log("sending...");
					$.ajax({
						//url: "http://gd.geobytes.com/AutoCompleteCity",
						url: "duplicates.php",
						dataType: "json",
						crossDomain: true,
						data: {
							q: $input.val()
						}
					})
					.then( function ( response ) {
						console.log(response);
						$.each( response, function ( i, val ) {
							html += "<li>" + val + "</li>";
						});
						$ul.html( html );
						$ul.listview( "refresh" );
						$ul.trigger( "updatelayout");
					});
				}
			});
		});
    </script>
	<style>
	html, body { padding: 0; margin: 0; }
	html, .ui-mobile, .ui-mobile body {
    	height: 1035px;
	}
	.ui-mobile, .ui-mobile .ui-page {
    	min-height: 1035px;
	}
	.ui-content{
		padding:10px 15px 0px 15px;
	}
	.ui-filter-inset {
		margin-top: 0;
	}
	</style>
</head>

<body>
	
<div data-role="page" id="browseDups" style="max-height:1040px; min-height:1040px;">
	<div role="main" class="ui-content">
    	<div data-demo-html="true" data-demo-js="true" data-demo-css="true">
			<ul id="autocomplete" data-role="listview" data-inset="true" data-filter="true"
			data-filter-placeholder="Find a photo..." data-filter-theme="a"></ul>
		</div>
	</div>
</div>


</body>
</html>
<?
}
?>