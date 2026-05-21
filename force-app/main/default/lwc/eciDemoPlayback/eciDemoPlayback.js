import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = [
    'Demo_Video_Call__c.Call_Title__c',
    'Demo_Video_Call__c.Call_Started__c',
    'Demo_Video_Call__c.Call_Duration_Minutes__c',
    'Demo_Video_Call__c.Language__c',
    'Demo_Video_Call__c.Related_Account__c',
    'Demo_Video_Call__c.Related_Record_Display__c',
    'Demo_Video_Call__c.Customer_Name__c',
    'Demo_Video_Call__c.Customer_Company__c',
    'Demo_Video_Call__c.Internal_Rep_Name__c',
    'Demo_Video_Call__c.Internal_Rep_Company__c',
    'Demo_Video_Call__c.Video_URL__c',
    'Demo_Video_Call__c.Transcript_JSON__c',
    'Demo_Video_Call__c.Insights_JSON__c',
    'Demo_Video_Call__c.Summary_Customer_Impression__c',
    'Demo_Video_Call__c.Summary_Call_Overview__c',
    'Demo_Video_Call__c.Summary_Next_Steps__c',
    'Demo_Video_Call__c.Generative_Insights_JSON__c',
    'Demo_Video_Call__c.Talk_Ratio_Customer__c',
    'Demo_Video_Call__c.Talk_Ratio_Rep__c',
    'Demo_Video_Call__c.Call_Explorer_QA_JSON__c',
    'Demo_Video_Call__c.OwnerId',
    'Demo_Video_Call__c.Owner.Name'
];

export default class EciDemoPlayback extends LightningElement {
    @api recordId;
    callData;
    error;
    isLoading = true;
    activeTab = 'transcript';
    collapsedInsights = {};
    showExplorer = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCall({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.callData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.callData = undefined;
        }
    }

    get hasData() {
        return !!this.callData;
    }

    _field(fieldName) {
        return getFieldValue(this.callData, `Demo_Video_Call__c.${fieldName}`);
    }

    get callTitle() {
        return this._field('Call_Title__c') || '';
    }

    get callStartedFormatted() {
        const dt = this._field('Call_Started__c');
        if (!dt) return '';
        const d = new Date(dt);
        return d.toLocaleDateString('en-US', {
            month: 'numeric', day: 'numeric', year: 'numeric'
        }) + ', ' + d.toLocaleTimeString('en-US', {
            hour: 'numeric', minute: '2-digit', hour12: true
        });
    }

    get callDurationFormatted() {
        const mins = this._field('Call_Duration_Minutes__c');
        if (!mins) return '';
        const m = Math.floor(mins);
        const s = Math.round((mins - m) * 60);
        return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }

    get language() {
        return this._field('Language__c') || 'English';
    }

    get relatedRecordDisplay() {
        return this._field('Related_Record_Display__c') || '';
    }

    get ownerName() {
        return getFieldValue(this.callData, 'Demo_Video_Call__c.Owner.Name') || '';
    }

    get customerName() {
        return this._field('Customer_Name__c') || '';
    }

    get customerCompany() {
        return this._field('Customer_Company__c') || '';
    }

    get internalRepName() {
        return this._field('Internal_Rep_Name__c') || '';
    }

    get internalRepCompany() {
        return this._field('Internal_Rep_Company__c') || '';
    }

    get videoUrl() {
        return this._field('Video_URL__c') || '';
    }

    get hasVideo() {
        return !!this.videoUrl;
    }

    get isYouTube() {
        const url = this.videoUrl;
        return /youtube\.com|youtu\.be/i.test(url);
    }

