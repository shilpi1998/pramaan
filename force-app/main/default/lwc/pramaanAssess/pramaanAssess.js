import { LightningElement, api, track } from 'lwc';
import getUseCaseDetail from '@salesforce/apex/PramaanController.getUseCaseDetail';
import updateUseCase from '@salesforce/apex/PramaanController.updateUseCase';
import runRiskAssessment from '@salesforce/apex/PramaanController.runRiskAssessment';
import getLLMAnalysis from '@salesforce/apex/PramaanController.getLLMAnalysis';
import createGovernancePack from '@salesforce/apex/PramaanGovernanceService.createGovernancePack';
import createClauseMappings from '@salesforce/apex/PramaanGovernanceService.createClauseMappings';

export default class PramaanAssess extends LightningElement {
    @api useCaseId;
    @api snapshotId;
    @track isLoading = false;
    @track isEditing = false;
    @track isAnalyzing = false;
    @track assessmentComplete = false;
    @track riskResult;
    @track llmAnalysis;
    @track dna = {
        subSector: 'SCB',
        decisionImpact: 'Decisioning',
        autonomy: 'Human-on-loop',
        audience: 'Customer',
        func: 'KYC',
        dataCategories: 'PII, Financial, Aadhaar',
        channels: 'Web, Mobile, WhatsApp',
        vulnerable: true
    };
    @track agentDescription = 'Automates KYC verification for bank customers — validates identity documents (Aadhaar, PAN), screens against PEP/sanctions/RBI watchlists, and flags high-risk profiles for manual review.';
    subSectorOptions = [
        { label: 'Scheduled Commercial Bank (SCB)', value: 'SCB' },
        { label: 'Small Finance Bank (SFB)', value: 'SFB' },
        { label: 'Payments Bank', value: 'Payments Bank' },
        { label: 'NBFC Upper Layer', value: 'NBFC Upper' },
        { label: 'NBFC Middle Layer', value: 'NBFC Middle' },
        { label: 'NBFC Base Layer', value: 'NBFC Base' },
        { label: 'Housing Finance Company', value: 'HFC' },
        { label: 'Insurer', value: 'Insurer' },
        { label: 'Asset Management Company', value: 'AMC' },
        { label: 'Broker', value: 'Broker' }
    ];

    decisionImpactOptions = [
        { label: 'Informational', value: 'Informational' },
        { label: 'Advisory', value: 'Advisory' },
        { label: 'Decisioning', value: 'Decisioning' },
        { label: 'Transactional', value: 'Transactional' }
    ];

    autonomyOptions = [
        { label: 'Human-in-loop (Full human control)', value: 'Human-in-loop' },
        { label: 'Human-on-loop (Human monitors)', value: 'Human-on-loop' },
        { label: 'Autonomous (No human oversight)', value: 'Autonomous' }
    ];

    audienceOptions = [
        { label: 'Employee', value: 'Employee' },
        { label: 'Partner', value: 'Partner' },
        { label: 'Customer', value: 'Customer' }
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
        { label: 'Internal Ops', value: 'Internal Ops' }
    ];

    connectedCallback() {
        if (this.useCaseId) this.loadUseCase();
    }

