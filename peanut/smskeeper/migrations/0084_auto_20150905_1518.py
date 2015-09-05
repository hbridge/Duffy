# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0083_merge'),
    ]

    operations = [
        migrations.CreateModel(
            name='SimulationResult',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('sim_id', models.IntegerField(null=True, blank=True)),
                ('git_revision', models.CharField(max_length=6, db_index=True)),
                ('sim_classification', models.CharField(db_index=True, max_length=100, null=True, blank=True)),
                ('sim_classification_scores_json', models.CharField(max_length=1000, null=True, blank=True)),
                ('message', models.ForeignKey(to='smskeeper.Message')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.AlterField(
            model_name='historicaluser',
            name='digest_state',
            field=models.CharField(default=b'default', max_length=20, choices=[(b'default', b'default'), (b'limited', b'limited'), (b'never', b'never')]),
        ),
    ]
