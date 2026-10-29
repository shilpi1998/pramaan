import { LightningElement, api, track } from 'lwc';
import getReviewerBriefs from '@salesforce/apex/PramaanController.getReviewerBriefs';
import recordDecision from '@salesforce/apex/PramaanGovernanceService.recordDecision';
import askReviewerQuestion from '@salesforce/apex/PramaanController.askReviewerQuestion';
import getReviewQAs from '@salesforce/apex/PramaanController.getReviewQAs';

export default class PramaanReviewerLens extends LightningElement {
    _packId;
    @track briefs = [];
    @track isLoading = false;
    @track expandedQA = {};
    @track qaMap = {};
    @track askingMap = {};
    @track questionMap = {};
    @track selectedAskBriefId = '';
    @track globalQuestion = '';
    @track isGlobalAsking = false;
    @track allQAs = [];

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) this.loadBriefs();
    }

    @api
    refreshBriefs() {
        if (this._packId) this.loadBriefs();
    }

    async loadBriefs() {
        if (!this.packId) return;
        this.isLoading = true;
        try {
            const data = await getReviewerBriefs({ packId: this.packId });
            this.briefs = data.map(b => ({
                Id: b.Id,
                Name: b.Name,
                Lens__c: b.Lens__c,
                Approval_Status__c: b.Approval_Status__c,
                Decision_Date__c: b.Decision_Date__c,
                Reviewer_Comments__c: b.Reviewer_Comments__c,
                Brief_Content__c: b.Brief_Content__c,
                isPending: b.Approval_Status__c === 'Pending',
                reviewerName: b.Reviewer__r ? b.Reviewer__r.Name : '',
                cardClass: 'slds-box gate-card gate-' + (b.Approval_Status__c || 'pending').toLowerCase(),
                badgeClass: 'badge-' + (b.Approval_Status__c || 'pending').toLowerCase(),
                lensIcon: this._lensIcon(b.Lens__c),
                qaExpanded: this.expandedQA[b.Id] === true,
                qas: this.qaMap[b.Id] || [],
                hasQAs: (this.qaMap[b.Id] || []).length > 0,
                isAsking: this.askingMap[b.Id] === true
            }));
            for (const b of this.briefs) {
                if (!this.qaMap[b.Id]) {
                    this._loadQAs(b.Id);
                }
            }
        } catch (e) {
            console.error('Load briefs error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadQAs(briefId) {
        try {
            const data = await getReviewQAs({ briefId });
            this.qaMap = {
                ...this.qaMap,
                [briefId]: data.map(qa => ({
                    Id: qa.Id,
                    question: qa.Question__c,
                    answer: qa.Answer__c,
                    askedBy: qa.Asked_By__c,
                    askedAt: qa.Asked_At__c
                }))
            };
            this._refreshBriefState();
        } catch (e) {
            console.error('Load QAs error:', e);
        }
    }

    _refreshBriefState() {
        this.briefs = this.briefs.map(b => ({
            ...b,
            qaExpanded: this.expandedQA[b.Id] === true,
            qas: this.qaMap[b.Id] || [],
            hasQAs: (this.qaMap[b.Id] || []).length > 0,
            isAsking: this.askingMap[b.Id] === true
        }));
    }

    _lensIcon(lens) {
        if (lens === 'Security') return 'utility:shield';
        if (lens === 'Compliance') return 'utility:check';
        if (lens === 'Legal') return 'utility:contract';
        if (lens === 'AI Risk Committee') return 'utility:warning';
        if (lens === 'Architecture') return 'utility:settings';
        return 'utility:question';
    }

    get hasBriefs() { return this.briefs.length > 0; }
    get totalGates() { return this.briefs.length; }
    get approvedCount() { return this.briefs.filter(b => b.Approval_Status__c === 'Approved').length; }
    get gateProgress() { return this.totalGates ? Math.round((this.approvedCount / this.totalGates) * 100) : 0; }
    get progressStyle() { return 'width:' + this.gateProgress + '%'; }

    get briefOptions() {
        return this.briefs.map(b => ({ label: b.Lens__c, value: b.Id }));
    }

    get globalQAs() { return this.allQAs; }
    get hasGlobalQAs() { return this.allQAs.length > 0; }

    handleAskBriefChange(event) {
        this.selectedAskBriefId = event.detail.value;
    }

    handleGlobalQuestionInput(event) {
        this.globalQuestion = event.target.value;
    }

    handleGlobalKeyPress(event) {
        if (event.key === 'Enter') this.handleGlobalAsk();
    }

    async handleGlobalAsk() {
        let briefId = this.selectedAskBriefId;
        if (!briefId && this.briefs.length > 0) briefId = this.briefs[0].Id;
        if (!briefId || !this.globalQuestion || !this.globalQuestion.trim()) return;

        this.isGlobalAsking = true;
        const question = this.globalQuestion.trim();
        const lens = (this.briefs.find(b => b.Id === briefId) || {}).Lens__c || '';

        try {
            await askReviewerQuestion({ briefId, question });
            this.globalQuestion = '';
            const inputEl = this.template.querySelector('.ask-input-field');
            if (inputEl) inputEl.value = '';
            await this._loadQAs(briefId);
            const qas = this.qaMap[briefId] || [];
            const latest = qas[qas.length - 1];
            if (latest) {
                this.allQAs = [...this.allQAs, { ...latest, lens }];
            }
        } catch (e) {
            console.error('Global ask error:', e);
        } finally {
            this.isGlobalAsking = false;
        }
    }

    handleToggleQA(event) {
        const briefId = event.currentTarget.dataset.briefId;
        this.expandedQA = {
            ...this.expandedQA,
            [briefId]: !this.expandedQA[briefId]
        };
        this._refreshBriefState();
    }

    handleQuestionInput(event) {
        const briefId = event.currentTarget.dataset.briefId;
        this.questionMap = {
            ...this.questionMap,
            [briefId]: event.target.value
        };
    }

    async handleAskQuestion(event) {
        const briefId = event.currentTarget.dataset.briefId;
        const question = this.questionMap[briefId];
        if (!question || !question.trim()) return;

        this.askingMap = { ...this.askingMap, [briefId]: true };
        this._refreshBriefState();

        try {
            await askReviewerQuestion({ briefId, question: question.trim() });
            this.questionMap = { ...this.questionMap, [briefId]: '' };
            const inputEl = this.template.querySelector(`lightning-input[data-qa-input="${briefId}"]`);
            if (inputEl) inputEl.value = '';
            await this._loadQAs(briefId);
        } catch (e) {
            console.error('Ask question error:', e);
        } finally {
            this.askingMap = { ...this.askingMap, [briefId]: false };
            this._refreshBriefState();
        }
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            this.handleAskQuestion(event);
        }
    }

    async handleDecision(event) {
        const briefId = event.target.dataset.briefId;
        const decision = event.target.dataset.decision;
        const textarea = this.template.querySelector(`lightning-textarea[data-brief-id="${briefId}"]`);
        const comments = textarea ? textarea.value : '';

        try {
            await recordDecision({ briefId, decision, comments });
            this.loadBriefs();
        } catch (e) {
            console.error('Decision error:', e);
        }
    }
}
