import { LightningElement, api, track } from 'lwc';
import getLearningDashboard from '@salesforce/apex/PramaanLearningLoop.getLearningDashboard';
import triggerManualScan from '@salesforce/apex/PramaanLearningLoop.triggerManualScan';

export default class PramaanLearningLoop extends LightningElement {
    _packId;
    @track dashboard = {};
    @track regulationUpdates = [];
    @track rejectionLearnings = [];
    @track templateEvolutions = [];
    @track isLoading = false;
    @track isScanning = false;
    @track scanResult = null;
    @track lastScanDate = '';
    @track totalRegulations = 0;
    @track newThisMonth = 0;
    @track adaptationScore = 0;

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        try {
            const data = await getLearningDashboard({ packId: this._packId });
            this.dashboard = data;
            this.lastScanDate = data.lastScanDate || 'Never';
            this.totalRegulations = data.totalRegulationsTracked || 0;
            this.newThisMonth = data.newRegulationsThisMonth || 0;
            this.adaptationScore = data.adaptationScore || 0;

            this.regulationUpdates = (data.regulationUpdates || []).map((r, i) => ({
                ...r,
                key: 'reg-' + i,
                typeBadgeClass: r.updateType === 'New' ? 'll-badge ll-badge-new' : 'll-badge ll-badge-amendment',
                impactClass: 'll-badge ll-impact-' + (r.impact || 'medium').toLowerCase(),
                inclusionIcon: r.autoIncluded ? 'utility:check' : 'utility:clock',
                inclusionVariant: r.autoIncluded ? 'success' : 'warning',
                inclusionLabel: r.autoIncluded ? 'Auto-included' : 'Pending review'
            }));

            this.rejectionLearnings = (data.rejectionLearnings || []).map((l, i) => ({
                ...l,
                key: 'learn-' + i,
                statusClass: l.status === 'Applied' ? 'll-badge ll-status-applied' : 'll-badge ll-status-pending',
                statusIcon: l.status === 'Applied' ? 'utility:check' : 'utility:clock'
            }));

            this.templateEvolutions = (data.templateEvolutions || []).map((t, i) => ({
                ...t,
                key: 'tmpl-' + i,
                changeLabel: t.changeCount + (t.changeCount === 1 ? ' section updated' : ' sections updated')
            }));
        } catch (e) {
            console.error('Learning dashboard error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleManualScan() {
        this.isScanning = true;
        this.scanResult = null;
        try {
            await new Promise(resolve => setTimeout(resolve, 3000));
            const result = await triggerManualScan({ packId: this._packId });
            this.scanResult = result;
            await this.loadDashboard();
        } catch (e) {
            console.error('Manual scan error:', e);
        } finally {
            this.isScanning = false;
        }
    }

    get hasRegulations() { return this.regulationUpdates.length > 0; }
    get hasLearnings() { return this.rejectionLearnings.length > 0; }
    get hasEvolutions() { return this.templateEvolutions.length > 0; }
    get hasScanResult() { return this.scanResult != null; }
    get scanSummary() {
        if (!this.scanResult) return '';
        return 'Found ' + this.scanResult.newRegulations + ' new regulations, updated '
            + this.scanResult.templatesUpdated + ' templates, applied '
            + this.scanResult.learningsApplied + ' learnings';
    }

    get scoreCircleStyle() {
        const pct = this.adaptationScore;
        const deg = Math.round((pct / 100) * 360);
        if (pct <= 50) {
            return 'background: conic-gradient(#0176d3 ' + deg + 'deg, #e0e5ee ' + deg + 'deg)';
        }
        return 'background: conic-gradient(#2e844a ' + deg + 'deg, #e0e5ee ' + deg + 'deg)';
    }

    get scanButtonLabel() {
        return this.isScanning ? 'Scanning...' : 'Run Manual Scan';
    }
}
