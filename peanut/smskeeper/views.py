import json
from multiprocessing import Process
import uuid
import boto
import requests
import cStringIO
import random
import math
from PIL import Image

from django.shortcuts import render

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

from smskeeper.forms import UserIdForm, SmsContentForm
from smskeeper.models import User, Note, NoteEntry, IncomingMessage

from strand import notifications_util
from common import api_util
from peanut.settings import constants

def sendResponse(msg):
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response><Sms>%s</Sms></Response>" % msg
	print "Sending response %s" % msg
	return HttpResponse(content, content_type="text/xml")

def sendMsg(user, msg, mediaUrls, keeperNumber):
	print "Sending %s to %s" % (msg, user.phone_number)
	if mediaUrls:
		notifications_util.sendSMSThroughTwilio(user.phone_number, msg, mediaUrls, keeperNumber)
	else:
		notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, keeperNumber)

def sendNoResponse():
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response></Response>"
	print "Sending blank response"
	return HttpResponse(content, content_type="text/xml")

def isLabel(msg):
	stripedMsg = msg.strip()
	return (' ' in stripedMsg) == False and stripedMsg.startswith("#")

def isClearLabel(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'clear') or (isLabel(tokens[1]) and tokens[0].lower()=='clear'))

def isPickFromLabel(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'pick') or (isLabel(tokens[1]) and tokens[0].lower()=='pick'))

def isListsCommand(msg):
	return msg.strip().lower() == 'show lists' or msg.strip().lower() == 'show all'

def isHelpCommand(msg):
	return msg.strip().lower() == 'help'

