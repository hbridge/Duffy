from django import forms

class ManualAddPhoto(forms.Form):
	user = forms.CharField()
	metadata = forms.CharField(required = False)
	location_data = forms.CharField(required = False)
	file_key = forms.CharField(initial = "file0")
	file0  = forms.FileField()
	iphone_faceboxes_topleft = forms.CharField(required = False)