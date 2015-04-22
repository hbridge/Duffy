from gcalsync import register
from gcalsync.transformation import BaseTransformer
from models import Event

class EventTransformer(BaseTransformer):
    model = Event

    def transform(self, event_data):
        if not self.validate(event_data):
            return False

        start_datetime = self.parse_datetime(event_data['start']['dateTime'])
        end_datetime = self.parse_datetime(event_data['end']['dateTime'])

        return {
            'title': event_data['summary'],
            'start_date': start_datetime.date(),
            'start_time': start_datetime.time(),
            'end_date': end_datetime.date(),
            'end_time': end_datetime.time(),
            'url': event_data['htmlLink'],
            'event_id': event_data['id']
        }

register("primary", [EventTransformer])