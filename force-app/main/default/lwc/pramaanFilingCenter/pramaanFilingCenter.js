import { LightningElement, api, track } from 'lwc';
import getFilingDocuments from '@salesforce/apex/PramaanController.getFilingDocuments';

const RPT_STYLES = `
.rpt-banner{background:#032d60;color:#fff;text-align:center;padding:6px 16px;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase}
.rpt-head{text-align:center;padding:20px 24px 16px;border-bottom:3px double #032d60;background:#f8fafc}
.rpt-org{font-size:11.5px;color:#706e6b;text-transform:uppercase;letter-spacing:1.5px;margin-bottom:2px}
.rpt-div{font-size:11px;color:#939393;margin-bottom:10px}
.rpt-head h1{font-size:16px;font-weight:700;color:#032d60;margin:0;line-height:1.3}
.rpt-body{padding:20px 24px}
.rpt-meta{width:100%;border-collapse:collapse;margin:16px 0;font-size:12.5px;border:1px solid #d8dde6}
.rpt-meta td{padding:6px 12px;border:1px solid #d8dde6}
.rpt-ml{background:#f3f3f3;font-weight:600;width:180px;color:#3e3e3c}
h2{font-size:14px;font-weight:700;color:#032d60;margin:20px 0 8px;padding-bottom:4px;border-bottom:2px solid #1b96ff}
h3{font-size:13px;font-weight:600;color:#3e3e3c;margin:14px 0 6px}
p{margin:6px 0;text-align:justify;font-size:12.5px;line-height:1.65}
.rpt-tbl{width:100%;border-collapse:collapse;margin:10px 0;font-size:12px}
.rpt-tbl th{background:#032d60;color:#fff;padding:7px 10px;text-align:left;font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.3px}
.rpt-tbl td{padding:6px 10px;border-bottom:1px solid #e5e5e5}
.rpt-tbl tr:nth-child(even) td{background:#f8fafc}
.rpt-risk-h{color:#c23934;font-weight:700}
.rpt-risk-m{color:#b86800;font-weight:700}
.rpt-risk-l{color:#2e844a;font-weight:700}
.rpt-gap{color:#c23934}.rpt-met{color:#2e844a}.rpt-partial{color:#b86800}
.rpt-tag{display:inline-block;padding:1px 8px;border-radius:10px;font-size:10.5px;font-weight:600}
.rpt-tag-red{background:#fde8e4;color:#c23934}
.rpt-tag-green{background:#e6f5ec;color:#2e844a}
.rpt-tag-amber{background:#fef3e0;color:#b86800}
.rpt-tag-blue{background:#eef4ff;color:#0070d2}
.rpt-callout{background:#eef4ff;border-left:4px solid #1b96ff;padding:10px 14px;margin:12px 0;font-size:12.5px}
.rpt-callout-warn{background:#fef3e0;border-left-color:#fe9339}
.rpt-sign{margin:16px 0;border:1px solid #d8dde6;border-radius:4px;overflow:hidden}
.rpt-sign-head{background:#f3f3f3;padding:8px 12px;font-weight:700;font-size:12.5px;color:#032d60}
.rpt-sign table{width:100%;border-collapse:collapse}
.rpt-sign td{padding:8px 12px;border-bottom:1px solid #e5e5e5;font-size:12px}
.rpt-sign .rpt-sl{width:180px;font-weight:600;color:#3e3e3c}
.rpt-footer{text-align:center;padding:12px;border-top:2px solid #032d60;margin-top:20px;font-size:10.5px;color:#706e6b}
.rpt-watermark{color:#c8d6e5;font-size:10px;text-align:center;letter-spacing:3px;margin:8px 0}
ul,ol{margin:6px 0 6px 20px;padding:0;font-size:12.5px}
li{margin:3px 0}
`;

export default class PramaanFilingCenter extends LightningElement {
    _packId;
    @track documents = [];
    @track isLoading = false;
    @track selectedDocId = null;
    _renderedDocId = null;

    @api
    get packId() { return this._packId; }
    set packId(value) {
        this._packId = value;
        if (value) this.loadDocuments();
    }

    async loadDocuments() {
        if (!this._packId) return;
        this.isLoading = true;
        try {
            const docData = await getFilingDocuments({ packId: this._packId });
            this.documents = docData.map(d => ({
                ...d,
                generatedLabel: d.Generated_At__c ? new Date(d.Generated_At__c).toLocaleString() : '',
                isSelected: d.Id === this.selectedDocId,
                cardClass: d.Id === this.selectedDocId ? 'doc-card doc-card-selected' : 'doc-card'
            }));
            if (this.documents.length > 0 && !this.selectedDocId) {
                this.selectedDocId = this.documents[0].Id;
                this.documents[0].isSelected = true;
                this.documents[0].cardClass = 'doc-card doc-card-selected';
            }
        } catch (e) {
            console.error('Load documents error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get hasPackId() { return !!this._packId; }
    get hasDocuments() { return this.documents.length > 0; }

    get selectedDocument() {
        return this.documents.find(d => d.Id === this.selectedDocId) || null;
    }

    renderedCallback() {
        this._renderDocContent();
    }

    _renderDocContent() {
        const doc = this.selectedDocument;
        const docId = doc ? doc.Id : null;
        if (docId === this._renderedDocId) return;
        this._renderedDocId = docId;
        const container = this.template.querySelector('.doc-viewer-content');
        if (!container) return;
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
        if (doc && doc.Content__c) {
            const styleEl = document.createElement('style');
            styleEl.textContent = RPT_STYLES;
            container.appendChild(styleEl);
            const parser = new DOMParser();
            const parsed = parser.parseFromString(doc.Content__c, 'text/html');
            const fragment = document.createDocumentFragment();
            Array.from(parsed.body.childNodes).forEach(node => {
                fragment.appendChild(document.importNode(node, true));
            });
            container.appendChild(fragment);
        }
    }

    handleSelectDoc(event) {
        const docId = event.currentTarget.dataset.id;
        this.selectedDocId = docId;
        this.documents = this.documents.map(d => ({
            ...d,
            isSelected: d.Id === docId,
            cardClass: d.Id === docId ? 'doc-card doc-card-selected' : 'doc-card'
        }));
        this._renderedDocId = null;
    }
}
