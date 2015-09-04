# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('smskeeper', '0081_historicalentry'),
    ]

    operations = [
        migrations.CreateModel(
            name='HistoricalUser',
            fields=[
                ('id', models.IntegerField(verbose_name='ID', db_index=True, auto_created=True, blank=True)),
                ('phone_number', models.CharField(max_length=100, db_index=True)),
                ('name', models.CharField(max_length=100, blank=True)),
                ('completed_tutorial', models.BooleanField(default=False)),
                ('tutorial_step', models.IntegerField(default=0)),
                ('product_id', models.IntegerField(default=0)),
                ('activated', models.DateTimeField(null=True, blank=True)),
                ('paused', models.BooleanField(default=False)),
                ('last_paused_timestamp', models.DateTimeField(null=True, blank=True)),
                ('state', models.CharField(default=b'not-activated', max_length=100, choices=[(b'normal', b'normal'), (b'help', b'help'), (b'not-activated', b'not-activated'), (b'tutorial-list', b'tutorial-list'), (b'tutorial-remind', b'tutorial-remind'), (b'tutorial-todo', b'tutorial-todo'), (b'tutorial-student', b'tutorial-student'), (b'remind', b'remind'), (b'reminder-sent', b'reminder-sent'), (b'delete', b'delete'), (b'add', b'add'), (b'implicit-label', b'implicit-label'), (b'unresolved-handles', b'unresolved-handles'), (b'unknown-command', b'unknown-command'), (b'stopped', b'stopped'), (b'suspended', b'suspended'), (b'not-activated-from-reminder', b'not-activated-from-reminder'), (b'tutorial-medical', b'tutorial-medical'), (b'joke-sent', b'joke-sent'), (b'survey-sent', b'survey-sent')])),
                ('last_state', models.CharField(default=b'not-activated', max_length=100, choices=[(b'normal', b'normal'), (b'help', b'help'), (b'not-activated', b'not-activated'), (b'tutorial-list', b'tutorial-list'), (b'tutorial-remind', b'tutorial-remind'), (b'tutorial-todo', b'tutorial-todo'), (b'tutorial-student', b'tutorial-student'), (b'remind', b'remind'), (b'reminder-sent', b'reminder-sent'), (b'delete', b'delete'), (b'add', b'add'), (b'implicit-label', b'implicit-label'), (b'unresolved-handles', b'unresolved-handles'), (b'unknown-command', b'unknown-command'), (b'stopped', b'stopped'), (b'suspended', b'suspended'), (b'not-activated-from-reminder', b'not-activated-from-reminder'), (b'tutorial-medical', b'tutorial-medical'), (b'joke-sent', b'joke-sent'), (b'survey-sent', b'survey-sent')])),
                ('state_data', models.TextField(null=True, blank=True)),
                ('next_state', models.CharField(max_length=100, null=True, blank=True)),
                ('next_state_data', models.TextField(null=True, blank=True)),
                ('last_state_change', models.DateTimeField(null=True, blank=True)),
                ('signup_data_json', models.TextField(null=True, blank=True)),
                ('invite_code', models.CharField(max_length=100, null=True, blank=True)),
                ('key', models.CharField(max_length=100, null=True, blank=True)),
                ('timezone', models.CharField(max_length=100, null=True, blank=True)),
                ('postal_code', models.CharField(max_length=10, null=True, blank=True)),
                ('wxcode', models.CharField(max_length=10, null=True, blank=True)),
                ('signature_num_lines', models.IntegerField(null=True)),
                ('stripe_data_json', models.TextField(null=True, blank=True)),
                ('sent_tips', models.TextField(null=True, blank=True)),
                ('disable_tips', models.BooleanField(default=False)),
                ('digest_hour', models.IntegerField(default=9)),
                ('digest_minute', models.IntegerField(default=0)),
                ('digest_state', models.CharField(default=b'default', max_length=20, choices=[(b'default', b'default'), (b'limited', b'limited')])),
                ('tip_frequency_days', models.IntegerField(default=3)),
                ('last_tip_sent', models.DateTimeField(null=True, blank=True)),
                ('added', models.DateTimeField(db_index=True, null=True, editable=False, blank=True)),
                ('updated', models.DateTimeField(db_index=True, null=True, editable=False, blank=True)),
                ('last_share_upsell', models.DateTimeField(null=True, blank=True)),
                ('last_feedback_prompt', models.DateTimeField(null=True, blank=True)),
                ('temp_format', models.CharField(default=b'imperial', max_length=10, choices=[(b'imperial', b'imperial'), (b'metric', b'metric')])),
                ('done_count', models.IntegerField(default=0)),
                ('create_todo_count', models.IntegerField(default=0)),
                ('history_id', models.AutoField(serialize=False, primary_key=True)),
                ('history_date', models.DateTimeField()),
                ('history_type', models.CharField(max_length=1, choices=[('+', 'Created'), ('~', 'Changed'), ('-', 'Deleted')])),
                ('history_user', models.ForeignKey(related_name='+', on_delete=django.db.models.deletion.SET_NULL, to=settings.AUTH_USER_MODEL, null=True)),
            ],
            options={
                'ordering': ('-history_date', '-history_id'),
                'get_latest_by': 'history_date',
                'verbose_name': 'historical user',
            },
            bases=(models.Model,),
        ),
    ]
