public with sharing class EciDemoController {

    @AuraEnabled
    public static Id generateVideoCall(String inputJson) {
        try {
            EciDemoDataGenerator.CallInput input =
                (EciDemoDataGenerator.CallInput) JSON.deserialize(
                    inputJson, EciDemoDataGenerator.CallInput.class
                );
            return EciDemoDataGenerator.generateVideoCall(input);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to generate video call: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static Demo_Video_Call__c getVideoCallData(Id recordId) {
        return [
            SELECT Id, Name, Call_Title__c, Call_Started__c,
                   Call_Duration_Minutes__c, Language__c,
                   Related_Account__c, Related_Account__r.Name,
                   Related_Record_Display__c, Customer_Name__c,
                   Customer_Company__c, Internal_Rep_Name__c,
                   Internal_Rep_Company__c, Video_URL__c,
                   Transcript_JSON__c, Insights_JSON__c,
                   Summary_Customer_Impression__c, Summary_Call_Overview__c,
                   Summary_Next_Steps__c, Generative_Insights_JSON__c,
                   Talk_Ratio_Customer__c, Talk_Ratio_Rep__c,
                   OwnerId, Owner.Name, CreatedDate
            FROM Demo_Video_Call__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Call_Recommendation__c> getRecommendations(Id videoCallId) {
        return [
            SELECT Id, Name, Recommendation_Title__c, Recommendation_Detail__c,
                   Action_Type__c, Action_Config_JSON__c, Priority__c,
                   Status__c, Button_Label__c, Rationale__c,
                   Demo_Video_Call__c, CreatedDate
            FROM Call_Recommendation__c
            WHERE Demo_Video_Call__c = :videoCallId
            ORDER BY Priority__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static Id executeRecommendation(Id recommendationId) {
        try {
            Call_Recommendation__c rec = [
                SELECT Id, Action_Type__c, Action_Config_JSON__c, Status__c,
                       Demo_Video_Call__c,
                       Demo_Video_Call__r.Related_Account__c,
                       Demo_Video_Call__r.Customer_Name__c,
                       Demo_Video_Call__r.Customer_Company__c,
                       Demo_Video_Call__r.Internal_Rep_Name__c
                FROM Call_Recommendation__c
                WHERE Id = :recommendationId
                LIMIT 1
            ];

            Map<String, Object> config = new Map<String, Object>();
            if (String.isNotBlank(rec.Action_Config_JSON__c)) {
                config = (Map<String, Object>) JSON.deserializeUntyped(
                    rec.Action_Config_JSON__c
                );
            }

            Id accountId = rec.Demo_Video_Call__r.Related_Account__c;
            Id resultId;

            switch on rec.Action_Type__c {
                when 'Create Task' {
                    resultId = createTask(config, accountId);
                }
                when 'Create Opportunity' {
                    resultId = createOpportunity(config, accountId);
                }
                when 'Update Opportunity' {
                    resultId = updateOpportunity(config, accountId);
                }
                when 'Create Event' {
                    resultId = createEvent(config, accountId);
                }
                when 'Log Follow-Up Call' {
                    resultId = logFollowUpCall(config, accountId);
                }
                when 'Update Competitor' {
                    resultId = updateCompetitor(config, accountId);
                }
                when 'Create Contact' {
                    resultId = createContact(config, accountId,
                        rec.Demo_Video_Call__r.Customer_Name__c);
                }
                when else {
                    throw new AuraHandledException(
                        'Unsupported action type: ' + rec.Action_Type__c
                    );
                }
            }

            rec.Status__c = 'Completed';
            update rec;

            return resultId;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to execute recommendation: ' + e.getMessage()
            );
        }
    }

    // ── Private helpers ──────────────────────────────────────────────

    private static Id createTask(Map<String, Object> config, Id accountId) {
        Task t = new Task(
            Subject     = (String) config.get('subject') ?? 'Follow-up Task',
            Description = (String) config.get('description'),
            Status      = 'Not Started',
            Priority    = 'Normal',
            OwnerId     = UserInfo.getUserId(),
            ActivityDate = Date.today().addDays(
                safeInteger(config.get('daysOut'), 7)
            )
        );
        if (accountId != null) {
            t.WhatId = accountId;
        }
        insert t;
        return t.Id;
    }

    private static Id createOpportunity(Map<String, Object> config, Id accountId) {
        Opportunity opp = new Opportunity(
            Name      = (String) config.get('name') ?? 'New Opportunity',
            StageName = (String) config.get('stageName') ?? 'Qualification',
            CloseDate = parseCloseDate(config.get('closeDate')),
            AccountId = accountId
        );
        Object amtVal = config.get('amount');
        if (amtVal != null) {
            opp.Amount = ((Decimal) amtVal);
        }
        insert opp;
        return opp.Id;
    }

    private static Id updateOpportunity(Map<String, Object> config, Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Cannot update opportunity: no related account on this video call.'
            );
        }
        List<Opportunity> opps = [
            SELECT Id, StageName
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = FALSE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new AuraHandledException(
                'No open opportunity found for this account.'
            );
        }
        Opportunity opp = opps[0];
        opp.StageName = (String) config.get('stageName') ?? opp.StageName;
        update opp;
        return opp.Id;
    }

    private static Id createEvent(Map<String, Object> config, Id accountId) {
        Event ev = new Event(
            Subject            = (String) config.get('subject') ?? 'Follow-up Meeting',
            StartDateTime      = Datetime.now().addDays(
                safeInteger(config.get('daysOut'), 3)
            ),
            DurationInMinutes  = safeInteger(config.get('durationMinutes'), 30),
            OwnerId            = UserInfo.getUserId()
        );
        if (accountId != null) {
            ev.WhatId = accountId;
        }
        insert ev;
        return ev.Id;
    }

    private static Id logFollowUpCall(Map<String, Object> config, Id accountId) {
        Task t = new Task(
            Subject      = (String) config.get('subject') ?? 'Follow-Up Call',
            Description  = (String) config.get('description'),
            Type         = 'Call',
            Status       = 'Completed',
            ActivityDate = Date.today(),
            OwnerId      = UserInfo.getUserId()
        );
        if (accountId != null) {
            t.WhatId = accountId;
        }
        insert t;
        return t.Id;
    }

    private static Id updateCompetitor(Map<String, Object> config, Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Cannot update competitor: no related account on this video call.'
            );
        }
        Account acct = [
            SELECT Id, Primary_Competitor__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        acct.Primary_Competitor__c = (String) config.get('competitorName');
        update acct;
        return acct.Id;
    }

    private static Id createContact(
        Map<String, Object> config, Id accountId, String customerName
    ) {
        Contact c = new Contact(AccountId = accountId);
        if (String.isNotBlank(customerName)) {
            List<String> nameParts = customerName.trim().split('\\s+', 2);
            c.FirstName = nameParts[0];
            c.LastName  = nameParts.size() > 1 ? nameParts[1] : nameParts[0];
        } else {
            c.LastName = 'Unknown';
        }
        String title = (String) config.get('title');
        if (String.isNotBlank(title)) {
            c.Title = title;
        }
        String email = (String) config.get('email');
        if (String.isNotBlank(email)) {
            c.Email = email;
        }
        insert c;
        return c.Id;
    }

    // ── Utility methods ──────────────────────────────────────────────

    private static Integer safeInteger(Object val, Integer defaultVal) {
        if (val == null) {
            return defaultVal;
        }
        if (val instanceof Decimal) {
            return ((Decimal) val).intValue();
        }
        if (val instanceof Integer) {
            return (Integer) val;
        }
        try {
            return Integer.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return defaultVal;
        }
    }

    @TestVisible
    private static Date parseCloseDate(Object closeDateVal) {
        if (closeDateVal == null) {
            return Date.today().addDays(90);
        }
        String raw = String.valueOf(closeDateVal).trim().toLowerCase();
        Pattern daysPat = Pattern.compile('(\\d+)\\s*days?');
        Matcher m = daysPat.matcher(raw);
        if (m.find()) {
            return Date.today().addDays(Integer.valueOf(m.group(1)));
        }
        try {
            return Date.valueOf(raw);
        } catch (Exception e) {
            return Date.today().addDays(90);
        }
    }
}
