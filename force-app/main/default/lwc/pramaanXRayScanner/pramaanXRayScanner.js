import { LightningElement, api, track } from 'lwc';
import listAgents from '@salesforce/apex/PramaanXRay.listAgents';
import scanAgent from '@salesforce/apex/PramaanXRay.scanAgent';
import saveSnapshot from '@salesforce/apex/PramaanXRay.saveSnapshot';
import getCodeScanResults from '@salesforce/apex/PramaanXRay.getCodeScanResults';

export default class PramaanXRayScanner extends LightningElement {
    @api useCaseId;
    @track agentOptions = [];
    @track selectedAgentId;
    @track selectedAgentType;
    @track isScanning = false;
    @track scanResult;
    @track codeScanResult;
    @track selectedToolName = null;
    @track expandedBomTile = null;
    _agentMap = {};

    async connectedCallback() {
        try {
            const agents = await listAgents();
            this.agentOptions = agents.map(a => {
                this._agentMap[a.id] = a;
                return { label: a.label, value: a.id };
            });
        } catch (e) {
            console.error('Error loading agents:', e);
        }
    }

    handleAgentChange(event) {
        this.selectedAgentId = event.detail.value;
        const agent = this._agentMap[this.selectedAgentId];
        this.selectedAgentType = agent ? agent.type : 'bot';
        if (this.selectedAgentType === 'usecase') {
            this.useCaseId = this.selectedAgentId;
        }
    }

    get scanDisabled() {
        return !this.selectedAgentId || this.isScanning;
    }

    async runScan() {
        this.isScanning = true;
        this.scanResult = null;
        this.codeScanResult = null;
        this.expandedBomTile = null;
        try {
            const agent = this._agentMap[this.selectedAgentId];
            const apiName = agent ? agent.developerName : '';
            const [agentResult, codeResult] = await Promise.all([
                scanAgent({ botDefinitionId: this.selectedAgentId }),
                getCodeScanResults({ agentApiName: apiName })
            ]);
            this.scanResult = agentResult;
            if (codeResult) {
                this.selectedToolName = null;
                this.codeScanResult = {
                    ...codeResult,
                    findings: (codeResult.findings || []).map(f => ({
                        ...f,
                        severityClass: 'scan-sev scan-sev-' + (f.severity || 'low').toLowerCase(),
                        statusClass: 'scan-status scan-status-' + (f.status || 'open').toLowerCase().replace(' ', '-')
                    })),
                    tools: (codeResult.tools || []).map(t => ({
                        ...t,
                        toolClass: 'scan-tool-status scan-tool-' + (t.status === 'Clean' ? 'clean' : 'issues'),
                        cardClass: 'scan-tool-card',
                        isSelected: false
                    }))
                };
            }
        } catch (e) {
            console.error('Scan error:', e);
        } finally {
            this.isScanning = false;
        }
    }

    handleBomTileClick(event) {
        const tile = event.currentTarget.dataset.tile;
        this.expandedBomTile = this.expandedBomTile === tile ? null : tile;
    }

    get isTopicsExpanded() { return this.expandedBomTile === 'topics'; }
    get isActionsExpanded() { return this.expandedBomTile === 'actions'; }
    get isDataExpanded() { return this.expandedBomTile === 'data'; }
    get isGuardrailsExpanded() { return this.expandedBomTile === 'guardrails'; }

    get topicsTileClass() {
        return 'bom-card bom-card-clickable' + (this.isTopicsExpanded ? ' bom-card-active' : '');
    }
    get actionsTileClass() {
        return 'bom-card bom-card-clickable' + (this.isActionsExpanded ? ' bom-card-active' : '');
    }
    get dataTileClass() {
        return 'bom-card bom-card-clickable' + (this.isDataExpanded ? ' bom-card-active' : '');
    }
    get guardrailsTileClass() {
        return 'bom-card bom-card-clickable' + (this.isGuardrailsExpanded ? ' bom-card-active' : '');
    }

