package com.duffy;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;
import java.io.IOException;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.handler.AbstractHandler;

import java.util.*;
import com.joestelmach.natty.*;

import com.google.gson.Gson;

public class NattyDateParserServer extends AbstractHandler
{
    public class NattyResult {
        private List<Date> dates;
        private List<Long> timestamps;
        private String matchingValue;
	    private String syntaxTree;
        private int column;

        public NattyResult( DateGroup dateGroup) {
            this.dates = dateGroup.getDates();

            this.timestamps = new ArrayList<Long>();
            for (Date date : dates) {
                timestamps.add(date.getTime() / 1000);
            }

            this.matchingValue = dateGroup.getText();
            this.column = dateGroup.getPosition();
	        this.syntaxTree = dateGroup.getSyntaxTree().toStringTree();
        }
        /*
            List<Date> dates = group.getDates();
            int line = group.getLine();
            int column = group.getPosition();
            String matchingValue = group.getText();
            String syntaxTree = group.getSyntaxTree().toStringTree();
            Map<String, List<ParseLocation>> parseMap = group.getParseLocations();
            boolean isRecurreing = group.isRecurring();
            Date recursUntil = group.getRecursUntil();
        */

    }

    public void handle(String target,
                       Request baseRequest,
                       HttpServletRequest request,
                       HttpServletResponse response)
        throws IOException, ServletException
    {
        Date baseDate;
    	String query = request.getParameter("q");
    	String tz = request.getParameter("tz");
        String baseDateStr = request.getParameter("baseDate");

    	if (tz == null) {
    	    tz = "US/Eastern";
    	}

        System.out.println(baseDateStr);
        if (baseDateStr == null) {
            baseDate = new Date();
        } else {
            baseDate = new Date(Long.parseLong(baseDateStr) * 1000);
        }

        CalendarSource.setBaseDate(baseDate);
        Parser parser = new Parser(TimeZone.getTimeZone(tz));
        Gson gson = new Gson();


        if (query != null) {
            System.out.println(query);

            List<DateGroup> groups = parser.parse(query);
            List<NattyResult> nattyResults = new ArrayList<NattyResult>();

            for (DateGroup group : groups) {
                NattyResult result = new NattyResult(group);
                nattyResults.add(result);
            }

            String json = gson.toJson(nattyResults);
            System.out.println(json);

            response.setContentType("text/html;charset=utf-8");
            response.setStatus(HttpServletResponse.SC_OK);
            baseRequest.setHandled(true);
            response.getWriter().println(json);
        }


    }

    public static void main(String[] args) throws Exception
    {
        Server server = new Server(7990);
        server.setHandler(new NattyDateParserServer());

        System.out.println("Hello World!");

        server.start();
        server.join();
    }
}

    /*
static int main
Parser parser = new Parser();
List groups = parser.parse("the day before next thursday");
for(DateGroup group:groups) {
    List dates = group.getDates();
    int line = group.getLine();
    int column = group.getPosition();
    String matchingValue = group.getText();
    String syntaxTree = group.getSyntaxTree().toStringTree();
    Map> parseMap = group.getParseLocations();
    boolean isRecurreing = group.isRecurring();
    Date recursUntil = group.getRecursUntil();
}
    */
