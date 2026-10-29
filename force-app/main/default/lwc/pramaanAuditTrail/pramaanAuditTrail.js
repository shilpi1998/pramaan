import { LightningElement, api, track } from 'lwc';
import getAuditTrail from '@salesforce/apex/PramaanAuditTrail.getAuditTrail';
import verifyChain from '@salesforce/apex/PramaanAuditTrail.verifyChain';

const TYPE_COLORS = {
    'Pack Created': { dot: '#0176d3', bg: '#eaf5fe', label: 'Created' },
    'Risk Scanned': { dot: '#fe9339', bg: '#fef3e6', label: 'Scanned' },
    'Clauses Mapped': { dot: '#9050e9', bg: '#f3eefb', label: 'Mapped' },
    'Filing': { dot: '#9050e9', bg: '#f3eefb', label: 'Filed' },
    'Filed for Review': { dot: '#9050e9', bg: '#f3eefb', label: 'Filed' },
    'Document Generated': { dot: '#0d9dda', bg: '#e6f7ff', label: 'Document' },
    'Approval': { dot: '#2e844a', bg: '#e6f7e6', label: 'Approved' },
    'Rejection': { dot: '#c23934', bg: '#fde8e8', label: 'Rejected' },
    'Passport Issued': { dot: '#2e844a', bg: '#e6f7e6', label: 'Passport' },
    'Mapping': { dot: '#9050e9', bg: '#f3eefb', label: 'Mapped' },
    'X-Ray': { dot: '#fe9339', bg: '#fef3e6', label: 'X-Ray' }
};
const DEFAULT_COLOR = { dot: '#706e6b', bg: '#f3f3f3', label: 'Event' };

export default class PramaanAuditTrail extends LightningElement {
    _packId;
    @track events = [];
    @track chainStatus;
    @track isLoading = false;
    @track expandedIds = {};

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) this.loadAll();
    }

    async loadAll() {
        this.isLoading = true;
        try {
            await Promise.all([this.loadEvents(), this.doVerifyChain()]);
        } finally {
            this.isLoading = false;
        }
    }

    async loadEvents() {
        if (!this._packId) return;
        try {
            const result = await getAuditTrail({ governancePackId: this._packId });
            this.events = result.map((e, idx) => {
                const colors = TYPE_COLORS[e.Event_Type__c] || DEFAULT_COLOR;
                return {
                    ...e,
                    dotStyle: `background:${colors.dot}`,
                    badgeBg: `background:${colors.bg};color:${colors.dot};border:1px solid ${colors.dot}`,
                    typeLabel: colors.label,
                    hashShort: e.Event_Hash__c ? e.Event_Hash__c.substring(0, 12) : '---',
                    prevHashShort: e.Previous_Hash__c ? (e.Previous_Hash__c === '0' ? 'GENESIS' : e.Previous_Hash__c.substring(0, 12)) : '---',
                    isGenesis: idx === 0,
                    isLast: idx === result.length - 1,
                    isExpanded: false,
                    formattedTimestamp: this._fmtTime(e.Event_Timestamp__c),
                    seqLabel: '#' + e.Sequence__c
                };
            });
        } catch (e) {
            console.error('Load audit trail error:', e);
        }
    }

    async doVerifyChain() {
        if (!this._packId) return;
        try {
            this.chainStatus = await verifyChain({ governancePackId: this._packId });
        } catch (e) {
            console.error('Verify chain error:', e);
        }
    }

    _fmtTime(ts) {
        if (!ts) return '';
        try {
            const d = new Date(ts);
            return d.toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true });
        } catch (_e) {
            return ts;
        }
    }

    get hasEvents() { return this.events.length > 0; }
    get isChainVerified() { return this.chainStatus?.verified === true; }
    get hasChainStatus() { return !!this.chainStatus; }
    get totalEvents() { return this.events.length; }

    get chainBadgeClass() {
        return this.isChainVerified ? 'integrity-badge integrity-ok' : 'integrity-badge integrity-broken';
    }
    get chainBadgeIcon() { return this.isChainVerified ? 'utility:check' : 'utility:error'; }
    get chainBadgeText() {
        if (!this.chainStatus) return 'Not Verified';
        return this.isChainVerified ? 'Immutable Record — Chain Intact' : 'TAMPER DETECTED at event #' + this.chainStatus.brokenAt;
    }

    get timeSpan() {
        if (this.events.length < 2) return 'N/A';
        const first = this.events[0].Event_Timestamp__c;
        const last = this.events[this.events.length - 1].Event_Timestamp__c;
        if (!first || !last) return 'N/A';
        const d1 = new Date(first);
        const d2 = new Date(last);
        const diffMs = d2 - d1;
        const diffDays = Math.floor(diffMs / 86400000);
        const diffHrs = Math.floor((diffMs % 86400000) / 3600000);
        if (diffDays > 0) return diffDays + 'd ' + diffHrs + 'h';
        const diffMin = Math.floor((diffMs % 3600000) / 60000);
        return diffHrs + 'h ' + diffMin + 'm';
    }

    get eventTypeCounts() {
        const counts = {};
        for (const e of this.events) {
            const label = (TYPE_COLORS[e.Event_Type__c] || DEFAULT_COLOR).label;
            counts[label] = (counts[label] || 0) + 1;
        }
        const total = this.events.length || 1;
        return Object.entries(counts).map(([label, count]) => ({
            label,
            count,
            barStyle: `width:${Math.round((count / total) * 100)}%`,
            color: this._colorForLabel(label)
        }));
    }

    _colorForLabel(label) {
        for (const v of Object.values(TYPE_COLORS)) {
            if (v.label === label) return v.dot;
        }
        return '#706e6b';
    }

    get chainBlocks() {
        return this.events.map((e, idx) => ({
            ...e,
            blockClass: 'chain-block' + (idx === 0 ? ' chain-genesis' : '') + (e.isExpanded ? ' chain-expanded' : ''),
            showConnector: idx > 0,
            isExpanded: this.expandedIds[e.Id] === true
        }));
    }

    handleToggleBlock(event) {
        const evtId = event.currentTarget.dataset.id;
        this.expandedIds = { ...this.expandedIds, [evtId]: !this.expandedIds[evtId] };
    }

    handleRefresh() {
        this.loadAll();
    }

    handleExport() {
        window.print();
    }
}
