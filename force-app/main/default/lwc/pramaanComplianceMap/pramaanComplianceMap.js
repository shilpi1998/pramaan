import { LightningElement, api, track } from 'lwc';
import getClauseMappings from '@salesforce/apex/PramaanController.getClauseMappings';
import updateClauseMapping from '@salesforce/apex/PramaanController.updateClauseMapping';
import fileForReviewApex from '@salesforce/apex/PramaanGovernanceService.fileForReview';
import getTemplateReadiness from '@salesforce/apex/PramaanController.getTemplateReadiness';
import generateFromTemplate from '@salesforce/apex/PramaanController.generateFromTemplate';
import generateAllRequired from '@salesforce/apex/PramaanController.generateAllRequiredDocuments';

export default class PramaanComplianceMap extends LightningElement {
    _packId;
    @api useCaseId;
    @track allMappings = [];
    @track readiness = [];
    @track isLoading = false;
    @track isGenerating = false;
    @track generatingTemplateName = '';
    @track expandedRegulators = {};
    @track showEvidenceModal = false;
    @track selectedClause = {};
    @track evidenceText = '';
    @track evidenceStatus = 'Met';

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) {
            this.loadMappings();
        }
    }

    evidenceStatusOptions = [
        { label: 'Met', value: 'Met' },
        { label: 'Partial', value: 'Partial' },
        { label: 'Gap', value: 'Gap' }
    ];

    async loadMappings() {
        if (!this._packId) return;
        this.isLoading = true;
        try {
            const [data, readinessData] = await Promise.all([
                getClauseMappings({ packId: this._packId }),
                getTemplateReadiness({ packId: this._packId })
            ]);
            this.allMappings = data.map(r => ({
                ...r,
                obligationText: r.Obligation__c || r.Name,
                statusBadgeClass: this._statusBadge(r.Mapping_Status__c),
                hasEvidence: !!r.Evidence__c
            }));
            this.readiness = readinessData.map(tr => ({
                ...tr,
                readinessBadgeClass: this._readinessBadge(tr.readinessLabel),
                progressStyle: 'width:' + tr.readinessPercent + '%',
                barClass: tr.readinessPercent >= 80 ? 'rd-bar rd-ready' :
                    tr.readinessPercent >= 50 ? 'rd-bar rd-partial' : 'rd-bar rd-incomplete',
                statusIcon: tr.alreadyGenerated ? 'utility:check' : (tr.required ? 'utility:warning' : 'utility:dash'),
                statusVariant: tr.alreadyGenerated ? 'success' : (tr.required ? 'warning' : ''),
                canGenerate: !tr.alreadyGenerated,
                cardClass: 'tmpl-card' + (tr.required ? ' tmpl-required' : ' tmpl-optional') +
                    (tr.alreadyGenerated ? ' tmpl-done' : '')
            }));
        } catch (e) {
            console.error('Load mappings error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get mappings() {
        return this.allMappings.filter(m => m.Mapping_Status__c !== 'N/A');
    }

    get hasMappings() { return this.mappings.length > 0; }
    get generatingLabel() { return 'Generating ' + this.generatingTemplateName + '...'; }
    get applicableCount() { return this.mappings.length; }
    get metCount() { return this.mappings.filter(m => m.Mapping_Status__c === 'Met').length; }
    get gapCount() { return this.mappings.filter(m => m.Mapping_Status__c === 'Gap' || m.Mapping_Status__c === 'Partial').length; }
    get regulatorGroupCount() {
        return new Set(this.mappings.map(m => m.Regulator__c)).size;
    }

    get completionPercent() {
        const total = this.applicableCount;
        if (total === 0) return 0;
        return Math.round((this.metCount / total) * 100);
    }

    get progressStyle() {
        return 'width:' + this.completionPercent + '%';
    }

    get regulatorGroups() {
        const grouped = {};
        for (const m of this.mappings) {
            const reg = m.Regulator__c || 'Other';
            if (!grouped[reg]) {
                grouped[reg] = { regulator: reg, clauses: [], count: 0, metCount: 0, gapCount: 0 };
            }
            grouped[reg].clauses.push(m);
            grouped[reg].count++;
            if (m.Mapping_Status__c === 'Met') grouped[reg].metCount++;
            if (m.Mapping_Status__c === 'Gap' || m.Mapping_Status__c === 'Partial') grouped[reg].gapCount++;
        }

        return Object.values(grouped)
            .sort((a, b) => b.count - a.count)
            .map(g => ({
                ...g,
                key: g.regulator,
                isExpanded: this.expandedRegulators[g.regulator] === true,
                headerClass: 'reg-group-header' + (this.expandedRegulators[g.regulator] ? ' reg-group-expanded' : ''),
                arrow: this.expandedRegulators[g.regulator] ? '▲' : '▼',
                summaryLabel: g.metCount + ' met' + (g.gapCount > 0 ? ', ' + g.gapCount + ' gaps' : ', 0 gaps'),
                progressPercent: g.count > 0 ? Math.round((g.metCount / g.count) * 100) : 100,
                progressStyle: 'width:' + (g.count > 0 ? Math.round((g.metCount / g.count) * 100) : 100) + '%',
                progressClass: g.gapCount > 0 ? 'reg-progress reg-progress-gaps' : 'reg-progress reg-progress-clear'
            }));
    }

    handleRegulatorToggle(event) {
        const reg = event.currentTarget.dataset.regulator;
        this.expandedRegulators = {
            ...this.expandedRegulators,
            [reg]: !this.expandedRegulators[reg]
        };
    }

    handleAddEvidence(event) {
        const clauseId = event.currentTarget.dataset.id;
        const clause = this.allMappings.find(m => m.Id === clauseId);
        if (clause) {
            this.selectedClause = clause;
            this.evidenceText = clause.Evidence__c || '';
            this.evidenceStatus = clause.Evidence_Status__c || 'Met';
            this.showEvidenceModal = true;
        }
    }

    async handleMarkMet(event) {
        const clauseId = event.currentTarget.dataset.id;
        await this._updateStatus(clauseId, 'Met');
    }

    async _updateStatus(clauseId, status) {
        try {
            await updateClauseMapping({
                clauseMappingId: clauseId,
                status: status,
                evidence: null,
                evidenceStatus: null
            });
            this.allMappings = this.allMappings.map(m =>
                m.Id === clauseId
                    ? { ...m, Mapping_Status__c: status, statusBadgeClass: this._statusBadge(status) }
                    : m
            );
        } catch (e) {
            console.error('Update status error:', e);
        }
    }

    closeEvidenceModal() { this.showEvidenceModal = false; }
    handleEvidenceText(event) { this.evidenceText = event.target.value; }
    handleEvidenceStatus(event) { this.evidenceStatus = event.detail.value; }

    async saveEvidence() {
        if (!this.selectedClause.Id) return;
        try {
            await updateClauseMapping({
                clauseMappingId: this.selectedClause.Id,
                status: this.evidenceStatus,
                evidence: this.evidenceText,
                evidenceStatus: this.evidenceStatus
            });
            this.allMappings = this.allMappings.map(m =>
                m.Id === this.selectedClause.Id
                    ? {
                        ...m,
                        Mapping_Status__c: this.evidenceStatus,
                        Evidence__c: this.evidenceText,
                        Evidence_Status__c: this.evidenceStatus,
                        statusBadgeClass: this._statusBadge(this.evidenceStatus),
                        hasEvidence: !!this.evidenceText
                    }
                    : m
            );
            this.showEvidenceModal = false;
        } catch (e) {
            console.error('Save evidence error:', e);
        }
    }

    async fileForReview() {
        this.isLoading = true;
        this.isGenerating = true;
        this.generatingTemplateName = 'reviewer briefs for all governance gates';
        try {
            await fileForReviewApex({ packId: this._packId });
            await new Promise(resolve => setTimeout(resolve, 3000));
            this.dispatchEvent(new CustomEvent('filecomplete', {
                detail: { packId: this._packId }
            }));
        } catch (e) {
            console.error('File for review error:', e);
        } finally {
            this.isLoading = false;
            this.isGenerating = false;
            this.generatingTemplateName = '';
        }
    }

    get requiredTemplates() { return this.readiness.filter(r => r.required); }
    get optionalTemplates() { return this.readiness.filter(r => !r.required); }
    get hasOptional() { return this.optionalTemplates.length > 0; }
    get requiredCount() { return this.requiredTemplates.length; }
    get generatedCount() { return this.readiness.filter(r => r.alreadyGenerated).length; }
    get pendingCount() { return this.requiredTemplates.filter(r => !r.alreadyGenerated).length; }
    get allRequiredDone() { return this.pendingCount === 0 && this.requiredCount > 0; }
    get hasReadiness() { return this.readiness.length > 0; }

    _delay(ms) { return new Promise(resolve => { setTimeout(resolve, ms); }); }

    async handleGenerateAll() {
        this.isLoading = true;
        this.isGenerating = true;
        this.generatingTemplateName = 'all required documents';
        try {
            await generateAllRequired({ packId: this._packId });
            await this._delay(3000);
            await this.loadMappings();
            this.dispatchEvent(new CustomEvent('generatecomplete'));
        } catch (e) {
            console.error('Generate all error:', e);
        } finally {
            this.isLoading = false;
            this.isGenerating = false;
            this.generatingTemplateName = '';
        }
    }

    async handleGenerateSingle(event) {
        const templateType = event.currentTarget.dataset.type;
        const tmpl = this.readiness.find(t => t.templateType === templateType);
        this.generatingTemplateName = tmpl ? tmpl.templateName : templateType;
        this.isLoading = true;
        this.isGenerating = true;
        try {
            await generateFromTemplate({ packId: this._packId, templateType: templateType });
            await this._delay(2000);
            await this.loadMappings();
        } catch (e) {
            console.error('Generate error:', e);
        } finally {
            this.isLoading = false;
            this.isGenerating = false;
            this.generatingTemplateName = '';
        }
    }

    _statusBadge(status) {
        if (status === 'Met') return 'status-badge status-met';
        if (status === 'Gap') return 'status-badge status-gap';
        if (status === 'Partial') return 'status-badge status-partial';
        return 'status-badge status-na';
    }

    _readinessBadge(label) {
        if (label === 'Ready') return 'status-badge status-met';
        if (label === 'Partial') return 'status-badge status-partial';
        return 'status-badge status-gap';
    }

}
