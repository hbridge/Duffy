from django import forms
import datetime

from phonenumber_field.formfields import PhoneNumberField

class StrandApiForm(forms.Form):
	# OS is android or iphone for example
	build_os = forms.CharField(required=False)

	# Build num is the version of the build, like 1285
	build_num = forms.IntegerField(required=False)

	# Build id is the idenitfier for type of build like com.Duffy.Strand
	build_id = forms.CharField(required=False)


"""
	Web Forms
"""
class InappropriateContentForm(forms.Form):
	name = forms.CharField(required=False)
	mail = forms.CharField(required=False)
	offender = forms.CharField(required=False)
	contenttime = forms.CharField(required=False)
	discuss = forms.CharField(required=False)


"""
	API Forms
"""

class GetJoinableStrandsForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)

class GetNewPhotosForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	start_date_time = forms.DateTimeField(input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])

class RegisterAPNSTokenForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	device_token = forms.CharField(min_length=1, max_length=100)

class UpdateUserLocationForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)
	timestamp = forms.DateTimeField(required=False, input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])
	accuracy = forms.FloatField(required=False)

class GetFriendsNearbyMessageForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)

class SendSmsCodeForm(StrandApiForm):
	phone_number = PhoneNumberField()

class AuthPhoneForm(StrandApiForm):
	phone_number = PhoneNumberField()
	sms_access_code = forms.IntegerField(min_value=1000, max_value=9999)
	display_name = forms.CharField(min_length=1, max_length=100)
	phone_id = forms.CharField(min_length=1, max_length=100, required=False)

class OnlyUserIdForm(StrandApiForm):
	user_id = forms.IntegerField(min_value=1, max_value=10000)