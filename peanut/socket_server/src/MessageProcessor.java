/*
 * Author: Aseem Sood
 * Date: 10/2/2014
 */

import java.net.*;
import java.io.*;
import java.util.*;
import java.util.Date;
import java.util.logging.Logger;
import java.sql.*;
import java.text.*;

public class MessageProcessor extends Thread {
	
	// JDBC driver name and database URL
	static final String JDBC_DRIVER = "com.mysql.jdbc.Driver";
	static final String DB_URL = "jdbc:mysql://localhost:3306/duffy";

	//  Database credentials
	static final String USER = "djangouser";
	static final String PASS = "djangopass";	

	// taken from constants.py
	static final int IOS_NOTIFICATIONS_RESULT_ERROR = 0;
	static final int IOS_NOTIFICATIONS_RESULT_SENT = 1;

	private Hashtable<Integer, MobileClient> clients = null;
	private Connection dbConnection = null;
	Logger logger = Logger.getLogger("SocketServerLog");

	public MessageProcessor(Hashtable clients) {
        this.clients = (Hashtable<Integer,MobileClient>)clients;
	}

	public void run(){
		logger.info("Starting MessageProcessor...");

		Statement stmt = null;
		ResultSet logEntry = null;

		Date timeWithin, dAdded = null;
		SimpleDateFormat dft = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

		String sqlFetch = null;
		String sqlUpdate = "UPDATE strand_notification_log SET result = ? WHERE id = ?";
		PreparedStatement bulkUpdateStmt;
		Boolean writeToDatabase = false;

		try {
			Class.forName("com.mysql.jdbc.Driver");

			dbConnection = DriverManager.getConnection(DB_URL,USER,PASS);

			stmt = dbConnection.createStatement();

			while (true){
				// Calculate time interval
				timeWithin = new Date();
				timeWithin.setTime(timeWithin.getTime() - (timeWithin.getTime() % 1000)); // take out the milliseconds

				if (timeWithin.getSeconds() < 4) {
					timeWithin.setSeconds(0);
					timeWithin.setMinutes(timeWithin.getMinutes()-1);
				}
				else {
					timeWithin.setSeconds(0);
				}

				System.err.println(dft.format(timeWithin));

				// Fetch and process entries from database
				sqlFetch = "SELECT * FROM strand_notification_log WHERE result is null and msg_type=8 and added >='" + dft.format(timeWithin) + "'";
				logEntry = stmt.executeQuery(sqlFetch);


				bulkUpdateStmt = dbConnection.prepareStatement(sqlUpdate);
				dbConnection.setAutoCommit(false);
				writeToDatabase = false;

				while (logEntry.next()) {
					int userId = logEntry.getInt("user_id");
					int logEntryId = logEntry.getInt("id");
					System.err.println(userId);
					System.err.println(logEntryId);
					if (clients.containsKey(userId)) {
						logger.info("Sending refresh message to " + userId);
						clients.get(userId).sendMessage("refresh:" + logEntry.getInt("id"));
						
						// update logEntry
						bulkUpdateStmt.setInt(1, MessageProcessor.IOS_NOTIFICATIONS_RESULT_SENT);
						bulkUpdateStmt.setInt(2, logEntryId);
						bulkUpdateStmt.addBatch();
						writeToDatabase = true;
					}

					String sAdded = logEntry.getString("added");

      				try { 
          				dAdded = dft.parse(sAdded); 
      				} catch (ParseException e) { 
          				logger.info("Unparseable using " + dft); 
     				}

					if ((new Date()).getTime() - dAdded.getTime() > 4000) {
						// update logEntry
						bulkUpdateStmt.setInt(1, MessageProcessor.IOS_NOTIFICATIONS_RESULT_ERROR);
						bulkUpdateStmt.setInt(2, logEntryId);
						bulkUpdateStmt.addBatch();
						writeToDatabase = true;
						logger.info("Failed to send to " + userId + " after 4 seconds, canceling");
					}

				}
 				if (writeToDatabase == true) {
					int[] numUpdates = bulkUpdateStmt.executeBatch();
					dbConnection.commit();
					writeToDatabase = false;
				}
				else {
					dbConnection.setAutoCommit(true);
					try {
						Thread.sleep(1000); 
					} catch(InterruptedException ex) {
						Thread.currentThread().interrupt();
					}
				}

			}

		} catch (SQLException se) {
			se.printStackTrace();
		} catch (Exception e) {
			//Handle errors for Class.forName
			e.printStackTrace();
		} finally {
				//finally block used to close resources
			try {
				if (stmt!=null) {
					stmt.close();
				}
			} catch(SQLException se2){
				// nothing we can do	
			}
			try {
				if (dbConnection != null) {
					dbConnection.close();
				}
			} catch (SQLException se){
				se.printStackTrace();
			} //end finally try
		}//end try
	}
}
