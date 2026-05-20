import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateVideoCall from '@salesforce/apex/EciDemoController.generateVideoCall';

const SCENARIO_DEFAULTS = {
    Renewal: {
        callNarrative: 'Discussion about the upcoming contract renewal. The customer expressed satisfaction with the current product but raised concerns about pricing for additional licenses. Both parties discussed potential for upgrading to a higher tier and expanding the number of seats.',
        keyProducts: 'Intermediate Subscription\nAdvanced Subscription',
        keyObjections: 'Need corporate approval for all purchases\nNot sure the advanced tier is necessary',
        sentiment: 'Positive',
        nextSteps: 'Send renewal pricing proposal by end of week\nSchedule demo of Advanced tier features\nCustomer to discuss upgrade options with corporate'
    },
    Discovery: {
        callNarrative: 'Initial discovery call to understand the prospect\'s current challenges and evaluate fit. The customer described pain points with their existing solution and expressed interest in exploring alternatives. We discussed requirements, timeline, and budget considerations.',
        keyProducts: 'Enterprise Platform\nAnalytics Add-On',
        keyObjections: 'Current vendor has a long-term contract\nConcerned about migration complexity',
        sentiment: 'Positive',
        nextSteps: 'Send product overview and case studies\nSchedule technical deep-dive with their IT team\nPrepare custom demo for their use case'
    },
    DemoFollowUp: {
        callNarrative: 'Follow-up call after the product demonstration. The customer provided positive feedback on core features but had questions about specific workflows. We addressed technical concerns and discussed next steps for a proof of concept.',
        keyProducts: 'Core Platform\nWorkflow Automation Module',
        keyObjections: 'Integration with existing systems is a concern\nWant to see more customization options',
        sentiment: 'Positive',
        nextSteps: 'Provide detailed integration documentation\nSet up POC environment by next Wednesday\nSchedule follow-up with their technical lead'
    },
    CompetitiveDisplacement: {
        callNarrative: 'Strategic call to discuss replacing the customer\'s current vendor. The customer expressed frustration with their incumbent solution and is actively evaluating alternatives. We positioned our differentiated capabilities and discussed a migration path.',
        keyProducts: 'Enterprise Suite\nMigration Services',
        keyObjections: 'Switching costs are a concern\nNeed to justify the change to executive leadership',
        sentiment: 'Neutral',
        nextSteps: 'Prepare TCO comparison document\nSchedule executive briefing\nProvide reference customers in their industry'
    },
    UpsellCrossSell: {
        callNarrative: 'Call with existing customer about expanding their usage. The customer has been successful with the current product and is interested in additional capabilities. We discussed complementary products and potential volume discounts for expanded deployment.',
        keyProducts: 'Premium Add-On\nAdvanced Analytics',
        keyObjections: 'Budget constraints for this quarter\nNeed to prove ROI of current investment first',
        sentiment: 'Positive',
        nextSteps: 'Send expanded product pricing\nSchedule workshop on advanced analytics features\nPrepare ROI report based on current usage data'
    }
};

export default class EciDemoWizard extends NavigationMixin(LightningElement) {
    currentStep = '1';
    isGenerating = false;

    callTitle = '';
    customerName = '';
    customerCompany = '';
    internalRepName = '';
    internalRepCompany = '';
    callStarted = '';
    callDurationMinutes = 5;
    language = 'English';
    relatedAccountId = '';
    relatedRecordDisplay = '';
    videoUrl = '';

    scenarioType = '';
    callNarrative = '';
    keyProductsText = '';
    keyObjectionsText = '';
    customerSentiment = 'Positive';
    pricingDiscussed = false;
    pricingDetails = '';
    nextStepsText = '';

    @track _transcriptEntries = [];

    summaryCustomerImpression = '';
    summaryCallOverview = '';
    summaryNextSteps = '';
    @track _insightQAs = [
        { question: 'What were the deal terms on this call?', answer: '' },
        { question: 'What was the customer sentiment on this call?', answer: '' },
        { question: 'Will this deal close this quarter?', answer: '' }
    ];

