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
	#altTerms = indexes.CharField(default="")

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
		return self.prepared_data['locationData'] + '\n' + self.clean_classData(obj, 20) + '\n' + self.get_altTerms(obj, 20)		

	def prepare_userId(self, obj):
		return str(obj.user.id)

	def prepare_timeTaken(self, obj):
		if obj.time_taken:
			return obj.time_taken
		else:
			return "1900-01-01T01:01:01Z"

	'''
	loads the list of alternate terms, adds them to the index for any classification that
	is greater than threshold
	'''

	def get_altTerms(self, obj, threshold):
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
	Cleans the classification list to only include entries higher than threshold and 
	removes underscores
	'''

	def clean_classData(self, obj, threshold):
		newList = list()
		if (self.prepared_data['classificationData']):
			catList = json.loads(obj.classification_data)
			for entry in catList:
				if (entry['rating'] > threshold):
					newClass = dict()
					newClass['class_name'] = entry['class_name'].replace('_', ' ').encode('ascii')
					newClass['rating'] = entry['rating']
					newList.append(newClass)
		return str(newList)
