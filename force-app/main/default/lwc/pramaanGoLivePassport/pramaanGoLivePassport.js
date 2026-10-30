import { LightningElement, api, track } from 'lwc';
import getPassportInfo from '@salesforce/apex/PramaanController.getPassportInfo';

export default class PramaanGoLivePassport extends LightningElement {
    _packId;
    @track passport;
    @track briefs = [];
    @track chainVerified = false;
    @track totalEvents = 0;
    @track isLoading = false;

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) this.loadPassport();
    }

    async loadPassport() {
        if (!this._packId) return;
        this.isLoading = true;
        try {
            const result = await getPassportInfo({ packId: this._packId });
            this.passport = result.pack;
            this.briefs = result.briefs || [];
            this.chainVerified = result.chainVerified === true;
            this.totalEvents = result.totalEvents || 0;
        } catch (e) {
            console.error('Load passport error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get hasPassport() { return !!this.passport; }
    get hasPassportNumber() { return !!this.passport?.Passport_Number__c; }

    get agentName() {
        return this.passport?.AI_Use_Case__r?.Name || 'AI Agent';
    }

    get riskTier() {
        return this.passport?.AI_Use_Case__r?.Risk_Tier__c || 'Unknown';
    }

    get riskTierClass() {
        const t = (this.riskTier || '').toLowerCase();
        return 'pp-tier-badge pp-tier-' + t;
    }

    get isPassed() {
        if (!this.hasPassportNumber || this.briefs.length === 0) return false;
        return this.briefs.every(b => b.Approval_Status__c === 'Approved');
    }

    get statusLabel() {
        return this.isPassed ? 'CLEARED FOR PRODUCTION' : 'PENDING REVIEW';
    }

    get statusBannerClass() {
        return 'pp-status-banner' + (this.isPassed ? ' pp-status-passed' : ' pp-status-pending');
    }

    get gatesList() {
        return this.briefs.map(b => ({
            id: b.Id || b.Lens__c,
            lens: b.Lens__c,
            status: b.Approval_Status__c,
            isApproved: b.Approval_Status__c === 'Approved',
            reviewer: b.Reviewer__r ? b.Reviewer__r.Name : '',
            date: b.Decision_Date__c || '',
            icon: b.Approval_Status__c === 'Approved' ? 'utility:check' : 'utility:clock',
            rowClass: 'pp-gate-row' + (b.Approval_Status__c === 'Approved' ? ' pp-gate-approved' : ' pp-gate-pending')
        }));
    }

    get approvedCount() {
        return this.briefs.filter(b => b.Approval_Status__c === 'Approved').length;
    }

    get totalGates() {
        return this.briefs.length;
    }

    get clausesMet() {
        return this.passport?.Clauses_Met__c || 0;
    }

    get clausesTotal() {
        return this.passport?.Clauses_Total__c || 0;
    }

    get passportSummary() {
        const name = this.agentName;
        const tier = this.riskTier;
        const gates = this.briefs.filter(b => b.Approval_Status__c === 'Approved').map(b => b.Lens__c);
        const gateNames = gates.length > 0 ? gates.join(', ') : 'all required gates';
        const events = this.totalEvents;

        if (this.isPassed) {
            return name + ' has been assessed as ' + tier + ' risk, cleared all ' +
                gates.length + ' governance gates (' + gateNames +
                '), and is approved for production deployment. All applicable regulatory clauses from RBI, DPDP Act, and CERT-In have been mapped and evidenced.' +
                (events > 0 ? ' Audit chain verified with ' + events + ' tamper-free events.' : '');
        }
        const pending = this.briefs.filter(b => b.Approval_Status__c !== 'Approved').map(b => b.Lens__c);
        return name + ' (' + tier + ' risk) has cleared ' + gates.length + ' of ' +
            this.briefs.length + ' governance gates. Awaiting approval from: ' +
            pending.join(', ') + '.';
    }

    get caseTicketStatusClass() {
        return 'pp-case-ticket-status' + (this.isPassed ? ' pp-case-status-passed' : ' pp-case-status-pending');
    }

    get caseTicketStatusLabel() {
        return this.isPassed ? 'PASSED' : 'IN PROGRESS';
    }

    get caseBriefText() {
        const name = this.agentName;
        const tier = this.riskTier;
        const clauses = this.clausesMet;
        const total = this.clausesTotal;

        if (this.isPassed) {
            return name + ', classified as ' + tier + ' risk, underwent a full governance lifecycle — ' +
                'agent capabilities were scanned, risk DNA profiled across 9 dimensions, and ' +
                clauses + ' of ' + total + ' applicable regulatory clauses were mapped and evidenced. ' +
                'All governance gates were reviewed and approved. The agent is cleared for production.';
        }
        return name + ' (' + tier + ' risk) is undergoing governance review. ' +
            'Agent scan and risk assessment are complete. ' +
            clauses + ' of ' + total + ' clauses mapped so far. Gate approvals are in progress.';
    }

    get frameworksList() {
        return 'RBI IT Gov · DPDP Act 2023 · CERT-In · UIDAI · SEBI AI';
    }

    get issuedDate() {
        if (!this.passport?.Passport_Issued_At__c) return '';
        return new Date(this.passport.Passport_Issued_At__c).toLocaleDateString('en-IN', {
            day: 'numeric', month: 'long', year: 'numeric'
        });
    }

    get configHash() {
        return this.passport?.Approved_Hash__c || '';
    }

    get hasConfigHash() {
        return !!this.passport?.Approved_Hash__c;
    }
}
