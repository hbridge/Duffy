
import pytz
import datetime

from django.contrib import admin
from django.db.models import Q

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


def mark_as_hidden(modeladmin, request, entries):
	for entry in entries:
		entry.hidden = True
		entry.save()
mark_as_hidden.short_description = "Mark as hidden"


@admin.register(Reminder)
class ReminderAdmin(admin.ModelAdmin):

	def queryset(self, request):
		qs = super(ReminderAdmin, self).queryset(request)
		return qs.filter(remind_timestamp__isnull=False).exclude(Q(creator__state=keeper_constants.STATE_STOPPED) | Q(creator__state=keeper_constants.STATE_SUSPENDED)).order_by("hidden", "remind_timestamp")

	def added_tz_aware(self, obj):
		return obj.added.astimezone(obj.creator.getTimezone()).replace(tzinfo=None)

	def remind_timestamp_tz_aware(self, obj):
		return obj.remind_timestamp.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)

	def product_id(self, obj):
		return obj.creator.product_id

	def remind_last_notified_tz_aware(self, obj):
		if obj.remind_last_notified:
			return obj.remind_last_notified.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)
		else:
			return ""

	def get_object(self, request, object_id):
		obj = super(ReminderAdmin, self).get_object(request, object_id)
		if obj is not None:
			obj.remind_timestamp = obj.remind_timestamp.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)
			if obj.remind_last_notified:
				obj.remind_last_notified = obj.remind_last_notified.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)

		return obj

	def fix_timezones(self, obj):
		# Time comes in as utc, so we need to convert back to user's timezone
		tz = obj.creator.getTimezone()
		obj.remind_timestamp = tz.localize(obj.remind_timestamp.replace(tzinfo=None))
		if obj.remind_last_notified:
			obj.remind_last_notified = tz.localize(obj.remind_last_notified.replace(tzinfo=None))

	def save_model(self, request, obj, form, chage):
		self.fix_timezones(obj)

		obj.manually_updated = True
		obj.manually_updated_timestamp = datetime.datetime.now(pytz.utc)
		obj.save()

	list_display = ('id', 'creator', 'text', 'orig_text', 'remind_timestamp_tz_aware', 'added_tz_aware', 'remind_to_be_sent', 'hidden', 'updated')
	readonly_fields = ['added_tz_aware']
	search_fields = ['creator__id']

	actions = [mark_as_hidden]


class ToCheck(Reminder):
	class Meta:
		proxy = True


def mark_as_approved(modeladmin, request, entries):
	for entry in entries:
		entry.manually_check = False
		entry.manually_approved_timestamp = datetime.datetime.now(pytz.utc)
		entry.save()
mark_as_approved.short_description = "Mark as approved"


@admin.register(ToCheck)
class ToCheck(ReminderAdmin):

	actions = [mark_as_approved, mark_as_hidden]

	list_display = ('id', 'creator', 'text', 'orig_text', 'remind_timestamp_tz_aware', 'added_tz_aware', 'remind_to_be_sent', 'updated')


	def queryset(self, request):
		qs = super(ToCheck, self).queryset(request)
		return qs.filter(manually_check=True).exclude(hidden=True)

	def save_model(self, request, obj, form, chage):
		self.fix_timezones(obj)

		obj.manually_check = False
		obj.manually_approved_timestamp = datetime.datetime.now(pytz.utc)

		obj.manually_updated = True
		obj.manually_updated_timestamp = datetime.datetime.now(pytz.utc)

		obj.save()
