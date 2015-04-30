package com.joestelmach.natty;

import junit.framework.Assert;
import org.junit.BeforeClass;
import org.junit.Test;

import java.text.DateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;

/**
 * 
 * @author Joe Stelmach
 */
public class SearchTest extends AbstractTest {
  @BeforeClass
  public static void oneTime() {
    Locale.setDefault(Locale.US);
    TimeZone.setDefault(TimeZone.getTimeZone("US/Eastern"));
    initCalendarAndParser();
  }
  
  @Test
  public void test() throws Exception {
    Date reference = DateFormat.getDateInstance(DateFormat.SHORT).parse("2/20/2011");
    CalendarSource.setBaseDate(reference);
    
    Parser parser = new Parser();
    List<DateGroup> groups = parser.parse("golf tomorrow at 9 AM at pebble beach");
    Assert.assertEquals(1, groups.size());
    DateGroup group = groups.get(0);
    Assert.assertEquals(1, group.getLine());
    Assert.assertEquals(6, group.getPosition());
    Assert.assertEquals(1, group.getDates().size());
    validateDate(group.getDates().get(0), 2, 21, 2011);
    validateTime(group.getDates().get(0), 9, 0, 0);
    
    groups = parser.parse("golf with friends tomorrow at 10 ");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    Assert.assertEquals(1, group.getLine());
    Assert.assertEquals(19, group.getPosition());
    Assert.assertEquals(1, group.getDates().size());
    validateDate(group.getDates().get(0), 2, 21, 2011);
    validateTime(group.getDates().get(0), 10, 0, 0);
    
    parser = new Parser();
    groups = parser.parse("golf with freinds tomorrow at 9 or Thursday at 10 am");
    Assert.assertEquals(1, groups.size());
    List<Date> dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 21, 2011); 
    validateTime(dates.get(0), 9, 0, 0); 
    validateDate(dates.get(1), 2, 24, 2011); 
    validateTime(dates.get(1), 10, 0, 0); 
    
