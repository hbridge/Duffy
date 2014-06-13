import time
import json
import datetime
import pytz

from django.http import HttpResponse

from django.db.models import Q

from peanut import settings

from common.models import Photo, User, Neighbor

from common import api_util, cluster_util

from strand import geo_util
from strand.forms import GetJoinableStrandsForm, GetNewPhotosForm

def getGroupForPhoto(photo, clusters):
	for cluster in clusters:
		if photo in cluster:
			return cluster
	return None

def removeDups(seq, idFunction=None): 
   # order preserving
   if idFunction is None:
	   def idFunction(x): return x
   seen = {}
   result = []
   for item in seq:
	   id = idFunction(item)
	   if id in seen: continue
	   seen[id] = 1
	   result.append(item)
   return result

def getGroups(groupings, labelRecent = True):
	if len(groupings) == 0:
		return []

	output = list()

	photoIds = list()
	for group in groupings:
		for photo in group:
			photoIds.append(photo.id)

	# Fetch all the similarities at once so we can process in memory
	simCaches = cluster_util.getSimCaches(photoIds)

	for i, group in enumerate(groupings):
		if len(group) == 0:
			continue
			
		if i == 0 and labelRecent:
			# If first group, assume this is "Recent"
			title = "Recent"
		else:
			title = group[0].location_city
			
		clusters = cluster_util.getClustersFromPhotos(group, settings.DEFAULT_CLUSTER_THRESHOLD, settings.DEFAULT_DUP_THRESHOLD, simCaches)

		output.append({'title': title, 'clusters': clusters})
	return output
	
"""
	Get photos that have neighbor entries for this user and are after the given startTime
"""
def getNeighboredPhotos(userId, startTime):
	# Get all neighbors for this user's photos
	neighbors = Neighbor.objects.select_related().filter(Q(user_1_id=userId) | Q(user_2_id=userId)).filter(Q(photo_1__time_taken__gt=startTime) | Q(photo_2__time_taken__gt=startTime)).order_by('photo_1')

	latestPhotos = list()

	# For each neighbor, find the other people's photos that were taken after the given start time
	for neighbor in neighbors:
		if neighbor.user_1_id == userId and neighbor.photo_2.time_taken > startTime:
			latestPhotos.append(neighbor.photo_2)
		elif neighbor.user_2_id == userId and neighbor.photo_1.time_taken > startTime:
			latestPhotos.append(neighbor.photo_1)

	uniquePhotos = removeDups(latestPhotos, lambda x: x.id)

	return uniquePhotos

def neighbors(request):
	response = dict({'result': True})
	data = getRequestData(request)

	if data.has_key('user_id'):
		userId = data['user_id']
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return returnFailure(response, "user_id not found")
	else:
		return returnFailure(response, "Need user_id")

	results = Neighbor.objects.select_related().exclude(user_1_id=1).exclude(user_2_id=1).filter(Q(user_1=user) | Q(user_2=user)).order_by('photo_1')

	# Creates a list of lists for the sections then groups.
	# We'll first get this list setup, de-duped and sorted
	groupings = list()
	for neighbor in results:
		group = getGroupForPhoto(neighbor.photo_1, groupings)

		if (group):
			# If the first photo is in a cluster, see if the other photo is in there already
			#   if it isn't, and this isn't a dup, then add photo_2 in
			if neighbor.photo_2 not in group:
				group.append(neighbor.photo_2)
		else:
			# If the first photo isn't in a cluster, see if the second one is
			group = getGroupForPhoto(neighbor.photo_2, groupings)

			if (group):
				# If the second photo is in a cluster and this isn't a dup then add in
				group.append(neighbor.photo_1)
			else:
				# If neither photo is in a cluster, we create a new one
				group = [neighbor.photo_1, neighbor.photo_2]

				groupings.append(group)

	sortedGroups = list()
	for group in groupings:
		group = sorted(group, key=lambda x: x.time_taken, reverse=True)

		# This is a crappy hack.  What we'd like to do is define a dup as same time_taken and same
		#   location_point.  But a bug in mysql looks to be corrupting the lat/lon we fetch here.
		#   So using location_city instead.  This means we might cut out some photos that were taken
		#   at the exact same time in the same city
		uniqueGroup = removeDups(group, lambda x: (x.time_taken, x.location_city))
		sortedGroups.append(uniqueGroup)

	
	# now sort clusters by the time_taken of the first photo in each cluster
	sortedGroups = sorted(sortedGroups, key=lambda x: x[0].time_taken, reverse=True)

	# Try to find recent photos
	# If there are no previous groups, then fetch all photos and call them recent
	recentPhotos = Photo.objects.filter(user_id=userId).order_by("-time_taken")
	if len(sortedGroups) > 0 and len (sortedGroups[0]) > 0:
		lastPhotoTime = sortedGroups[0][0].time_taken
		sortedGroups = sortedGroups.filter(time_taken__gt=lastPhotoTime)

	haveRecentPhotos = len(recentPhotos) > 0
	
	if (haveRecentPhotos):
		sortedGroups.insert(0, recentPhotos)

	# Now we have to turn into our Duffy JSON, first, convert into the right format

	groups = getGroups(sortedGroups, labelRecent = haveRecentPhotos)
	lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)
	response['objects'] = objects
	response['next_start_date_time'] = lastDate
	return HttpResponse(json.dumps(response, cls=api_util.TimeEnabledEncoder), content_type="application/json")

