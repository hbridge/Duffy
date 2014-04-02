package com.duffy;

import com.joestelmach.natty.*;


public class DateParse {
    public static void main(String args[]) {
	Parser parser = new Parser();
	System.out.println("Hello JBT!");
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