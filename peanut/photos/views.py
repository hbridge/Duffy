from django.shortcuts import render
from django.http import HttpResponse
from .forms import ManualAddPhoto
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt, csrf_protect

from django.template import RequestContext, loader

import os, datetime
import json

from photos.models import Photo, User

def handle_uploaded_file(user, f):
	basePath = "/home/derek/user_data"
	userUploadsPath = os.path.join(basePath, str(user.id))
	outputFilename = os.path.join(userUploadsPath, f.name)

	print("Writing to " + outputFilename)

	try:
		os.stat(userUploadsPath)
	except:
		os.mkdir(userUploadsPath)

	with open(outputFilename, 'wb+') as destination:
		for chunk in f.chunks():
			destination.write(chunk)

def manualAddPhoto(request):
	form = ManualAddPhoto()

	context = {'form' : form}
	return render(request, 'photos/manualAddPhoto.html', context)

@csrf_exempt
def addPhoto(request):
	response_data = {}

	if request.method == 'POST':
		form = ManualAddPhoto(request.POST, request.FILES)
		if form.is_valid():
			phoneId = form.cleaned_data['phone_id']
			photoMetadata = form.cleaned_data['photo_metadata']
			locationData = form.cleaned_data['location_data']

			try:
				user = User.objects.get(phone_id=phoneId)
			except User.DoesNotExist:
				user = User(first_name="", last_name="", phone_id = phoneId)
				user.save()

			handle_uploaded_file(user, request.FILES['file'])

			photo = Photo(user = user, location_data = locationData, filename = request.FILES['file'].name, metadata = photoMetadata)
			photo.save()

			response_data['result'] = True
			response_data['debug'] = photoMetadata
			return HttpResponse(json.dumps(response_data), content_type="application/json")
		else:
			response_data['result'] = False
			response_data['debug'] = 'Form data is incorrect'
			return HttpResponse(json.dumps(response_data), content_type="application/json")
	else:
		return HttpResponse("This needs to be a POST")

def groups(request, user_id):
	return HttpResponse("Userid: " + str(user_id))