    @track _recommendations = [];
    _summaryAutoPopulated = false;
    _recsAutoPopulated = false;

    get scenarioOptions() {
        return [
            { label: 'Renewal Discussion', value: 'Renewal' },
            { label: 'Discovery Call', value: 'Discovery' },
            { label: 'Demo Follow-Up', value: 'DemoFollowUp' },
            { label: 'Competitive Displacement', value: 'CompetitiveDisplacement' },
            { label: 'Upsell / Cross-Sell', value: 'UpsellCrossSell' }
        ];
    }

    get sentimentOptions() {
        return [
            { label: 'Positive', value: 'Positive' },
            { label: 'Neutral', value: 'Neutral' },
            { label: 'Negative', value: 'Negative' }
        ];
    }

    get speakerOptions() {
        return [
            { label: 'Customer', value: 'customer' },
            { label: 'Rep', value: 'rep' }
        ];
    }

    get actionTypeOptions() {
        return [
            { label: 'Create Task', value: 'Create Task' },
            { label: 'Create Opportunity', value: 'Create Opportunity' },
            { label: 'Update Opportunity', value: 'Update Opportunity' },
            { label: 'Create Event', value: 'Create Event' },
            { label: 'Log Follow-Up Call', value: 'Log Follow-Up Call' },
            { label: 'Update Competitor', value: 'Update Competitor' },
            { label: 'Create Contact', value: 'Create Contact' }
        ];
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }
    get isStep6() { return this.currentStep === '6'; }

    get canGoBack() { return parseInt(this.currentStep, 10) > 1; }
    get canGoNext() { return parseInt(this.currentStep, 10) < 6; }

    handleBack() {
        const step = parseInt(this.currentStep, 10);
        if (step > 1) this.currentStep = String(step - 1);
    }

