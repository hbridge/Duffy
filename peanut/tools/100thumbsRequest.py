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

				dataArray.append(data)
			count += 1

	return (files, dataArray)

def main(argv):
	url = "http://asood123.no-ip.biz:8000/api/photos/bulk/"
	(files, dataArray) = getFilesAndData("/Users/derek/Dropbox/Projects/Duffy/thumbs/", 100)

	payload = {'bulk_photos': json.dumps(dataArray)}
	r = requests.post(url, files=files, data=payload)

	print r.text

if __name__ == "__main__":
	main(sys.argv[1:])