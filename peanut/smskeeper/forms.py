from django import forms


class UserIdForm(forms.Form):
	user_id = forms.IntegerField(required=True)

class SmsContentForm(forms.Form):
	From = forms.CharField(required=True)
	To = forms.CharField(required=False)
	Body = forms.CharField(required=False)
	NumMedia = forms.IntegerField(required=False)

class AllNotesForm(forms.Form):
        PhoneNum = forms.CharField(required=True)
        KeeperNum = forms.CharField(required=True)
