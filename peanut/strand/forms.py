from django import forms
import datetime

class GetJoinableStrandsForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)
	start_date_time = forms.DateTimeField(required=False, initial=datetime.datetime.utcnow())

class GetNewPhotosForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	start_date_time = forms.DateTimeField()