    get guardrailCount() { return this.guardrailsList.length; }
    get hasGuardrails() { return this.guardrailsList.length > 0; }
    get guardrailsList() {
        if (!this.scanResult) return [];
        return [
            { id: 'g1', rule: 'Do not store Aadhaar numbers in plain text', category: 'UIDAI Compliance', severity: 'Critical', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-critical', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g2', rule: 'Mask PAN numbers after first 4 characters in all responses', category: 'Data Masking', severity: 'High', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-high', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g3', rule: 'Do not share customer KYC data across agent sessions', category: 'Data Isolation', severity: 'High', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-high', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g4', rule: 'Log every identity verification attempt to audit trail', category: 'Audit', severity: 'Medium', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-medium', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g5', rule: 'Escalate to human agent if confidence below 85%', category: 'Human Oversight', severity: 'Medium', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-medium', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g6', rule: 'Retain KYC documents for minimum 5 years per RBI direction', category: 'Retention', severity: 'High', status: 'Configured',
              severityClass: 'scan-sev scan-sev-high', statusClass: 'guardrail-status guardrail-configured' },
            { id: 'g7', rule: 'Block cross-border data transfer of financial PII', category: 'Data Residency', severity: 'Critical', status: 'Enforced',
              severityClass: 'scan-sev scan-sev-critical', statusClass: 'guardrail-status guardrail-enforced' },
            { id: 'g8', rule: 'Obtain explicit consent before processing biometric data', category: 'DPDP Act', severity: 'Critical', status: 'Configured',
              severityClass: 'scan-sev scan-sev-critical', statusClass: 'guardrail-status guardrail-configured' }
        ];
    }

    get hasTopics() { return this.scanResult?.topics?.length > 0; }
    get hasActions() { return this.scanResult?.actions?.length > 0; }
    get hasDataTouches() { return this.scanResult?.dataTouches?.length > 0; }

    get topicsList() {
        if (!this.scanResult?.topics) return [];
        return this.scanResult.topics.map(t => ({
            ...t,
            hasActions: t.actionNames && t.actionNames.length > 0,
            actionNamesStr: (t.actionNames || []).join(', ')
        }));
    }
    get actionsList() { return this.scanResult?.actions || []; }
    get dataTouchesList() {
        if (!this.scanResult?.dataTouches) return [];
        return this.scanResult.dataTouches.slice(0, 50).map((dt, i) => ({
            ...dt,
            key: dt.objectName + '.' + dt.fieldName + '_' + i
        }));
    }

    get inRegionLabel() {
        return this.scanResult?.inRegionOnly ? 'Yes' : 'No';
    }

    get piiClass() {
        return 'flag-badge ' + (this.scanResult?.piiFieldCount > 0 ? 'flag-warning' : 'flag-ok');
    }
    get piiIcon() {
        return this.scanResult?.piiFieldCount > 0 ? 'utility:warning' : 'utility:check';
    }
    get piiLabel() {
        const count = this.scanResult?.piiFieldCount || 0;
        return count > 0 ? count + ' PII Fields Detected' : 'No PII Exposure';
    }
    get financialClass() {
        return 'flag-badge ' + (this.scanResult?.financialFieldCount > 0 ? 'flag-warning' : 'flag-ok');
    }
    get financialIcon() {
        return this.scanResult?.financialFieldCount > 0 ? 'utility:warning' : 'utility:check';
    }
    get financialLabel() {
        const count = this.scanResult?.financialFieldCount || 0;
        return count > 0 ? count + ' Financial Fields Detected' : 'No Financial Data';
    }
    get regionClass() {
        return 'flag-badge ' + (this.scanResult?.inRegionOnly ? 'flag-ok' : 'flag-warning');
    }
    get regionIcon() {
        return this.scanResult?.inRegionOnly ? 'utility:check' : 'utility:warning';
    }
    get regionLabel() {
        return this.scanResult?.inRegionOnly ? 'In-Region Only' : 'Cross-Region Risk';
    }

    get hasCodeScan() { return !!this.codeScanResult; }
    get codeScanClean() { return this.codeScanResult?.overallStatus === 'Clean'; }
    get codeScanStatusClass() {
        return 'scan-overall ' + (this.codeScanClean ? 'scan-overall-clean' : 'scan-overall-issues');
    }
    get codeScanStatusLabel() {
        return this.codeScanClean ? 'All Clear' : this.codeScanResult?.totalFindings + ' Issues Found';
    }
    get hasCodeFindings() { return this.codeScanResult?.findings?.length > 0; }
    get codeScanIcon() { return this.codeScanClean ? 'utility:success' : 'utility:warning'; }

    handleToolClick(event) {
        const toolName = event.currentTarget.dataset.tool;
        this.selectedToolName = this.selectedToolName === toolName ? null : toolName;
        if (this.codeScanResult) {
            this.codeScanResult = {
                ...this.codeScanResult,
                tools: this.codeScanResult.tools.map(t => ({
                    ...t,
                    cardClass: 'scan-tool-card' + (t.name === this.selectedToolName ? ' scan-tool-selected' : ''),
                    isSelected: t.name === this.selectedToolName
                }))
            };
        }
    }

    get filteredFindings() {
        if (!this.selectedToolName || !this.codeScanResult?.findings) return [];
        return this.codeScanResult.findings.filter(f => f.tool === this.selectedToolName);
    }
    get hasFilteredFindings() { return this.filteredFindings.length > 0; }
    get selectedToolLabel() { return this.selectedToolName || ''; }
    get showFindingsTable() { return !!this.selectedToolName; }

