from django import forms
import datetime

from phonenumber_field.formfields import PhoneNumberField

from common.models import User, Strand


class StrandApiForm(forms.Form):
	# OS is android or iphone for example
	build_os = forms.CharField(required=False)

	# Build num is the version of the build, like 1285
	build_number = forms.IntegerField(required=False)

	# Build id is the idenitfier for type of build like com.Duffyapp.Strand
	build_id = forms.CharField(required=False)

class UserIdMixin():
	def clean_user_id(self):
		userId = self.cleaned_data['user_id']
		try:
			user = User.objects.get(id=userId)
			self.cleaned_data['user'] = user

			if user.id < 500:
				raise forms.ValidationError("User not found")
		except User.DoesNotExist:
			raise forms.ValidationError("User not found")
	
		return self.cleaned_data['user_id']

class StrandIdMixin():
	def clean_strand_id(self):
		strandId = self.cleaned_data['strand_id']
		try:
			strand = Strand.objects.get(id=strandId)
			self.cleaned_data['strand'] = strand
		except Strand.DoesNotExist:
			raise forms.ValidationError("Strand not found")
	
		return self.cleaned_data['strand_id']

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

class GetJoinableStrandsForm(StrandApiForm, UserIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)

class GetNewPhotosForm(StrandApiForm, UserIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	start_date_time = forms.DateTimeField(input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])

class RegisterAPNSTokenForm(StrandApiForm, UserIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	device_token = forms.CharField(min_length=1, max_length=100)

class UpdateUserLocationForm(StrandApiForm, UserIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	lat = forms.FloatField(min_value=-90, max_value=90)
	lon = forms.FloatField(min_value=-180, max_value=180)
	timestamp = forms.DateTimeField(required=False, input_formats=['%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S'])
	accuracy = forms.FloatField(required=False)

class GetFriendsNearbyMessageForm(StrandApiForm, UserIdMixin):
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

class OnlyUserIdForm(StrandApiForm, UserIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)

class UserIdAndStrandIdForm(StrandApiForm, UserIdMixin, StrandIdMixin):
	user_id = forms.IntegerField(min_value=1, max_value=10000)
	strand_id = forms.IntegerField(min_value=1, max_value=10000000)