    get youTubeEmbedUrl() {
        const url = this.videoUrl;
        let videoId = '';
        const shortMatch = url.match(/youtu\.be\/([^?&#]+)/);
        const longMatch = url.match(/[?&]v=([^&#]+)/);
        if (shortMatch) {
            videoId = shortMatch[1];
        } else if (longMatch) {
            videoId = longMatch[1];
        }
        return videoId ? `https://www.youtube.com/embed/${videoId}` : '';
    }

    get isGoogleDrive() {
        return /drive\.google\.com\/file\/d\//i.test(this.videoUrl);
    }

    get googleDriveEmbedUrl() {
        const match = this.videoUrl.match(/\/file\/d\/([^/]+)/);
        return match ? `https://drive.google.com/file/d/${match[1]}/preview` : '';
    }

    get isDirectVideo() {
        return this.hasVideo && !this.isYouTube && !this.isGoogleDrive;
    }

    // --- Insights ---

    get insightsData() {
        const raw = this._field('Insights_JSON__c');
        if (!raw) return {};
        try {
            return JSON.parse(raw);
        } catch {
            return {};
        }
    }

    get insightCategories() {
        const data = this.insightsData;
        const categories = [];

        const addCategory = (key, label, items) => {
            if (items && items.length > 0) {
                categories.push({
                    key,
                    label,
                    items: items.map((item, idx) => ({
                        key: `${key}-${idx}`,
                        label: item.label,
                        count: item.count
                    })),
                    isExpanded: !this.collapsedInsights[key],
                    chevron: this.collapsedInsights[key]
                        ? 'utility:chevronright' : 'utility:chevrondown'
                });
            }
        };

        addCategory('product', 'Product', data.product);
        addCategory('objection', 'Objection', data.objection);
        addCategory('pricing', 'Pricing', data.pricing);
        if (data.longestMonologue) {
            addCategory('longestMonologue', 'Longest Monologue', [{
                label: 'Longest Monologue',
                count: 1
            }]);
        }
        addCategory('nextStep', 'Next Step', data.nextStep);

        return categories;
    }

    toggleInsightCategory(event) {
        const key = event.currentTarget.dataset.key;
        this.collapsedInsights = {
            ...this.collapsedInsights,
            [key]: !this.collapsedInsights[key]
        };
    }

    // --- Timeline Dots ---

    get timelineDots() {
        const entries = this.transcriptEntries;
        const dots = [];
        const totalSlots = 30;
        for (let i = 0; i < totalSlots; i++) {
            const entryIdx = Math.floor((i / totalSlots) * entries.length);
            const entry = entries[entryIdx];
            const hasInsight = entry && entry.hasInsights;
            dots.push({
                id: `dot-${i}`,
                cssClass: hasInsight ? 'dot dot-insight' : 'dot dot-empty'
            });
        }
        return dots;
    }

    // --- Talk Ratios ---

    get customerRatio() {
        return this._field('Talk_Ratio_Customer__c') || 0;
    }

    get repRatio() {
        return this._field('Talk_Ratio_Rep__c') || 0;
    }

    get customerRatioFormatted() {
        return Math.round(this.customerRatio) + '%';
    }

    get repRatioFormatted() {
        return Math.round(this.repRatio) + '%';
    }

    get customerRatioStyle() {
        return `width: ${this.customerRatio}%`;
    }

    get repRatioStyle() {
        return `width: ${this.repRatio}%`;
    }

    // --- Tabs ---

    get isTranscriptTab() { return this.activeTab === 'transcript'; }
    get isSummaryTab() { return this.activeTab === 'summary'; }
    get isInsightsTab() { return this.activeTab === 'insights'; }
    get isActionsTab() { return this.activeTab === 'actions'; }

    get tabClassTranscript() {
        return this.activeTab === 'transcript'
            ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }
    get tabClassSummary() {
        return this.activeTab === 'summary'
            ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }
    get tabClassInsights() {
        return this.activeTab === 'insights'
            ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }
    get tabClassActions() {
        return this.activeTab === 'actions'
            ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    // --- Transcript ---

    get transcriptEntries() {
        const raw = this._field('Transcript_JSON__c');
        if (!raw) return [];
        try {
            const entries = JSON.parse(raw);
            return entries.map((entry, idx) => ({
                id: `te-${idx}`,
                speakerLabel: entry.speaker === 'customer'
                    ? this.customerName || 'Customer'
                    : this.internalRepName || 'Rep',
                timestamp: entry.timestamp || '00:00',
                text: entry.text || '',
                insights: entry.insights || [],
                hasInsights: entry.insights && entry.insights.length > 0
            }));
        } catch {
            return [];
        }
    }

    // --- Summary ---

    get customerImpression() {
        return this._field('Summary_Customer_Impression__c') || '';
    }

    get callSummary() {
        return this._field('Summary_Call_Overview__c') || '';
    }

    get nextStepsList() {
        const raw = this._field('Summary_Next_Steps__c');
        if (!raw) return [];
        return raw.split('\n')
            .filter(line => line.trim())
            .map((line, idx) => ({
                id: `ns-${idx}`,
                number: idx + 1,
                text: line.replace(/^\d+\.\s*/, '').trim()
            }));
    }

    handleCopySummary() {
        const text = [
            'Customer Impression:',
            this.customerImpression,
            '',
            'Call Summary:',
            this.callSummary,
            '',
            'Next Steps:',
            this._field('Summary_Next_Steps__c') || ''
        ].join('\n');

        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
        }
        this.dispatchEvent(new ShowToastEvent({
            title: 'Copied',
            message: 'Summary copied to clipboard',
            variant: 'success'
        }));
    }

    // --- Generative Insights ---

    get generativeInsights() {
        const raw = this._field('Generative_Insights_JSON__c');
        if (!raw) return [];
        try {
            const items = JSON.parse(raw);
            return items.map((item, idx) => ({
                id: `gi-${idx}`,
                question: item.question || '',
                answer: item.answer || ''
            }));
        } catch {
            return [];
        }
    }

    // --- Call Explorer ---

    get explorerQaData() {
        const raw = this._field('Call_Explorer_QA_JSON__c');
        if (!raw) return [];
        try {
            return JSON.parse(raw);
        } catch {
            return [];
        }
    }

    get transcriptRawData() {
        const raw = this._field('Transcript_JSON__c');
        if (!raw) return [];
        try {
            return JSON.parse(raw);
        } catch {
            return [];
        }
    }

    get summaryDataForExplorer() {
        return {
            impression: this.customerImpression,
            overview: this.callSummary,
            nextSteps: this._field('Summary_Next_Steps__c') || ''
        };
    }

    handleOpenExplorer() {
        this.showExplorer = true;
    }

    handleCloseExplorer() {
        this.showExplorer = false;
    }

    // --- Recommendation Events ---

    handleRecommendationExecuted() {
        // Refresh could be added here if needed
    }
}
