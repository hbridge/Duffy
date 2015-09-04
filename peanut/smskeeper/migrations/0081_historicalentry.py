# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('smskeeper', '0080_auto_20150831_2139'),
    ]

    operations = [
        migrations.CreateModel(
            name='HistoricalEntry',
            fields=[
                ('id', models.IntegerField(verbose_name='ID', db_index=True, auto_created=True, blank=True)),
                ('label', models.CharField(db_index=True, max_length=100, blank=True)),
                ('text', models.TextField(null=True, blank=True)),
                ('orig_text', models.TextField(null=True, blank=True)),
                ('img_url', models.TextField(null=True, blank=True)),
                ('remind_timestamp', models.DateTimeField(null=True, blank=True)),
                ('remind_last_notified', models.DateTimeField(null=True, blank=True)),
                ('remind_to_be_sent', models.BooleanField(default=True, db_index=True)),
                ('use_digest_time', models.BooleanField(default=False)),
                ('remind_recur', models.CharField(default=b'default', max_length=100, choices=[(b'default', b'default'), (b'one-time', b'one-time'), (b'weekly', b'weekly'), (b'weekdays', b'weekdays'), (b'daily', b'daily'), (b'monthly', b'monthly'), (b'every-2-days', b'every-2-days')])),
                ('remind_recur_end', models.DateTimeField(null=True, blank=True)),
                ('hidden', models.BooleanField(default=False)),
                ('manually_updated', models.BooleanField(default=False)),
                ('manually_updated_timestamp', models.DateTimeField(null=True, blank=True)),
                ('state', models.CharField(default=b'normal', max_length=100, choices=[(b'normal', b'normal'), (b'swept', b'swept')])),
                ('last_state_change', models.DateTimeField(null=True, blank=True)),
                ('manually_check', models.BooleanField(default=False)),
                ('manually_approved_timestamp', models.DateTimeField(null=True, blank=True)),
                ('created_from_entry_id', models.IntegerField(null=True, blank=True)),
                ('added', models.DateTimeField(db_index=True, null=True, editable=False, blank=True)),
                ('updated', models.DateTimeField(db_index=True, null=True, editable=False, blank=True)),
                ('history_id', models.AutoField(serialize=False, primary_key=True)),
                ('history_date', models.DateTimeField()),
                ('history_type', models.CharField(max_length=1, choices=[('+', 'Created'), ('~', 'Changed'), ('-', 'Deleted')])),
                ('creator', models.ForeignKey(related_name='+', on_delete=django.db.models.deletion.DO_NOTHING, db_constraint=False, blank=True, to='smskeeper.User', null=True)),
                ('history_user', models.ForeignKey(related_name='+', on_delete=django.db.models.deletion.SET_NULL, to=settings.AUTH_USER_MODEL, null=True)),
            ],
            options={
                'ordering': ('-history_date', '-history_id'),
                'get_latest_by': 'history_date',
                'verbose_name': 'historical entry',
            },
            bases=(models.Model,),
        ),
    ]
