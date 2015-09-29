# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0101_message_natty_result_pkl'),
    ]

    operations = [
        migrations.AddField(
            model_name='historicaluser',
            name='phone_number_info',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='phone_number_info',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
