<?

function startsWith($haystack, $needle)
{
    return $needle === "" || strpos($haystack, $needle) === 0;
}

function getRating($url, $classNameForRating, $urlObjects) {
	$obj = $urlObjects[$url];

	foreach ($obj['results'] as $className => $rating) {
		if ($className == $classNameForRating) {
			return $rating;
		}
	}
	return 0;
}

function getRankingScore($userSearchQuery, $url, $urlObjects, $matchReasonArray) {
	$score = 0;

	$obj = $urlObjects[$url];

	foreach ($matchReasonArray as $matchArray) {
		$rating = getRating($url, $matchArray['className'], $urlObjects);

		$multiplier = 1;

		if ($matchArray['type'] == 'directFull') {
			$multiplier = 5;
		} else if ($matchArray['type'] == 'directPart') {
			$multiplier = 1;
		} else if ($matchArray['type'] == 'alt') {
			$multiplier = 3;
		}

		$score += $rating * $multiplier;
	}

	return $score;
}

function getResultsForQuery($userQuery, $indexedUrls, $altWords) {
	$resultUrls = array();
	foreach (explode(' ', $userQuery) as $searchWord) {
		foreach ($indexedUrls as $className => $urlArray) {
			if (startsWith($className, $searchWord)) {
				foreach ($urlArray as $url) {
					if (!array_key_exists($url, $resultUrls)) {
						$resultUrls[$url] = array();
					}
					if ($className == $searchWord) {
						array_push($resultUrls[$url], array('url' => $url, 'className' => $className, 'type' => 'directFull'));
					} else {
						array_push($resultUrls[$url], array('url' => $url, 'className' => $className, 'type' => 'directPart'));
					}
				}
			}
		}

		foreach ($altWords as $altWord => $classNameArray) {
			if ($altWord == $searchWord) {
				foreach ($classNameArray as $className) {
					if (array_key_exists($className, $indexedUrls)) {
						foreach ($indexedUrls[$className] as $url) {
							if (!array_key_exists($url, $resultUrls)) {
								$resultUrls[$url] = array();
							}
							array_push($resultUrls[$url], array('url' => $url, 'className' => $className, 'type' => 'alt'));
						}
					}
				}
			}
		}
	}
	return $resultUrls;
}

function getOutputHtmlList($resultUrls, $urlObjects, $rankings){
	$output = array();
	foreach ($resultUrls as $url => $matchReasonsArray) {
		$obj = $urlObjects[$url];

		$html = "";
		$html .= '<a href="' . $obj['url'] . '" class="link-line"><img src="' . $obj['thumb'] . '">';
		$html .= '<table class="class-table">';

		foreach ($obj['results'] as $resultClassName => $rating) {
			$html .= "<tr>";

			$html .= '<td>' . $resultClassName . '</td>';
			$html .= '<td>' . $rating . '</td>';

			$html .= "</tr>";
		}
		$html .= "</table>";

		$html .= '<span class="ui-li-count">' . $rankings[$url] . '</span></a>' . "\n";

		array_push($output, $html);
	}

	return $output;
}

function cmpWithRanking($a, $b) {
	global $rankings;

	$aScore = $rankings[$a[0]['url']];
	$bScore = $rankings[$b[0]['url']];

	return $aScore < $bScore;
}

$altWordsFilename = "alt_words.csv";



// Open the file
$altWordsFp = @fopen($altWordsFilename, 'r'); 

// $indexedUrls[$class] = array($url, ...)
$indexedUrls = array();

// $altWords[$altWord] = array($className, ...)
$altWords = array();

// $thumbs[$url] => $thumbUrl
$thumbs = array();

// $urlObjects[$url] = array('url' => $url, 'results' => array(className => rating, ...), 'thumb' => $thumb_url)
$urlObjects = array();

// $rankings[$url] = $rating
$rankings = array();


if (!$_GET['userId']) {
	echo "Please put the userId param into the URL";
	exit;
} else {
	$userId = $_GET['userId'];
}


