import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecommendations from '@salesforce/apex/EciDemoController.getRecommendations';
import executeRecommendation from '@salesforce/apex/EciDemoController.executeRecommendation';

export default class EciRecommendedActions extends NavigationMixin(LightningElement) {
    @api recordId;
    recommendations = [];
    error;
    isLoading = true;
    executingId = null;
    wiredResult;

    @wire(getRecommendations, { videoCallId: '$recordId' })
    wiredRecs(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.recommendations = result.data.map((rec, idx) => ({
                ...rec,
                displayNumber: idx + 1,
                buttonLabel: rec.Button_Label__c || this.defaultButtonLabel(rec.Action_Type__c),
                isCompleted: rec.Status__c === 'Completed',
                cardClass: rec.Status__c === 'Completed'
                    ? 'rec-card rec-card-completed slds-m-bottom_x-small'
                    : 'rec-card slds-m-bottom_x-small'
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.recommendations = [];
        }
    }

    defaultButtonLabel(actionType) {
        const labels = {
            'Create Task': 'Create Task',
            'Create Opportunity': 'Create Opportunity',
            'Update Opportunity': 'Update Deal',
            'Create Event': 'Create Event',
            'Log Follow-Up Call': 'Log Call',
            'Update Competitor': 'Update Account',
            'Create Contact': 'Create Contact'
        };
        return labels[actionType] || 'Execute';
    }

    get hasRecommendations() {
        return this.recommendations.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.hasRecommendations && !this.error;
    }

    async handleExecute(event) {
        const recId = event.currentTarget.dataset.id;
        this.executingId = recId;

        try {
            const createdId = await executeRecommendation({ recommendationId: recId });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Action Completed',
                message: 'Record created successfully.',
                variant: 'success'
            }));

            if (createdId) {
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: { recordId: createdId, actionName: 'view' }
                }).then(url => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Record Created',
                        message: `{0}`,
                        messageData: [
                            {
                                url,
                                label: 'View Record'
                            }
                        ],
                        variant: 'success'
                    }));
                });
            }

            await refreshApex(this.wiredResult);
            this.dispatchEvent(new CustomEvent('recommendationexecuted'));

        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: err.body ? err.body.message : 'An error occurred.',
                variant: 'error'
            }));
        } finally {
            this.executingId = null;
        }
    }
}