    async loadUseCase() {
        this.isLoading = true;
        try {
            const result = await getUseCaseDetail({ useCaseId: this.useCaseId });
            const uc = result.useCase;
            this.dna = {
                subSector: uc.Sub_Sector__c || 'SCB',
                decisionImpact: uc.Decision_Impact__c || 'Decisioning',
                autonomy: uc.Autonomy__c || 'Human-on-loop',
                audience: uc.Audience__c || 'Customer',
                func: uc.Function__c || 'KYC',
                dataCategories: uc.Data_Categories__c || 'PII, Financial, Aadhaar',
                channels: uc.Channels__c || 'Web, Mobile, WhatsApp',
                vulnerable: uc.Vulnerable_Customers__c !== undefined ? uc.Vulnerable_Customers__c : true
            };
        } catch (e) {
            console.error('Load use case error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get derivedRegulators() {
        const sub = this.dna.subSector || '';
        const regs = new Set();
        if (['SCB', 'SFB', 'Payments Bank', 'NBFC Upper', 'NBFC Middle', 'NBFC Base', 'HFC'].includes(sub)) regs.add('RBI');
        if (['AMC', 'Broker'].includes(sub)) regs.add('SEBI');
        if (sub === 'Insurer') regs.add('IRDAI');
        regs.add('CERT-In');
        regs.add('MeitY');
        return Array.from(regs).join(', ');
    }

    handleDnaChange(event) {
        const field = event.target.dataset.field;
        this.dna = { ...this.dna, [field]: event.target.value };
    }

    handleVulnerableChange(event) {
        this.dna = { ...this.dna, vulnerable: event.target.checked };
    }

    handleDescriptionChange(event) {
        this.agentDescription = event.target.value;
    }

    async saveDnaChanges() {
        this.isEditing = true;
        try {
            await updateUseCase({
                useCaseId: this.useCaseId,
                subSector: this.dna.subSector,
                decisionImpact: this.dna.decisionImpact,
                autonomy: this.dna.autonomy,
                audience: this.dna.audience,
                channels: this.dna.channels,
                func: this.dna.func,
                dataCategories: this.dna.dataCategories,
                vulnerable: this.dna.vulnerable
            });
        } catch (e) {
            console.error('Save DNA error:', e);
        } finally {
            this.isEditing = false;
        }
    }

    async submitAssessment() {
        if (!this.useCaseId) return;
        this.isLoading = true;
        this.isAnalyzing = true;
        try {
            await this.saveDnaChanges();
            const [riskResult, llmResult] = await Promise.all([
                runRiskAssessment({ useCaseId: this.useCaseId }),
                getLLMAnalysis({ useCaseId: this.useCaseId, apiKey: '' })
            ]);
            this.riskResult = {
                score: riskResult.score,
                tier: riskResult.tier,
                factors: JSON.parse(riskResult.factors),
                floors: riskResult.floors || [],
                hardTriggers: riskResult.hardTriggers || []
            };
            if (llmResult) {
                const sortOrder = { 'Applies': 0, 'Partial': 1, 'N/A': 2 };
                const sorted = (llmResult.regulators || [])
                    .map(r => ({
                        ...r,
                        badgeClass: 'reg-badge reg-' + (r.applicability === 'Applies' ? 'applies' : r.applicability === 'Partial' ? 'partial' : 'na'),
                        confClass: 'conf-badge conf-' + (r.confidence || 'Medium').toLowerCase()
                    }))
                    .sort((a, b) => (sortOrder[a.applicability] ?? 9) - (sortOrder[b.applicability] ?? 9));
                this.llmAnalysis = { ...llmResult, regulators: sorted };
            }
            this.assessmentComplete = true;
        } catch (e) {
            console.error('Risk assessment error:', e);
        } finally {
            this.isLoading = false;
            this.isAnalyzing = false;
        }
    }

    get riskTierClass() {
        const tier = (this.riskResult?.tier || '').toLowerCase();
        return 'risk-badge risk-' + tier;
    }

    get riskFactors() {
        if (!this.riskResult?.factors) return [];
        const maxMap = { 'Audience': 3, 'Decision Impact': 3, 'Human Oversight Level': 3, 'Data Sensitivity': 3, 'Vulnerable Customers': 2 };
        return this.riskResult.factors.map(f => {
            const max = maxMap[f.factor] || 3;
            const pct = Math.round((f.points / max) * 100);
            const level = f.points === 0 ? 'none' : pct <= 33 ? 'low' : pct <= 66 ? 'med' : 'high';
            return {
                ...f,
                maxPoints: max,
                barStyle: 'width:' + pct + '%',
                barClass: 'factor-bar-fill factor-bar-' + level
            };
        });
    }

    get hasFloors() { return this.riskResult?.floors?.length > 0; }
    get hasHardTriggers() { return this.riskResult?.hardTriggers?.length > 0; }
    get hasLLMAnalysis() { return !!this.llmAnalysis; }
    get hasKeyRisks() { return this.llmAnalysis?.keyRisks?.length > 0; }
    get llmSourceLabel() {
        return this.llmAnalysis?.isLLMGenerated ? 'Pramaan AI Analysis' : 'Pramaan Rule Engine Analysis';
    }
    get llmSourceIcon() {
        return this.llmAnalysis?.isLLMGenerated ? 'utility:einstein' : 'utility:rules';
    }
    get applicableRegCount() {
        if (!this.llmAnalysis?.regulators) return 0;
        return this.llmAnalysis.regulators.filter(r => r.applicability === 'Applies' || r.applicability === 'Partial').length;
    }
    get totalEstimatedClauses() {
        if (!this.llmAnalysis?.regulators) return 0;
        return this.llmAnalysis.regulators.reduce((sum, r) => sum + (r.estimatedClauses || 0), 0);
    }

    goBackToEdit() {
        this.assessmentComplete = false;
    }

    async createPackAndMap() {
        this.isLoading = true;
        try {
            const packId = await createGovernancePack({
                useCaseId: this.useCaseId,
                snapshotId: this.snapshotId
            });
            await createClauseMappings({ packId: packId, useCaseId: this.useCaseId });
            this.dispatchEvent(new CustomEvent('assesscomplete', {
                detail: { packId: packId }
            }));
        } catch (e) {
            console.error('Pack creation error:', e);
        } finally {
            this.isLoading = false;
        }
    }
}
