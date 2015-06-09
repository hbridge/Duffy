import pytz

from django.contrib import admin

from smskeeper.models import User, Entry
from smskeeper import keeper_constants
from smskeeper import user_util


def activate_to_remind(modeladmin, request, users):
	for user in users:
		user_util.activate(user, keeper_constants.FIRST_INTRO_MESSAGE_NO_MAGIC, keeper_constants.STATE_TUTORIAL_REMIND, user.getKeeperNumber())
activate_to_remind.short_description = "Activate to Remind Tutorial"


def activate_to_list(modeladmin, request, users):
	for user in users:
		user_util.activate(user, keeper_constants.FIRST_INTRO_MESSAGE_NO_MAGIC, False, keeper_constants.STATE_TUTORIAL_LIST, user.getKeeperNumber())
activate_to_list.short_description = "Activate to List Tutorial"


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
	list_display = ('id', 'activated', 'phone_number', 'name', 'state', 'completed_tutorial', 'state_data', 'print_last_message_date', 'total_msgs_from', 'history')
	actions = [activate_to_remind, activate_to_list]


@admin.register(Entry)
class EntryAdmin(admin.ModelAdmin):
	list_display = ('id', 'text', 'remind_timestamp', 'hidden')


class Reminder(Entry):
	class Meta:
		proxy = True


@admin.register(Reminder)
class ReminderAdmin(admin.ModelAdmin):

	def queryset(self, request):
		qs = super(ReminderAdmin, self).queryset(request)
		return qs.filter(remind_timestamp__isnull=False)

	def added_tz_aware(self, obj):
		return obj.added.astimezone(obj.creator.getTimezone()).replace(tzinfo=None)

	def remind_timestamp_tz_aware(self, obj):
		return obj.remind_timestamp.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)

	def remind_last_notified_tz_aware(self, obj):
		if obj.remind_last_notified:
			return obj.remind_last_notified.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)
		else:
			return ""

	def get_object(self, request, object_id):
		obj = super(ReminderAdmin, self).get_object(request, object_id)
		if obj is not None:
			obj.remind_timestamp = obj.remind_timestamp.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)
		return obj

	def save_model(self, request, obj, form, chage):
		# Time comes in as utc, so we need to convert back to user's timezone
		tz = obj.creator.getTimezone()
		obj.remind_timestamp = tz.localize(obj.remind_timestamp.replace(tzinfo=None))
		obj.save()

	list_display = ('id', 'creator', 'text', 'orig_text', 'remind_timestamp_tz_aware', 'remind_last_notified_tz_aware', 'added_tz_aware', 'hidden')
	readonly_fields = ['added_tz_aware']


class Todo(Reminder):
	class Meta:
		proxy = True


@admin.register(Todo)
class TodoAdmin(ReminderAdmin):

	def queryset(self, request):
		qs = super(TodoAdmin, self).queryset(request)
		return qs.filter(creator__product_id=1, label="#reminders")
