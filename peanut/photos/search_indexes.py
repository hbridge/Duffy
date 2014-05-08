import datetime
from haystack import indexes
from photos.models import Photo
import json
import time
import logging
from datetime import datetime


class PhotoIndex(indexes.SearchIndex, indexes.Indexable):
	text = indexes.CharField(document=True, use_template=False)
	userId = indexes.CharField()
	photoFilename = indexes.CharField(model_attr="full_filename", default="")
	photoId = indexes.CharField(model_attr="id", indexed=False)
	classificationData = indexes.CharField(model_attr="classification_data", default="")
	locationData = indexes.CharField(model_attr="location_data", default="")
	timeTaken = indexes.DateTimeField(model_attr="time_taken", default="")
	twoFishesData = indexes.CharField(model_attr="twofishes_data", default="")
	updated = indexes.DateField()
	
	logger = None

	#def __init__(self):
		#self.logger = logging.basicConfig(filename='indexer.log',level=logging.DEBUG)

	def get_model(self):
		return Photo

	def get_updated_field(self):
		return "updated"

	def index_queryset(self, using=None):
		"""Used when the entire index for model is updated."""
		return self.get_model().objects.filter(user__gt=1)

	'''
	This function prepares the text field (if use_template=False)

	'''
	def prepare_text(self, obj):
		return self.add_locData(obj) + '\n' + \
				self.add_classData(obj, 20) + '\n' + \
				self.add_altTerms(obj, 20) + '\n' + \
				self.add_faceKeywords(obj) + '\n' + \
				self.add_twofishesData(obj) + '\n' + \
				self.add_screenshotKeywords(obj)

	def prepare_userId(self, obj):
		return str(obj.user.id)

	def prepare_timeTaken(self, obj):
		if obj.time_taken:
			return obj.time_taken
		else:
			return "1900-01-01T01:01:01Z"

### Helper functions to clean up data before adding to index

	'''
	Cleans the location data to be inserted in the index
	'''
	def add_locData(self, obj):
		locText = list()
		if (obj.location_data):
			locData = json.loads(obj.location_data)
			if ('address' in locData):
				address = locData['address']
				for k, v in address.items():
					if type(v) is list: 
						locText.append(' '.join(v))
					else:
						if (v not in locText):
							locText.append(v)

			if ('pois' in locData):
				pois = locData['pois']
				for item in pois:
					#locText += item + '\n'
					if (item not in locText):
						locText.append(item)

		return u', '.join(locText)



	'''
	Cleans the classification list to only include entries higher than threshold and 
	removes underscores
	'''
	def add_classData(self, obj, threshold):
		newList = list()
		if (obj.classification_data):
			catList = json.loads(obj.classification_data)
			for entry in catList:
				if (entry['rating'] > threshold):
					newList.append(entry['class_name'].replace('_', ' ').encode('ascii'))
		return ', '.join(newList)


	'''
	loads the list of alternate terms, adds them to the index for any classification that
	is greater than threshold
	'''
	def add_altTerms(self, obj, threshold):
		altFilePath = '/home/derek/prod/Duffy/peanut/photos/'
		f = open(altFilePath + 'alt.txt', 'r')
		altDict = dict()
		termList = ""

		# build a dict
		for line in f:
			altSplit = line.split(',')
			if (len(altSplit) > 1):
				altDict[altSplit[0]] = line.split(',', 1)[1]

		if (obj.classification_data):
			catList = json.loads(obj.classification_data)
			for entry in catList:
				if (entry['rating'] > threshold):
					className = entry['class_name'].replace('_', ' ')
					if (className in altDict):
						termList = termList + str(altDict[className])
		return termList

	'''
	adds the keyword 'face, faces, people, person' if there is a photo detected
	'''
	def add_faceKeywords(self, obj):
		faceKeywords = {'face', 'faces', 'people', 'person'}
		smileKeywords = {'smile', 'smiles', 'smiling'}
		termList = ""
		foundSmile = False;
		foundFace = False;
		if (obj.iphone_faceboxes_topleft):
			facedict = json.loads(obj.iphone_faceboxes_topleft)
			if (len(facedict) > 0):
				foundFace = True;
				for k1,v1 in facedict.items():
					for k2,v2 in v1.items():
						if ('has_smile' in k2):
								if (v2 == 'false'):
									foundSmile = True
									break
				if (foundFace == True):
					termList += ', '.join(faceKeywords)
				if (foundSmile == True):
					termList += ',' 
					termList += ', '.join(smileKeywords)
				return termList
		return ''

	'''
	adds the keyword 'screenshot, screenshots' if there is a screenshot detected
	'''
	def add_screenshotKeywords(self, obj):
		screenshotKeywords = {'screenshot', 'screenshots'}
		png = 'png'

		if (obj.metadata):
			metadata = json.loads(obj.metadata)
			if "{PNG}" in metadata:
				return ', '.join(screenshotKeywords)
		return ''

	def add_twofishesData(self, obj):
		locText = list()

		if (obj.twofishes_data):
			twoFishesData = json.loads(obj.twofishes_data)
			
			for data in twoFishesData["interpretations"]:
				locText.append(data["feature"]["displayName"])

		return u', '.join(locText)
