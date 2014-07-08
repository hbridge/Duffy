import logging

from django.shortcuts import render
from django.http import HttpResponse

from common.models import Photo, User, Classification

from arbus.forms import ManualAddPhoto
from strand.forms import InappropriateContentForm

logger = logging.getLogger(__name__)

def neighbors(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if not data.has_key('user_id'):
		return HttpResponse("Please specify a user")

	context = {}
	return render(request, 'strand/neighbors.html', context)


def serveImage(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if (data.has_key('user_id')):
		userId = data['user_id']
	else:
		return HttpResponse("Missing user id data")

	if data.has_key('photo_id'):
		photoId = data['photo_id']
		print photoId
	else:
		return HttpResponse("Please specify a photo")


	thumbnailBasepath = "/user_data/" + str(userId) + "/"

	context = {	'photoId': photoId,
				'thumbnailBasepath': thumbnailBasepath}
	return render(request, 'strand/serve_image.html', context)

def innapropriateContentForm(request):
	form = InappropriateContentForm(request.GET)

	if form.is_valid():

		logStr = ""
		for key, value in form.cleaned_data.iteritems():
			logStr += "%s=%s," % (key, value)

		logger.error("INAPPROPRIATE: %s" % logStr)

		return HttpResponse("Thank you for your submission, we will evaluate this shortly")
	else:
		return HttpResponse("Please click back and fix the following errors: %s", form.errors)