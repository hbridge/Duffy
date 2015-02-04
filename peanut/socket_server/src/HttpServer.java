import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;
import java.io.IOException;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.handler.AbstractHandler;

import java.util.*;
import java.util.logging.Logger;
import java.sql.*;

public class HttpServer extends AbstractHandler {
    private Hashtable<Integer, MobileClient> clients = null;
    Logger logger = Logger.getLogger("SocketServerLog");
    String dbURL;
    
    public HttpServer(Hashtable clients, String dbURL) {
        this.clients = (Hashtable<Integer,MobileClient>)clients;
        this.dbURL = "jdbc:" + dbURL;        
        logger.info("HttpServer started.");
    }

    public void handle(String target,
                       Request baseRequest,
                       HttpServletRequest request,
                       HttpServletResponse response) 
        throws IOException, ServletException {

        // expects a comma separated list of notification log ids
        String ids = request.getParameter("ids");

        // parse idlist and turn into a list
        if (ids != null) {
            List idList = HttpServer.stringToIntList(ids);

            if (idList.size() > 0) {
                logger.info("Ids converted to int: " + idList);
                NotificationLogsProcessor nlp = new NotificationLogsProcessor(clients, dbURL);
                nlp.processIds(idList);

            }

            response.setContentType("text/html;charset=utf-8");
            response.setStatus(HttpServletResponse.SC_OK);
            baseRequest.setHandled(true);
            response.getWriter().println("got: " + idList);
        }        
    }

    public static List stringToIntList(String paramValue){
        List idList = new ArrayList<Integer>();
        Integer currentId;

        String[] splitList = paramValue.split(",");

        if (splitList.length > 0) {
            for (String str : splitList) {
                try {
                    currentId = Integer.valueOf(str);
                    idList.add(currentId);
                } catch (NumberFormatException e){
                    continue;
                }
            }
        }
        return idList;
    }
}
