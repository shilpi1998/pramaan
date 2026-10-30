import { LightningElement, track } from 'lwc';
import getPacksForUseCase from '@salesforce/apex/PramaanController.getPacksForUseCase';

export default class PramaanApp extends LightningElement {
    @track activeTab = 'hub';
    @track selectedUseCaseId;
    @track selectedPackId;
    @track selectedSnapshotId;

    handleTabChange(event) {
        this.activeTab = event.target.value;
        if (this.activeTab === 'passport') {
            setTimeout(() => {
                const passport = this.template.querySelector('c-pramaan-go-live-passport');
                if (passport) passport.refreshPassport();
            }, 100);
        }
    }

    async handleLaunchFlow(event) {
        const { useCaseId, packId, step } = event.detail;
        this.selectedUseCaseId = useCaseId;
        if (packId) {
            this.selectedPackId = packId;
        }
        this.activeTab = step || 'xray';
        if (!packId) {
            try {
                const packs = await getPacksForUseCase({ useCaseId });
                if (packs && packs.length > 0) {
                    this.selectedPackId = packs[0].Id;
                }
            } catch (e) {
                console.error('Load pack error:', e);
            }
        }
    }

    handleXRayComplete(event) {
        const { useCaseId, snapshotId } = event.detail;
        this.selectedUseCaseId = useCaseId;
        this.selectedSnapshotId = snapshotId;
        this.activeTab = 'assess';
    }

    handleAssessComplete(event) {
        const { packId } = event.detail;
        this.selectedPackId = packId;
        this.activeTab = 'map';
    }

    handleGenerateComplete() {
        this.activeTab = 'filing';
        setTimeout(() => {
            const filingCenter = this.template.querySelector('c-pramaan-filing-center');
            if (filingCenter) filingCenter.refreshDocuments();
        }, 100);
    }

    handleFileComplete() {
        this.activeTab = 'review';
        setTimeout(() => {
            const reviewer = this.template.querySelector('c-pramaan-reviewer-lens');
            if (reviewer) reviewer.refreshBriefs();
        }, 100);
    }

    handleDecisionComplete() {
        const passport = this.template.querySelector('c-pramaan-go-live-passport');
        if (passport) passport.refreshPassport();
        const audit = this.template.querySelector('c-pramaan-audit-trail');
        if (audit && audit.refreshTrail) audit.refreshTrail();
    }
}