"""
	Sees what strands the user would join if they took a picture at the given startTime (defaults to now)

	Searches for all photos of their friends within the time range and geo range but that don't have a
	  neighbor entry
"""
def get_joinable_strands(request):
	response = dict({'result': True})

	timeWithinHours = 3

	form = GetJoinableStrandsForm(request.GET) 
	if form.is_valid():
		userId = form.cleaned_data['user_id']
		lon = form.cleaned_data['lon']
		lat = form.cleaned_data['lat']
		startTime = form.cleaned_data['start_date_time']

		if not startTime:
			startTime = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

		timeLow = startTime - datetime.timedelta(hours=timeWithinHours)

		photosCache = Photo.objects.filter(time_taken__gt=timeLow).exclude(user_id=userId).exclude(location_point=None).filter(user__product_id=1)

		nearbyPhotosData = geo_util.getNearbyPhotos(startTime, lon, lat, photosCache, secondsWithin = timeWithinHours * 60 * 60)

		nearbyPhotos = list()
		for nearbyPhotoData in nearbyPhotosData:
			photo, timeDistance, geoDistance = nearbyPhotoData
			nearbyPhotos.append(photo)

		neighboredPhotos = getNeighboredPhotos(userId, timeLow)

		# We want to remove any photos that are already neighbored
		ids = Photo.getPhotosIds(neighboredPhotos)
		nonNeighboredPhotos = [item for item in nearbyPhotos if item.id not in ids]

		groups = getGroups([nonNeighboredPhotos], labelRecent=False)
		lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)
		response['objects'] = objects
		response['next_start_date_time'] = lastDate

		return HttpResponse(json.dumps(response, cls=api_util.TimeEnabledEncoder), content_type="application/json")
	else:
		response['result'] = False
		response['errors'] = json.dumps(form.errors)
		return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Returns back any new photos in the user's strands after the given date and time

	This looks at all the neighbor rows and see's if there's any ones with other people's photos
	taken after the startTime
"""
def get_new_photos(request):
	response = dict({'result': True})

	timeWithinHours = 3

	form = GetNewPhotosForm(request.GET)
	if form.is_valid():
		userId = form.cleaned_data['user_id']
		startTime = form.cleaned_data['start_date_time']

		photos = getNeighboredPhotos(userId, startTime)

		groups = getGroups([photos], labelRecent=False)
		lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)
		response['objects'] = objects
		response['next_start_date_time'] = lastDate

		return HttpResponse(json.dumps(response, cls=api_util.TimeEnabledEncoder), content_type="application/json")
	else:
		response['result'] = False
		response['errors'] = json.dumps(form.errors)
		return HttpResponse(json.dumps(response), content_type="application/json")

"""
Helper functions
"""
# TODO(Derek): pull this out to common, used in arbus
def getRequestData(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	return data


