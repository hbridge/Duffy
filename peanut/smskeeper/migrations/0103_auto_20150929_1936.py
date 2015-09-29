# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0102_auto_20150929_1812'),
    ]

    operations = [
        migrations.RenameField(
            model_name='historicaluser',
            old_name='phone_number_info',
            new_name='carrier_info_json',
        ),
        migrations.RenameField(
            model_name='user',
            old_name='phone_number_info',
            new_name='carrier_info_json',
        ),
    ]
