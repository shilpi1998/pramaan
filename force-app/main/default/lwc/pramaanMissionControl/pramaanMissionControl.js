import { LightningElement, track } from 'lwc';
import getUseCases from '@salesforce/apex/PramaanController.getUseCases';
import createUseCase from '@salesforce/apex/PramaanController.createUseCase';

export default class PramaanMissionControl extends LightningElement {
    @track useCases = [];
    @track showNewModal = false;
    @track newUseCase = {};
    @track stats = { draft: 0, scanning: 0, inReview: 0, approved: 0, rejected: 0 };
    @track error;

    columns = [
        { label: 'Use Case', fieldName: 'Name', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text',
          cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Risk Tier', fieldName: 'Risk_Tier__c', type: 'text' },
        { label: 'Passport #', fieldName: 'Passport_Number__c', type: 'text' },
        { label: 'Agent', fieldName: 'Agent_API_Name__c', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Continue Filing', name: 'continue' },
            { label: 'View Details', name: 'view' }
        ]}}
    ];

    subSectorOptions = [
        { label: 'Scheduled Commercial Bank', value: 'SCB' },
        { label: 'Small Finance Bank', value: 'SFB' },
        { label: 'Payments Bank', value: 'Payments Bank' },
        { label: 'NBFC Upper Layer', value: 'NBFC Upper' },
        { label: 'NBFC Middle Layer', value: 'NBFC Middle' },
        { label: 'NBFC Base Layer', value: 'NBFC Base' },
        { label: 'Housing Finance Co.', value: 'HFC' },
        { label: 'Insurer', value: 'Insurer' },
        { label: 'Asset Mgmt Co.', value: 'AMC' },
        { label: 'Broker', value: 'Broker' },
    ];

    decisionImpactOptions = [
        { label: 'Informational', value: 'Informational' },
        { label: 'Advisory', value: 'Advisory' },
        { label: 'Decisioning', value: 'Decisioning' },
        { label: 'Transactional', value: 'Transactional' },
    ];

    autonomyOptions = [
        { label: 'Human-in-loop', value: 'Human-in-loop' },
        { label: 'Human-on-loop', value: 'Human-on-loop' },
        { label: 'Autonomous', value: 'Autonomous' },
    ];

    audienceOptions = [
        { label: 'Employee', value: 'Employee' },
        { label: 'Partner', value: 'Partner' },
        { label: 'Customer', value: 'Customer' },
    ];

    functionOptions = [
        { label: 'Origination', value: 'Origination' },
        { label: 'Collections', value: 'Collections' },
        { label: 'Deposits', value: 'Deposits' },
        { label: 'Payments', value: 'Payments' },
        { label: 'Complaints', value: 'Complaints' },
        { label: 'KYC', value: 'KYC' },
        { label: 'Wealth', value: 'Wealth' },
        { label: 'Insurance Sales', value: 'Insurance Sales' },
        { label: 'Insurance Claims', value: 'Insurance Claims' },
        { label: 'Internal Ops', value: 'Internal Ops' },
    ];

    connectedCallback() {
        this.loadUseCases();
    }

    async loadUseCases() {
        try {
            const data = await getUseCases();
            this.useCases = data.map(r => ({
                Id: r.Id,
                Name: r.Name,
                Status__c: r.Status__c,
                Risk_Tier__c: r.Risk_Tier__c,
                Risk_Score__c: r.Risk_Score__c,
                Passport_Number__c: r.Passport_Number__c,
                Agent_API_Name__c: r.Agent_API_Name__c,
                packId: r.Governance_Packs__r && r.Governance_Packs__r.length > 0 ? r.Governance_Packs__r[0].Id : null,
                statusClass: 'status-' + (r.Status__c || 'draft').toLowerCase().replace(/\s+/g, '-')
            }));
            this.computeStats();
            this.error = undefined;
        } catch (e) {
            this.error = e;
            this.useCases = [];
            console.error('Load use cases error:', JSON.stringify(e));
        }
    }

    computeStats() {
        const s = { draft: 0, scanning: 0, inReview: 0, approved: 0, rejected: 0 };
        this.useCases.forEach(uc => {
            const st = (uc.Status__c || 'Draft').toLowerCase();
            if (st === 'draft') s.draft++;
            else if (st === 'scanned' || st === 'mapped') s.scanning++;
            else if (st === 'in review' || st === 'filed') s.inReview++;
            else if (st === 'approved') s.approved++;
            else if (st === 'rejected' || st === 'rework') s.rejected++;
            else s.draft++;
        });
        this.stats = s;
    }

    handleRefresh() {
        this.loadUseCases();
    }

    handleNewUseCase() {
        this.newUseCase = { Name: '', Purpose__c: '', Sub_Sector__c: 'SCB',
            Decision_Impact__c: 'Advisory', Autonomy__c: 'Human-in-loop',
            Audience__c: 'Customer', Channels__c: '', Function__c: 'Origination', Data_Categories__c: '' };
        this.showNewModal = true;
    }

    closeModal() {
        this.showNewModal = false;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.newUseCase = { ...this.newUseCase, [field]: event.target.value };
    }

    async handleCreate() {
        try {
            const uc = this.newUseCase;
            const useCaseId = await createUseCase({
                name: uc.Name,
                purpose: uc.Purpose__c,
                subSector: uc.Sub_Sector__c,
                decisionImpact: uc.Decision_Impact__c,
                autonomy: uc.Autonomy__c,
                audience: uc.Audience__c,
                channels: uc.Channels__c,
                func: uc.Function__c,
                dataCategories: uc.Data_Categories__c
            });
            this.showNewModal = false;
            this.loadUseCases();
            this.dispatchEvent(new CustomEvent('launchflow', {
                detail: { useCaseId, step: 'xray' }
            }));
        } catch (e) {
            console.error('Create use case error:', e);
        }
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        const status = (row.Status__c || 'Draft').toLowerCase();
        let step = 'xray';
        if (status === 'scanned' || status === 'mapped') step = 'assess';
        else if (status === 'in review' || status === 'filed') step = 'review';
        else if (status === 'approved') step = 'passport';

        this.dispatchEvent(new CustomEvent('launchflow', {
            detail: { useCaseId: row.Id, packId: row.packId, step: action.name === 'view' ? 'audit' : step }
        }));
    }
}
