<?
$host = "127.0.0.1";
$port = 5555;
// No Timeout 
set_time_limit(10);

function sendReply($result, $message) {
	$reply = array();
	$reply['result'] = $result;
	$reply['debug'] = $message;

	echo json_encode($reply);
	exit();
}

$success = true;

$socket = socket_create(AF_INET, SOCK_STREAM, 0) or sendReply(false, "Could not create socket");

$result = socket_connect($socket, $host, $port) or sendReply(false, "Could not connect to server");

socket_write($socket, $message, strlen($message)) or sendReply(false, "Could not send data to server");

socket_close($socket);

sendReply(true, "");
?>