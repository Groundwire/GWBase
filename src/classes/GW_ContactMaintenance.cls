// Written by Dave Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

public with sharing class GW_ContactMaintenance {

	public static void UpdateContactFieldsBeforeTrigger() {
		
		for (SObject obj : trigger.new) {
			Contact c = (Contact)obj;
			Contact cOld = trigger.isUpdate ? (Contact)trigger.oldMap.get(c.Id) : null;
			
			// the "Contact - Do Not Mail" workflow rule.
			if (c.Do_Not_Mail__c && (cOld == null || !cOld.Do_Not_Mail__c)) {
				c.Primary_Address__c = 'No Mail';
			}
			
			// the "Contact Inactive or Deceased" workflow rule.
			if ((c.Inactive__c && (cOld == null || !cOld.Inactive__c)) ||
				(c.Deceased__c && (cOld == null || !cOld.Deceased__c))) {
				c.Communication_Preference__c = 'Do Not Contact';
				c.DoNotCall = true;
				c.Do_Not_Mail__c = true;
				c.Do_Not_Solicit__c = true;
				c.Do_Not_Trade__c = true;
				c.HasOptedOutOfEmail = true;
				c.Newsletter_Opt_Out__c = true;
				c.Primary_Address__c = 'No Mail';
				
				// copy a bunch of stuff to the description field before clearing field values				
				c.Description = ((c.Description == null) ? '' : c.Description + '\n\n') +
					((c.Phone == null) ? '' : 'Work Phone: ' + c.Phone + '\n') +
					((c.HomePhone == null) ? '' : 'Home Phone: ' + c.HomePhone + '\n') +
					((c.MobilePhone == null) ? '' : 'Mobile: ' + c.MobilePhone + '\n') +
					((c.OtherPhone == null) ? '' : 'Other Phone: ' + c.OtherPhone + '\n') +
					((c.Email == null) ? '' : 'Email: ' + c.Email + '\n') +
					((c.Secondary_Email__c == null) ? '' : 'Secondary Email: ' + c.Secondary_Email__c + '\n');
								
				c.Phone = null;
				c.HomePhone = null;
				c.MobilePhone = null;
				c.OtherPhone = null;
				c.Email = null;
				c.Secondary_Email__c = null;
			}
				
			// the "Unmark Bad Email Address" workflow rule.
			if (c.Email != null && cOld != null && c.Email != cOld.Email) {
				c.Bad_Email_Address__c = false;
			}
		}
		
	}
	
	static testmethod void TestContactDeceased() {
		Contact c = new Contact();
		c.FirstName = 'Micky';
		c.LastName = 'Mouse';
		c.Email = 'micky@mouse.com';
		c.Description = 'RAT!';
		insert c;
		System.Assert(c.Id != null);
		
		c.Deceased__c = true;
		update c;
		
		c = [select Id, Description, Email from Contact where Id=:c.Id];
		system.assertEquals('RAT!\n\nEmail: micky@mouse.com', c.Description);
		system.assert(c.Email == null);
	}	
}