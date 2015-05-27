# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0032_user_last_share_upsell'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='manual',
            field=models.BooleanField(default=None),
            preserve_default=True,
        ),
        migrations.AlterField(
            model_name='entry',
            name='keeper_number',
            field=models.CharField(max_length=100, null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='entry',
            name='label',
            field=models.CharField(db_index=True, max_length=100, blank=True),
        ),
        migrations.AlterField(
            model_name='entry',
            name='orig_text',
            field=models.TextField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='entry',
            name='remind_timestamp',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='entry',
            name='text',
            field=models.TextField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='invite_code',
            field=models.CharField(max_length=100, null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='last_share_upsell',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='next_state',
            field=models.CharField(max_length=100, null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='next_state_data',
            field=models.TextField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='signup_data_json',
            field=models.TextField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='state_data',
            field=models.TextField(null=True, blank=True),
        ),
    ]
