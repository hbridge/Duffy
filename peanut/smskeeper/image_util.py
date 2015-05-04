from PIL import Image
import requests
import math
import cStringIO
import boto
import uuid

'''
	Gets a list of urls and generates a grid image to send back.
'''
def generateImageGridUrl(imageURLs):
	# if one url, just return that
	if len(imageURLs) == 1:
		return imageURLs[0]

	# if more than one, now setup the grid system
	imageList = list()

	imageSize = 300 #in pixels
	spacing = 3 #in pixels

	# fetch all images and resize them into imageSize x imageSize
	for imageUrl in imageURLs:
		resp = requests.get(imageUrl)
		img = Image.open(cStringIO.StringIO(resp.content))
		imageList.append(resizeImage(img, imageSize, True))

	if len(imageURLs) < 5:
		# generate an 2xn grid
		cols = 2
	else:
		# generate an 3xn grid
		cols = 3

	rows = int(math.ceil(float(len(imageURLs))/(float)(cols)))
	newImage = Image.new("RGB", (cols*imageSize+spacing*(cols-1), imageSize*rows+(rows-1)*spacing), "white")

	for i,image in enumerate(imageList):
		x = imageSize*(i % cols)+(i%cols)*spacing
		y = imageSize*(i/cols % cols)+(i/cols %cols)*spacing
		newImage.paste(image, (x,y,x+imageSize,y+imageSize))

	return saveImageToS3(newImage)


def moveMediaToS3(mediaUrlList):

	conn = boto.connect_s3('AKIAJBSV42QT6SWHHGBA', '3DjvtP+HTzbDzCT1V1lQoAICeJz16n/2aKoXlyZL')
	bucket = conn.get_bucket('smskeeper')
	newUrlList = list()

	for mediaUrl in mediaUrlList:
		resp = requests.get(mediaUrl)
		media = cStringIO.StringIO(resp.content)

		# Upload to S3
		keyStr = uuid.uuid4()
		key = bucket.new_key(keyStr)
		key.set_contents_from_string(media.getvalue())
		newUrlList.append('https://s3.amazonaws.com/smskeeper/'+ str(keyStr))

	return newUrlList

def saveImageToS3(img):
	conn = boto.connect_s3('AKIAJBSV42QT6SWHHGBA', '3DjvtP+HTzbDzCT1V1lQoAICeJz16n/2aKoXlyZL')
	bucket = conn.get_bucket('smskeeper')

	outIm = cStringIO.StringIO()
	img.save(outIm, 'JPEG')

	# Upload to S3
	keyStr = "grid-" + str(uuid.uuid4()) + '.jpeg'
	key = bucket.new_key(keyStr)
	key.set_contents_from_string(outIm.getvalue())
	return 'https://s3.amazonaws.com/smskeeper/'+ str(keyStr)

"""
	Does image resizes and creates a new file (JPG) of the specified size
"""
def resizeImage(im, size, crop):

	#calc ratios and new min size
	wratio = (size/float(im.size[0])) #width check
	hratio = (size/float(im.size[1])) #height check

	if (hratio > wratio):
		newSize = hratio*im.size[0], hratio*im.size[1]
	else:
		newSize = wratio*im.size[0], wratio*im.size[1]
	im.thumbnail(newSize, Image.ANTIALIAS)

	# setup the crop to size x size image
	if (crop):
		if (hratio > wratio):
			buffer = int((im.size[0]-size)/2)
			im = im.crop((buffer, 0, (im.size[0]-buffer), size))
		else:
			buffer = int((im.size[1]-size)/2)
			im = im.crop((0, buffer, size, (im.size[1] - buffer)))

	im.load()
	return im