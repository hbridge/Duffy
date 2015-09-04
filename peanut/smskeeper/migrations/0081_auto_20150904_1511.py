# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0080_auto_20150831_2139'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='digest_state',
            field=models.CharField(default=b'default', max_length=20, choices=[(b'default', b'default'), (b'limited', b'limited'), (b'never', b'never')]),
        ),
    ]