    groups = parser.parse("golf with friends tomorrow at 9 or Thursday at 10");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 21, 2011); 
    validateTime(dates.get(0), 9, 0, 0); 
    validateDate(dates.get(1), 2, 24, 2011); 
    validateTime(dates.get(1), 10, 0, 0); 
    
    groups = parser.parse("I want to go to park tomorrow and then email john@aol.com");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 21, 2011); 
    
    groups = parser.parse("I want to pay off all my debt in the next two years.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 
    validateDate(dates.get(1), 2, 20, 2013); 
    
    groups = parser.parse("I want to purchase a car in the next month.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 3, 20, 2011); 
    
    groups = parser.parse("I want to plan a get-together with my friends for this Friday.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 25, 2011); 
    
    groups = parser.parse("I want to lose five pounds in the next two months.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 
    validateDate(dates.get(1), 4, 20, 2011); 
    
    groups = parser.parse("I want to finalize my college schedule by next week.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 27, 2011); 
    
    groups = parser.parse("I want to read this weekend.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 26, 2011); 
    
    groups = parser.parse("I want to travel a big chunk of world next year.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 20, 2012); 
    
    groups = parser.parse("last 2 weeks");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 
    validateDate(dates.get(1), 2, 6, 2011); 
    
    groups = parser.parse("last 5 years");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 
    validateDate(dates.get(1), 2, 20, 2006); 
    
    groups = parser.parse("next 5 years");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(2, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 
    validateDate(dates.get(1), 2, 20, 2016); 
    
    groups = parser.parse("I want to go to my doctors appointment on May 15, 2011.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 5, 15, 2011); 
    
    groups = parser.parse("I intend to become a zombie on December, 21st 2012.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 12, 21, 2012); 
    
    groups = parser.parse("I want to hire a virtual assistant to do research for me on March 15, 2011");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 3, 15, 2011); 
    
    groups = parser.parse("I want to see my mother on sunday.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 27, 2011); 
    
    groups = parser.parse("I want to be able to jog 3 miles non-stop by September.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 1, 2011);
    
    groups = parser.parse("I want to lose 10 lbs in 10 days");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 3, 2, 2011); 
    
    groups = parser.parse("I want to visit my grandfathers grave on December 30 2011");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 12, 30, 2011); 
    
    groups = parser.parse("i want to have 1 kid this year");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 20, 2011); 

    groups = parser.parse("save $1000 by September");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 1, 2011);

    groups = parser.parse("have my son play at muse music in provo UT at the 3 band cause they always have fog on the third band at 7:30");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDateTime(dates.get(0), 2, 20, 2011, 7, 30, 0); 
    
    groups = parser.parse("i want to eat chinese tonight");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDateTime(dates.get(0), 2, 20, 2011, 20, 0, 0); 
    
    groups = parser.parse("Watch School Spirits on June 20 on syfy channel");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 6, 20, 2011);
    
    groups = parser.parse("Watch School Spirits on June 20 on");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 6, 20, 2011);
    
    groups = parser.parse("Watch School Spirits on June 20");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 6, 20, 2011);
    
    groups = parser.parse("hillary clinton sep 13, 2013");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 13, 2013);
    Assert.assertEquals(17, groups.get(0).getPosition());
    Assert.assertEquals("sep 13, 2013", groups.get(0).getText());
    
    groups = parser.parse("hillary clinton 9/13/2013");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 13, 2013);
    Assert.assertEquals(17, groups.get(0).getPosition());
    Assert.assertEquals("9/13/2013", groups.get(0).getText());
    
    groups = parser.parse("hillary clintoo sep 13, 2013");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 13, 2013);
    Assert.assertEquals(17, groups.get(0).getPosition());
    Assert.assertEquals("sep 13, 2013", groups.get(0).getText());
    
    groups = parser.parse("clinton sep 13 2013");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 13, 2013);
    Assert.assertEquals(9, groups.get(0).getPosition());
    Assert.assertEquals("sep 13 2013", groups.get(0).getText());
    
    groups = parser.parse("wedding dinner with Pam");
    Assert.assertEquals(0, groups.size());
    
    groups = parser.parse("yummy fried chicken");
    Assert.assertEquals(0, groups.size());
    
    groups = parser.parse("I am friend with Pam");
    Assert.assertEquals(0, groups.size());
    
    groups = parser.parse("bfriday blah blah");
    Assert.assertEquals(0, groups.size());
    
    groups = parser.parse("dinner bmong friends");
    Assert.assertEquals(0, groups.size());

    groups = parser.parse("I know we should meet tomorrow");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 2, 21, 2011);

    groups = parser.parse("**SHOT 01/31/15**");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 1, 31, 2015);

    groups = parser.parse("KOSTROMA REGION, RUSSIA. SEPTEMBER 24, 2014. A woman cleaning up fallen leaves on the grounds of the Shchelykovo museum reserve of Russian playwright Alexander Ostrovsky.");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 9, 24, 2014);

    groups = parser.parse("21 November 2014-NYC-USA **** STRICTLY NOT AVAILABLE FOR USA ***");
    Assert.assertEquals(1, groups.size());
    dates = groups.get(0).getDates();
    Assert.assertEquals(1, dates.size());
    validateDate(dates.get(0), 11, 21, 2014);
  }

  @Test
  public void testLocations() throws Exception {
    Date reference = DateFormat.getDateInstance(DateFormat.SHORT).parse("2/20/2011");
    CalendarSource.setBaseDate(reference);

    Parser parser = new Parser();
    List<DateGroup> groups = parser.parse("I want to go to the movies on september 1st.  Or maybe we should go on October 3rd.");
    Assert.assertEquals(2, groups.size());
    DateGroup group = groups.get(0);
    Assert.assertEquals(1, group.getLine());
    Assert.assertEquals(31, group.getPosition());
    group = groups.get(1);
    Assert.assertEquals(1, group.getLine());
    Assert.assertEquals(72, group.getPosition());

    groups = parser.parse("I want to go to \nthe movies on september 1st to see The Alan Turing Movie.");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    Assert.assertEquals(2, group.getLine());
    Assert.assertEquals(15, group.getPosition());
  }

  @Test
  public void testPrefixSuffix() throws Exception {

    Date reference = DateFormat.getDateInstance(DateFormat.SHORT).parse("2/20/2011");
    CalendarSource.setBaseDate(reference);

    // no prefix or suffix
    Parser parser = new Parser();
    List<DateGroup> groups = parser.parse("Sept. 1st");
    Assert.assertEquals(1, groups.size());
    DateGroup group = groups.get(0);
    Assert.assertEquals(0, group.getPrefix(3).length());
    Assert.assertEquals(0, group.getSuffix(3).length());

    // no prefix
    groups = parser.parse("Sept. 1st is the date");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    Assert.assertEquals(0, group.getPrefix(3).length());
    String suffix = group.getSuffix(3);
    Assert.assertEquals(3, suffix.length());
    Assert.assertEquals(" is",suffix);

    // no suffix
    groups = parser.parse("The date is Sept. 1st");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    String prefix = group.getPrefix(3);
    Assert.assertEquals(3, prefix.length());
    Assert.assertEquals("is ", prefix);
    Assert.assertEquals(0, group.getSuffix(3).length());

    // ask for a larger prefix than available
    groups = parser.parse("a Sept. 1st");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    prefix = group.getPrefix(5);
    Assert.assertEquals(2, prefix.length());
    Assert.assertEquals("a ", prefix);
    Assert.assertEquals(0, group.getSuffix(3).length());

    // ask for a larger suffix than available
    groups = parser.parse("Sept. 1st a");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    suffix = group.getSuffix(5);
    Assert.assertEquals(2,suffix.length());
    Assert.assertEquals(" a", suffix);
    Assert.assertEquals(0, group.getPrefix(3).length());

    // ask for a larger prefix and suffix than available
    groups = parser.parse("a Sept. 1st a");
    Assert.assertEquals(1, groups.size());
    group = groups.get(0);
    prefix = group.getPrefix(5);
    suffix = group.getSuffix(5);
    Assert.assertEquals(2,prefix.length());
    Assert.assertEquals("a ", prefix);
    Assert.assertEquals(2,suffix.length());
    Assert.assertEquals(" a", suffix);
  }

  @Test
  public void testNoDates() {
    List<Date> dates = parseCollection("Fried Chicken, Wedding Dinner");
    Assert.assertEquals(0, dates.size());

    parseCollection("Cleveland");
    Assert.assertEquals(0, dates.size());
  }

}
