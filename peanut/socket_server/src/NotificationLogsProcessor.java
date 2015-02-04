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

import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.datasource.SimpleDriverDataSource;

public class NotificationLogsProcessor {
	
	// JDBC driver name and database URL
	static final String JDBC_DRIVER = "com.mysql.jdbc.Driver";

	//  Database credentials
	static final String USER = "djangouser";
	static final String PASS = "djangopass";	

	// taken from constants.py
	static final int IOS_NOTIFICATIONS_RESULT_ERROR = 0;
	static final int IOS_NOTIFICATIONS_RESULT_SENT = 1;

	private Hashtable<Integer, MobileClient> clients = null;
	private Connection dbConnection = null;
	Logger logger = Logger.getLogger("SocketServerLog");
	private NamedParameterJdbcTemplate jdbcTemplate;
	private SimpleDriverDataSource dataSource;

	public NotificationLogsProcessor(Hashtable clients, String dbURL) {
        this.clients = (Hashtable<Integer,MobileClient>)clients;
        
        this.dataSource = new SimpleDriverDataSource();
        try {
            dataSource.setDriverClass((Class<Driver>)Class.forName(JDBC_DRIVER));
            dataSource.setUsername(USER);
            dataSource.setUrl(dbURL);
            dataSource.setPassword(PASS);

        	this.jdbcTemplate = new NamedParameterJdbcTemplate(dataSource);
         } catch (ClassNotFoundException e) {
            e.printStackTrace();
         } catch (Exception e) {
         	e.printStackTrace();
         }
	}

	public void processIds(List<Integer> ids){
		// fetch those logs from the table
		List<NotLogIdToUserId> idUserList = getUserIdsFromLogs(ids);

		// Now iterate over them to see who's connected
		List<Long> successfullyRefreshedLogIds = new ArrayList<Long>();
		List<Long> failedRefreshLogIds = new ArrayList<Long>();


		for (NotLogIdToUserId entry : idUserList) {
			// If a user is current connected, send them a ping
			if (clients.containsKey(entry.userId)) {
				logger.info("Sending refresh message to " + entry.userId);
				clients.get(entry.userId).sendMessage("refresh:" + entry.notLogId);
				successfullyRefreshedLogIds.add(entry.notLogId);
			}
			// Otherwise, ignore
			else {
				logger.info("UserId not found in hashtable: " + entry.userId);
				failedRefreshLogIds.add(entry.notLogId);
			}
		}

		// Now update all rows with success or failure
		Map<String, List<Long>> param; 
		String sqlUpdate;

		if (successfullyRefreshedLogIds.size() > 0) {
			param = Collections.singletonMap("logIds",successfullyRefreshedLogIds);
			sqlUpdate = "UPDATE strand_notification_log SET result = " + IOS_NOTIFICATIONS_RESULT_SENT + " WHERE id IN (:logIds)";
			jdbcTemplate.update(sqlUpdate, param);
		}
		if (failedRefreshLogIds.size() > 0) {
			param = Collections.singletonMap("logIds",failedRefreshLogIds);
			sqlUpdate = "UPDATE strand_notification_log SET result = " + IOS_NOTIFICATIONS_RESULT_ERROR + " WHERE id IN (:logIds)";
			jdbcTemplate.update(sqlUpdate, param);
		}
	}

	/*
	Takes in a list of Notification Log Ids and returns a tuple of Id, userId in that log
	*/

	private List getUserIdsFromLogs(List<Integer> logIds){
		Map<String, List<Integer>> param = Collections.singletonMap("logIds",logIds);
		String sql = "Select id, user_id FROM strand_notification_log WHERE id IN (:logIds)";

		List<NotLogIdToUserId> rows = jdbcTemplate.query(sql, param, 
			new RowMapper<NotLogIdToUserId>() {
				@Override
				public NotLogIdToUserId mapRow(ResultSet resultSet, int rowNum) throws SQLException {
					return new NotLogIdToUserId(resultSet.getLong("id"), resultSet.getInt("user_id"));
				}
			}); 
	    return rows;
	}


	private class NotLogIdToUserId {
		public Long notLogId;
		public Integer userId;

		public NotLogIdToUserId(Long logId, Integer userId){
			this.notLogId = logId;
			this.userId = userId;
		}
	}
}
