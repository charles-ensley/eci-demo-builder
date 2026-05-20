@IsTest
private class EciDemoControllerTest {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;
    }

    static Account getTestAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
    }

    static String buildInputJson(Account acct) {
        Map<String, Object> input = new Map<String, Object>{
            'callTitle'          => 'Test Call - Discovery',
            'customerName'       => 'Jane Smith',
            'customerCompany'    => 'TestCo',
            'internalRepName'    => 'John Rep',
            'internalRepCompany' => 'Our Company',
            'callDurationMinutes'=> 10,
            'language'           => 'English',
            'relatedAccountId'   => acct.Id,
            'relatedRecordDisplay' => 'TestCo - Widget Deal - 50k',
            'scenarioType'       => 'Discovery',
            'callNarrative'      => 'Initial discovery to understand requirements.',
            'keyProducts'        => new List<String>{ 'Enterprise Platform', 'Analytics' },
            'keyObjections'      => new List<String>{ 'Budget constraints' },
            'pricingDiscussed'   => true,
            'pricingDetails'     => 'Discussed annual licensing at $50k.',
            'nextSteps'          => new List<String>{ 'Send proposal', 'Schedule demo' },
            'customerSentiment'  => 'Positive'
        };
        return JSON.serialize(input);
    }

    @IsTest
    static void testGenerateVideoCall() {
        Account acct = getTestAccount();
        String inputJson = buildInputJson(acct);

        Test.startTest();
        Id vcId = EciDemoController.generateVideoCall(inputJson);
        Test.stopTest();

        System.assertNotEquals(null, vcId, 'Video call ID should be returned');

        Demo_Video_Call__c vc = [
            SELECT Call_Title__c, Customer_Name__c, Transcript_JSON__c,
                   Insights_JSON__c, Summary_Customer_Impression__c,
                   Summary_Call_Overview__c, Summary_Next_Steps__c,
                   Generative_Insights_JSON__c, Talk_Ratio_Customer__c,
                   Talk_Ratio_Rep__c, Related_Account__c
            FROM Demo_Video_Call__c
            WHERE Id = :vcId
        ];

        System.assertEquals('Test Call - Discovery', vc.Call_Title__c);
        System.assertEquals('Jane Smith', vc.Customer_Name__c);
        System.assertEquals(acct.Id, vc.Related_Account__c);
        System.assert(String.isNotBlank(vc.Transcript_JSON__c), 'Transcript should be populated');
        System.assert(String.isNotBlank(vc.Insights_JSON__c), 'Insights should be populated');
        System.assert(String.isNotBlank(vc.Summary_Customer_Impression__c), 'Customer impression should be populated');
        System.assert(String.isNotBlank(vc.Summary_Call_Overview__c), 'Call overview should be populated');
        System.assert(String.isNotBlank(vc.Summary_Next_Steps__c), 'Next steps should be populated');
        System.assert(String.isNotBlank(vc.Generative_Insights_JSON__c), 'Generative insights should be populated');
        System.assert(vc.Talk_Ratio_Customer__c > 0, 'Customer talk ratio should be > 0');
        System.assert(vc.Talk_Ratio_Rep__c > 0, 'Rep talk ratio should be > 0');

        List<Call_Recommendation__c> recs = [
            SELECT Id FROM Call_Recommendation__c WHERE Demo_Video_Call__c = :vcId
        ];
        System.assert(!recs.isEmpty(), 'Recommendations should be created');
    }

    @IsTest
    static void testGenerateVideoCallInvalidInput() {
        Boolean caught = false;
        Test.startTest();
        try {
            EciDemoController.generateVideoCall('invalid json!!!');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        System.assert(caught, 'Should throw AuraHandledException for invalid input');
    }

    @IsTest
    static void testGetVideoCallData() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Test.startTest();
        Demo_Video_Call__c result = EciDemoController.getVideoCallData(vcId);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Test Call - Discovery', result.Call_Title__c);
    }

    @IsTest
    static void testGetRecommendations() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Test.startTest();
        List<Call_Recommendation__c> recs = EciDemoController.getRecommendations(vcId);
        Test.stopTest();

        System.assert(!recs.isEmpty(), 'Should return recommendations');
        System.assertEquals('New', recs[0].Status__c, 'Default status should be New');
    }

    @IsTest
    static void testExecuteRecommendationCreateTask() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Test task rec',
            Action_Type__c           = 'Create Task',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'subject' => 'Test task subject',
                'daysOut' => 3,
                'description' => 'Test description'
            })
        );
        insert rec;

        Test.startTest();
        Id taskId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        System.assertNotEquals(null, taskId, 'Task ID should be returned');
        Task t = [SELECT Subject, Status FROM Task WHERE Id = :taskId];
        System.assertEquals('Test task subject', t.Subject);
        System.assertEquals('Not Started', t.Status);

        Call_Recommendation__c updated = [SELECT Status__c FROM Call_Recommendation__c WHERE Id = :rec.Id];
        System.assertEquals('Completed', updated.Status__c, 'Recommendation should be marked completed');
    }

    @IsTest
    static void testExecuteRecommendationCreateOpportunity() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Test opp rec',
            Action_Type__c           = 'Create Opportunity',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'name'      => 'Test Opportunity',
                'stageName' => 'Qualification',
                'closeDate' => '60 days',
                'amount'    => 50000
            })
        );
        insert rec;

        Test.startTest();
        Id oppId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        Opportunity opp = [SELECT Name, StageName, Amount FROM Opportunity WHERE Id = :oppId];
        System.assertEquals('Test Opportunity', opp.Name);
        System.assertEquals('Qualification', opp.StageName);
        System.assertEquals(50000, opp.Amount);
    }

    @IsTest
    static void testExecuteRecommendationCreateEvent() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Test event rec',
            Action_Type__c           = 'Create Event',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'subject'         => 'Follow-up Meeting',
                'daysOut'         => 5,
                'durationMinutes' => 45
            })
        );
        insert rec;

        Test.startTest();
        Id eventId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        Event ev = [SELECT Subject, DurationInMinutes FROM Event WHERE Id = :eventId];
        System.assertEquals('Follow-up Meeting', ev.Subject);
        System.assertEquals(45, ev.DurationInMinutes);
    }

    @IsTest
    static void testExecuteRecommendationLogCall() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Log call rec',
            Action_Type__c           = 'Log Follow-Up Call',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'subject'     => 'Follow-up call logged',
                'description' => 'Discussed next steps'
            })
        );
        insert rec;

        Test.startTest();
        Id taskId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        Task t = [SELECT Subject, Status, Type FROM Task WHERE Id = :taskId];
        System.assertEquals('Follow-up call logged', t.Subject);
        System.assertEquals('Completed', t.Status);
        System.assertEquals('Call', t.Type);
    }

    @IsTest
    static void testExecuteRecommendationCreateContact() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Create contact rec',
            Action_Type__c           = 'Create Contact',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'title' => 'VP Sales'
            })
        );
        insert rec;

        Test.startTest();
        Id contactId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        Contact c = [SELECT FirstName, LastName, Title, AccountId FROM Contact WHERE Id = :contactId];
        System.assertEquals('Jane', c.FirstName);
        System.assertEquals('Smith', c.LastName);
        System.assertEquals('VP Sales', c.Title);
        System.assertEquals(acct.Id, c.AccountId);
    }

    @IsTest
    static void testExecuteRecommendationUpdateOpportunity() {
        Account acct = getTestAccount();
        Id vcId = EciDemoController.generateVideoCall(buildInputJson(acct));

        Opportunity opp = new Opportunity(
            Name      = 'Test Opp to Update',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id
        );
        insert opp;

        Call_Recommendation__c rec = new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Update opp rec',
            Action_Type__c           = 'Update Opportunity',
            Status__c                = 'New',
            Priority__c              = 1,
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'stageName' => 'Needs Analysis'
            })
        );
        insert rec;

        Test.startTest();
        Id oppId = EciDemoController.executeRecommendation(rec.Id);
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :oppId];
        System.assertEquals('Needs Analysis', updated.StageName);
    }

    @IsTest
    static void testAllScenarioTypes() {
        Account acct = getTestAccount();
        List<String> scenarios = new List<String>{
            'Renewal', 'DemoFollowUp', 'CompetitiveDisplacement', 'UpsellCrossSell'
        };

        Test.startTest();
        for (String scenario : scenarios) {
            Map<String, Object> input = new Map<String, Object>{
                'callTitle'          => 'Test - ' + scenario,
                'customerName'       => 'Test Customer',
                'customerCompany'    => 'Test Corp',
                'internalRepName'    => 'Test Rep',
                'scenarioType'       => scenario,
                'keyProducts'        => new List<String>{ 'Product A' },
                'keyObjections'      => new List<String>{ 'Budget constraints' },
                'relatedAccountId'   => acct.Id,
                'customerSentiment'  => 'Positive'
            };

            Id vcId = EciDemoController.generateVideoCall(JSON.serialize(input));
            System.assertNotEquals(null, vcId, 'Should create video call for scenario: ' + scenario);

            Demo_Video_Call__c vc = [
                SELECT Transcript_JSON__c, Summary_Call_Overview__c
                FROM Demo_Video_Call__c WHERE Id = :vcId
            ];
            System.assert(String.isNotBlank(vc.Transcript_JSON__c), 'Transcript should exist for ' + scenario);
        }
        Test.stopTest();
    }

    @IsTest
    static void testCustomTranscriptEntries() {
        Account acct = getTestAccount();

        List<Map<String, Object>> entries = new List<Map<String, Object>>{
            new Map<String, Object>{
                'speaker'   => 'rep',
                'text'      => 'Hi there, thanks for meeting.',
                'timestamp' => '00:00',
                'insights'  => new List<String>()
            },
            new Map<String, Object>{
                'speaker'   => 'customer',
                'text'      => 'Happy to be here. Let us discuss the Enterprise Platform.',
                'timestamp' => '00:15',
                'insights'  => new List<String>{ 'Product' }
            }
        };

        Map<String, Object> input = new Map<String, Object>{
            'callTitle'          => 'Custom Transcript Test',
            'customerName'       => 'Custom User',
            'customerCompany'    => 'Custom Co',
            'internalRepName'    => 'Rep',
            'scenarioType'       => 'Discovery',
            'keyProducts'        => new List<String>{ 'Enterprise Platform' },
            'transcriptEntries'  => entries,
            'relatedAccountId'   => acct.Id,
            'customerSentiment'  => 'Neutral'
        };

        Test.startTest();
        Id vcId = EciDemoController.generateVideoCall(JSON.serialize(input));
        Test.stopTest();

        Demo_Video_Call__c vc = [SELECT Transcript_JSON__c FROM Demo_Video_Call__c WHERE Id = :vcId];
        System.assert(vc.Transcript_JSON__c.contains('Enterprise Platform'), 'Custom transcript should contain product text');
    }

    @IsTest
    static void testParseCloseDate() {
        Date result90 = EciDemoController.parseCloseDate('90 days');
        System.assertEquals(Date.today().addDays(90), result90);

        Date result30 = EciDemoController.parseCloseDate('30 day');
        System.assertEquals(Date.today().addDays(30), result30);

        Date resultNull = EciDemoController.parseCloseDate(null);
        System.assertEquals(Date.today().addDays(90), resultNull);

        Date resultInvalid = EciDemoController.parseCloseDate('not a date');
        System.assertEquals(Date.today().addDays(90), resultInvalid);
    }
}