    handleNext() {
        const step = parseInt(this.currentStep, 10);
        const nextStep = step + 1;

        if (nextStep === 4 && !this._summaryAutoPopulated) {
            this._autoPopulateSummary();
        }
        if (nextStep === 5 && !this._recsAutoPopulated) {
            this._autoPopulateRecommendations();
        }

        if (step < 6) this.currentStep = String(nextStep);
    }

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.detail.value || event.target.value;
    }

    handleToggle(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.target.checked;
    }

    handleScenarioChange(event) {
        this.scenarioType = event.detail.value;
        const defaults = SCENARIO_DEFAULTS[this.scenarioType];
        if (defaults) {
            this.callNarrative = defaults.callNarrative;
            this.keyProductsText = defaults.keyProducts;
            this.keyObjectionsText = defaults.keyObjections;
            this.customerSentiment = defaults.sentiment;
            this.nextStepsText = defaults.nextSteps;
        }
        this._summaryAutoPopulated = false;
        this._recsAutoPopulated = false;
    }

    // ── Transcript Builder ───────────────────────────────────────────

    get wizardTranscriptEntries() {
        return this._transcriptEntries.map((entry, idx) => ({
            ...entry,
            id: `te-${idx}`,
            index: idx,
            insightsText: (entry.insights || []).join(', ')
        }));
    }

    get hasTranscriptEntries() {
        return this._transcriptEntries.length > 0;
    }

    get transcriptCount() {
        return this._transcriptEntries.length;
    }

    handleAddTranscriptEntry() {
        this._transcriptEntries = [
            ...this._transcriptEntries,
            { speaker: 'rep', timestamp: '', text: '', insights: [] }
        ];
    }

    handleRemoveTranscriptEntry(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this._transcriptEntries = this._transcriptEntries.filter((_, i) => i !== idx);
    }

    handleTranscriptFieldChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.tfield;
        const value = event.detail.value || event.target.value;

        this._transcriptEntries = this._transcriptEntries.map((entry, i) => {
            if (i !== idx) return entry;
            const updated = { ...entry };
            if (field === 'insightsText') {
                updated.insights = value.split(',').map(s => s.trim()).filter(Boolean);
            } else {
                updated[field] = value;
            }
            return updated;
        });
    }

    handleGenerateTranscript() {
        const cust = this.customerName || 'Customer';
        const rep = this.internalRepName || 'Rep';
        const custCo = this.customerCompany || 'their company';
        const products = this._splitLines(this.keyProductsText);
        const objections = this._splitLines(this.keyObjectionsText);
        const prod = products.length > 0 ? products[0] : 'the platform';
        const obj = objections.length > 0 ? objections[0] : '';
        const scenario = this.scenarioType || 'Discovery';
        const pricing = this.pricingDiscussed;
        const priceDtl = this.pricingDetails || 'We\'ve put together competitive pricing.';
        const steps = this._splitLines(this.nextStepsText);
        const stepsDialogue = steps.length > 0
            ? 'I\'d suggest we ' + steps.join(', and ') + '.'
            : 'I\'ll send over some materials and we can schedule a follow-up.';

        const entries = [];
        const add = (speaker, text) => entries.push({ speaker, text, timestamp: '', insights: [] });

        if (scenario === 'Renewal') {
            add('rep', `Hi ${cust}, thanks for making time today. I wanted to touch base on your upcoming renewal and make sure we're aligned on everything going forward.`);
            add('customer', `Of course, ${rep}. We've been reviewing the current contract internally and have a few thoughts to share.`);
            add('rep', `Great. Before we dive in, I'd love to hear how things have been going with ${prod} over the past year. What's been working well for your team?`);
            add('customer', `Honestly, ${prod} has been solid. The team uses it daily and it has really become core to our workflow. Adoption has been strong across the board.`);
            if (obj) {
                add('customer', `That said, we do have some concerns. ${obj} is something we need to address before we move forward with the renewal.`);
                add('rep', `I appreciate you raising that. We've actually been investing heavily in that area. Let me walk you through what we've done to address ${obj} and the roadmap ahead.`);
            }
            if (pricing) {
                add('rep', `Let's talk about the commercial side. ${priceDtl}`);
                add('customer', `Pricing is definitely a factor in our decision. We need to see that the investment is justified by the outcomes we're achieving.`);
            }
            add('rep', `I also wanted to mention a few new capabilities we're rolling out that could be a great fit, particularly around expanding your use of ${prod}.`);
            add('customer', `We're open to hearing about that. If it makes sense from a budget and resources perspective, we'd consider expanding.`);
            add('rep', `Perfect. In terms of next steps, ${stepsDialogue}`);
            add('customer', `Sounds good. Let's target getting everything reviewed within the next two weeks so we can stay on track.`);
            add('rep', `That works perfectly. Thanks again, ${cust}. I'll follow up with everything by end of day tomorrow.`);
        } else if (scenario === 'DemoFollowUp') {
            add('rep', `Hi ${cust}, thanks for jumping on again. I wanted to follow up on the demo from last week and hear your team's feedback.`);
            add('customer', `Hi ${rep}. Thanks for the follow-up. Overall the reaction was really positive. The team was impressed with ${prod}.`);
            add('rep', `That's great to hear. Were there any specific features or capabilities that stood out?`);
            add('customer', `The automation piece definitely got a lot of attention. People could see how it would save time on some of the repetitive work we're doing today.`);
            if (obj) {
                add('customer', `We did have some questions come up though, especially around ${obj}. A few stakeholders flagged that as something we need to resolve before moving forward.`);
                add('rep', `Completely understandable. Let me address that directly. ${obj} is something we've worked through with similar organizations. I can share some reference architectures and connect you with a customer who had the same concern.`);
            }
            if (pricing) {
                add('rep', `Should we talk through the commercial side as well? ${priceDtl}`);
                add('customer', `Yes, let's go through the numbers. Budget approval is the next gate for us.`);
            }
            add('rep', `Based on the feedback, it sounds like a POC could be the logical next step. We could set up a focused pilot with your priority use cases and have results within two to three weeks.`);
            add('customer', `I think that makes sense. Let me confirm with our IT lead, but a POC would help us build the internal business case.`);
            add('rep', `Perfect. ${stepsDialogue}`);
            add('customer', `Sounds like a plan. Talk soon.`);
        } else if (scenario === 'CompetitiveDisplacement') {
            add('rep', `Hi ${cust}, thanks for taking the time. I know you're currently evaluating alternatives and I wanted to discuss how ${prod} compares to what you have in place today.`);
            add('customer', `Hi ${rep}. Yes, we're in an active evaluation. Our current vendor has been falling short in a few areas and we need to make a change.`);
            add('rep', `Can you share more about what's driving the decision to look at alternatives?`);
            add('customer', `The biggest issue is reliability. We've had multiple outages this year and the support response has been poor. On top of that, their product roadmap doesn't align with where we're heading as a business.`);
            add('rep', `I hear that a lot from organizations making the switch. With ${prod}, we've built our platform around the exact pain points you're describing — reliability, proactive support, and a roadmap driven by customer input.`);
            if (obj) {
                add('customer', `My concern about switching is ${obj}. We went through a painful migration once before and I don't want to repeat that.`);
                add('rep', `That's a valid concern. We've developed a structured migration program specifically for customers coming from your current platform. We handle the heavy lifting and the typical transition takes four to six weeks with zero downtime.`);
            }
            add('rep', `Let me share some ROI data from customers who made a similar move. On average, they've seen a thirty percent reduction in operational costs and a significant improvement in system uptime within the first quarter.`);
            add('customer', `Those numbers are compelling. What does the migration plan actually look like in practice?`);
            add('rep', `For next steps, ${stepsDialogue}`);
            add('customer', `Let's do it. I'll loop in our CTO for the next conversation. Appreciate the detail, ${rep}.`);
        } else if (scenario === 'UpsellCrossSell') {
            add('rep', `Hi ${cust}, thanks for connecting. I've been looking at how ${custCo} has been using the platform and I see some opportunities where we could drive even more value for your team.`);
            add('customer', `Hi ${rep}. We're always open to hearing about ways to get more out of the investment. What did you have in mind?`);
            add('rep', `Right now your team is using the core platform really effectively. What I've noticed is that teams with your usage profile tend to see a big lift when they add ${prod}.`);
            add('customer', `Interesting. We've heard about ${prod} but haven't explored it in depth. How does it complement what we're already doing?`);
            add('rep', `${prod} extends your current setup by adding deeper analytics and automation capabilities. Think of it as the next layer that turns the data you're already capturing into actionable insights.`);
            if (obj) {
                add('customer', `That sounds promising, but I'm a bit concerned about ${obj}. We don't have a lot of bandwidth for a big rollout right now.`);
                add('rep', `Totally fair. The good news is that ${prod} is designed to layer on top of your existing setup with minimal effort. Most customers are up and running within a week.`);
            }
            if (pricing) {
                add('rep', `On the pricing side, ${priceDtl}`);
                add('customer', `That helps. Can you send over the pricing details so I can share with our finance team?`);
            }
            add('rep', `In terms of timeline, we could have a pilot running within the next two weeks if you're ready to move forward.`);
            add('customer', `Let me talk to the team and come back to you by end of week. I think there's definitely interest.`);
            add('rep', `Sounds good. ${stepsDialogue}`);
        } else {
            add('rep', `Hi ${cust}, thanks for joining today. I'm excited to learn more about what ${custCo} is working on. I thought we could start with your current setup and then explore where we might be able to help.`);
            add('customer', `Sounds good, ${rep}. We're at a point where we're evaluating options so the timing works well.`);
            add('rep', `Great. Can you walk me through how your team currently handles the processes that ${prod} would touch?`);
            add('customer', `Right now it's mostly manual. We have a mix of spreadsheets and legacy tools that don't talk to each other. It's creating bottlenecks, especially as we scale.`);
            if (obj) {
                add('customer', `One of our biggest pain points is around ${obj}. It's been a persistent challenge and a key driver for this evaluation.`);
                add('rep', `That's a challenge we hear often. ${prod} was actually designed with that exact scenario in mind. Let me show you how other customers in your space have tackled ${obj}.`);
            }
            add('customer', `That's interesting. Can you tell me more about how ${prod} integrates with our existing systems? We don't want a rip-and-replace situation.`);
            add('rep', `Absolutely. We have pre-built connectors for most major platforms, and our API framework is designed for the kind of hybrid environment you described.`);
            add('rep', `In terms of fit, it sounds like ${prod} aligns well with your goals around consolidation and addressing the challenges you mentioned.`);
            add('customer', `I'd agree with that assessment. What does the typical timeline look like from evaluation to go-live?`);
            add('rep', `Typically we see about sixty to ninety days from contract to production. For next steps, ${stepsDialogue}`);
            add('customer', `That works for us. Let's plan on reconnecting next week with the broader team. Appreciate the thorough walkthrough, ${rep}.`);
        }

        let seconds = 0;
        for (const entry of entries) {
            const mins = Math.floor(seconds / 60);
            const secs = seconds % 60;
            entry.timestamp = String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
            const wordCount = entry.text.split(/\s+/).length;
            seconds += Math.max(15, Math.min(45, wordCount * 2));
        }

        this._transcriptEntries = entries;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Transcript Generated',
            message: `${entries.length} transcript entries created from your scenario. Edit any entry below.`,
            variant: 'success'
        }));
    }

    // ── Auto-populate Summary & Insights ─────────────────────────────

    _autoPopulateSummary() {
        const cust = this.customerName || 'Customer';
        const rep = this.internalRepName || 'Rep';
        const custCo = this.customerCompany || 'their company';
        const repCo = this.internalRepCompany || 'our company';
        const products = this._splitLines(this.keyProductsText);
        const objections = this._splitLines(this.keyObjectionsText);
        const sentiment = this.customerSentiment || 'Neutral';
        const duration = this.callDurationMinutes || 5;
        const scenario = this.scenarioType || 'Discovery';
        const steps = this._splitLines(this.nextStepsText);

        const scenarioLabels = {
            Renewal: 'renewal',
            Discovery: 'discovery',
            DemoFollowUp: 'demo follow-up',
            CompetitiveDisplacement: 'competitive displacement',
            UpsellCrossSell: 'upsell/cross-sell'
        };
        const scenLabel = scenarioLabels[scenario] || 'discovery';

        if (!this.summaryCustomerImpression) {
            if (sentiment === 'Positive') {
                this.summaryCustomerImpression = `${cust} was engaged and receptive throughout the conversation. They expressed clear enthusiasm about the product capabilities and indicated strong alignment with their strategic priorities. ${rep}'s consultative approach resonated well with the customer.`;
            } else if (sentiment === 'Negative') {
                this.summaryCustomerImpression = `${cust} expressed notable reservations during the call. While willing to continue the evaluation, there are unresolved concerns that ${rep} will need to address in follow-up communications. Careful attention to the customer's specific objections will be important for progressing this opportunity.`;
            } else {
                this.summaryCustomerImpression = `${cust} was professional and measured in their engagement. They showed interest in the discussion but maintained a cautious evaluation posture. ${rep} should continue building value and addressing any unstated concerns in subsequent interactions.`;
            }
        }

        if (!this.summaryCallOverview) {
            let overview = `${rep} from ${repCo} connected with ${cust} from ${custCo} for a ${duration}-minute ${scenLabel} call. `;
            if (products.length > 0) {
                overview += `Key products discussed included ${products.join(', ')}. `;
            }
            if (objections.length > 0) {
                overview += `The customer raised concerns around ${objections.join(', ')}, which were addressed during the conversation. `;
            }
            if (this.pricingDiscussed) {
                overview += 'Pricing was discussed during the call. ';
            }
            overview += 'The call concluded with clear alignment on next steps.';
            this.summaryCallOverview = overview;
        }

        if (!this.summaryNextSteps) {
            if (steps.length > 0) {
                this.summaryNextSteps = steps.map((s, i) => `${i + 1}. ${s}`).join('\n');
            } else {
                this.summaryNextSteps = '1. Send follow-up email with meeting summary\n2. Schedule next meeting\n3. Share relevant materials';
            }
        }

        const prodStr = products.join(', ') || 'the platform';
        const sentLower = sentiment.toLowerCase();

        const pricingAnswer = this.pricingDiscussed && this.pricingDetails
            ? `Pricing was discussed on this call. ${this.pricingDetails}`
            : `Specific deal terms were not discussed in detail on this call. The conversation focused on ${prodStr} and evaluating fit before moving to commercial discussions.`;

        const sentimentAnswer = `The overall customer sentiment on this call was ${sentLower}. ${cust} from ${custCo} was ${
            sentLower === 'positive' ? 'engaged and receptive, showing clear interest in moving forward.' :
            sentLower === 'negative' ? 'reserved and raised several concerns that need to be addressed before progressing.' :
            'professional and evaluative, maintaining an open but cautious posture throughout the discussion.'}`;

        let closeAnswer;
        if (sentLower === 'positive' && steps.length > 0) {
            closeAnswer = 'Based on the positive customer sentiment and clear next steps established during the call, there is a strong likelihood this deal could progress to close this quarter, contingent on successful completion of the outlined action items.';
        } else if (sentLower === 'negative') {
            closeAnswer = 'Given the concerns raised during the call, closing this quarter may be challenging. The sales team should prioritize addressing the customer\'s objections and re-establishing momentum before forecasting a close date.';
        } else {
            closeAnswer = 'The deal shows potential but the timeline depends on how quickly the next steps are executed and any remaining concerns are resolved. Close this quarter is possible but not certain based on current signals.';
        }

        let compAnswer;
        if (objections.length > 0 && scenario === 'CompetitiveDisplacement') {
            compAnswer = `Competitive dynamics were a central theme on this call. The customer is actively evaluating alternatives due to dissatisfaction with their current vendor. Key concerns included ${objections.join(', ')}. The team should prepare competitive battle cards and be ready to differentiate on these specific points.`;
        } else if (objections.length > 0) {
            compAnswer = `While this was not explicitly a competitive evaluation, the customer raised concerns around ${objections.join(', ')} which could indicate competitive alternatives are being considered. Proactive competitive positioning is recommended.`;
        } else {
            compAnswer = 'No direct competitive threats were mentioned on this call. The customer appears to be evaluating the solution on its own merits rather than in a comparative context.';
        }

        this._insightQAs = [
            { question: 'What were the deal terms on this call?', answer: pricingAnswer },
            { question: 'What was the customer sentiment on this call?', answer: sentimentAnswer },
            { question: 'Will this deal close this quarter?', answer: closeAnswer },
            { question: 'What competitive threats were mentioned?', answer: compAnswer }
        ];

        this._summaryAutoPopulated = true;
    }

    // ── Auto-populate Recommendations ────────────────────────────────

    _autoPopulateRecommendations() {
        const cust = this.customerName || 'Customer';
        const custCo = this.customerCompany || 'Acme Corp';
        const products = this._splitLines(this.keyProductsText);
        const prod = products.length > 0 ? products[0] : 'Platform';
        const scenario = this.scenarioType || 'Discovery';

        const recs = [];

        recs.push({
            title: `Schedule follow-up meeting with ${cust}`,
            detail: `Set up a follow-up meeting to continue the conversation and maintain momentum with ${custCo}.`,
            rationale: `because timely follow-up is critical to keeping the deal progressing`,
            actionType: 'Create Event',
            buttonLabel: 'Create Event'
        });

        recs.push({
            title: `Send meeting summary to ${cust}`,
            detail: 'Prepare and send a follow-up email summarizing key discussion points and agreed-upon next steps.',
            rationale: 'because sending a prompt summary reinforces professionalism and ensures alignment on action items',
            actionType: 'Create Task',
            buttonLabel: 'Create Task'
        });

        if (scenario === 'Renewal') {
            recs.push({
                title: `Prepare renewal proposal for ${custCo}`,
                detail: 'Draft a renewal proposal with current terms, proposed changes, and expansion options.',
                rationale: 'because the customer indicated readiness to review renewal terms and a timely proposal maintains momentum',
                actionType: 'Create Task',
                buttonLabel: 'Create Task'
            });
            recs.push({
                title: 'Update opportunity stage to Negotiation',
                detail: 'Move the opportunity forward to reflect the active renewal discussion.',
                rationale: 'because the customer is engaged in renewal discussions and the deal stage should reflect current status',
                actionType: 'Update Opportunity',
                buttonLabel: 'Update Deal'
            });
        } else if (scenario === 'Discovery') {
            recs.push({
                title: `Create qualification opportunity for ${custCo}`,
                detail: 'Create a new opportunity to track this evaluation through the sales pipeline.',
                rationale: 'because the discovery call confirmed genuine interest and a formal opportunity should be created',
                actionType: 'Create Opportunity',
                buttonLabel: 'Create Opportunity'
            });
            recs.push({
                title: `Send product documentation to ${cust}`,
                detail: 'Share relevant product documentation, data sheets, and case studies.',
                rationale: 'because providing supporting materials helps the customer build an internal business case',
                actionType: 'Create Task',
                buttonLabel: 'Create Task'
            });
        } else if (scenario === 'DemoFollowUp') {
            recs.push({
                title: `Schedule POC kick-off with ${cust}`,
                detail: 'Set up a POC kick-off meeting to define success criteria and timeline.',
                rationale: 'because the customer expressed interest in a POC as the next evaluation step',
                actionType: 'Create Event',
                buttonLabel: 'Create Event'
            });
            recs.push({
                title: 'Update opportunity stage to Proposal',
                detail: 'Advance the opportunity stage to reflect post-demo progress.',
                rationale: 'because the positive demo feedback and POC interest indicate the deal has progressed beyond discovery',
                actionType: 'Update Opportunity',
                buttonLabel: 'Update Deal'
            });
        } else if (scenario === 'CompetitiveDisplacement') {
            recs.push({
                title: 'Create competitive displacement opportunity',
                detail: 'Create an opportunity to track the competitive displacement evaluation.',
                rationale: 'because the customer is actively evaluating alternatives and pipeline tracking is essential',
                actionType: 'Create Opportunity',
                buttonLabel: 'Create Opportunity'
            });
            recs.push({
                title: 'Update competitor field on account',
                detail: 'Record the competitor information discussed during the call.',
                rationale: 'because capturing competitive intelligence ensures team-wide visibility',
                actionType: 'Update Competitor',
                buttonLabel: 'Update Account'
            });
            recs.push({
                title: `Prepare TCO comparison for ${custCo}`,
                detail: 'Build a total cost of ownership comparison to quantify the benefit of switching.',
                rationale: 'because a data-driven TCO comparison is the most effective way to overcome switching hesitation',
                actionType: 'Create Task',
                buttonLabel: 'Create Task'
            });
        } else if (scenario === 'UpsellCrossSell') {
            recs.push({
                title: `Create cross-sell opportunity for ${prod}`,
                detail: `Create a new opportunity to track the cross-sell motion for ${prod}.`,
                rationale: 'because the customer expressed interest in expanding their usage',
                actionType: 'Create Opportunity',
                buttonLabel: 'Create Opportunity'
            });
            recs.push({
                title: `Schedule technical deep-dive on ${prod}`,
                detail: `Arrange a technical session to demonstrate ${prod} capabilities in detail.`,
                rationale: 'because a technical deep-dive will help the customer evaluate fit and build confidence',
                actionType: 'Create Event',
                buttonLabel: 'Create Event'
            });
        }

        this._recommendations = recs;
        this._recsAutoPopulated = true;
    }

    // ── Summary & Insights handlers ──────────────────────────────────

    get wizardInsightQAs() {
        return this._insightQAs.map((qa, idx) => ({
            ...qa,
            id: `qa-${idx}`,
            index: idx
        }));
    }

    handleQAChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.qafield;
        const value = event.detail.value || event.target.value;
        this._insightQAs = this._insightQAs.map((qa, i) => {
            if (i !== idx) return qa;
            return { ...qa, [field]: value };
        });
    }

    handleAddQA() {
        this._insightQAs = [...this._insightQAs, { question: '', answer: '' }];
    }

    handleRemoveQA(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this._insightQAs = this._insightQAs.filter((_, i) => i !== idx);
    }

    // ── Recommendations handlers ─────────────────────────────────────

    get wizardRecommendations() {
        return this._recommendations.map((rec, idx) => ({
            ...rec,
            id: `rec-${idx}`,
            index: idx
        }));
    }

    get recommendationCount() {
        return this._recommendations.length;
    }

    handleRecChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.rfield;
        const value = event.detail.value || event.target.value;
        this._recommendations = this._recommendations.map((rec, i) => {
            if (i !== idx) return rec;
            return { ...rec, [field]: value };
        });
    }

    handleAddRec() {
        this._recommendations = [
            ...this._recommendations,
            {
                title: '',
                detail: '',
                rationale: '',
                actionType: 'Create Task',
                buttonLabel: 'Create Task'
            }
        ];
    }

    handleRemoveRec(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this._recommendations = this._recommendations.filter((_, i) => i !== idx);
    }

    // ── Generate ─────────────────────────────────────────────────────

    async handleGenerate() {
        this.isGenerating = true;

        const input = {
            callTitle: this.callTitle,
            customerName: this.customerName,
            customerCompany: this.customerCompany,
            internalRepName: this.internalRepName,
            internalRepCompany: this.internalRepCompany,
            callStarted: this.callStarted || null,
            callDurationMinutes: this.callDurationMinutes || 5,
            language: this.language,
            relatedAccountId: this.relatedAccountId || null,
            relatedRecordDisplay: this.relatedRecordDisplay,
            videoUrl: this.videoUrl,
            scenarioType: this.scenarioType,
            callNarrative: this.callNarrative,
            keyProducts: this._splitLines(this.keyProductsText),
            keyObjections: this._splitLines(this.keyObjectionsText),
            pricingDiscussed: this.pricingDiscussed,
            pricingDetails: this.pricingDetails,
            nextSteps: this._splitLines(this.nextStepsText),
            customerSentiment: this.customerSentiment,
            transcriptEntries: this._transcriptEntries.length > 0 ? this._transcriptEntries : null,
            recommendations: this._recommendations.length > 0
                ? this._recommendations.map(rec => ({
                    title: rec.title,
                    detail: rec.detail,
                    rationale: rec.rationale,
                    actionType: rec.actionType,
                    buttonLabel: rec.buttonLabel,
                    actionConfig: {}
                }))
                : null,
            summaryCustomerImpression: this.summaryCustomerImpression || null,
            summaryCallOverview: this.summaryCallOverview || null,
            summaryNextSteps: this.summaryNextSteps || null,
            generativeInsights: this._insightQAs.filter(qa => qa.question && qa.answer).length > 0
                ? this._insightQAs.filter(qa => qa.question && qa.answer)
                : null
        };

        try {
            const recordId = await generateVideoCall({ inputJson: JSON.stringify(input) });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Demo Call Created',
                message: 'Your demo video call has been generated successfully.',
                variant: 'success'
            }));

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Demo_Video_Call__c',
                    actionName: 'view'
                }
            });

        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: err.body ? err.body.message : 'Failed to generate demo call.',
                variant: 'error'
            }));
        } finally {
            this.isGenerating = false;
        }
    }

    _splitLines(text) {
        if (!text) return [];
        return text.split('\n').map(l => l.trim()).filter(Boolean);
    }
}
