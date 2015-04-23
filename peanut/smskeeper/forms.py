from django import forms


class UserIdForm(forms.Form):
	user_id = forms.IntegerField(required=True)

class SmsContentForm(forms.Form):
	From = forms.CharField(required=True)
	Body = forms.CharField(required=False)