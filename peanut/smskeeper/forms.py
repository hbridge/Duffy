from django import forms
from smskeeper.models import User


class UserMixin(forms.Form):
	def clean_user_id(self):
		userId = self.cleaned_data['user_id']

		if userId:
			try:
				user = User.objects.get(id=userId)
				self.cleaned_data['user'] = user

			except User.DoesNotExist:
				raise forms.ValidationError("User not found")

		return self.cleaned_data['user_id']

	def clean_key(self):
		userKey = self.cleaned_data['key']

		if userKey:
			try:
				user = User.objects.get(key=userKey)
				self.cleaned_data['user'] = user

			except User.DoesNotExist:
				raise forms.ValidationError("User not found")

		return self.cleaned_data['key']


class UserIdForm(UserMixin):
	user_id = forms.IntegerField(required=False)
	key = forms.CharField(required=False)
	development = forms.BooleanField(required=False)


class SendSMSForm(UserMixin):
	user_id = forms.IntegerField(required=True)
	msg = forms.CharField(required=True)
	from_num = forms.CharField(required=False)
	direction = forms.CharField(required=False)
	override_class = forms.CharField(required=False)


class SendMediaForm(UserMixin):
	user_id = forms.IntegerField(required=True)
	msg = forms.CharField(required=False)
	url = forms.CharField(required=True)


class StripeForm(UserIdForm):
	stripe_data = forms.CharField(required=True)


class ResendMsgForm(UserMixin):
	msg_id = forms.IntegerField(required=True)
	from_num = forms.CharField(required=False)


class SmsContentForm(forms.Form):
	From = forms.CharField(required=True)
	To = forms.CharField(required=False)
	Body = forms.CharField(required=False)
	NumMedia = forms.IntegerField(required=False)


class PhoneNumberForm(forms.Form):
	PhoneNumber = forms.CharField(required=True)


class WebsiteRegistrationForm(forms.Form):
	phone_number = forms.CharField(min_length=1, max_length=100)
	source = forms.CharField(min_length=1, max_length=100, required=False)
	referrer = forms.CharField(min_length=1, max_length=100, required=False)
	paid = forms.CharField(min_length=1, max_length=100, required=False)
	exp = forms.CharField(min_length=1, max_length=100, required=False)
