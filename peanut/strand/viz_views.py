import logging

from django.shortcuts import render
from django.http import HttpResponse

from peanut.settings import constants

from common.models import Photo, User, Classification, Strand, Action

from arbus.forms import ManualAddPhoto
from strand.forms import InappropriateContentForm
from django.db.models import Count


logger = logging.getLogger(__name__)

def strandStats(request):

	# stats on strands
	strands = list(Strand.objects.prefetch_related('photos', 'users').filter(private=False))

	strandBucket1 = strandBucket2 = strandBucket3 = strandBucket4 = 0
	
	for strand in strands:
		if strand.photos.count() == 1:
			strandBucket1 += 1
		elif strand.photos.count() < 5:
			strandBucket2 += 1
		elif strand.photos.count() < 10:
			strandBucket3 += 1
		else:
			strandBucket4 += 1

	strandCounts = dict()
	strandCounts['all'] = len(strands)
	strandCounts['b1'] = strandBucket1
	strandCounts['b2'] = strandBucket2
	strandCounts['b3'] = strandBucket3
	strandCounts['b4'] = strandBucket4

	# stats on strand users

	userBucket1 = userBucket2 = userBucket3 = userBucket4 = 0
	
	for strand in strands:
		if strand.users.count() == 1:
			userBucket1 += 1
		elif strand.users.count() == 2:
			userBucket2 += 1
		elif strand.photos.count() == 3:
			userBucket3 += 1
		else:
			userBucket4 += 1

	userCounts = dict()
	userCounts['all'] = len(strands)
	userCounts['b1'] = userBucket1
	userCounts['b2'] = userBucket2
	userCounts['b3'] = userBucket3
	userCounts['b4'] = userBucket4

	context = {	'strandCounts': strandCounts,
				'userCounts': userCounts}
	return render(request, 'strand/strandStats.html', context)


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

		return HttpResponse("Thank you for your submission. We will evaluate it shortly and get back to you.")
	else:
		return HttpResponse("Please click back and fix the following errors: %s", form.errors)