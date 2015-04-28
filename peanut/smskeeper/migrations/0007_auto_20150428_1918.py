# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0006_auto_20150424_2216'),
    ]

    operations = [
        migrations.RenameField(
            model_name='noteentry',
            old_name='img_urls_json',
            new_name='img_url',
        ),
    ]
