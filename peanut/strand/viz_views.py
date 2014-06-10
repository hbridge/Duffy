from django.shortcuts import render
from django.http import HttpResponse


from peanut import settings
from common.models import Photo, User, Classification

from arbus import image_util, search_util, gallery_util, cluster_util
from arbus.forms import ManualAddPhoto

def neighbors(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if not data.has_key('user_id'):
		return HttpResponse("Please specify a user")

	context = {}
	return render(request, 'strand/neighbors.html', context)