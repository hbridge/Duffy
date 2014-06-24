import requests
import json
import sys, os


def getFilesAndData(rootdir, num):
	count = 0

	files = dict()
	dataArray = list()

	for subdir, dirs, filenames in os.walk(rootdir):
		for filename in filenames:
			if count == num:
				return (files, dataArray)
			else:
				keyName = "key" + str(count)
				filepath = os.path.join(rootdir, filename)
				files[keyName] = open(filepath, "r")

				data = dict()
				data["file_key"] = keyName
				data["user"] = 1
				data["metadata"] = '{"{Exif}": {"PixelXDimension": 3264, "LensSpecification": [4.12, 4.12, 2.2, 2.2], "Flash": 0, "SceneCaptureType": 0, "MeteringMode": 5, "ExifVersion": [2, 2, 1], "ExposureProgram": 2, "ShutterSpeedValue": 4.099890230515917, "ColorSpace": 1, "PixelYDimension": 2448, "DateTimeDigitized": "2013:10:21 18:07:08", "ApertureValue": 2.275007124536905, "SceneType": 1, "LensModel": "iPhone 5s back camera 4.12mm f/2.2", "BrightnessValue": 0.2157125620056308, "WhiteBalance": 0, "SensingMethod": 2, "FNumber": 2.2, "CustomRendered": 2, "DateTimeOriginal": "2013:10:21 18:07:08", "FocalLength": 4.12, "SubsecTimeOriginal": "323", "ExposureMode": 0, "ComponentsConfiguration": [1, 2, 3, 0], "SubsecTimeDigitized": "323", "ISOSpeedRatings": [320], "ExposureTime": 0.05882352941176471, "FocalLenIn35mmFilm": 30, "FlashPixVersion": [1, 0], "LensMake": "Apple"}, "Orientation": 6, "ColorModel": "RGB", "{DFCameraRollExtras}": {"DateTimeCreated": "2013:10:21 21:07:08"}, "{ExifAux}": {"Regions": {"HeightAppliedTo": 2448, "WidthAppliedTo": 3264, "RegionList": [{"Timestamp": 2147483647, "AngleInfoYaw": 0, "Height": 0.1875, "Width": 0.140625, "AngleInfoRoll": 270, "Y": 0.497753, "X": 0.254442, "FaceID": 8, "Type": "Face", "ConfidenceLevel": 250}]}}, "DPIHeight": 72, "Depth": 8, "{TIFF}": {"YResolution": 72, "ResolutionUnit": 2, "Orientation": 6, "Make": "Apple", "DateTime": "2013:10:21 18:07:08", "XResolution": 72, "Model": "iPhone 5s", "Software": "7.0.2"}, "PixelWidth": 3264, "{GPS}": {"ImgDirection": 99.69675090252707, "AltitudeRef": 0, "TimeStamp": "01:07:07", "Altitude": 7.615844544095665, "Longitude": 122.4123466666667, "DateStamp": "2013:10:21", "Latitude": 37.75908333333334, "ImgDirectionRef": "T", "LongitudeRef": "W", "LatitudeRef": "N"}, "{MakerApple}": {"10": 2, "1": 0, "3": {"epoch": 0, "flags": 1, "timescale": 1000000000, "value": 75742864678583}, "5": 194, "4": 1, "7": 1, "6": 184}, "PixelHeight": 2448, "DPIWidth": 72}'

				dataArray.append(data)
			count += 1

	return (files, dataArray)

def main(argv):
	url = "http://prod.duffyapp.com/api/photos/bulk/"
	(files, dataArray) = getFilesAndData("/Users/derek/Dropbox/Projects/Duffy/thumbs/", 100)

	payload = {'bulk_photos': json.dumps(dataArray)}
	r = requests.post(url, files=files, data=payload)

	print r.text

if __name__ == "__main__":
	main(sys.argv[1:])