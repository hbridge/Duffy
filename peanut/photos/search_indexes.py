import datetime
from haystack import indexes
from photos.models import Photo
import json
import time
from datetime import datetime


class PhotoIndex(indexes.SearchIndex, indexes.Indexable):
	text = indexes.CharField(document=True, use_template=True)
	userId = indexes.CharField()
	photoFilename = indexes.CharField(model_attr="new_filename")
	photoId = indexes.CharField(model_attr="id", indexed=False)
	classificationData = indexes.CharField(model_attr="classification_data", default="")
	locationData = indexes.CharField(model_attr="location_data", default="")
	timeTaken = indexes.DateTimeField(model_attr="time_taken")

	def get_model(self):
		return Photo

	def index_queryset(self, using=None):
		"""Used when the entire index for model is updated."""
		#return self.get_model().objects.filter(pub_date__lte=datetime.datetime.now())
		return self.get_model().objects.all()

	def prepare_userId(self, obj):
		return str(obj.user.id)
