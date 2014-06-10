import time
import json
import datetime

from django.http import HttpResponse

from django.db.models import Q

from common.models import Photo, User, Neighbor
from common.serializers import SmallPhotoSerializer

from common import api_util

class TimeEnabledEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		return json.JSONEncoder.default(self, obj)


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

	groupings = list()
	for neighbor in results:
		group = getGroupForPhoto(neighbor.photo_1, groupings)

		if (group):
			# If the first photo is in a cluster, see if the other photo is in there already
			#   if it isn't, and this isn't a dup, then add photo_2 in
			if neighbor.photo_2 not in group:
				group['clusters'].append(neighbor.photo_2)
		else:
			# If the first photo isn't in a cluster, see if the second one is
			group = getGroupForPhoto(neighbor.photo_2, groupings)

			if (group):
				# If the second photo is in a cluster and this isn't a dup then add in
				group['clusters'].append(neighbor.photo_1)
			else:
				title = neighbor.photo_1.location_city
				# If neither photo is in a cluster, we create a new one
				group = {'title': title, 'clusters': [neighbor.photo_1, neighbor.photo_2]}			
				groupings.append(group)

	sortedClusters = list()
	for cluster in clusters:
		sortedCluster = sorted(cluster, key=lambda x: x['time_taken'])

		# This is a crappy hack.  What we'd like to do is define a dup as same time_taken and same
		#   location_point.  But a bug in mysql looks to be corrupting the lat/lon we fetch here.
		#   So using location_city instead.  This means we might cut out some photos that were taken
		#   at the exact same time in the same city
		uniqueCluster = removeDups(sortedCluster, lambda x: (x['time_taken'], x['location_city']))
		sortedClusters.append(uniqueCluster)

	# now sort clusters by the time_taken of the first photo in each cluster
	sortedClusters = sorted(sortedClusters, key=lambda x: x[0]['time_taken'])

	response['neighbors'] = sortedClusters
	return HttpResponse(json.dumps(response, cls=TimeEnabledEncoder), content_type="application/json")
	
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


