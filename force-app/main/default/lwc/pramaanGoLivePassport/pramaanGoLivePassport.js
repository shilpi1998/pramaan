import { LightningElement, api, track } from 'lwc';
import getPackStatus from '@salesforce/apex/PramaanGovernanceService.getPackStatus';
import verifyChain from '@salesforce/apex/PramaanAuditTrail.verifyChain';

export default class PramaanGoLivePassport extends LightningElement {
    @api packId;
    @track passport;
    @track chainResult;
    @track isLoading = false;

    connectedCallback() {
        if (this.packId) this.loadPassport();
    }

    async loadPassport() {
        if (!this.packId) return;
        this.isLoading = true;
        try {
            const status = await getPackStatus({ packId: this.packId });
            this.passport = status.pack;
            if (this.passport?.Passport_Number__c) {
                this.chainResult = await verifyChain({ governancePackId: this.packId });
            }
        } catch (e) {
            console.error('Load passport error:', e);
        } finally {
            this.isLoading = false;
        }
    }
}
