# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0089_merge'),
    ]

    operations = [
        migrations.CreateModel(
            name='SimulationRun',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('git_revision', models.CharField(max_length=7)),
                ('source', models.CharField(max_length=1, choices=[(b'p', b'prod'), (b'd', b'dev'), (b'l', b'local')])),
                ('sim_type', models.CharField(db_index=True, max_length=2, choices=[(b'pp', b'prodpush'), (b'dp', b'devpush'), (b't', b'test')])),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.RemoveField(
            model_name='simulationresult',
            name='git_revision',
        ),
        migrations.RemoveField(
            model_name='simulationresult',
            name='message_source',
        ),
        migrations.RemoveField(
            model_name='simulationresult',
            name='sim_id',
        ),
        migrations.RemoveField(
            model_name='simulationresult',
            name='sim_type',
        ),
        migrations.AddField(
            model_name='simulationresult',
            name='run',
            field=models.ForeignKey(to='smskeeper.SimulationRun', null=True),
            preserve_default=True,
        ),
    ]
