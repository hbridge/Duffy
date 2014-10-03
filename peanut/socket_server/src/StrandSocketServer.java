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

    public static void main(String[] args) throws IOException {
 
        if (args.length != 1) {
            System.err.println("Usage: java StrandSocketServer <port number>");
            System.exit(1);
        }

        // logging
        Logger logger = Logger.getLogger("SocketServerLog");  
    	FileHandler fh;  
		SimpleFormatter formatter;
    	
    	try {  

	        // This block configure the logger with handler and formatter  
	        fh = new FileHandler("/var/log/duffy/socket-server-java.log");  
	        logger.addHandler(fh);
	        formatter = new SimpleFormatter();  
	        fh.setFormatter(formatter);

    	} catch (SecurityException e) {  
        	e.printStackTrace();  
    	} catch (IOException e) {  
        	e.printStackTrace();  
    	} 
        
        StrandSocketServer ss = new StrandSocketServer();
        int portNumber = Integer.parseInt(args[0]);
        boolean listening = true;

	    logger.info("Starting StrandSocketServer...");  
        // Start the message processor to query database
        MessageProcessor mp = new MessageProcessor(ss.clients);
        mp.start();

        // Start monitoring port
        try (ServerSocket serverSocket = new ServerSocket(portNumber)) { 
            while (listening) {
                new MobileClient(serverSocket.accept(), ss.clients).start();
            }
        } catch (IOException e) {
            logger.info("Could not listen on port " + portNumber);
            System.exit(-1);
        }
    }

}