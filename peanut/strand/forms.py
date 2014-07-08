from django import forms
import datetime

from phonenumber_field.formfields import PhoneNumberField

class InappropriateContentForm(forms.Form):
	name = forms.CharField(required=False)
	mail = forms.CharField(required=False)
	offender = forms.CharField(required=False)
	contenttime = forms.CharField(required=False)
	discuss = forms.CharField(required=False)

class GetJoinableStrandsForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)

class GetNewPhotosForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	start_date_time = forms.DateTimeField(input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])

class RegisterAPNSTokenForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	device_token = forms.CharField(min_length=1, max_length=100)
	# build_type: 0 is devel, 1 is adhoc, 2 is app store
	build_type = forms.IntegerField(required=False, min_value=0, max_value=2)

class UpdateUserLocationForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)
	timestamp = forms.DateTimeField(required=False, input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])

class GetFriendsNearbyMessageForm(forms.Form):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)

class SendSmsCodeForm(forms.Form):
	phone_number = PhoneNumberField()

class AuthPhoneForm(forms.Form):
	phone_number = PhoneNumberField()
	sms_access_code = forms.IntegerField(min_value=1000, max_value=9999)
	display_name = forms.CharField(min_length=1, max_length=100)
	phone_id = forms.CharField(min_length=1, max_length=100, required=False)