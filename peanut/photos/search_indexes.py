import datetime
from haystack import indexes
from photos.models import Photo
import json
import time
from datetime import datetime


class PhotoIndex(indexes.SearchIndex, indexes.Indexable):
	text = indexes.CharField(document=True, use_template=False)
	userId = indexes.CharField()
	photoFilename = indexes.CharField(model_attr="new_filename")
	photoId = indexes.CharField(model_attr="id", indexed=False)
	classificationData = indexes.CharField(model_attr="classification_data", default="")
	locationData = indexes.CharField(model_attr="location_data", default="")
	timeTaken = indexes.DateTimeField(model_attr="time_taken", default="")

	def get_model(self):
		return Photo

	def index_queryset(self, using=None):
		"""Used when the entire index for model is updated."""
		#return self.get_model().objects.filter(pub_date__lte=datetime.datetime.now())
		return self.get_model().objects.all()

	'''
	This function prepares the text field (if use_template=False)

	'''
	def prepare_text(self, obj):
		#self.add_faceKeywords(obj)
		return self.add_locData(obj) + '\n' + \
				self.add_classData(obj, 20) + '\n' + \
				self.add_altTerms(obj, 20) + '\n' + \
				self.add_faceKeywords(obj)

	def prepare_userId(self, obj):
		return str(obj.user.id)

	def prepare_timeTaken(self, obj):
		if obj.time_taken:
			return obj.time_taken
		else:
			return "1900-01-01T01:01:01Z"

	'''
	Cleans the location data to be inserted in the index
	'''
	def add_locData(self, obj):
		locText = list()
		if (self.prepared_data['locationData']):
			locData = json.loads(self.prepared_data['locationData'])
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

		return ', '.join(locText)



	'''
	Cleans the classification list to only include entries higher than threshold and 
	removes underscores
	'''
	def add_classData(self, obj, threshold):
		newList = list()
		if (self.prepared_data['classificationData']):
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

		if (self.prepared_data['classificationData']):
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
