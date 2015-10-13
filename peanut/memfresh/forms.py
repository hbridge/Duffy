from django import forms


class UserIdForm(forms.Form):
	user_id = forms.IntegerField(required=True)

class AuthForm(forms.Form):
	state = forms.IntegerField(required=True)
	code = forms.CharField(required=True)

class SmsContentForm(forms.Form):
	From = forms.CharField(required=True)
	Body = forms.CharField(required=False)
