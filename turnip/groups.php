<?
/*
Determines if we should show a particular image in a certain class.  Look to see if there's
a pretty sure guess (something with a rating above 30)...and if its not this class, then don't show
*/
function shouldShow($raw_ratings, $url, $classToTest) {
	foreach ($raw_ratings[$url] as $className => $rating) {
		if ($rating > 30 && $classToTest != $className) {
			return false;
		}
	}
	return true;
}

$filename = "aseem.csv";
// Open the file
$fp = @fopen($filename, 'r'); 

$lines = array();

// $classes[$]
$classes = array();

// $thumbs[$url] => $thumbUrl
$thumbs = array();

// $raw_ratings[$url][$className] => $rating
$raw_ratings = array();

// $sorted_photos[$className][$url] => $rating
$sorted_photos = array();

// Add each line to an array
if ($fp) {
   $file = explode("\n", fread($fp, filesize($filename)));

   foreach ($file as $line) {
       array_push($lines, explode(",", $line));
   }
}

// Kill first line
unset($lines[0]);

// Make classes unique
$classes = array_unique($classes);


foreach ($lines as $line) {
	// For each class
	for ($x = 1; $x < 6; $x++) {
		$classAndRating = explode(" ", trim($line[$x]));
		$className = $classAndRating[0];
		$rating = trim($classAndRating[1], "()");
		$url = $line[0];

		$filename = substr($line[0], 52, -4) . "_thumb.jpg";
		$thumb = "aseem/" . $filename;

		if (!array_key_exists($className, $sorted_photos)) {
			$sorted_photos[$className] = array();
		}
		$sorted_photos[$className][$url] = $rating;
		$thumbs[$url] = $thumb;

		if (!array_key_exists($url, $raw_ratings)) {
			$raw_ratings[$url] = array();
		}
		$raw_ratings[$url][$className] = $rating;
	}
}

// Clear out class-url entries where we think its a bad guess (top guess is >30)
// Clear out classes with 0 or 1 entries
foreach ($sorted_photos as $className => $urlToRatings) {
	foreach ($urlToRatings as $url => $rating) {
		if (!shouldShow($raw_ratings, $url, $className)) {
			unset($sorted_photos[$className][$url]);
		}
	}
	if (count($sorted_photos[$className]) < 2) {
		unset($sorted_photos[$className]);
	}
}

foreach ($sorted_photos as $className => $urlToRatings) {
	arsort($urlToRatings);
	$sorted_photos[$className] = $urlToRatings;
}
?>

<!DOCTYPE html> 
<html> 

<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1"> 
	<title>Auto-categorized photo viewer</title> 
	<link rel="stylesheet" href="//code.jquery.com/mobile/1.0/jquery.mobile-1.0.min.css" />
	<script src="http://code.jquery.com/jquery-1.6.4.min.js"></script>
	<script src="http://code.jquery.com/mobile/1.0/jquery.mobile-1.0.min.js"></script>


<style type="text/css">

.image-line {
	font-size: x-small;
	display:inline-block;
	height: 80px;
}

.image-list .ui-li {
	height: 80px;

}

.link-line {
	padding: 0px 0px 0px 100px  !important;
}

.class-table {
	font-size: xx-small;
	display:inline-block;
	height: 65px;
	border-spacing: 0px;
}

.sameClass {
	font-weight: bold !important;
}

.ui-btn-up-c {
	font-weight: normal;
}
</style>
</head> 

<body> 
<?
//	$classesToShow = array("church", "television");
	array_multisort(array_map('count', $sorted_photos), SORT_DESC, $sorted_photos);
	$classesToShow = array_keys($sorted_photos);
?>

<div data-role="page" id="index">

	<div data-role="header" data-theme="b">
		<h1>Aseem's photos (<? echo count($sorted_photos) ?>)</h1>
	</div><!-- /header -->

	<div data-role="content">
		<ul data-role="listview" data-inset="true" data-filter="true" data-filter-placeholder="Search photos...">
	<?
		foreach ($classesToShow as $className) {
			echo '<li><a href="#' . $className . '">' . $className . '</a><span class="ui-li-count">' . count($sorted_photos[$className]) . '</span></li>' . "\n";
		}
	?>
		</ul>
	</div><!-- /content -->

	
</div><!-- /page -->

<?
	foreach ($classesToShow as $className) {
?>
<div data-role="page" id="<? echo $className ?>">
	<div data-role="header" data-theme="b">
        <a href="#demo-intro" data-rel="back" data-icon="arrow-l" data-iconpos="notext" data-shadow="false" data-icon-shadow="false">Back</a>
        <h1><? echo $className ?></h1>
    </div><!-- /header -->

	<div data-role="content">
		<ul data-role="listview" data-inset="true" class="image-list">
		<?
			foreach ($sorted_photos[$className] as $url => $rating) {
				if (shouldShow($raw_ratings, $url, $className)) {
					echo '<li>';
				
					echo '<a href="' . $url . '" class="link-line"><img src="" data-lazy-src="' . $thumbs[$url] . '" class="lazy">';
					echo '<table class="class-table">';
					foreach ($raw_ratings[$url] as $thisClass => $classRating) {
						echo "<tr><td>";
						if ($className == $thisClass) {
							echo '<td class="sameClass">' . $thisClass . "</td>";
						} else {
							echo '<td>' . $thisClass . '</td>';
						}

						if ($className == $thisClass) {
							echo '<td class="sameClass">' . $classRating . '</td>';
						} else {
							echo '<td>' . $classRating . '</td>';
						}

						echo "</tr>";
					}
					echo "</table>";

					echo '<span class="ui-li-count">' . $rating . '</span></a></li>' . "\n";
				}
			}
		?>
		</ul>
	</div>
</div>

<?
	}
?>

</body>

<script>
		$('div').live('pagebeforeshow', function (event) {
 
		    $(this).find('img.lazy').each(function () {
		        $(this).attr('src', $(this).attr('data-lazy-src'));
		    });
		 
		});
	</script>
</html>