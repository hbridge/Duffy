
import pytz
import datetime

from django.contrib import admin
from django.db.models import Q
from django.utils import safestring

from smskeeper.models import User, Entry
from smskeeper import keeper_constants


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
	list_display = ('id', 'activated', 'phone_number', 'name', 'state', 'completed_tutorial', 'state_data', 'print_last_message_date', 'total_msgs_from', 'history')


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


def filterReminderQueryset(qs):
	return qs.filter(remind_timestamp__isnull=False).exclude(Q(creator__state=keeper_constants.STATE_STOPPED) | Q(creator__state=keeper_constants.STATE_SUSPENDED)).order_by("hidden", "remind_timestamp")

@admin.register(Reminder)
class ReminderAdmin(admin.ModelAdmin):

	def getNiceDate(self, obj, dt):
		if dt.year != 2015:
			dtBase = dt.strftime('%a, %b %d, %Y')
		else:
			dtBase = dt.strftime('%a, %b %d')
		dtTime = dt.strftime('%I:%M %p').lstrip("0").replace(" 0", " ")
		if obj.use_digest_time:
			return "%s, digest" % dtBase
		else:
			return "%s, %s" % (dtBase, dtTime)

	def queryset(self, request):
		qs = super(ReminderAdmin, self).queryset(request)
		return filterReminderQueryset(qs)

	def time_added_tz_aware(self, obj):
		dt = obj.added.astimezone(obj.creator.getTimezone()).replace(tzinfo=None)
		return self.getNiceDate(obj, dt)

	def remind_timestamp_tz_aware(self, obj):
		dt = obj.remind_timestamp.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)

		return self.getNiceDate(obj, dt)

	def product_id(self, obj):
		return obj.creator.product_id

	def remind_last_notified_tz_aware(self, obj):
		if obj.remind_last_notified:
			return obj.remind_last_notified.astimezone(obj.creator.getTimezone()).replace(tzinfo=pytz.utc)
		else:
			return ""

	def reminder_sent(self, obj):
		return not obj.remind_to_be_sent
	reminder_sent.boolean = True

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

	list_display = ('id', 'creator', 'text', 'orig_text', 'remind_timestamp_tz_aware', 'time_added_tz_aware', 'remind_recur', 'reminder_sent', 'hidden', 'updated')
	readonly_fields = ['time_added_tz_aware']
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
	# regular stuff
	class Media:
		js = (
			'//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js',  # jquery
			'smskeeper/admin.js',
		)

	def approve_button(self, obj):
		# This uses javascript from admin.js
		return safestring.mark_safe('<input type="button" onclick="approveEntry(\'%s\');" value="Approve"/>' % (obj.id))
	approve_button.short_description = 'Approve'
	approve_button.allow_tags = True

	def creator_with_link(self, obj):
		# This uses javascript from admin.js
		return safestring.mark_safe('<a href=\'/smskeeper/history?user_id=%s\'/>%s&nbsp;-&nbsp;%s</a>' % (obj.creator.id, obj.creator.id, obj.creator.name))
	creator_with_link.short_description = 'Id'
	creator_with_link.allow_tags = True

	actions = [mark_as_approved, mark_as_hidden]

	list_display = ('id', 'approve_button', 'creator_with_link', 'text', 'orig_text', 'remind_timestamp_tz_aware', 'time_added_tz_aware', 'remind_recur', 'reminder_sent', 'updated')

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
