from django import forms

class ManualAddPhoto(forms.Form):
	phone_id = forms.CharField()
	photo_metadata = forms.CharField(required = False)
	location_data = forms.CharField(required = False)
	file  = forms.FileField()
	iphone_faceboxes_topleft = forms.CharField(required = False)