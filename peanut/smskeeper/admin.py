from django.conf import settings

from django.contrib import admin

from smskeeper.models import User
from smskeeper import keeper_constants
from smskeeper import user_util


def activate_to_remind(modeladmin, request, users):
	for user in users:
		user_util.activate(user, False, keeper_constants.STATE_TUTORIAL_REMIND, settings.KEEPER_NUMBER)
activate_to_remind.short_description = "Activate to Remind Tutorial"


def activate_to_list(modeladmin, request, users):
	for user in users:
		user_util.activate(user, False, keeper_constants.STATE_TUTORIAL_LIST, settings.KEEPER_NUMBER)
activate_to_list.short_description = "Activate to List Tutorial"


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
	list_display = ('id', 'activated', 'phone_number', 'name', 'state', 'completed_tutorial', 'state_data', 'print_last_message_date', 'total_msgs_from', 'history')
	actions = [activate_to_remind, activate_to_list]
