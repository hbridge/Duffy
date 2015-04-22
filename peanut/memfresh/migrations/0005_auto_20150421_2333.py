# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0004_contactentry'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='followup',
            name='for_email',
        ),
        migrations.AddField(
            model_name='followup',
            name='contact',
            field=models.ForeignKey(default='', to='memfresh.ContactEntry'),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='user',
            name='email',
            field=models.CharField(default='', max_length=100),
            preserve_default=False,
        ),
    ]