def hasList(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return True
	return False

def getLabel(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return word
	return None

def getData(msg, numMedia, request):
	# process text
	nonLabels = list()
	label = None
	for word in msg.split(' '):
		if isLabel(word):
			label = word
		else:
			nonLabels.append(word)

	# process media
	mediaUrlList = list()

	requestDict = api_util.getRequestData(request)

	for n in range(numMedia):
		param = 'MediaUrl' + str(n)
		mediaUrlList.append(requestDict[param])
		#TODO need to store mediacontenttype as well. 

	#TODO use a separate process but probably this is not the right place to do it.
	if numMedia > 0:
		mediaUrlList = moveMediaToS3(mediaUrlList)
	return (' '.join(nonLabels), label, mediaUrlList)

def moveMediaToS3(mediaUrlList):

	conn = boto.connect_s3('AKIAJBSV42QT6SWHHGBA', '3DjvtP+HTzbDzCT1V1lQoAICeJz16n/2aKoXlyZL')
	bucket = conn.get_bucket('smskeeper')
	newUrlList = list()
	
	for mediaUrl in mediaUrlList:
		resp = requests.get(mediaUrl)
		media = cStringIO.StringIO(resp.content)

		# Upload to S3 
		keyStr = uuid.uuid4()
		key = bucket.new_key(keyStr)
		key.set_contents_from_string(media.getvalue())
		newUrlList.append('https://s3.amazonaws.com/smskeeper/'+ str(keyStr))

	return newUrlList

def sendBackNote(note, keeperNumber):
	clearMsg = "\n\nSend '%s clear' to clear this list."%(note.label)
	entries = NoteEntry.objects.filter(note=note).order_by("added")
	mediaUrls = list()

	if len(entries) == 0:
		return False

	currentMsg = "%s:" % note.label

	count = 1
	for entry in entries:
		if not entry.img_urls_json:
			currentMsg = currentMsg + "\n " + str(count) + ". " + entry.text
			count += 1
		else:
			mediaUrls.extend(json.loads(entry.img_urls_json))


	if len(mediaUrls) > 0:
		if (len(mediaUrls) > 1):
			photoPhrase = " photos"
		else:
			photoPhrase = " photo"

		currentMsg = currentMsg + "\n +" + str(len(mediaUrls)) + photoPhrase + " coming separately"

		sendMsg(note.user, currentMsg + clearMsg, None, keeperNumber)
		gridImageUrl = generateImageGridUrl(mediaUrls)
		sendMsg(note.user, '', gridImageUrl, keeperNumber)
		return sendNoResponse()
	else:
		return sendResponse(currentMsg + clearMsg)

'''
	Gets a list of urls and generates a grid image to send back.
'''
def generateImageGridUrl(imageURLs):
	# if one url, just return that
	if len(imageURLs) == 1:
		return imageURLs[0]

	# if more than one, now setup the grid system
	imageList = list()

	imageSize = 300

	# fetch all images and resize them into imageSize x imageSize
	for imageUrl in imageURLs:
		resp = requests.get(imageUrl)
		img = Image.open(cStringIO.StringIO(resp.content))
		imageList.append(resizeImage(img, imageSize, True))


	if len(imageURLs) < 5:
		# generate an 2xn grid
		rows = int(math.ceil(float(len(imageURLs))/2.0))
		newImage = Image.new("RGB", (2*imageSize, imageSize*rows), "white")
	
		for i,image in enumerate(imageList):
			x = imageSize*(i % 2)
			y = imageSize*(i/2 % 2)
			newImage.paste(image, (x,y,x+imageSize,y+imageSize))
	else:
		# generate a 3xn grid
		rows = int(math.ceil(float(len(imageURLs))/3.0))
		newImage = Image.new("RGB", (3*imageSize, imageSize*rows), "white")

		for i,image in enumerate(imageList):
			x = imageSize*(i % 3)
			y = imageSize*(i/3 % 3)
			newImage.paste(image, (x,y,x+imageSize,y+imageSize))

	return saveImageToS3(newImage)

	

def saveImageToS3(img):
	conn = boto.connect_s3('AKIAJBSV42QT6SWHHGBA', '3DjvtP+HTzbDzCT1V1lQoAICeJz16n/2aKoXlyZL')
	bucket = conn.get_bucket('smskeeper')
	
	outIm = cStringIO.StringIO()
	img.save(outIm, 'JPEG')

	# Upload to S3 
	keyStr = "grid-" + str(uuid.uuid4())
	key = bucket.new_key(keyStr)
	key.set_contents_from_string(outIm.getvalue())
	return 'https://s3.amazonaws.com/smskeeper/'+ str(keyStr)

"""
	Does image resizes and creates a new file (JPG) of the specified size
"""
def resizeImage(im, size, crop):

	#calc ratios and new min size
	wratio = (size/float(im.size[0])) #width check
	hratio = (size/float(im.size[1])) #height check

	if (hratio > wratio):
		newSize = hratio*im.size[0], hratio*im.size[1]
	else:
		newSize = wratio*im.size[0], wratio*im.size[1]
	im.thumbnail(newSize, Image.ANTIALIAS)

	# setup the crop to size x size image
	if (crop):
		if (hratio > wratio):
			buffer = int((im.size[0]-size)/2)
			im = im.crop((buffer, 0, (im.size[0]-buffer), size))			
		else:
			buffer = int((im.size[1]-size)/2)
			im = im.crop((0, buffer, size, (im.size[1] - buffer)))
	
	im.load()
	return im

def sendItemFromNote(note, keeperNumber):
	entries = NoteEntry.objects.filter(note=note).order_by("added")
	if len(entries) == 0:
		return False
		
	entry = random.choice(entries)
	if entry.img_urls_json:
		sendMsg(note.user, entry.text, json.loads(entry.img_urls_json), keeperNumber)
	else:
		return sendResponse(entry.text)


@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		keeperNumber = str(form.cleaned_data['To'])
		msg = form.cleaned_data['Body']
		numMedia = int(form.cleaned_data['NumMedia'])

		try:
			user = User.objects.get(phone_number=phoneNumber)
		except User.DoesNotExist:
			user = User.objects.create(phone_number=phoneNumber)

			return sendResponse("Hi. I'm Keeper. I can keep track of your lists, notes, photos, etc.\n\nLet's try creating your grocery list. Type an item you want to buy and add '#grocery' at the end.")
		finally:
			IncomingMessage.objects.create(user=user, msg_json=json.dumps(api_util.getRequestData(request)))

			
		if numMedia == 0 and isLabel(msg):
			# This is a label fetch.  See if a note with that label exists then return
			label = msg
			try:
				note = Note.objects.get(user=user, label=label)
				response = sendBackNote(note, keeperNumber)
				if response:
					return response
				else:
					return sendResponse("Sorry, I didn't find anything for %s" % label)

			except Note.DoesNotExist:
				return sendResponse("Sorry, I didn't find anything for %s" % label)
		elif numMedia == 0 and isClearLabel(msg):
			try:
				label = getLabel(msg)
				note = Note.objects.get(user=user, label=label)
				note.delete()
				return sendResponse("%s cleared"% (label))
			except Note.DoesNotExist:
				return sendResponse("Sorry, I don't have anything for %s" % label)
		elif numMedia == 0 and isPickFromLabel(msg):
			label = getLabel(msg)
			try:
				note = Note.objects.get(user=user, label=label)
				response = sendItemFromNote(note, keeperNumber)
				if response:
					return response
				else:
					return sendResponse("Sorry, I didn't find anything for %s" % label)

			except Note.DoesNotExist:
				return sendResponse("Sorry, I didn't find anything for %s" % label)

		elif hasList(msg):
			text, label, media = getData(msg, numMedia, request)
			note, created = Note.objects.get_or_create(user=user, label=label)

			entry = NoteEntry(note=note)
			if text:
				entry.text = text
			if media:
				entry.img_urls_json = json.dumps(media)
			entry.save()
			return sendResponse("Got it")
		elif isHelpCommand(msg):
			return sendResponse("You can create a list by adding #listname to any msg.\n You can retrieve all items in a list by typing just '#listname' in a message.")
		else:
			return sendResponse("Oops I need a label for that message. ex: #grocery, #tobuy, #toread. Send 'help' to find out more.")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)
