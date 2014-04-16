from photos.models import Photo

from collections import OrderedDict

from datetime import datetime, date
from dateutil.relativedelta import relativedelta

def splitPhotosFromDBbyMonth(userId, photoSet=None, groupThreshold=None):
	if (photoSet == None):
		photoSet = Photo.objects.filter(user_id=userId)

	if (groupThreshold == None):
		groupThreshold = 11

	dates = photoSet.datetimes('time_taken', 'month')
	
	photos = list()

	entry = dict()
	entry['date'] = 'Undated'
	entry['mainPhotos'] = list(photoSet.filter(time_taken=None)[:groupThreshold])
	entry['subPhotos'] = list(photoSet.filter(time_taken=None)[groupThreshold:])
	entry['count'] = len(entry['subPhotos'])
	photos.append(entry)

	for date in dates:
		entry = dict()
		entry['date'] = date.strftime('%b %Y')
		entry['mainPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[:groupThreshold])
		entry['subPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[groupThreshold:])
		entry['count'] = len(entry['subPhotos'])
		photos.append(entry)

	return photos

def splitPhotosFromIndexbyMonth(userId, photoSet=None):
	if (photoSet == None):
		photoSet = 	SearchQuerySet().filter(userId=userId)

	dateFacet = photoSet.date_facet('timeTaken', start_date=date(1900,1,1), end_date=date(2014,5,1), gap_by='month').facet('timeTaken', mincount=1, limit=-1, sort=False)
	facetCounts = dateFacet.facet_counts()
	
	photos = list()

	del facetCounts['dates']['timeTaken']['start']
	del facetCounts['dates']['timeTaken']['end']
	del facetCounts['dates']['timeTaken']['gap']

	od = OrderedDict(sorted(facetCounts['dates']['timeTaken'].items()))
	for dateKey, countVal in od.items():
		entry = dict()
		startDate = datetime.strptime(dateKey[:-1], '%Y-%m-%dT%H:%M:%S')
		entry['date'] = startDate.strftime('%b %Y')
		newDate = startDate+relativedelta(months=1)
		entry['photos'] = list(photoSet.exclude(timeTaken__lt=startDate).exclude(timeTaken__gt=newDate).order_by('timeTaken'))
		entry['count'] = len(entry['photos'])
		photos.append(entry)
		
	return photos