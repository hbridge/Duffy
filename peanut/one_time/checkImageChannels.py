import requests
import sys, os, getopt
import json
import tempfile
import pyexiv2

import Image

"""
Goes through the user_data directory and prints any filenames that aren't RGB
"""

def main(argv):
	rootdir = '/home/derek/user_data/'

	for i in range(250):
		if (i < 141): # already checked the directories before that one
			continue
		print "Dir: {0}".format(i)
		for subdir, dirs, filenames in os.walk(rootdir + str(i) + '/'):
				for filename in filenames:
					name, ext = os.path.splitext(filename)
					if ('thumb' in name):
						continue

					if (ext in [".jpg", ".JPG"]):
						filepath = os.path.join(rootdir, subdir, filename)
						im = Image.open(filepath)
						if (im.getbands() != ('R', 'G', 'B')):
							print "{0}: {1}".format(filepath, im.getbands())


if __name__ == "__main__":
    main(sys.argv[1:])