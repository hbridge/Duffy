from django import forms
from smskeeper.models import User

class UserIdMixin(forms.Form):
	def clean_user_id(self):
		userId = self.cleaned_data['user_id']
		try:
			user = User.objects.get(id=userId)
			self.cleaned_data['user'] = user

		except User.DoesNotExist:
			raise forms.ValidationError("User not found")
	
		return self.cleaned_data['user_id']

class UserIdForm(UserIdMixin):
	user_id = forms.IntegerField(required=True)

class SendSMSForm(UserIdMixin):
	user_id = forms.IntegerField(required=True)
	msg = forms.CharField(required=True)
	from_num = forms.CharField(required=False)

class SmsContentForm(forms.Form):
	From = forms.CharField(required=True)
	To = forms.CharField(required=False)
	Body = forms.CharField(required=False)
	NumMedia = forms.IntegerField(required=False)

class PhoneNumberForm(forms.Form):
	PhoneNumber = forms.CharField(required=True)
