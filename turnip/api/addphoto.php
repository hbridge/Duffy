<?
$success = false;
$output = "";

if ($_POST['userId']) {
	$userId = $_POST['userId'];
} else {
	$userId = $_SERVER['REMOTE_ADDR'];
}

$uploaddir = realpath('./') . '/../uploads/' . $userId . '/';

if (!file_exists($uploaddir)) {
    mkdir($uploaddir, 0777);
}

foreach ($_FILES as $key => $fileinfo) {
	$uploadfile = $uploaddir . basename($_FILES[$key]['name']);

	if (move_uploaded_file($_FILES[$key]['tmp_name'], $uploadfile)) {
    	$success = true;
	} else {
		$output .= 'Error with file upload.  Debug info:';
		$output .= print_r($_FILES, true);
		$output .= print_r($_POST, true);
	}
}



// -------   OUTPUT
header('Content-Type: application/json; charset=UTF-8');

$reply = array();
$reply['result'] = $success;
$reply['debug'] = $output;

echo json_encode($reply);
?>