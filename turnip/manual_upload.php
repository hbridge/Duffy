<html>
<head>
<title>File Upload Form</title>
</head>
<body>
This form allows you to upload a photo for a user.<br>
<form action="api/addphoto.php" method="post" enctype= "multipart/form-data"><br>
UserID: <input type="text" name="userId"><br/>
Type (or select) Filename: <input type="file" name="uploadFile"><br/>
<input type="submit" value="Upload File">
</form>
</body>
</html>