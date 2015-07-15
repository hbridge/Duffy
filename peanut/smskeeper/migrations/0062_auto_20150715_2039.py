# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0061_auto_20150715_2029'),
    ]

    operations = [
        migrations.RenameField(
            model_name='user',
            old_name='zipcode',
            new_name='postal_code',
        ),
        migrations.AddField(
            model_name='user',
            name='wxcode',
            field=models.CharField(max_length=10, null=True, blank=True),
            preserve_default=True,
        ),
    ]
