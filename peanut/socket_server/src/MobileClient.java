/*
 * Author: Aseem Sood
 * Date: 10/2/2014
 */

import java.net.*;
import java.io.*;
import java.util.*;
import java.util.logging.Logger;
 
public class MobileClient extends Thread {
    private Socket socket = null;
    private PrintWriter out = null;
    private Hashtable<Integer, MobileClient> clients = null;
    private Logger logger = Logger.getLogger("SocketServerLog"); 
 
    public MobileClient(Socket socket, Hashtable clients) {
        super("MobileClient");
        this.socket = socket;
        this.clients = (Hashtable<Integer,MobileClient>)clients;
    }
    
    public void sendMessage(String msg){
        if (out != null) {
            out.println(msg + "\n");
        }
    }

    public void run() {
        
        try (
            
            BufferedReader in = new BufferedReader(
                new InputStreamReader(
                    socket.getInputStream()));
        ) {
            this.out = new PrintWriter(socket.getOutputStream(), true);
            logger.info("New MobileClient connected");
            String input;
            // keep connection open
            while ((input = in.readLine()) != null) {
                // Check for initial registration from client
                if (input != null) {
                    String[] splitInput = input.split(":");

                    if (splitInput.length > 1) {
                        if (splitInput[0].equalsIgnoreCase("user_id")) {
                            int userId = Integer.parseInt(splitInput[1].trim());

                            // add to client list
                            clients.put(userId, this);
                            logger.info("Got user id: " + userId);
                        }
                    }
                }              
            }
            //socket.close();

        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}