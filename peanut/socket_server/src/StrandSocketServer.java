/*
 * Author: Aseem Sood
 * Date: 10/2/2014
 */

import java.net.*;
import java.io.*;
import java.util.*;
import java.util.logging.*;
import java.sql.*;
 
public class StrandSocketServer {

    Hashtable<Integer, MobileClient> clients;
    Logger logger;

    public StrandSocketServer(){

        this.clients = new Hashtable<Integer, MobileClient>();         
    }

    public void cleanupHashtable(){
        Enumeration<Integer> keys = clients.keys();
        MobileClient mc;
        Integer key, keysRemoved = 0;
        Calendar hourAgo = Calendar.getInstance();        
        hourAgo.add(Calendar.HOUR, -1);

        while (keys.hasMoreElements()){
            key = keys.nextElement();
            mc = clients.get(key);        
            if (mc.getTimeStarted().before(hourAgo.getTime())){
                clients.remove(key);
                logger.info("Removed " + key);
                keysRemoved++;
            }
        }
    }

    public static void main(String[] args) throws IOException {
 
        if (args.length != 2) {
            System.err.println("Usage: java StrandSocketServer <port number> <db_url>");
            System.exit(1);
        }
        
        StrandSocketServer ss = new StrandSocketServer();
        int portNumber = Integer.parseInt(args[0]);
        String dbURL = args[1];
        boolean listening = true;

        // logging
        ss.logger = Logger.getLogger("SocketServerLog");  
        FileHandler fh;  
        SimpleFormatter formatter;
        
        try {  

            // This block configure the logger with handler and formatter  
            fh = new FileHandler("/var/log/duffy/socket-server-java.log");  
            ss.logger.addHandler(fh);
            formatter = new SimpleFormatter();  
            fh.setFormatter(formatter);

        } catch (SecurityException e) {  
            e.printStackTrace();  
        } catch (IOException e) {  
            e.printStackTrace();  
        } 

	    ss.logger.info("Starting StrandSocketServer...");  
        // Start the message processor to query database
        MessageProcessor mp = new MessageProcessor(ss.clients, dbURL);
        mp.start();

        // Start monitoring port
        try (ServerSocket serverSocket = new ServerSocket(portNumber)) { 
            while (listening) {
                new MobileClient(serverSocket.accept(), ss.clients).start();
                ss.cleanupHashtable();
            }
        } catch (IOException e) {
            ss.logger.info("Could not listen on port " + portNumber);
            System.exit(-1);
        }
    }

}