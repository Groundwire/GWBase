global class ONEN_UTIL_TimeCalculations {
// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	global static string ConvertTimeTo24Hr ( string timeStr ) {
		
		// given a string representing a time w/ hours & minutes in the form "10:45 PM"
		// convert it a string in the form of a 24-hr time including seconds ("22:45:00")
		// this latter can be used to construct a datetime value
		//
		// this is handy for converting a picklist value representing a time into 
		// something the system can use for a datetime
		
		string newTime = ':00';
		boolean isPM;		
		
		// split string on whitespace or colon
		string Patt = '[\\s:]';
		String[] splits = timeStr.split (Patt);
		
//		system.debug (splits);

		// loop backward through the elements of the string (AM/PM first)
		for ( integer i=splits.size()-1 ; i >= 0 ; i-- ) {
			string part = splits[i];
			if ( i==splits.size()-1 ) {
				isPM = (part == 'PM') ? true : false;
			} else if (i > 0 ) {
				// just prepend the minutes as-is
				newTime = part + newTime;
			} else {
				// for the hour, convert to 24-hr notation if nec.
				integer hour12 = Integer.valueOf (part);
				integer hour24 = (isPM && hour12<>12 ) ? hour12 + 12 : hour12;
				if ( hour24 == 12 && isPM == false ) { hour24 = 0; }
				newTime = string.valueOf (hour24) + ':' + newTime;
				if ( hour24 < 10 ) { newTime = '0' + newTime; }
			}
		}
		
		return newTime;
		
	}
	
	
	global static integer CalcTimeDuration ( string Time1, string Time2 ) {
		
		// given two strings representing times, in the form "10:45 PM"
		// with the first earlier than the 2nd
		// calculate the number of minutes separating them
		// this can then be used to create an Event rec (which expects start time and DurationInMinutes)
		
		integer Duration;
		
		string dateString = '2007-12-25';  // date doesn't really matter here
		
		string Time1_24 = ConvertTimeTo24Hr (Time1);
		string Time2_24 = ConvertTimeTo24Hr (Time2);
		
		datetime DT1 = Datetime.valueOf ( dateString + ' ' + Time1_24 + ':00' );
		datetime DT2 = Datetime.valueOf ( dateString + ' ' + Time2_24 + ':00' );
		
		// this function must return a Long
		Long DT1ms = DT1.getTime();
		Long DT2ms = DT2.getTime();
		
		Long Diffms = DT2ms - DT1ms;
		
		// need to cast the long to int (long way around)
		// (see: http://community.salesforce.com/sforce/board/message?board.id=apex&message.id=1881)
		Integer DiffmsInt = Integer.valueOf(String.valueOf(Diffms));
		
		// convert from ms to minutes
		Duration = DiffmsInt / 1000 / 60;
		
		return Duration;
	} 

	static testmethod void testTime () {		
		system.assertEquals('22:45:00', ONEN_UTIL_TimeCalculations.ConvertTimeTo24Hr('10:45 PM'));
		system.assertEquals(90, ONEN_UTIL_TimeCalculations.CalcTimeDuration('10:00 AM','11:30 AM'));
		system.assertEquals(90, ONEN_UTIL_TimeCalculations.CalcTimeDuration('11:00 AM','12:30 PM'));
	}

}