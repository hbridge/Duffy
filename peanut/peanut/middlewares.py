from time import time
from operator import add
import re
import logging

from django.db import connection




class StatsMiddleware(object):

    def process_view(self, request, view_func, view_args, view_kwargs):
        '''
        In your base template, put this:
        <div id="stats">
        <!-- STATS: Total: %(total_time).2fs Python: %(python_time).2fs DB: %(db_time).2fs Queries: %(db_queries)d ENDSTATS -->
        </div>
        '''

        if (not request.path.startswith('/viz/') and (not request.path.startswith('/strand/viz/'))):
            return None

        # Uncomment the following if you want to get stats on DEBUG=True only
        #if not settings.DEBUG:
        #    return None

        # get number of db queries before we do anything
        n = len(connection.queries)

        # time the view
        start = time()
        response = view_func(request, *view_args, **view_kwargs)
        total_time = time() - start

        # compute the db time for the queries just run
        db_queries = len(connection.queries) - n
        if db_queries:
            db_time = reduce(add, [float(q['time'])
                                   for q in connection.queries[n:]])
        else:
            db_time = 0.0

        # and backout python time
        python_time = total_time - db_time

        stats = {
            'total_time': total_time,
            'python_time': python_time,
            'db_time': db_time,
            'db_queries': db_queries,
        }

        # replace the comment if found
        if response and response.content:
            s = response.content
            regexp = re.compile(r'(?P<cmt><!--\s*STATS:(?P<fmt>.*?)ENDSTATS\s*-->)')
            match = regexp.search(s)
            if match:
                s = (s[:match.start('cmt')] +
                     match.group('fmt') % stats +
                     s[match.end('cmt'):])
                response.content = s

        return response
""" 

commenting out due to it raising DisallowedHost
Could put in that check but also it doesn't seem to really be working

class SqlLogMiddleware(object):
    logging.basicConfig(filename='/mnt/log/requests.log',
                        level=logging.DEBUG,
                        format='%(asctime)s %(levelname)s %(message)s')
    logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
    logger = logging.getLogger(__name__)

    def process_response(self, request, response):
        
        sqltime = 0 # Variable to store execution time
        for query in connection.queries:
            sqltime += float(query["time"])  # Add the time that the query took to the total
 
        try:
            # len(connection.queries) = total number of queries
            self.logger.info("Page render for url %s: %s sec with %s queries" % (request.build_absolute_uri(), unicode(sqltime), unicode(len(connection.queries))))

        
        return response
"""