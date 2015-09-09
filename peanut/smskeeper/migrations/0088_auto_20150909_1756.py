# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0087_zipdata_temp_format'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='simulationresult',
            name='message',
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='message_auto_classification',
            field=models.CharField(max_length=100, null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='message_body',
            field=models.TextField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='message_classification',
            field=models.CharField(max_length=100, null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='message_id',
            field=models.IntegerField(default=0),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='message_source',
            field=models.CharField(default='l', max_length=1, choices=[(b'p', b'prod'), (b'd', b'dev'), (b'l', b'local')]),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='sim_type',
            field=models.CharField(default='t', max_length=2, db_index=True, choices=[(b'pp', b'prodpush'), (b'dp', b'devpush'), (b't', b'test')]),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name='simulationresult',
            name='sim_classification',
            field=models.CharField(max_length=100, null=True, blank=True),
        ),
        migrations.AlterField(
            model_name='simulationresult',
            name='sim_id',
            field=models.IntegerField(db_index=True, null=True, blank=True),
        ),
    ]
