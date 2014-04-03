import os, sys, os.path
import Image

def imageThumbnail(photoFname, size, userId):
	# comment this out when production server runs it
	#path = '/home/aseem/userdata/' + str(userId) + '/images/'
	path = '/home/derek/user_data/' + str(userId) + '/'
	outfile = path + str.split(str(photoFname), '.')[0] + "-thumb-" + str(size) + '.jpg'

	if (os.path.isfile(outfile)):
		return outfile
	
	try:
		infile = path + photoFname
		im = Image.open(infile)

		#calc ratios and new min size
		wratio = (size/float(im.size[0])) #width check
		hratio = (size/float(im.size[1])) #height check

		if (hratio > wratio):
			newSize = hratio*im.size[0], hratio*im.size[1]
		else:
			newSize = wratio*im.size[0], wratio*im.size[1]		
		im.thumbnail(newSize, Image.ANTIALIAS)

		# setup the crop to size x size image
		
		if (hratio > wratio):
			buffer = int((im.size[0]-size)/2)
			im = im.crop((buffer, 0, (im.size[0]-buffer), size))			
		else:
			buffer = int((im.size[1]-size)/2)
			im = im.crop((0, buffer, size, (im.size[1] - buffer)))
		
		im.load()
		im.save(outfile, "JPEG")
		print "generated thumbnail: '%s" % outfile
		return outfile
	except IOError:
		print "cannot create thumbnail for '%s'" % infile
		return None
