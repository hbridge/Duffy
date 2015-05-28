# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0033_auto_20150527_1843'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='activated',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='last_state_change',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='last_tip_sent',
            field=models.DateTimeField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='name',
            field=models.CharField(max_length=100, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='sent_tips',
            field=models.TextField(null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='timezone',
            field=models.CharField(max_length=100, null=True, blank=True),
        ),
    ]