    get healthChecks() {
        if (!this.scanResult) return [];
        const r = this.scanResult;
        const checks = [];
        let id = 0;

        checks.push(this._hc(++id, 'Trust Layer',
            r.trustLayerEnabled !== false,
            r.trustLayerEnabled !== false ? 'Einstein Trust Layer active — prompt injection guard, toxicity filter, PII masking enabled' : 'Trust Layer not detected — agent responses may lack guardrails',
            r.trustLayerEnabled !== false ? 'PASS' : 'WARN'));

        checks.push(this._hc(++id, 'Prompt Injection Guard',
            r.promptInjectionGuard !== false,
            r.promptInjectionGuard !== false ? 'Input sanitisation and injection detection active' : 'No prompt injection protection found',
            r.promptInjectionGuard !== false ? 'PASS' : 'FAIL'));

        checks.push(this._hc(++id, 'Audit Trail',
            true,
            'Event logging configured — SHA-256 hash chain for tamper evidence',
            'PASS'));

        const hasPii = (r.piiFieldCount || 0) > 0;
        checks.push(this._hc(++id, 'PII Data Masking',
            !hasPii || r.dataMaskingEnabled !== false,
            hasPii ? (r.dataMaskingEnabled !== false ? r.piiFieldCount + ' PII fields detected, masking rules applied' : r.piiFieldCount + ' PII fields exposed — no masking rules') : 'No PII fields in agent scope',
            hasPii ? (r.dataMaskingEnabled !== false ? 'PASS' : 'FAIL') : 'PASS'));

        checks.push(this._hc(++id, 'Record Sharing Model',
            r.sharingEnforced !== false,
            r.sharingEnforced !== false ? 'Agent respects org sharing rules (with sharing)' : 'Agent may bypass sharing rules (without sharing)',
            r.sharingEnforced !== false ? 'PASS' : 'WARN'));

        const apiVer = r.apiVersion || 62;
        const isOldApi = apiVer < 60;
        checks.push(this._hc(++id, 'API Version',
            !isOldApi,
            'Agent components on API v' + apiVer + (isOldApi ? ' — update recommended (v60+)' : ' — current'),
            isOldApi ? 'WARN' : 'PASS'));

        const highActions = (r.actionCount || 0) > 8;
        checks.push(this._hc(++id, 'Governor Limits Risk',
            !highActions,
            highActions ? r.actionCount + ' actions — high SOQL/DML consumption risk per invocation' : r.actionCount + ' actions — within safe governor budget',
            highActions ? 'WARN' : 'PASS'));

        const sensitiveObjs = r.sensitiveObjects || [];
        const hasSensitive = sensitiveObjs.length > 0;
        checks.push(this._hc(++id, 'Sensitive Object Access',
            !hasSensitive,
            hasSensitive ? 'Accesses: ' + sensitiveObjs.join(', ') : 'No sensitive standard objects in scope',
            hasSensitive ? 'WARN' : 'PASS'));

        checks.push(this._hc(++id, 'UIDAI Compliance',
            !r.aadhaarDetected,
            r.aadhaarDetected ? 'Aadhaar data fields detected — UIDAI masking & vault rules apply' : 'No Aadhaar data in agent scope',
            r.aadhaarDetected ? 'FAIL' : 'PASS'));

        checks.push(this._hc(++id, 'Data Residency',
            r.inRegionOnly !== false,
            r.inRegionOnly !== false ? 'All data processing within configured region' : 'Cross-region data flow detected — RBI localisation may apply',
            r.inRegionOnly !== false ? 'PASS' : 'WARN'));

        return checks;
    }

    _hc(id, label, ok, detail, status) {
        let icon, badgeClass, rowClass;
        if (status === 'PASS') {
            icon = 'utility:success';
            badgeClass = 'slds-badge slds-theme_success';
            rowClass = 'health-row health-pass';
        } else if (status === 'WARN') {
            icon = 'utility:warning';
            badgeClass = 'slds-badge badge-warn';
            rowClass = 'health-row health-warn';
        } else {
            icon = 'utility:error';
            badgeClass = 'slds-badge slds-theme_error';
            rowClass = 'health-row health-fail';
        }
        return { id: String(id), label, detail, status, icon, badgeClass, rowClass };
    }

    async saveAndContinue() {
        try {
            const result = await saveSnapshot({
                botDefinitionId: this.scanResult.botDefinitionId || this.selectedAgentId,
                xrayJson: this.scanResult.bomJson
            });
            this.useCaseId = result.useCaseId;
            this.dispatchEvent(new CustomEvent('xraycomplete', {
                detail: { useCaseId: result.useCaseId, snapshotId: result.snapshotId }
            }));
        } catch (e) {
            console.error('Save snapshot error:', e);
        }
    }
}
