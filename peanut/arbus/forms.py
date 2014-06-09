from django import forms
import datetime

class ManualAddPhoto(forms.Form):
	user = forms.CharField()
	metadata = forms.CharField(required = False)
	location_data = forms.CharField(required = False)
	file_key = forms.CharField(initial = "file0")
	file0  = forms.FileField()
	iphone_faceboxes_topleft = forms.CharField(required = False)


class SearchQueryForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	r = forms.BooleanField(required=False)
	debug = forms.BooleanField(required=False)
	q = forms.CharField(max_length=50)
	num = forms.IntegerField(min_value=1, max_value=10000, initial=30, required=False)
	start_date_time = forms.DateTimeField(required=False, initial=datetime.date(1901,1,1))
	docstack = forms.BooleanField(required=False, initial=False)