$dataFilename = "user_data/" . $userId . "/" . $userId . ".csv";
$thumbsBaseDir = "user_data/" . $userId . "/photos/";

// Open the file
$fp = @fopen($dataFilename, 'r');

// Add each line to an array
if ($fp) {
	$file = explode("\n", fread($fp, filesize($dataFilename)));

	$lines = array();
   	foreach ($file as $line) {
       	array_push($lines, explode(",", $line));
   	}

   	// Kill first line
	unset($lines[0]);

   	foreach ($lines as $line) {
		$obj = array();
		$url = $line[0];
		$obj['url'] = $url;
		$obj['results'] = array();
		// For each class
		for ($x = 1; $x < 6; $x++) {
			$classAndRating = explode(" ", trim($line[$x]));
			$className = strtolower($classAndRating[0]);
			$rating = trim($classAndRating[1], "()");

			$filename = substr($url,0, -4) . "_thumb.jpg";
			$thumb = $thumbsBaseDir. "/" . $filename;

			$thumbs[$url] = $thumb;

			$obj['results'][$className] = $rating;
			$obj['thumb'] = $thumb;


			if (!array_key_exists($className, $indexedUrls)) {
				$indexedUrls[$className] = array();
			}
			array_push($indexedUrls[$className], $url);
		}
		$urlObjects[$url] = $obj;
	}

	foreach ($indexedUrls as $urls) {
		array_unique($urls);
	}
}



if ($altWordsFp) {
	$file = explode("\n", fread($altWordsFp, filesize($altWordsFilename)));

	$lines = array();
	foreach ($file as $line) {
		array_push($lines, explode(",", $line));
	}

	foreach ($lines as $line) {
		$className = strtolower(trim($line[0]));

		$numWords = count($line);
		for ($x = 1; $x < $numWords; $x++) {
			$altWord = $line[$x];
			if (!array_key_exists($altWord, $altWords)) {
				$altWords[$altWord] = array();
			}
			array_push($altWords[$altWord], $className);
		}
	}
}

foreach ($indexedUrls as $className => $urlArray) {
	$classTerms = explode("_", $className);
	foreach ($classTerms as $term) {
		if (!array_key_exists($term, $altWords)) {
			$altWords[$term] = array();
		}
		array_push($altWords[$term], $className);
	}
}

// START PAGE LOGIC

$userQuery = strtolower(trim(urldecode($_GET["q"])));

if ($userQuery != "") {
	header('Content-Type: application/json; charset=UTF-8');

	// Get starting guesses for images we might want
	// $resultUrls[$url] => array('url' => $url, className' => $className, 'type' => 'direct' or 'alt')
	$resultUrls = getResultsForQuery($userQuery, $indexedUrls, $altWords);

	// Get rankings for each image
	foreach ($resultUrls as $url => $matchReasonsArray) {
		$rankings[$url] = getRankingScore($userQuery, $url, $urlObjects, $matchReasonsArray);
	}

	// Sort them based on the rankings
	uasort($resultUrls, "cmpWithRanking");

	// Grab the top 10
	$resultUrls = array_slice($resultUrls, 0, 10);

	// get the html to be outputed by JSON
	$output = getOutputHtmlList($resultUrls, $urlObjects, $rankings);

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
		$( document ).on( "pageinit", "#searchPhoto", function() {
			$( "#autocomplete" ).on( "filterablebeforefilter", function ( e, data ) {
				var $ul = $( this ),
					$input = $( data.input ),
					value = $input.val(),
					html = "";
				$ul.html( "" );
				if ( value && value.length > 2 ) {
					$ul.html( "<li><div class='ui-loader'><span class='ui-icon ui-icon-loading'></span></div></li>" );
					$ul.listview( "refresh" );
					console.log("sending...");
					$.ajax({
						//url: "http://gd.geobytes.com/AutoCompleteCity",
						url: "search.php",
						dataType: "json",
						crossDomain: true,
						data: {
							userId: "<? echo $userId ?>",
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
	
<div data-role="page" id="searchPhoto" style="max-height:1040px; min-height:1040px;">
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