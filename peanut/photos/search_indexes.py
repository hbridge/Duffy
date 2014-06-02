import datetime
from haystack import indexes
from photos.models import Photo
import json
import time
import logging
from datetime import datetime


class PhotoIndex(indexes.SearchIndex, indexes.Indexable):
	text = indexes.CharField(document=True, use_template=False)
	userId = indexes.CharField(model_attr="user_id")
	photoId = indexes.CharField(model_attr="id", indexed=False)
	timeTaken = indexes.DateTimeField(model_attr="time_taken", default="")
	updated = indexes.DateTimeField(model_attr="updated")
	isLocal = indexes.BooleanField(model_attr="is_local")

	locations = indexes.MultiValueField(faceted=True, indexed=False)
	classes = indexes.MultiValueField(faceted=True, indexed=False)

	# Used for auto-complete
	content_auto = indexes.EdgeNgramField()
	
	logger = None

	altDict = None

	def prepare_content_auto(self, obj):
		items = list()
		items.extend(self.getTwoFishesData(obj))
		items.extend(self.getMetadataKeywords(obj, forSearch=False))
		items.extend(self.getAltTerms(obj, 15))
		items.extend(self.getFaceKeywords(obj, forSearch=False))

		# we break down the words in the code by \n
		return '\n'.join(items)

	def prepare_locations(self, obj):
		locItems = self.getTwoFishesData(obj)
		return locItems

	def prepare_classes(self, obj):
		items = list()
		items.extend(self.getMetadataKeywords(obj, forSearch=False))
		items.extend(self.getAltTerms(obj, 15))
		items.extend(self.getFaceKeywords(obj, forSearch=False))

		return items

	#def __init__(self):
		#self.logger = logging.basicConfig(filename='indexer.log',level=logging.DEBUG)

	def get_model(self):
		return Photo

	def get_updated_field(self):
		return "updated"

	def index_queryset(self, using=None):
		self.prepAltList()
		"""Used when the entire index for model is updated."""
		return self.get_model().objects.filter(user__gt=1)

	'''
	This function prepares the text field (if use_template=False)

	'''
	def prepare_text(self, obj):
		if (not self.altDict):
			self.prepAltList()

		items = list()
		items.extend(self.getTwoFishesData(obj))
		items.extend(self.getMetadataKeywords(obj))
		items.extend(self.getAltTerms(obj, 20))
		items.extend(self.getFaceKeywords(obj))
		return self.add_locData(obj) + '\n' + \
				u', '.join(items)
				

	def prepare_userId(self, obj):
		return str(obj.user.id)

	def prepare_timeTaken(self, obj):
		if obj.time_taken:
			return obj.time_taken
		else:
			return obj.added

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
	def getClassData(self, obj, threshold):
		classes = list()
		if (obj.overfeat_data):
			catList = json.loads(obj.overfeat_data)
			for entry in catList:
				if (entry['rating'] > threshold):
					classes.append(entry['class_name'].replace('_', ' ').encode('ascii'))
		return classes

	def prepAltList(self):
		altFilePath = '/home/derek/prod/Duffy/peanut/photos/'
		f = open(altFilePath + 'alt.txt', 'r')
		self.altDict = dict()

		# build a dict
		for line in f:
			altSplit = line.strip().split(',')
			if (len(altSplit) > 1):
				self.altDict[altSplit[0]] = altSplit[1:]

	'''
	loads the list of alternate terms, adds them to the index for any classification that
	is greater than threshold
	'''
	def getAltTerms(self, obj, threshold):
		altTermItems = list()

		if (obj.overfeat_data):
			catList = json.loads(obj.overfeat_data)
			for entry in catList:
				if (entry['rating'] > threshold):
					className = entry['class_name'].replace('_', ' ')
					if (className in self.altDict):
						altTermItems.extend(self.altDict[className])
		return altTermItems

	'''
	adds the keyword 'face, faces, people, person' if there is a photo detected
	'''
	def getFaceKeywords(self, obj, forSearch=True):
		faceKeywords = ['people', 'face', 'faces', 'person']
		smileKeywords = ['smile', 'smiles', 'smiling']
		termList = list()
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
				

		if (obj.faces_data):
			facesData = json.loads(obj.faces_data)
			if "rects" in facesData["opencv"]:
				foundFace = True


		if (foundFace == True):
			if forSearch:
				termList.extend(faceKeywords)
			else:
				termList.append(faceKeywords[0])
				
		if (foundSmile == True):
			termList.extend(smileKeywords)
		
		return termList

	'''
		Adds keywords based on metadata
		Right now, we're just doing basic text searches.  Probably want to upgrade this at some point.
		adds the keyword 'face, faces, people, person' if there is a photo detected
	'''
	def getMetadataKeywords(self, obj, forSearch=True):
		foundTerms = list()
		keywords = {"front camera" : ['selfies', 'selfie', 'selfy'],
					"{PNG}" : ['screenshots', 'screenshot']}

		if (obj.metadata):
			for key in keywords:
				if (str(obj.metadata).find(key) >= 0):
					if forSearch:
						foundTerms.extend(keywords[key])
					else:
						foundTerms.append(keywords[key][0])

		return foundTerms


	def getTwoFishesData(self, obj):
		locItems = list()

		if (obj.twofishes_data):
			twoFishesData = json.loads(obj.twofishes_data)
			
			for data in twoFishesData["interpretations"]:
				if "woeType" in data["feature"]:
					#  Filter out states and countries
					# https://github.com/foursquare/twofishes/blob/master/interface/src/main/thrift/geocoder.thrift
					if data["feature"]["woeType"] != 8 and data["feature"]["woeType"] != 12:
						locItems.append(data["feature"]["displayName"])

		return locItems
