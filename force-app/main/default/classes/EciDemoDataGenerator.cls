public with sharing class EciDemoDataGenerator {

    // ── Input wrappers ──────────────────────────────────────────────────

    public class CallInput {
        public String  callTitle;
        public String  customerName;
        public String  customerCompany;
        public String  internalRepName;
        public String  internalRepCompany;
        public Datetime callStarted;
        public Integer callDurationMinutes;
        public String  language;
        public Id      relatedAccountId;
        public String  relatedRecordDisplay;
        public String  videoUrl;
        public String  scenarioType;
        public String  callNarrative;
        public List<String> keyProducts;
        public List<String> keyObjections;
        public Boolean pricingDiscussed;
        public String  pricingDetails;
        public List<String> nextSteps;
        public String  customerSentiment;
        public List<TranscriptEntry>    transcriptEntries;
        public List<RecommendationInput> recommendations;
        public String summaryCustomerImpression;
        public String summaryCallOverview;
        public String summaryNextSteps;
        public List<GenerativeInsightInput> generativeInsights;
    }

    public class GenerativeInsightInput {
        public String question;
        public String answer;
    }

    public class TranscriptEntry {
        public String speaker;
        public String text;
        public String timestamp;
        public List<String> insights;

        public TranscriptEntry() {
            this.insights = new List<String>();
        }
    }

    public class RecommendationInput {
        public String title;
        public String detail;
        public String rationale;
        public String actionType;
        public String buttonLabel;
        public Map<String, Object> actionConfig;
    }

    // ── Main entry point ────────────────────────────────────────────────

    public static Id generateVideoCall(CallInput input) {
        applyDefaults(input);

        List<TranscriptEntry> transcript = generateTranscript(input);
        String insightsJson             = generateInsights(transcript);
        Map<String, Decimal> talkRatios = calculateTalkRatios(transcript);

        String impression;
        String overview;
        String nextStepsSummary;
        if (String.isNotBlank(input.summaryCustomerImpression) ||
            String.isNotBlank(input.summaryCallOverview) ||
            String.isNotBlank(input.summaryNextSteps)) {
            impression      = input.summaryCustomerImpression;
            overview        = input.summaryCallOverview;
            nextStepsSummary = input.summaryNextSteps;
        } else {
            Map<String, String> summaries = generateSummary(input, transcript);
            impression      = summaries.get('impression');
            overview        = summaries.get('overview');
            nextStepsSummary = summaries.get('nextSteps');
        }

        String genInsightsJson;
        if (input.generativeInsights != null && !input.generativeInsights.isEmpty()) {
            List<Map<String, String>> pairs = new List<Map<String, String>>();
            for (GenerativeInsightInput gi : input.generativeInsights) {
                pairs.add(new Map<String, String>{ 'question' => gi.question, 'answer' => gi.answer });
            }
            genInsightsJson = JSON.serialize(pairs);
        } else {
            genInsightsJson = generateGenerativeInsights(input);
        }

        String explorerQaJson = generateExplorerQA(input, transcript, impression, overview, nextStepsSummary);

        Demo_Video_Call__c vc = new Demo_Video_Call__c(
            Call_Title__c                = input.callTitle,
            Call_Started__c              = input.callStarted,
            Call_Duration_Minutes__c     = input.callDurationMinutes,
            Language__c                  = input.language,
            Related_Account__c           = input.relatedAccountId,
            Related_Record_Display__c    = input.relatedRecordDisplay,
            Customer_Name__c             = input.customerName,
            Customer_Company__c          = input.customerCompany,
            Internal_Rep_Name__c         = input.internalRepName,
            Internal_Rep_Company__c      = input.internalRepCompany,
            Video_URL__c                 = input.videoUrl,
            Transcript_JSON__c           = JSON.serialize(transcript),
            Insights_JSON__c             = insightsJson,
            Summary_Customer_Impression__c = impression,
            Summary_Call_Overview__c       = overview,
            Summary_Next_Steps__c          = nextStepsSummary,
            Generative_Insights_JSON__c    = genInsightsJson,
            Call_Explorer_QA_JSON__c       = explorerQaJson,
            Talk_Ratio_Customer__c       = talkRatios.get('customer'),
            Talk_Ratio_Rep__c            = talkRatios.get('rep')
        );
        insert vc;

        generateRecommendations(input, vc.Id);
        return vc.Id;
    }

    // ── Defaults ────────────────────────────────────────────────────────

    private static void applyDefaults(CallInput input) {
        if (String.isBlank(input.callTitle))          { input.callTitle          = 'Demo Call'; }
        if (String.isBlank(input.customerName))       { input.customerName       = 'Customer'; }
        if (String.isBlank(input.customerCompany))    { input.customerCompany    = 'Acme Corp'; }
        if (String.isBlank(input.internalRepName))    { input.internalRepName    = 'Sales Rep'; }
        if (String.isBlank(input.internalRepCompany)) { input.internalRepCompany = 'Our Company'; }
        if (input.callStarted == null)                { input.callStarted        = Datetime.now(); }
        if (input.callDurationMinutes == null || input.callDurationMinutes == 0) {
            input.callDurationMinutes = 30;
        }
        if (String.isBlank(input.language))           { input.language           = 'English'; }
        if (String.isBlank(input.scenarioType))       { input.scenarioType       = 'Discovery'; }
        if (input.keyProducts == null)                { input.keyProducts        = new List<String>{ 'Platform' }; }
        if (input.keyObjections == null)              { input.keyObjections      = new List<String>(); }
        if (input.pricingDiscussed == null)            { input.pricingDiscussed   = false; }
        if (input.nextSteps == null)                  { input.nextSteps          = new List<String>(); }
        if (String.isBlank(input.customerSentiment))  { input.customerSentiment  = 'Neutral'; }
    }

    // ── Transcript generation ───────────────────────────────────────────

    public static List<TranscriptEntry> generateTranscript(CallInput input) {
        if (input.transcriptEntries != null && !input.transcriptEntries.isEmpty()) {
            tagInsights(input.transcriptEntries, input);
            return input.transcriptEntries;
        }

        List<TranscriptEntry> entries = new List<TranscriptEntry>();
        String scenario = input.scenarioType;

        if (scenario == 'Renewal') {
            buildRenewalTranscript(entries, input);
        } else if (scenario == 'DemoFollowUp') {
            buildDemoFollowUpTranscript(entries, input);
        } else if (scenario == 'CompetitiveDisplacement') {
            buildCompetitiveDisplacementTranscript(entries, input);
        } else if (scenario == 'UpsellCrossSell') {
            buildUpsellCrossSellTranscript(entries, input);
        } else {
            buildDiscoveryTranscript(entries, input);
        }

        assignTimestamps(entries);
        tagInsights(entries, input);
        return entries;
    }

    // ── Renewal ─────────────────────────────────────────────────────────

    private static void buildRenewalTranscript(List<TranscriptEntry> entries, CallInput inp) {
        String prod  = firstProduct(inp);
        String objn  = firstObjection(inp);

        addEntry(entries, 'rep',      'Hi ' + inp.customerName + ', thanks for making time today. I wanted to touch base on your upcoming renewal and make sure we\'re aligned on everything going forward.');
        addEntry(entries, 'customer', 'Of course, ' + inp.internalRepName + '. We\'ve been reviewing the current contract internally and have a few thoughts to share.');
        addEntry(entries, 'rep',      'Great. Before we dive in, I\'d love to hear how things have been going with ' + prod + ' over the past year. What\'s been working well for your team?');
        addEntry(entries, 'customer', 'Honestly, ' + prod + ' has been solid. The team uses it daily and it has really become core to our workflow. Adoption has been strong across the board.');

        if (!inp.keyObjections.isEmpty()) {
            addEntry(entries, 'customer', 'That said, we do have some concerns. ' + objn + ' is something we need to address before we move forward with the renewal.');
            addEntry(entries, 'rep',      'I appreciate you raising that. We\'ve actually been investing heavily in that area. Let me walk you through what we\'ve done to address ' + objn + ' and the roadmap ahead.');
        } else {
            addEntry(entries, 'customer', 'We don\'t have any major concerns at this point. Everything has been running smoothly.');
            addEntry(entries, 'rep',      'That\'s great to hear. We want to make sure that continues and look at ways we can deliver even more value.');
        }

        if (inp.pricingDiscussed == true) {
            addEntry(entries, 'rep',      'Let\'s talk about the commercial side. ' + safe(inp.pricingDetails, 'We\'ve put together a competitive renewal package that reflects the value you\'re getting.'));
            addEntry(entries, 'customer', 'Pricing is definitely a factor in our decision. We need to see that the investment is justified by the outcomes we\'re achieving.');
            addEntry(entries, 'rep',      'Absolutely. I\'ll send over a detailed breakdown showing the ROI you\'ve realized this year alongside the proposed renewal terms.');
        }

        addEntry(entries, 'rep',      'I also wanted to mention a few new capabilities we\'re rolling out that could be a great fit, particularly around expanding your use of ' + prod + '.');
        addEntry(entries, 'customer', 'We\'re open to hearing about that. If it makes sense from a budget and resources perspective, we\'d consider expanding.');
        addEntry(entries, 'rep',      'Perfect. In terms of next steps, I\'ll send over the renewal proposal along with the expansion options. ' + buildNextStepsDialogue(inp));
        addEntry(entries, 'customer', 'Sounds good. Let\'s target getting everything reviewed within the next two weeks so we can stay on track.');
        addEntry(entries, 'rep',      'That works perfectly. Thanks again, ' + inp.customerName + '. I\'ll follow up with everything by end of day tomorrow.');
    }

    // ── Discovery ───────────────────────────────────────────────────────

    private static void buildDiscoveryTranscript(List<TranscriptEntry> entries, CallInput inp) {
        String prod  = firstProduct(inp);
        String objn  = firstObjection(inp);

        addEntry(entries, 'rep',      'Hi ' + inp.customerName + ', thanks for joining today. I\'m excited to learn more about what ' + inp.customerCompany + ' is working on. I thought we could start with your current setup and then explore where we might be able to help.');
        addEntry(entries, 'customer', 'Sounds good, ' + inp.internalRepName + '. We\'re at a point where we\'re evaluating options so the timing works well.');
        addEntry(entries, 'rep',      'Great. Can you walk me through how your team currently handles the processes that ' + prod + ' would touch?');
        addEntry(entries, 'customer', 'Right now it\'s mostly manual. We have a mix of spreadsheets and legacy tools that don\'t talk to each other. It\'s creating bottlenecks, especially as we scale.');

        if (!inp.keyObjections.isEmpty()) {
            addEntry(entries, 'customer', 'One of our biggest pain points is around ' + objn + '. It\'s been a persistent challenge and a key driver for this evaluation.');
            addEntry(entries, 'rep',      'That\'s a challenge we hear often. ' + prod + ' was actually designed with that exact scenario in mind. Let me show you how other customers in your space have tackled ' + objn + '.');
        } else {
            addEntry(entries, 'customer', 'Our main goal is to consolidate and modernize. We want one platform that can grow with us.');
            addEntry(entries, 'rep',      'That makes perfect sense. ' + prod + ' is built for exactly that kind of consolidation and long-term scalability.');
        }

        addEntry(entries, 'customer', 'That\'s interesting. Can you tell me more about how ' + prod + ' integrates with our existing systems? We don\'t want a rip-and-replace situation.');
        addEntry(entries, 'rep',      'Absolutely. We have pre-built connectors for most major platforms, and our API framework is designed for the kind of hybrid environment you described. Most customers are fully integrated within four to six weeks.');
        addEntry(entries, 'rep',      'In terms of fit, it sounds like ' + prod + ' aligns well with your goals around consolidation and addressing the ' + safe(objn, 'operational challenges') + ' you mentioned.');
        addEntry(entries, 'customer', 'I\'d agree with that assessment. What does the typical timeline look like from evaluation to go-live?');
        addEntry(entries, 'rep',      'Typically we see about sixty to ninety days from contract to production, depending on complexity. We can definitely tailor that to your schedule.');
        addEntry(entries, 'rep',      'For next steps, ' + buildNextStepsDialogue(inp));
        addEntry(entries, 'customer', 'That works for us. Let\'s plan on reconnecting next week with the broader team. Appreciate the thorough walkthrough, ' + inp.internalRepName + '.');
        addEntry(entries, 'rep',      'Likewise, ' + inp.customerName + '. I\'ll send over some materials today and get that follow-up on the calendar. Talk soon.');
    }

    // ── Demo Follow-Up ──────────────────────────────────────────────────

    private static void buildDemoFollowUpTranscript(List<TranscriptEntry> entries, CallInput inp) {
        String prod = firstProduct(inp);
        String objn = firstObjection(inp);

        addEntry(entries, 'rep',      'Hi ' + inp.customerName + ', thanks for jumping on again. I wanted to follow up on the demo from last week and hear your team\'s feedback.');
        addEntry(entries, 'customer', 'Hi ' + inp.internalRepName + '. Thanks for the follow-up. Overall the reaction was really positive. The team was impressed with ' + prod + '.');
        addEntry(entries, 'rep',      'That\'s great to hear. Were there any specific features or capabilities that stood out?');
        addEntry(entries, 'customer', 'The automation piece definitely got a lot of attention. People could see how it would save time on some of the repetitive work we\'re doing today.');

        if (!inp.keyObjections.isEmpty()) {
            addEntry(entries, 'customer', 'We did have some questions come up though, especially around ' + objn + '. A few stakeholders flagged that as something we need to resolve before moving forward.');
            addEntry(entries, 'rep',      'Completely understandable. Let me address that directly. ' + objn + ' is something we\'ve worked through with similar organizations. I can share some reference architectures and connect you with a customer who had the same concern.');
        }

        if (inp.pricingDiscussed == true) {
            addEntry(entries, 'rep',      'Should we talk through the commercial side as well? ' + safe(inp.pricingDetails, 'I have a few packaging options that align with the scope you showed interest in during the demo.'));
            addEntry(entries, 'customer', 'Yes, let\'s go through the numbers. Budget approval is the next gate for us.');
        }

        addEntry(entries, 'rep',      'Based on the feedback, it sounds like a POC could be the logical next step. We could set up a focused pilot with your priority use cases and have results within two to three weeks.');
        addEntry(entries, 'customer', 'I think that makes sense. Let me confirm with our IT lead, but a POC would help us build the internal business case.');
        addEntry(entries, 'rep',      'Perfect. ' + buildNextStepsDialogue(inp));
        addEntry(entries, 'customer', 'Sounds like a plan. Talk soon.');
        addEntry(entries, 'rep',      'Thanks, ' + inp.customerName + '. I\'ll get everything over to you today.');
    }

    // ── Competitive Displacement ────────────────────────────────────────

    private static void buildCompetitiveDisplacementTranscript(List<TranscriptEntry> entries, CallInput inp) {
        String prod = firstProduct(inp);
        String objn = firstObjection(inp);

        addEntry(entries, 'rep',      'Hi ' + inp.customerName + ', thanks for taking the time. I know you\'re currently evaluating alternatives and I wanted to discuss how ' + prod + ' compares to what you have in place today.');
        addEntry(entries, 'customer', 'Hi ' + inp.internalRepName + '. Yes, we\'re in an active evaluation. Our current vendor has been falling short in a few areas and we need to make a change.');
        addEntry(entries, 'rep',      'Can you share more about what\'s driving the decision to look at alternatives?');
        addEntry(entries, 'customer', 'The biggest issue is reliability. We\'ve had multiple outages this year and the support response has been poor. On top of that, their product roadmap doesn\'t align with where we\'re heading as a business.');
        addEntry(entries, 'rep',      'I hear that a lot from organizations making the switch. With ' + prod + ', we\'ve built our platform around the exact pain points you\'re describing — reliability, proactive support, and a roadmap driven by customer input.');

        if (!inp.keyObjections.isEmpty()) {
            addEntry(entries, 'customer', 'My concern about switching is ' + objn + '. We went through a painful migration once before and I don\'t want to repeat that.');
            addEntry(entries, 'rep',      'That\'s a valid concern. We\'ve developed a structured migration program specifically for customers coming from your current platform. We handle the heavy lifting and the typical transition takes four to six weeks with zero downtime.');
        }

        addEntry(entries, 'rep',      'Let me share some ROI data from customers who made a similar move. On average, they\'ve seen a thirty percent reduction in operational costs and a significant improvement in system uptime within the first quarter.');
        addEntry(entries, 'customer', 'Those numbers are compelling. What does the migration plan actually look like in practice?');
        addEntry(entries, 'rep',      'We start with a data assessment, then run a parallel environment for two weeks so your team can validate everything before we cut over. We assign a dedicated migration engineer to your account throughout the process.');
        addEntry(entries, 'rep',      'For next steps, ' + buildNextStepsDialogue(inp));
        addEntry(entries, 'customer', 'Let\'s do it. I\'ll loop in our CTO for the next conversation. Appreciate the detail, ' + inp.internalRepName + '.');
        addEntry(entries, 'rep',      'Absolutely. I\'ll put together the migration assessment and get it on the calendar. Thanks, ' + inp.customerName + '.');
    }

    // ── Upsell / Cross-Sell ─────────────────────────────────────────────

    private static void buildUpsellCrossSellTranscript(List<TranscriptEntry> entries, CallInput inp) {
        String prod = firstProduct(inp);
        String objn = firstObjection(inp);

        addEntry(entries, 'rep',      'Hi ' + inp.customerName + ', thanks for connecting. I\'ve been looking at how ' + inp.customerCompany + ' has been using the platform and I see some opportunities where we could drive even more value for your team.');
        addEntry(entries, 'customer', 'Hi ' + inp.internalRepName + '. We\'re always open to hearing about ways to get more out of the investment. What did you have in mind?');
        addEntry(entries, 'rep',      'So right now your team is using the core platform really effectively. Adoption is strong and you\'re getting great results. What I\'ve noticed is that teams with your usage profile tend to see a big lift when they add ' + prod + '.');
        addEntry(entries, 'customer', 'Interesting. We\'ve heard about ' + prod + ' but haven\'t explored it in depth. How does it complement what we\'re already doing?');
        addEntry(entries, 'rep',      prod + ' extends your current setup by adding deeper analytics and automation capabilities. Think of it as the next layer that turns the data you\'re already capturing into actionable insights.');

        if (!inp.keyObjections.isEmpty()) {
            addEntry(entries, 'customer', 'That sounds promising, but I\'m a bit concerned about ' + objn + '. We don\'t have a lot of bandwidth for a big rollout right now.');
            addEntry(entries, 'rep',      'Totally fair. The good news is that ' + prod + ' is designed to layer on top of your existing setup with minimal effort. Most customers are up and running within a week. We can start with a focused use case to prove value without straining your team.');
        }

        if (inp.pricingDiscussed == true) {
            addEntry(entries, 'rep',      'On the pricing side, ' + safe(inp.pricingDetails, 'since you\'re already a customer, we can offer a bundled rate that makes the addition very cost-effective.'));
            addEntry(entries, 'customer', 'That helps. Can you send over the pricing details so I can share with our finance team?');
        }

        addEntry(entries, 'rep',      'In terms of timeline, we could have a pilot running within the next two weeks if you\'re ready to move forward.');
        addEntry(entries, 'customer', 'Let me talk to the team and come back to you by end of week. I think there\'s definitely interest.');
        addEntry(entries, 'rep',      'Sounds good. ' + buildNextStepsDialogue(inp));
        addEntry(entries, 'customer', 'Thanks, ' + inp.internalRepName + '. Let\'s reconnect Friday.');
        addEntry(entries, 'rep',      'Looking forward to it. Have a great rest of your day, ' + inp.customerName + '.');
    }

    // ── Transcript helpers ──────────────────────────────────────────────

    private static void addEntry(List<TranscriptEntry> entries, String speaker, String text) {
        TranscriptEntry te = new TranscriptEntry();
        te.speaker = speaker;
        te.text    = text;
        entries.add(te);
    }

    private static void assignTimestamps(List<TranscriptEntry> entries) {
        Integer seconds = 0;
        for (Integer i = 0; i < entries.size(); i++) {
            entries[i].timestamp = formatTimestamp(seconds);
            Integer words = entries[i].text.split('\\s+').size();
            Integer increment = Math.max(15, Math.min(45, words * 2));
            seconds += increment;
        }
    }

    private static String formatTimestamp(Integer totalSeconds) {
        Integer mins = totalSeconds / 60;
        Integer secs = Math.mod(totalSeconds, 60);
        return (mins < 10 ? '0' : '') + String.valueOf(mins) + ':' +
               (secs < 10 ? '0' : '') + String.valueOf(secs);
    }

    private static void tagInsights(List<TranscriptEntry> entries, CallInput input) {
        Set<String> productTokens   = tokensLower(input.keyProducts);
        Set<String> objectionTokens = tokensLower(input.keyObjections);

        Integer longestCustomerIdx  = -1;
        Integer longestCustomerLen  = 0;

        for (Integer i = 0; i < entries.size(); i++) {
            TranscriptEntry te = entries[i];
            if (te.insights == null) { te.insights = new List<String>(); }
            String lower = te.text.toLowerCase();

            for (String tok : productTokens) {
                if (lower.contains(tok)) { te.insights.add('Product'); break; }
            }

            Boolean objTagged = false;
            for (String tok : objectionTokens) {
                if (lower.contains(tok) && !objTagged) {
                    te.insights.add(categorizeObjection(tok));
                    objTagged = true;
                }
            }

            if (lower.contains('pricing') || lower.contains('price') ||
                lower.contains('cost') || lower.contains('budget') ||
                lower.contains('commercial') || lower.contains('investment')) {
                te.insights.add('Pricing');
            }

            if (lower.contains('next step') || lower.contains('follow up') ||
                lower.contains('follow-up') || lower.contains('action item') ||
                lower.contains('reconnect') || lower.contains('schedule')) {
                te.insights.add('Next Step');
            }

            if (te.speaker == 'customer') {
                Integer wc = te.text.split('\\s+').size();
                if (wc > longestCustomerLen) {
                    longestCustomerLen = wc;
                    longestCustomerIdx = i;
                }
            }
        }

        if (longestCustomerIdx >= 0) {
            entries[longestCustomerIdx].insights.add('Longest Monologue');
        }
    }

    private static String categorizeObjection(String token) {
        String lower = token.toLowerCase();
        if (lower.contains('authority') || lower.contains('decision') || lower.contains('stakeholder')) {
            return 'Objection - Authority';
        } else if (lower.contains('budget') || lower.contains('price') || lower.contains('cost') || lower.contains('pricing')) {
            return 'Objection - Pricing';
        } else if (lower.contains('timeline') || lower.contains('time') || lower.contains('bandwidth') || lower.contains('capacity')) {
            return 'Objection - Timeline';
        }
        return 'Objection - Need';
    }

    private static Set<String> tokensLower(List<String> items) {
        Set<String> result = new Set<String>();
        if (items == null) { return result; }
        for (String s : items) {
            if (String.isNotBlank(s)) { result.add(s.toLowerCase()); }
        }
        return result;
    }

    // ── Insights generation ─────────────────────────────────────────────

    public static String generateInsights(List<TranscriptEntry> transcript) {
        Map<String, Map<String, Integer>> categories = new Map<String, Map<String, Integer>>();
        categories.put('product',   new Map<String, Integer>());
        categories.put('objection', new Map<String, Integer>());
        categories.put('pricing',   new Map<String, Integer>());
        categories.put('nextStep',  new Map<String, Integer>());

        Map<String, Object> longestMono = new Map<String, Object>();
        Integer longestLen = 0;

        for (Integer i = 0; i < transcript.size(); i++) {
            TranscriptEntry te = transcript[i];
            if (te.insights == null) { continue; }

            for (String tag : te.insights) {
                if (tag == 'Product') {
                    incrementCategory(categories.get('product'), 'Product', 1);
                } else if (tag.startsWith('Objection')) {
                    String label = tag.replace('Objection - ', '');
                    incrementCategory(categories.get('objection'), label, 1);
                } else if (tag == 'Pricing') {
                    incrementCategory(categories.get('pricing'), 'Pricing', 1);
                } else if (tag == 'Next Step') {
                    incrementCategory(categories.get('nextStep'), 'Next Step', 1);
                } else if (tag == 'Longest Monologue') {
                    longestMono.put('speaker', te.speaker);
                    longestMono.put('index', i);
                    longestMono.put('wordCount', te.text.split('\\s+').size());
                }
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('product',          categoryToList(categories.get('product')));
        result.put('objection',        categoryToList(categories.get('objection')));
        result.put('pricing',          categoryToList(categories.get('pricing')));
        result.put('longestMonologue', longestMono.isEmpty() ? null : longestMono);
        result.put('nextStep',         categoryToList(categories.get('nextStep')));

        return JSON.serialize(result);
    }

    private static void incrementCategory(Map<String, Integer> cat, String label, Integer amount) {
        Integer current = cat.containsKey(label) ? cat.get(label) : 0;
        cat.put(label, current + amount);
    }

    private static List<Map<String, Object>> categoryToList(Map<String, Integer> cat) {
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        for (String key : cat.keySet()) {
            items.add(new Map<String, Object>{ 'label' => key, 'count' => cat.get(key) });
        }
        return items;
    }

    // ── Summary generation ──────────────────────────────────────────────

    public static Map<String, String> generateSummary(CallInput input, List<TranscriptEntry> transcript) {
        Map<String, String> summaries = new Map<String, String>();
        summaries.put('impression', buildCustomerImpression(input));
        summaries.put('overview',   buildCallOverview(input, transcript));
        summaries.put('nextSteps',  buildNextStepsSummary(input));
        return summaries;
    }

    private static String buildCustomerImpression(CallInput input) {
        String sentiment = safe(input.customerSentiment, 'Neutral');
        if (sentiment == 'Positive') {
            return input.customerName + ' was engaged and receptive throughout the conversation. ' +
                   'They expressed clear enthusiasm about the product capabilities and indicated strong alignment with their strategic priorities. ' +
                   input.internalRepName + '\'s consultative approach resonated well with the customer.';
        } else if (sentiment == 'Negative') {
            return input.customerName + ' expressed notable reservations during the call. ' +
                   'While willing to continue the evaluation, there are unresolved concerns that ' + input.internalRepName + ' will need to address in follow-up communications. ' +
                   'Careful attention to the customer\'s specific objections will be important for progressing this opportunity.';
        }
        return input.customerName + ' was professional and measured in their engagement. ' +
               'They showed interest in the discussion but maintained a cautious evaluation posture. ' +
               input.internalRepName + ' should continue building value and addressing any unstated concerns in subsequent interactions.';
    }

    private static String buildCallOverview(CallInput input, List<TranscriptEntry> transcript) {
        String products = String.join(safe(input.keyProducts), ', ');
        String overview = input.internalRepName + ' from ' + input.internalRepCompany +
                          ' connected with ' + input.customerName + ' from ' + input.customerCompany +
                          ' for a ' + input.callDurationMinutes + '-minute ' + scenarioLabel(input.scenarioType) + ' call. ';

        if (String.isNotBlank(products)) {
            overview += 'Key products discussed included ' + products + '. ';
        }
        if (!input.keyObjections.isEmpty()) {
            overview += 'The customer raised concerns around ' + String.join(input.keyObjections, ', ') + ', which were addressed during the conversation. ';
        }
        if (input.pricingDiscussed == true) {
            overview += 'Pricing was discussed during the call. ';
        }
        overview += 'The call concluded with clear alignment on next steps.';
        return overview;
    }

    private static String buildNextStepsSummary(CallInput input) {
        List<String> steps = input.nextSteps;
        if (steps == null || steps.isEmpty()) {
            steps = defaultNextSteps(input.scenarioType, input);
        }
        String result = '';
        for (Integer i = 0; i < steps.size(); i++) {
            result += String.valueOf(i + 1) + '. ' + steps[i] + '\n';
        }
        return result.trim();
    }

    private static List<String> defaultNextSteps(String scenario, CallInput input) {
        List<String> steps = new List<String>();
        steps.add('Send follow-up email with meeting summary and discussed materials');
        if (scenario == 'Renewal') {
            steps.add('Prepare and send renewal proposal with expansion options');
            steps.add('Schedule internal review with procurement team');
        } else if (scenario == 'Discovery') {
            steps.add('Share product documentation and relevant case studies');
            steps.add('Schedule technical deep-dive with broader team');
        } else if (scenario == 'DemoFollowUp') {
            steps.add('Set up POC environment with priority use cases');
            steps.add('Schedule POC kick-off call');
        } else if (scenario == 'CompetitiveDisplacement') {
            steps.add('Deliver migration assessment and TCO comparison');
            steps.add('Arrange call with CTO and migration engineering team');
        } else {
            steps.add('Send pricing details for ' + firstProduct(input));
            steps.add('Schedule technical deep-dive on implementation approach');
        }
        return steps;
    }

    // ── Generative insights ─────────────────────────────────────────────

    public static String generateGenerativeInsights(CallInput input) {
        List<Map<String, String>> pairs = new List<Map<String, String>>();

        String products = String.join(safe(input.keyProducts), ', ');
        String dealTermsAnswer = input.pricingDiscussed == true && String.isNotBlank(input.pricingDetails)
            ? 'Pricing was discussed on this call. ' + input.pricingDetails
            : 'Specific deal terms were not discussed in detail on this call. The conversation focused on ' + products + ' and evaluating fit before moving to commercial discussions.';
        pairs.add(new Map<String, String>{ 'question' => 'What were the deal terms on this call?', 'answer' => dealTermsAnswer });

        String sentimentLower = safe(input.customerSentiment, 'Neutral').toLowerCase();
        String sentimentAnswer = 'The overall customer sentiment on this call was ' + sentimentLower + '. ' +
            input.customerName + ' from ' + input.customerCompany + ' was ' +
            (sentimentLower == 'positive' ? 'engaged and receptive, showing clear interest in moving forward.' :
             sentimentLower == 'negative' ? 'reserved and raised several concerns that need to be addressed before progressing.' :
             'professional and evaluative, maintaining an open but cautious posture throughout the discussion.');
        pairs.add(new Map<String, String>{ 'question' => 'What was the customer sentiment on this call?', 'answer' => sentimentAnswer });

        String closeAnswer;
        if (sentimentLower == 'positive' && (input.nextSteps != null && !input.nextSteps.isEmpty())) {
            closeAnswer = 'Based on the positive customer sentiment and clear next steps established during the call, there is a strong likelihood this deal could progress to close this quarter, contingent on successful completion of the outlined action items.';
        } else if (sentimentLower == 'negative') {
            closeAnswer = 'Given the concerns raised during the call, closing this quarter may be challenging. The sales team should prioritize addressing the customer\'s objections and re-establishing momentum before forecasting a close date.';
        } else {
            closeAnswer = 'The deal shows potential but the timeline depends on how quickly the next steps are executed and any remaining concerns are resolved. Close this quarter is possible but not certain based on current signals.';
        }
        pairs.add(new Map<String, String>{ 'question' => 'Will this deal close this quarter?', 'answer' => closeAnswer });

        String competitiveAnswer;
        if (!input.keyObjections.isEmpty() && input.scenarioType == 'CompetitiveDisplacement') {
            competitiveAnswer = 'Competitive dynamics were a central theme on this call. The customer is actively evaluating alternatives due to dissatisfaction with their current vendor. Key concerns included ' +
                String.join(input.keyObjections, ', ') + '. The team should prepare competitive battle cards and be ready to differentiate on these specific points.';
        } else if (!input.keyObjections.isEmpty()) {
            competitiveAnswer = 'While this was not explicitly a competitive evaluation, the customer raised concerns around ' +
                String.join(input.keyObjections, ', ') + ' which could indicate competitive alternatives are being considered. Proactive competitive positioning is recommended.';
        } else {
            competitiveAnswer = 'No direct competitive threats were mentioned on this call. The customer appears to be evaluating the solution on its own merits rather than in a comparative context.';
        }
        pairs.add(new Map<String, String>{ 'question' => 'What competitive threats were mentioned?', 'answer' => competitiveAnswer });

        return JSON.serialize(pairs);
    }

    // ── Talk ratio ──────────────────────────────────────────────────────

    public static Map<String, Decimal> calculateTalkRatios(List<TranscriptEntry> transcript) {
        Integer customerWords = 0;
        Integer repWords      = 0;

        for (TranscriptEntry te : transcript) {
            Integer wc = te.text.split('\\s+').size();
            if (te.speaker == 'customer') {
                customerWords += wc;
            } else {
                repWords += wc;
            }
        }

        Integer total = customerWords + repWords;
        Map<String, Decimal> ratios = new Map<String, Decimal>();
        if (total == 0) {
            ratios.put('customer', 50);
            ratios.put('rep', 50);
        } else {
            ratios.put('customer', ((Decimal) customerWords / total * 100).setScale(1, RoundingMode.HALF_UP));
            ratios.put('rep',      ((Decimal) repWords / total * 100).setScale(1, RoundingMode.HALF_UP));
        }
        return ratios;
    }

    // ── Recommendations ─────────────────────────────────────────────────

    public static void generateRecommendations(CallInput input, Id videoCallId) {
        List<Call_Recommendation__c> recs = new List<Call_Recommendation__c>();
        Integer priority = 1;

        if (input.recommendations != null && !input.recommendations.isEmpty()) {
            for (RecommendationInput ri : input.recommendations) {
                recs.add(buildRecFromInput(ri, videoCallId, priority++));
            }
        } else {
            recs.addAll(defaultRecommendations(input, videoCallId, priority));
        }

        if (!recs.isEmpty()) {
            insert recs;
        }
    }

    private static Call_Recommendation__c buildRecFromInput(RecommendationInput ri, Id vcId, Integer priority) {
        return new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = ri.title,
            Recommendation_Detail__c = ri.detail,
            Rationale__c             = ri.rationale,
            Action_Type__c           = ri.actionType,
            Button_Label__c          = ri.buttonLabel,
            Action_Config_JSON__c    = ri.actionConfig != null ? JSON.serialize(ri.actionConfig) : null,
            Status__c                = 'New',
            Priority__c              = priority
        );
    }

    private static List<Call_Recommendation__c> defaultRecommendations(CallInput input, Id vcId, Integer startPriority) {
        List<Call_Recommendation__c> recs = new List<Call_Recommendation__c>();
        Integer p = startPriority;
        String prod = firstProduct(input);

        recs.add(new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Schedule follow-up meeting with ' + input.customerName,
            Recommendation_Detail__c = 'Set up a follow-up meeting to continue the conversation and maintain momentum with ' + input.customerCompany + '.',
            Rationale__c             = 'because timely follow-up after a ' + scenarioLabel(input.scenarioType) + ' call is critical to keeping the deal progressing',
            Action_Type__c           = 'Create Event',
            Button_Label__c          = 'Create Event',
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'subject'         => 'Follow-up: ' + input.callTitle,
                'daysOut'         => 7,
                'durationMinutes' => 30
            }),
            Status__c                = 'New',
            Priority__c              = p++
        ));

        recs.add(new Call_Recommendation__c(
            Demo_Video_Call__c       = vcId,
            Recommendation_Title__c  = 'Send meeting summary to ' + input.customerName,
            Recommendation_Detail__c = 'Prepare and send a follow-up email summarizing key discussion points and agreed-upon next steps.',
            Rationale__c             = 'because sending a prompt summary reinforces professionalism and ensures alignment on action items',
            Action_Type__c           = 'Create Task',
            Button_Label__c          = 'Create Task',
            Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                'subject'     => 'Send meeting summary - ' + input.customerCompany,
                'daysOut'     => 1,
                'description' => 'Send follow-up email with meeting notes and discussed materials'
            }),
            Status__c                = 'New',
            Priority__c              = p++
        ));

        String scenario = input.scenarioType;
        if (scenario == 'Renewal') {
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Prepare renewal proposal for ' + input.customerCompany,
                Recommendation_Detail__c = 'Draft a renewal proposal that includes current contract terms, proposed changes, and expansion opportunities discussed on the call.',
                Rationale__c             = 'because the customer indicated readiness to review renewal terms and a timely proposal maintains momentum',
                Action_Type__c           = 'Create Task',
                Button_Label__c          = 'Create Task',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'subject'     => 'Prepare renewal proposal - ' + input.customerCompany,
                    'daysOut'     => 3,
                    'description' => 'Draft renewal proposal with expansion options and updated pricing'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Update opportunity stage to Negotiation',
                Recommendation_Detail__c = 'Move the opportunity forward to reflect the active renewal discussion.',
                Rationale__c             = 'because the customer is engaged in renewal discussions and the deal stage should reflect current status',
                Action_Type__c           = 'Update Opportunity',
                Button_Label__c          = 'Update Deal',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'stageName' => 'Negotiation/Review'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
        } else if (scenario == 'Discovery') {
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Create qualification opportunity for ' + input.customerCompany,
                Recommendation_Detail__c = 'Create a new opportunity to track this evaluation through the sales pipeline.',
                Rationale__c             = 'because the discovery call confirmed genuine interest and a formal opportunity should be created to track progress',
                Action_Type__c           = 'Create Opportunity',
                Button_Label__c          = 'Create Opportunity',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'name'      => input.customerCompany + ' - ' + prod,
                    'stageName' => 'Qualification',
                    'closeDate' => '90 days',
                    'amount'    => 50000
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Send product documentation to ' + input.customerName,
                Recommendation_Detail__c = 'Share relevant product documentation, data sheets, and case studies discussed during the discovery call.',
                Rationale__c             = 'because providing supporting materials reinforces the value proposition and enables the customer to build an internal business case',
                Action_Type__c           = 'Create Task',
                Button_Label__c          = 'Create Task',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'subject'     => 'Send product docs to ' + input.customerName + ' - ' + input.customerCompany,
                    'daysOut'     => 1,
                    'description' => 'Share product documentation, data sheets, and case studies'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
        } else if (scenario == 'DemoFollowUp') {
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Schedule POC kick-off with ' + input.customerName,
                Recommendation_Detail__c = 'Set up a POC kick-off meeting to define success criteria and timeline for the proof of concept.',
                Rationale__c             = 'because the customer expressed interest in a POC as the next evaluation step',
                Action_Type__c           = 'Create Event',
                Button_Label__c          = 'Create Event',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'subject'         => 'POC Kick-off: ' + input.customerCompany,
                    'daysOut'         => 5,
                    'durationMinutes' => 60
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Update opportunity stage to Proposal',
                Recommendation_Detail__c = 'Advance the opportunity stage to reflect the post-demo evaluation progress.',
                Rationale__c             = 'because the positive demo feedback and POC interest indicate the deal has progressed beyond discovery',
                Action_Type__c           = 'Update Opportunity',
                Button_Label__c          = 'Update Deal',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'stageName' => 'Proposal/Price Quote'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
        } else if (scenario == 'CompetitiveDisplacement') {
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Create competitive displacement opportunity',
                Recommendation_Detail__c = 'Create an opportunity to track the competitive displacement evaluation.',
                Rationale__c             = 'because the customer is actively evaluating alternatives and a formal opportunity ensures proper pipeline tracking',
                Action_Type__c           = 'Create Opportunity',
                Button_Label__c          = 'Create Opportunity',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'name'      => input.customerCompany + ' - Competitive Displacement',
                    'stageName' => 'Qualification',
                    'closeDate' => '90 days',
                    'amount'    => 75000
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Update competitor field on account',
                Recommendation_Detail__c = 'Record the competitor information discussed during the call on the account record.',
                Rationale__c             = 'because capturing competitive intelligence on the account ensures the broader team has visibility into the competitive landscape',
                Action_Type__c           = 'Update Competitor',
                Button_Label__c          = 'Update Account',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'competitorName' => !input.keyObjections.isEmpty() ? input.keyObjections[0] : 'Unknown Competitor'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Prepare TCO comparison for ' + input.customerCompany,
                Recommendation_Detail__c = 'Build a total cost of ownership comparison to quantify the financial benefit of switching.',
                Rationale__c             = 'because a data-driven TCO comparison is the most effective way to overcome switching hesitation in competitive deals',
                Action_Type__c           = 'Create Task',
                Button_Label__c          = 'Create Task',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'subject'     => 'Prepare TCO comparison - ' + input.customerCompany,
                    'daysOut'     => 5,
                    'description' => 'Build TCO comparison between current vendor and our platform'
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
        } else if (scenario == 'UpsellCrossSell') {
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Create cross-sell opportunity for ' + prod,
                Recommendation_Detail__c = 'Create a new opportunity to track the cross-sell motion for ' + prod + '.',
                Rationale__c             = 'because the customer expressed interest in expanding their usage and a formal opportunity ensures pipeline visibility',
                Action_Type__c           = 'Create Opportunity',
                Button_Label__c          = 'Create Opportunity',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'name'      => input.customerCompany + ' - ' + prod + ' Cross-Sell',
                    'stageName' => 'Qualification',
                    'closeDate' => '60 days',
                    'amount'    => 35000
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
            recs.add(new Call_Recommendation__c(
                Demo_Video_Call__c       = vcId,
                Recommendation_Title__c  = 'Schedule technical deep-dive on ' + prod,
                Recommendation_Detail__c = 'Arrange a technical session to demonstrate ' + prod + ' capabilities in detail.',
                Rationale__c             = 'because a technical deep-dive will help the customer evaluate fit and build confidence in the expansion decision',
                Action_Type__c           = 'Create Event',
                Button_Label__c          = 'Create Event',
                Action_Config_JSON__c    = JSON.serialize(new Map<String, Object>{
                    'subject'         => 'Technical Deep-Dive: ' + prod + ' - ' + input.customerCompany,
                    'daysOut'         => 5,
                    'durationMinutes' => 60
                }),
                Status__c  = 'New',
                Priority__c = p++
            ));
        }

        return recs;
    }

    // ── Explorer Q&A generation ────────────────────────────────────────

    public static String generateExplorerQA(CallInput input, List<TranscriptEntry> transcript, String impression, String overview, String nextStepsSummary) {
        List<Map<String, Object>> qaPairs = new List<Map<String, Object>>();
        String products = String.join(safe(input.keyProducts), ', ');

        qaPairs.add(buildQA(
            'What was the outcome of the call?',
            overview + ' ' + impression,
            new List<String>{ 'outcome', 'result', 'conclusion', 'ended', 'happen' }
        ));

        qaPairs.add(buildQA(
            'What products were discussed?',
            'The following products were discussed during the call: ' + products + '. ' +
            input.internalRepName + ' walked through the capabilities and how they align with ' +
            input.customerCompany + '\'s requirements.',
            new List<String>{ 'product', 'products', 'solution', 'platform', 'offering', 'feature' }
        ));

        if (!input.keyObjections.isEmpty()) {
            String objList = String.join(input.keyObjections, ', ');
            qaPairs.add(buildQA(
                'What objections were raised?',
                input.customerName + ' raised concerns around ' + objList + '. ' +
                input.internalRepName + ' addressed these by sharing relevant experience and outlining how the solution handles these challenges.',
                new List<String>{ 'objection', 'concern', 'issue', 'problem', 'worry', 'risk', 'challenge' }
            ));
        } else {
            qaPairs.add(buildQA(
                'What objections were raised?',
                'No significant objections were raised during the call. ' + input.customerName +
                ' was receptive to the discussion and did not express major concerns.',
                new List<String>{ 'objection', 'concern', 'issue', 'problem', 'worry', 'risk' }
            ));
        }

        qaPairs.add(buildQA(
            'What are the next steps?',
            nextStepsSummary,
            new List<String>{ 'next', 'steps', 'follow', 'action', 'todo', 'plan' }
        ));

        qaPairs.add(buildQA(
            'How did the customer feel about the call?',
            impression,
            new List<String>{ 'sentiment', 'feel', 'feeling', 'impression', 'reaction', 'mood', 'happy', 'satisfied' }
        ));

        if (input.pricingDiscussed == true) {
            String pricingAnswer = 'Pricing was discussed during the call. ' +
                safe(input.pricingDetails, input.internalRepName + ' presented pricing options aligned with ' + input.customerCompany + '\'s requirements and budget.');
            qaPairs.add(buildQA(
                'What pricing was discussed?',
                pricingAnswer,
                new List<String>{ 'price', 'pricing', 'cost', 'budget', 'money', 'commercial', 'deal', 'terms', 'contract' }
            ));
        } else {
            qaPairs.add(buildQA(
                'What pricing was discussed?',
                'Specific pricing was not discussed on this call. The conversation focused on evaluating ' +
                products + ' and establishing fit before moving to commercial discussions.',
                new List<String>{ 'price', 'pricing', 'cost', 'budget', 'money', 'commercial', 'deal', 'terms' }
            ));
        }

        String competitorAnswer;
        if (input.scenarioType == 'CompetitiveDisplacement') {
            competitorAnswer = 'Yes, the customer is actively evaluating alternatives due to dissatisfaction with their current solution. ' +
                'The conversation centered on how ' + products + ' addresses the gaps in their current vendor\'s offering. ' +
                input.internalRepName + ' differentiated on reliability, support, and roadmap alignment.';
        } else {
            competitorAnswer = 'No specific competitors were mentioned by name during this call. ' +
                input.customerName + ' appeared to be evaluating the solution on its own merits.';
        }
        qaPairs.add(buildQA(
            'Were competitors mentioned?',
            competitorAnswer,
            new List<String>{ 'competitor', 'competition', 'alternative', 'vendor', 'rival', 'versus', 'compared' }
        ));

        qaPairs.add(buildQA(
            'Was a follow-up meeting scheduled?',
            'Yes, ' + input.internalRepName + ' and ' + input.customerName + ' agreed to a follow-up. ' +
            input.internalRepName + ' committed to sending supporting materials and scheduling the next meeting to continue the conversation.',
            new List<String>{ 'follow-up', 'followup', 'meeting', 'schedule', 'calendar', 'reconnect', 'booked' }
        ));

        String participantAnswer = 'The call participants were ' + input.customerName + ' from ' +
            input.customerCompany + ' (customer) and ' + input.internalRepName + ' from ' +
            input.internalRepCompany + ' (internal rep). The call lasted ' +
            input.callDurationMinutes + ' minutes.';
        qaPairs.add(buildQA(
            'Who was on the call?',
            participantAnswer,
            new List<String>{ 'who', 'participant', 'attendee', 'people', 'person', 'joined', 'present' }
        ));

        String durationStr = input.callDurationMinutes + ' minutes';
        Integer customerWords = 0;
        Integer repWords = 0;
        for (TranscriptEntry te : transcript) {
            Integer wc = te.text.split('\\s+').size();
            if (te.speaker == 'customer') { customerWords += wc; } else { repWords += wc; }
        }
        Integer total = customerWords + repWords;
        String custPct = total > 0 ? String.valueOf(((Decimal) customerWords / total * 100).setScale(0, RoundingMode.HALF_UP)) : '50';
        String repPct  = total > 0 ? String.valueOf(((Decimal) repWords / total * 100).setScale(0, RoundingMode.HALF_UP)) : '50';
        qaPairs.add(buildQA(
            'How long was the call?',
            'The call lasted ' + durationStr + '. Talk ratio was approximately ' + custPct +
            '% customer (' + input.customerName + ') and ' + repPct + '% rep (' + input.internalRepName + ').',
            new List<String>{ 'long', 'duration', 'length', 'minutes', 'time', 'ratio', 'talk' }
        ));

        return JSON.serialize(qaPairs);
    }

    private static Map<String, Object> buildQA(String question, String answer, List<String> keywords) {
        Map<String, Object> qa = new Map<String, Object>();
        qa.put('question', question);
        qa.put('answer', answer);
        qa.put('keywords', keywords);
        return qa;
    }

    // ── Utility ─────────────────────────────────────────────────────────

    private static String firstProduct(CallInput input) {
        return (input.keyProducts != null && !input.keyProducts.isEmpty())
            ? input.keyProducts[0]
            : 'Platform';
    }

    private static String firstObjection(CallInput input) {
        return (input.keyObjections != null && !input.keyObjections.isEmpty())
            ? input.keyObjections[0]
            : '';
    }

    private static String safe(String val, String fallback) {
        return String.isNotBlank(val) ? val : fallback;
    }

    private static List<String> safe(List<String> val) {
        return val != null ? val : new List<String>();
    }

    private static String scenarioLabel(String scenarioType) {
        if (scenarioType == 'Renewal')                 { return 'renewal'; }
        if (scenarioType == 'DemoFollowUp')            { return 'demo follow-up'; }
        if (scenarioType == 'CompetitiveDisplacement') { return 'competitive displacement'; }
        if (scenarioType == 'UpsellCrossSell')         { return 'upsell/cross-sell'; }
        return 'discovery';
    }

    private static String buildNextStepsDialogue(CallInput input) {
        if (input.nextSteps != null && !input.nextSteps.isEmpty()) {
            return 'I\'d suggest we ' + String.join(input.nextSteps, ', and ') + '.';
        }
        if (input.scenarioType == 'Renewal') {
            return 'I\'ll get the renewal proposal over to you by end of week and we can regroup after your team has reviewed it.';
        } else if (input.scenarioType == 'DemoFollowUp') {
            return 'I\'ll work on getting the POC environment set up and send over the details by end of week.';
        } else if (input.scenarioType == 'CompetitiveDisplacement') {
            return 'I\'ll put together the migration assessment and TCO comparison and get those over to you early next week.';
        } else if (input.scenarioType == 'UpsellCrossSell') {
            return 'I\'ll send over the pricing details and some customer success stories for ' + firstProduct(input) + ' so you have everything you need for the internal conversation.';
        }
        return 'I\'d recommend we schedule a follow-up with the broader team and I\'ll send over some supporting materials in the meantime.';
    }
}
