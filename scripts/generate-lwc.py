#!/usr/bin/env python3
"""Generate all Pramaan LWC components."""
import os

BASE = "/Users/shilpi.mittal/IdeaProjects/Hack2Future/pramaan/force-app/main/default/lwc"

def write_component(name, html, js, meta_targets=None):
    d = os.path.join(BASE, name)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, f"{name}.html"), "w") as f:
        f.write(html)
    with open(os.path.join(d, f"{name}.js"), "w") as f:
        f.write(js)
    targets = meta_targets or ["lightning__AppPage", "lightning__RecordPage", "lightning__HomePage"]
    target_xml = "\n            ".join(f"<target>{t}</target>" for t in targets)
    meta = f"""<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>{name}</masterLabel>
    <targets>
        {target_xml}
    </targets>
</LightningComponentBundle>
"""
    with open(os.path.join(d, f"{name}.js-meta.xml"), "w") as f:
        f.write(meta)


# ── 1. pramaanApp - Main tab-based app wrapper ──
write_component("pramaanApp",
html="""<template>
    <div class="pramaan-app">
        <div class="slds-page-header slds-page-header_joined">
            <div class="slds-page-header__row">
                <div class="slds-page-header__col-title">
                    <div class="slds-media">
                        <div class="slds-media__figure">
                            <lightning-icon icon-name="standard:shield" size="large"></lightning-icon>
                        </div>
                        <div class="slds-media__body">
                            <h1 class="slds-page-header__title">Pramaan</h1>
                            <p class="slds-page-header__meta-text">Proof, not paperwork &mdash; AI Governance Filing System</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <lightning-tabset variant="scoped" active-tab-value={activeTab} onactive={handleTabChange}>
            <lightning-tab label="Mission Control" value="mission" icon-name="standard:dashboard">
                <pramaan-mission-control onlaunchflow={handleLaunchFlow}></pramaan-mission-control>
            </lightning-tab>
            <lightning-tab label="X-Ray" value="xray" icon-name="standard:scan_card">
                <pramaan-x-ray-scanner onxraycomplete={handleXRayComplete}></pramaan-x-ray-scanner>
            </lightning-tab>
            <lightning-tab label="Assess" value="assess" icon-name="standard:task2">
                <pramaan-assess
                    use-case-id={selectedUseCaseId}
                    onassesscomplete={handleAssessComplete}>
                </pramaan-assess>
            </lightning-tab>
            <lightning-tab label="Compliance Map" value="map" icon-name="standard:entitlement">
                <pramaan-compliance-map
                    pack-id={selectedPackId}
                    use-case-id={selectedUseCaseId}>
                </pramaan-compliance-map>
            </lightning-tab>
            <lightning-tab label="Review Gates" value="review" icon-name="standard:approval">
                <pramaan-reviewer-lens pack-id={selectedPackId}></pramaan-reviewer-lens>
            </lightning-tab>
            <lightning-tab label="Go-Live Passport" value="passport" icon-name="standard:endorsement">
                <pramaan-go-live-passport pack-id={selectedPackId}></pramaan-go-live-passport>
            </lightning-tab>
            <lightning-tab label="Audit Trail" value="audit" icon-name="standard:record_lookup">
                <pramaan-audit-trail pack-id={selectedPackId}></pramaan-audit-trail>
            </lightning-tab>
        </lightning-tabset>
    </div>
</template>
""",
js="""import { LightningElement, track } from 'lwc';

export default class PramaanApp extends LightningElement {
    @track activeTab = 'mission';
    @track selectedUseCaseId;
    @track selectedPackId;
    @track selectedSnapshotId;

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    handleLaunchFlow(event) {
        const { useCaseId, step } = event.detail;
        this.selectedUseCaseId = useCaseId;
        this.activeTab = step || 'xray';
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
}
""")


# ── 2. pramaanMissionControl - Dashboard ──
write_component("pramaanMissionControl",
html="""<template>
    <lightning-card title="Mission Control" icon-name="standard:dashboard">
        <div slot="actions">
            <lightning-button label="New Use Case" variant="brand" onclick={handleNewUseCase}></lightning-button>
            <lightning-button label="Refresh" icon-name="utility:refresh" onclick={loadUseCases} class="slds-m-left_x-small"></lightning-button>
        </div>

        <div class="slds-p-around_medium">
            <!-- Stats Row -->
            <div class="slds-grid slds-gutters slds-m-bottom_medium">
                <div class="slds-col slds-size_1-of-5">
                    <div class="stat-card draft">
                        <div class="stat-number">{stats.draft}</div>
                        <div class="stat-label">Draft</div>
                    </div>
                </div>
                <div class="slds-col slds-size_1-of-5">
                    <div class="stat-card scanning">
                        <div class="stat-number">{stats.scanning}</div>
                        <div class="stat-label">Scanning</div>
                    </div>
                </div>
                <div class="slds-col slds-size_1-of-5">
                    <div class="stat-card review">
                        <div class="stat-number">{stats.inReview}</div>
                        <div class="stat-label">In Review</div>
                    </div>
                </div>
                <div class="slds-col slds-size_1-of-5">
                    <div class="stat-card approved">
                        <div class="stat-number">{stats.approved}</div>
                        <div class="stat-label">Approved</div>
                    </div>
                </div>
                <div class="slds-col slds-size_1-of-5">
                    <div class="stat-card rejected">
                        <div class="stat-number">{stats.rejected}</div>
                        <div class="stat-label">Rejected</div>
                    </div>
                </div>
            </div>

            <!-- Use Case Table -->
            <template if:true={useCases.length}>
                <lightning-datatable
                    key-field="Id"
                    data={useCases}
                    columns={columns}
                    onrowaction={handleRowAction}
                    hide-checkbox-column>
                </lightning-datatable>
            </template>
            <template if:false={useCases.length}>
                <div class="slds-illustration slds-illustration_small slds-p-around_large slds-align_absolute-center">
                    <p class="slds-text-heading_medium slds-text-color_weak">No AI use cases filed yet</p>
                    <p class="slds-text-body_regular slds-text-color_weak slds-m-top_small">Click "New Use Case" to begin your first AI governance filing</p>
                </div>
            </template>
        </div>
    </lightning-card>

    <!-- New Use Case Modal -->
    <template if:true={showNewModal}>
        <section role="dialog" tabindex="-1" class="slds-modal slds-fade-in-open">
            <div class="slds-modal__container">
                <header class="slds-modal__header">
                    <h2 class="slds-modal__title">New AI Use Case</h2>
                    <button class="slds-button slds-button_icon slds-modal__close" onclick={closeModal}>
                        <lightning-icon icon-name="utility:close" size="small"></lightning-icon>
                    </button>
                </header>
                <div class="slds-modal__content slds-p-around_medium">
                    <lightning-input label="Use Case Name" value={newUseCase.Name} onchange={handleFieldChange} data-field="Name" required class="slds-m-bottom_small"></lightning-input>
                    <lightning-textarea label="Purpose" value={newUseCase.Purpose__c} onchange={handleFieldChange} data-field="Purpose__c" class="slds-m-bottom_small"></lightning-textarea>
                    <lightning-combobox label="Sub-Sector" value={newUseCase.Sub_Sector__c} options={subSectorOptions} onchange={handleFieldChange} data-field="Sub_Sector__c" class="slds-m-bottom_small"></lightning-combobox>
                    <lightning-combobox label="Decision Impact" value={newUseCase.Decision_Impact__c} options={decisionImpactOptions} onchange={handleFieldChange} data-field="Decision_Impact__c" class="slds-m-bottom_small"></lightning-combobox>
                    <lightning-combobox label="Autonomy" value={newUseCase.Autonomy__c} options={autonomyOptions} onchange={handleFieldChange} data-field="Autonomy__c" class="slds-m-bottom_small"></lightning-combobox>
                    <lightning-combobox label="Audience" value={newUseCase.Audience__c} options={audienceOptions} onchange={handleFieldChange} data-field="Audience__c" class="slds-m-bottom_small"></lightning-combobox>
                    <lightning-input label="Channels" value={newUseCase.Channels__c} onchange={handleFieldChange} data-field="Channels__c" class="slds-m-bottom_small"></lightning-input>
                    <lightning-input label="Function" value={newUseCase.Function__c} onchange={handleFieldChange} data-field="Function__c" class="slds-m-bottom_small"></lightning-input>
                    <lightning-input label="Data Categories" value={newUseCase.Data_Categories__c} onchange={handleFieldChange} data-field="Data_Categories__c" class="slds-m-bottom_small"></lightning-input>
                </div>
                <footer class="slds-modal__footer">
                    <lightning-button label="Cancel" onclick={closeModal}></lightning-button>
                    <lightning-button label="Create & Start X-Ray" variant="brand" onclick={handleCreate} class="slds-m-left_x-small"></lightning-button>
                </footer>
            </div>
        </section>
        <div class="slds-backdrop slds-backdrop_open"></div>
    </template>
</template>
""",
js="""import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class PramaanMissionControl extends LightningElement {
    @track useCases = [];
    @track showNewModal = false;
    @track newUseCase = {};
    @track stats = { draft: 0, scanning: 0, inReview: 0, approved: 0, rejected: 0 };

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
        { label: 'Scheduled Commercial Bank', value: 'Scheduled Commercial Bank' },
        { label: 'NBFC - Upper Layer', value: 'NBFC - Upper Layer' },
        { label: 'NBFC - Middle Layer', value: 'NBFC - Middle Layer' },
        { label: 'Insurance - Life', value: 'Insurance - Life' },
        { label: 'Insurance - General', value: 'Insurance - General' },
        { label: 'Stockbroker', value: 'Stockbroker' },
        { label: 'Payment Aggregator', value: 'Payment Aggregator' },
        { label: 'Small Finance Bank', value: 'Small Finance Bank' },
    ];

    decisionImpactOptions = [
        { label: 'Informational', value: 'Informational' },
        { label: 'Recommendation', value: 'Recommendation' },
        { label: 'Decision-making', value: 'Decision-making' },
        { label: 'Autonomous-action', value: 'Autonomous-action' },
    ];

    autonomyOptions = [
        { label: 'Human-in-the-loop', value: 'Human-in-the-loop' },
        { label: 'Human-on-the-loop', value: 'Human-on-the-loop' },
        { label: 'Human-out-of-the-loop', value: 'Human-out-of-the-loop' },
    ];

    audienceOptions = [
        { label: 'Internal', value: 'Internal' },
        { label: 'Customer-facing', value: 'Customer-facing' },
        { label: 'Both', value: 'Both' },
    ];

    connectedCallback() {
        this.loadUseCases();
    }

    async loadUseCases() {
        try {
            const result = await fetch('/services/data/v62.0/query/?q=' +
                encodeURIComponent("SELECT Id, Name, Status__c, Risk_Tier__c, Risk_Score__c, Passport_Number__c, Agent_API_Name__c, Sub_Sector__c, Purpose__c FROM AI_Use_Case__c ORDER BY CreatedDate DESC LIMIT 100"),
                { headers: { 'Authorization': 'Bearer ' + this.getSessionId() } }
            );
            if (result.ok) {
                const data = await result.json();
                this.useCases = (data.records || []).map(r => ({
                    ...r,
                    statusClass: 'status-' + (r.Status__c || 'draft').toLowerCase().replace(/\\s+/g, '-')
                }));
                this.computeStats();
            }
        } catch (e) {
            console.error('Load use cases error:', e);
        }
    }

    computeStats() {
        const s = { draft: 0, scanning: 0, inReview: 0, approved: 0, rejected: 0 };
        this.useCases.forEach(uc => {
            const st = (uc.Status__c || 'Draft').toLowerCase();
            if (st === 'draft') s.draft++;
            else if (st === 'scanning' || st === 'assessed') s.scanning++;
            else if (st === 'in review' || st === 'filed') s.inReview++;
            else if (st === 'approved') s.approved++;
            else if (st === 'rejected' || st === 'rework') s.rejected++;
            else s.draft++;
        });
        this.stats = s;
    }

    getSessionId() {
        const match = document.cookie.match(/sid=([^;]+)/);
        return match ? match[1] : '';
    }

    handleNewUseCase() {
        this.newUseCase = { Name: '', Purpose__c: '', Sub_Sector__c: 'Scheduled Commercial Bank',
            Decision_Impact__c: 'Recommendation', Autonomy__c: 'Human-in-the-loop',
            Audience__c: 'Customer-facing', Channels__c: '', Function__c: '', Data_Categories__c: '' };
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
            const body = { ...this.newUseCase, Status__c: 'Draft' };
            const result = await fetch('/services/data/v62.0/sobjects/AI_Use_Case__c', {
                method: 'POST',
                headers: {
                    'Authorization': 'Bearer ' + this.getSessionId(),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(body)
            });
            if (result.ok) {
                const data = await result.json();
                this.showNewModal = false;
                this.dispatchEvent(new CustomEvent('launchflow', {
                    detail: { useCaseId: data.id, step: 'xray' }
                }));
                this.loadUseCases();
            }
        } catch (e) {
            console.error('Create use case error:', e);
        }
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        const status = (row.Status__c || 'Draft').toLowerCase();
        let step = 'xray';
        if (status === 'assessed') step = 'map';
        else if (status === 'in review' || status === 'filed') step = 'review';
        else if (status === 'approved') step = 'passport';

        this.dispatchEvent(new CustomEvent('launchflow', {
            detail: { useCaseId: row.Id, step: action.name === 'view' ? 'audit' : step }
        }));
    }
}
""")


# ── 3. pramaanXRayScanner ──
write_component("pramaanXRayScanner",
html="""<template>
    <lightning-card title="Step 1: X-Ray Agent Scanner" icon-name="standard:scan_card">
        <div class="slds-p-around_medium">
            <p class="slds-text-body_regular slds-m-bottom_medium">
                Scan any Agentforce agent to generate its AI Bill of Materials — topics, actions, data touches, PII fields, and compliance flags.
            </p>

            <!-- Agent Picker -->
            <div class="slds-grid slds-gutters slds-m-bottom_medium">
                <div class="slds-col slds-size_2-of-3">
                    <lightning-combobox
                        label="Select Agent to Scan"
                        value={selectedAgentId}
                        options={agentOptions}
                        onchange={handleAgentChange}
                        placeholder="Choose an agent...">
                    </lightning-combobox>
                </div>
                <div class="slds-col slds-size_1-of-3 slds-grid slds-grid_vertical-align-end">
                    <lightning-button
                        label="Run X-Ray Scan"
                        variant="brand"
                        icon-name="utility:search"
                        onclick={runScan}
                        disabled={scanDisabled}>
                    </lightning-button>
                </div>
            </div>

            <!-- Loading -->
            <template if:true={isScanning}>
                <div class="slds-align_absolute-center slds-p-around_large">
                    <lightning-spinner alternative-text="Scanning agent..." size="medium"></lightning-spinner>
                    <p class="slds-m-left_medium">Scanning agent configuration...</p>
                </div>
            </template>

            <!-- Results -->
            <template if:true={scanResult}>
                <div class="slds-box slds-theme_shade slds-m-bottom_medium">
                    <h3 class="slds-text-heading_small slds-m-bottom_small">
                        AI Bill of Materials: {scanResult.agentName}
                    </h3>

                    <!-- BOM Stats -->
                    <div class="slds-grid slds-gutters slds-wrap slds-m-bottom_medium">
                        <div class="slds-col slds-size_1-of-4 slds-p-around_x-small">
                            <div class="bom-stat">
                                <lightning-icon icon-name="standard:topic2" size="small"></lightning-icon>
                                <span class="slds-m-left_x-small"><strong>{scanResult.topicCount}</strong> Topics</span>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4 slds-p-around_x-small">
                            <div class="bom-stat">
                                <lightning-icon icon-name="standard:flow" size="small"></lightning-icon>
                                <span class="slds-m-left_x-small"><strong>{scanResult.actionCount}</strong> Actions</span>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4 slds-p-around_x-small">
                            <div class="bom-stat">
                                <lightning-icon icon-name="standard:record" size="small"></lightning-icon>
                                <span class="slds-m-left_x-small"><strong>{scanResult.objectCount}</strong> Objects</span>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4 slds-p-around_x-small">
                            <div class="bom-stat">
                                <lightning-icon icon-name="standard:data_streams" size="small"></lightning-icon>
                                <span class="slds-m-left_x-small"><strong>{scanResult.fieldCount}</strong> Fields</span>
                            </div>
                        </div>
                    </div>

                    <!-- Compliance Flags -->
                    <div class="slds-grid slds-gutters slds-m-bottom_medium">
                        <div class="slds-col slds-size_1-of-3">
                            <div class={piiClass}>
                                <lightning-icon icon-name={piiIcon} size="x-small"></lightning-icon>
                                <span class="slds-m-left_x-small">{scanResult.piiFieldCount} PII Fields</span>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-3">
                            <div class={financialClass}>
                                <lightning-icon icon-name={financialIcon} size="x-small"></lightning-icon>
                                <span class="slds-m-left_x-small">{scanResult.financialFieldCount} Financial Fields</span>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-3">
                            <div class={aadhaarClass}>
                                <lightning-icon icon-name={aadhaarIcon} size="x-small"></lightning-icon>
                                <span class="slds-m-left_x-small">{aadhaarLabel}</span>
                            </div>
                        </div>
                    </div>

                    <!-- Region Info -->
                    <div class="slds-grid slds-gutters slds-m-bottom_medium">
                        <div class="slds-col">
                            <span class="slds-badge slds-badge_inverse">Region: {scanResult.region}</span>
                            <span class="slds-badge slds-theme_success slds-m-left_x-small">Model: {scanResult.modelProvider}</span>
                            <span class="slds-badge slds-m-left_x-small">Scan: {scanResult.scanDurationMs}ms</span>
                        </div>
                    </div>
                </div>

                <!-- Save & Continue -->
                <template if:true={useCaseId}>
                    <div class="slds-grid slds-grid_align-end">
                        <lightning-button
                            label="Save Snapshot & Continue to Assess"
                            variant="brand"
                            icon-name="utility:forward"
                            onclick={saveAndContinue}>
                        </lightning-button>
                    </div>
                </template>
            </template>
        </div>
    </lightning-card>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import listAgents from '@salesforce/apex/PramaanXRay.listAgents';
import scanAgent from '@salesforce/apex/PramaanXRay.scanAgent';
import saveSnapshot from '@salesforce/apex/PramaanXRay.saveSnapshot';

export default class PramaanXRayScanner extends LightningElement {
    @api useCaseId;
    @track agentOptions = [];
    @track selectedAgentId;
    @track isScanning = false;
    @track scanResult;

    async connectedCallback() {
        try {
            const agents = await listAgents();
            this.agentOptions = agents.map(a => ({
                label: a.label,
                value: a.id
            }));
        } catch (e) {
            console.error('Error loading agents:', e);
        }
    }

    handleAgentChange(event) {
        this.selectedAgentId = event.detail.value;
    }

    get scanDisabled() {
        return !this.selectedAgentId || this.isScanning;
    }

    async runScan() {
        this.isScanning = true;
        this.scanResult = null;
        try {
            this.scanResult = await scanAgent({ botDefinitionId: this.selectedAgentId });
        } catch (e) {
            console.error('Scan error:', e);
        } finally {
            this.isScanning = false;
        }
    }

    get piiClass() {
        return 'flag-badge ' + (this.scanResult?.piiFieldCount > 0 ? 'flag-warning' : 'flag-ok');
    }
    get piiIcon() {
        return this.scanResult?.piiFieldCount > 0 ? 'utility:warning' : 'utility:check';
    }
    get financialClass() {
        return 'flag-badge ' + (this.scanResult?.financialFieldCount > 0 ? 'flag-warning' : 'flag-ok');
    }
    get financialIcon() {
        return this.scanResult?.financialFieldCount > 0 ? 'utility:warning' : 'utility:check';
    }
    get aadhaarClass() {
        return 'flag-badge ' + (this.scanResult?.aadhaarDetected ? 'flag-critical' : 'flag-ok');
    }
    get aadhaarIcon() {
        return this.scanResult?.aadhaarDetected ? 'utility:error' : 'utility:check';
    }
    get aadhaarLabel() {
        return this.scanResult?.aadhaarDetected ? 'Aadhaar Detected!' : 'No Aadhaar';
    }

    async saveAndContinue() {
        try {
            const snapshotId = await saveSnapshot({
                botDefinitionId: this.selectedAgentId,
                xrayJson: this.scanResult.bomJson
            });
            this.dispatchEvent(new CustomEvent('xraycomplete', {
                detail: { useCaseId: this.useCaseId, snapshotId: snapshotId }
            }));
        } catch (e) {
            console.error('Save snapshot error:', e);
        }
    }
}
""")


# ── 4. pramaanAssess - Risk Assessment ──
write_component("pramaanAssess",
html="""<template>
    <lightning-card title="Step 2: Risk Assessment" icon-name="standard:task2">
        <div class="slds-p-around_medium">
            <template if:false={assessmentComplete}>
                <p class="slds-text-body_regular slds-m-bottom_medium">
                    Answer the following questions to determine the risk tier and applicable compliance requirements.
                </p>

                <!-- Progress -->
                <lightning-progress-bar value={progressPercent} size="large" class="slds-m-bottom_medium"></lightning-progress-bar>
                <p class="slds-text-body_small slds-text-color_weak slds-m-bottom_medium">
                    Question {currentQuestionIndex} of {totalQuestions}
                </p>

                <!-- Current Question -->
                <template if:true={currentQuestion}>
                    <div class="slds-box slds-m-bottom_medium">
                        <h3 class="slds-text-heading_small slds-m-bottom_small">{currentQuestion.label}</h3>
                        <p class="slds-text-body_small slds-text-color_weak slds-m-bottom_medium">{currentQuestion.help}</p>

                        <template if:true={currentQuestion.isCombobox}>
                            <lightning-combobox
                                value={currentAnswer}
                                options={currentQuestion.options}
                                onchange={handleAnswer}>
                            </lightning-combobox>
                        </template>
                        <template if:true={currentQuestion.isCheckbox}>
                            <lightning-input
                                type="checkbox"
                                label={currentQuestion.checkboxLabel}
                                checked={currentAnswerBool}
                                onchange={handleBoolAnswer}>
                            </lightning-input>
                        </template>
                        <template if:true={currentQuestion.isText}>
                            <lightning-textarea
                                value={currentAnswer}
                                onchange={handleAnswer}>
                            </lightning-textarea>
                        </template>
                    </div>
                </template>

                <div class="slds-grid slds-grid_align-spread">
                    <lightning-button label="Previous" onclick={prevQuestion} disabled={isFirstQuestion}></lightning-button>
                    <template if:false={isLastQuestion}>
                        <lightning-button label="Next" variant="brand" onclick={nextQuestion}></lightning-button>
                    </template>
                    <template if:true={isLastQuestion}>
                        <lightning-button label="Calculate Risk & Continue" variant="brand" onclick={submitAssessment} icon-name="utility:forward"></lightning-button>
                    </template>
                </div>
            </template>

            <!-- Assessment Result -->
            <template if:true={assessmentComplete}>
                <div class="slds-box slds-theme_shade">
                    <h3 class="slds-text-heading_small slds-m-bottom_medium">Risk Assessment Result</h3>
                    <div class="slds-grid slds-gutters slds-m-bottom_medium">
                        <div class="slds-col slds-size_1-of-3 slds-align_absolute-center">
                            <div class={riskTierClass}>
                                <div class="risk-score">{riskResult.riskScore}</div>
                                <div class="risk-label">{riskResult.riskTier}</div>
                                <div class="risk-sublabel">Risk Score (0-21)</div>
                            </div>
                        </div>
                        <div class="slds-col slds-size_2-of-3">
                            <dl class="slds-list_horizontal slds-wrap">
                                <dt class="slds-item_label slds-text-color_weak">Applicable Clauses:</dt>
                                <dd class="slds-item_detail">{riskResult.applicableClauses}</dd>
                                <dt class="slds-item_label slds-text-color_weak">N/A Clauses:</dt>
                                <dd class="slds-item_detail">{riskResult.naClauses}</dd>
                                <dt class="slds-item_label slds-text-color_weak">Review Gates:</dt>
                                <dd class="slds-item_detail">{riskResult.gateCount}</dd>
                            </dl>
                        </div>
                    </div>

                    <lightning-button
                        label="Create Governance Pack & Map Clauses"
                        variant="brand"
                        onclick={createPackAndMap}
                        icon-name="utility:forward">
                    </lightning-button>
                </div>
            </template>
        </div>
    </lightning-card>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import assessRisk from '@salesforce/apex/PramaanRiskEngine.assessRisk';
import createGovernancePack from '@salesforce/apex/PramaanGovernanceService.createGovernancePack';
import createClauseMappings from '@salesforce/apex/PramaanGovernanceService.createClauseMappings';

export default class PramaanAssess extends LightningElement {
    @api useCaseId;
    @api snapshotId;
    @track currentIdx = 0;
    @track answers = {};
    @track assessmentComplete = false;
    @track riskResult;

    questions = [
        { key: 'purpose', label: 'What is the primary purpose of this AI agent?', help: 'Describe the core business function this agent performs', isText: true },
        { key: 'decision_impact', label: 'What is the decision impact level?', help: 'How much authority does this agent have?', isCombobox: true,
          options: [
            { label: 'Informational - provides info only', value: 'Informational' },
            { label: 'Recommendation - suggests actions', value: 'Recommendation' },
            { label: 'Decision-making - makes decisions with oversight', value: 'Decision-making' },
            { label: 'Autonomous-action - acts independently', value: 'Autonomous-action' }
          ]},
        { key: 'autonomy', label: 'What is the human oversight model?', help: 'How is human control maintained?', isCombobox: true,
          options: [
            { label: 'Human-in-the-loop - human approves each action', value: 'Human-in-the-loop' },
            { label: 'Human-on-the-loop - human monitors and can intervene', value: 'Human-on-the-loop' },
            { label: 'Human-out-of-the-loop - fully autonomous', value: 'Human-out-of-the-loop' }
          ]},
        { key: 'audience', label: 'Who interacts with this agent?', help: 'Internal employees, external customers, or both?', isCombobox: true,
          options: [
            { label: 'Internal only', value: 'Internal' },
            { label: 'Customer-facing', value: 'Customer-facing' },
            { label: 'Both internal and external', value: 'Both' }
          ]},
        { key: 'data_categories', label: 'What data categories does the agent process?', help: 'Comma-separated: PII, Financial, Health, Biometric, Aadhaar, etc.', isText: true },
        { key: 'channels', label: 'Through which channels does the agent operate?', help: 'e.g., Web, Mobile, WhatsApp, Voice, Email', isText: true },
        { key: 'function', label: 'What business function does this support?', help: 'e.g., Lending, Insurance Claims, Customer Service, Trading', isText: true },
        { key: 'vulnerable', label: 'Does this agent interact with vulnerable customers?', help: 'Elderly, minors, financially distressed, differently-abled', isCheckbox: true, checkboxLabel: 'Yes, this agent may interact with vulnerable customers' },
        { key: 'cross_border', label: 'Does this involve cross-border data transfer?', help: 'Data leaving India or processing outside India', isCheckbox: true, checkboxLabel: 'Yes, cross-border data transfer is involved' },
        { key: 'disclosure', label: 'Is AI disclosure provided to users?', help: 'Do users know they are interacting with AI?', isCombobox: true,
          options: [
            { label: 'Yes - clear disclosure at start', value: 'Yes' },
            { label: 'Partial - mentioned but not prominent', value: 'Partial' },
            { label: 'No - no disclosure', value: 'No' }
          ]},
        { key: 'human_fallback', label: 'Is human fallback available?', help: 'Can users escalate to a human at any point?', isCheckbox: true, checkboxLabel: 'Yes, human fallback is always available' },
        { key: 'kill_switch', label: 'Is a kill switch implemented?', help: 'Can the agent be immediately shut down if needed?', isCheckbox: true, checkboxLabel: 'Yes, kill switch is in place' },
        { key: 'retention', label: 'What is the data retention period?', help: 'How long is conversational/decision data kept?', isText: true },
        { key: 'third_parties', label: 'Are third-party models or APIs used?', help: 'Any external AI services beyond Einstein Trust Layer?', isText: true },
        { key: 'rollback_plan', label: 'What is the rollback plan?', help: 'Steps to revert if the agent malfunctions', isText: true },
    ];

    get totalQuestions() { return this.questions.length; }
    get currentQuestionIndex() { return this.currentIdx + 1; }
    get progressPercent() { return Math.round(((this.currentIdx + 1) / this.totalQuestions) * 100); }
    get currentQuestion() { return this.questions[this.currentIdx]; }
    get currentAnswer() { return this.answers[this.currentQuestion?.key] || ''; }
    get currentAnswerBool() { return this.answers[this.currentQuestion?.key] === 'true'; }
    get isFirstQuestion() { return this.currentIdx === 0; }
    get isLastQuestion() { return this.currentIdx === this.totalQuestions - 1; }

    get riskTierClass() {
        const tier = (this.riskResult?.riskTier || '').toLowerCase();
        return 'risk-badge risk-' + tier;
    }

    handleAnswer(event) {
        this.answers = { ...this.answers, [this.currentQuestion.key]: event.target.value };
    }

    handleBoolAnswer(event) {
        this.answers = { ...this.answers, [this.currentQuestion.key]: String(event.target.checked) };
    }

    nextQuestion() { if (this.currentIdx < this.totalQuestions - 1) this.currentIdx++; }
    prevQuestion() { if (this.currentIdx > 0) this.currentIdx--; }

    async submitAssessment() {
        if (!this.useCaseId) {
            console.error('No use case ID provided');
            return;
        }
        try {
            this.riskResult = await assessRisk({ useCaseId: this.useCaseId });
            this.assessmentComplete = true;
        } catch (e) {
            console.error('Risk assessment error:', e);
        }
    }

    async createPackAndMap() {
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
        }
    }
}
""")


# ── 5. pramaanComplianceMap ──
write_component("pramaanComplianceMap",
html="""<template>
    <lightning-card title="Step 3: Compliance Map" icon-name="standard:entitlement">
        <div class="slds-p-around_medium">
            <template if:true={isLoading}>
                <lightning-spinner alternative-text="Loading..." size="medium"></lightning-spinner>
            </template>

            <template if:false={isLoading}>
                <!-- Summary Bar -->
                <template if:true={hasMappings}>
                    <div class="slds-grid slds-gutters slds-m-bottom_medium">
                        <div class="slds-col slds-size_1-of-4">
                            <div class="clause-stat applicable">
                                <div class="stat-number">{applicableCount}</div>
                                <div class="stat-label">Applicable</div>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4">
                            <div class="clause-stat met">
                                <div class="stat-number">{metCount}</div>
                                <div class="stat-label">Met</div>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4">
                            <div class="clause-stat gap">
                                <div class="stat-number">{gapCount}</div>
                                <div class="stat-label">Gaps</div>
                            </div>
                        </div>
                        <div class="slds-col slds-size_1-of-4">
                            <div class="clause-stat na">
                                <div class="stat-number">{naCount}</div>
                                <div class="stat-label">N/A</div>
                            </div>
                        </div>
                    </div>

                    <!-- Filter by Regulator -->
                    <lightning-combobox
                        label="Filter by Regulator"
                        value={selectedRegulator}
                        options={regulatorOptions}
                        onchange={handleRegulatorFilter}
                        class="slds-m-bottom_medium">
                    </lightning-combobox>

                    <!-- Clause Table -->
                    <lightning-datatable
                        key-field="Id"
                        data={filteredMappings}
                        columns={columns}
                        onrowaction={handleRowAction}
                        hide-checkbox-column>
                    </lightning-datatable>

                    <!-- File for Review Button -->
                    <div class="slds-grid slds-grid_align-end slds-m-top_medium">
                        <lightning-button
                            label="File for Review"
                            variant="brand"
                            icon-name="utility:forward"
                            onclick={fileForReview}>
                        </lightning-button>
                    </div>
                </template>

                <template if:false={hasMappings}>
                    <div class="slds-align_absolute-center slds-p-around_large">
                        <p class="slds-text-color_weak">No clause mappings found. Complete the assessment step first.</p>
                    </div>
                </template>
            </template>
        </div>
    </lightning-card>

    <!-- Evidence Upload Modal -->
    <template if:true={showEvidenceModal}>
        <section role="dialog" tabindex="-1" class="slds-modal slds-fade-in-open">
            <div class="slds-modal__container">
                <header class="slds-modal__header">
                    <h2 class="slds-modal__title">Upload Evidence: {selectedClause.Name}</h2>
                    <button class="slds-button slds-button_icon slds-modal__close" onclick={closeEvidenceModal}>
                        <lightning-icon icon-name="utility:close" size="small"></lightning-icon>
                    </button>
                </header>
                <div class="slds-modal__content slds-p-around_medium">
                    <p class="slds-m-bottom_small"><strong>Clause:</strong> {selectedClause.Clause_Reference__c}</p>
                    <p class="slds-m-bottom_medium"><strong>Why it applies:</strong> {selectedClause.Why_It_Applies__c}</p>
                    <lightning-textarea label="Evidence Description" value={evidenceText} onchange={handleEvidenceText} class="slds-m-bottom_small"></lightning-textarea>
                    <lightning-combobox label="Evidence Status" value={evidenceStatus} options={evidenceStatusOptions} onchange={handleEvidenceStatus}></lightning-combobox>
                </div>
                <footer class="slds-modal__footer">
                    <lightning-button label="Cancel" onclick={closeEvidenceModal}></lightning-button>
                    <lightning-button label="Save Evidence" variant="brand" onclick={saveEvidence} class="slds-m-left_x-small"></lightning-button>
                </footer>
            </div>
        </section>
        <div class="slds-backdrop slds-backdrop_open"></div>
    </template>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import fileForReviewApex from '@salesforce/apex/PramaanGovernanceService.fileForReview';

export default class PramaanComplianceMap extends LightningElement {
    @api packId;
    @api useCaseId;
    @track mappings = [];
    @track isLoading = false;
    @track selectedRegulator = 'All';
    @track showEvidenceModal = false;
    @track selectedClause = {};
    @track evidenceText = '';
    @track evidenceStatus = 'Met';

    columns = [
        { label: 'Clause', fieldName: 'Name', type: 'text' },
        { label: 'Regulator', fieldName: 'Regulator__c', type: 'text' },
        { label: 'Reference', fieldName: 'Clause_Reference__c', type: 'text' },
        { label: 'Status', fieldName: 'Mapping_Status__c', type: 'text',
          cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'Binding', fieldName: 'Binding_Status__c', type: 'text' },
        { label: 'Why Applies', fieldName: 'Why_It_Applies__c', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Add Evidence', name: 'evidence' },
            { label: 'Mark Met', name: 'met' },
            { label: 'Mark N/A', name: 'na' }
        ]}}
    ];

    evidenceStatusOptions = [
        { label: 'Met', value: 'Met' },
        { label: 'Partial', value: 'Partial' },
        { label: 'Gap', value: 'Gap' },
    ];

    connectedCallback() {
        if (this.packId) this.loadMappings();
    }

    async loadMappings() {
        if (!this.packId) return;
        this.isLoading = true;
        try {
            const result = await fetch('/services/data/v62.0/query/?q=' +
                encodeURIComponent(`SELECT Id, Name, Regulator__c, Clause_Reference__c, Mapping_Status__c, Binding_Status__c, Why_It_Applies__c FROM Clause_Mapping__c WHERE Governance_Pack__c = '${this.packId}' ORDER BY Regulator__c, Name`),
                { headers: { 'Authorization': 'Bearer ' + this.getSessionId() } }
            );
            if (result.ok) {
                const data = await result.json();
                this.mappings = (data.records || []).map(r => ({
                    ...r,
                    statusClass: 'status-' + (r.Mapping_Status__c || '').toLowerCase()
                }));
            }
        } catch (e) {
            console.error('Load mappings error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    getSessionId() {
        const match = document.cookie.match(/sid=([^;]+)/);
        return match ? match[1] : '';
    }

    get hasMappings() { return this.mappings.length > 0; }
    get applicableCount() { return this.mappings.filter(m => m.Mapping_Status__c !== 'N/A').length; }
    get metCount() { return this.mappings.filter(m => m.Mapping_Status__c === 'Met').length; }
    get gapCount() { return this.mappings.filter(m => m.Mapping_Status__c === 'Gap').length; }
    get naCount() { return this.mappings.filter(m => m.Mapping_Status__c === 'N/A').length; }

    get regulatorOptions() {
        const regs = new Set(this.mappings.map(m => m.Regulator__c).filter(Boolean));
        const opts = [{ label: 'All Regulators', value: 'All' }];
        regs.forEach(r => opts.push({ label: r, value: r }));
        return opts;
    }

    get filteredMappings() {
        if (this.selectedRegulator === 'All') return this.mappings;
        return this.mappings.filter(m => m.Regulator__c === this.selectedRegulator);
    }

    handleRegulatorFilter(event) {
        this.selectedRegulator = event.detail.value;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'evidence') {
            this.selectedClause = row;
            this.showEvidenceModal = true;
        } else if (action.name === 'met' || action.name === 'na') {
            this.updateClauseStatus(row.Id, action.name === 'met' ? 'Met' : 'N/A');
        }
    }

    async updateClauseStatus(clauseId, status) {
        try {
            await fetch(`/services/data/v62.0/sobjects/Clause_Mapping__c/${clauseId}`, {
                method: 'PATCH',
                headers: {
                    'Authorization': 'Bearer ' + this.getSessionId(),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ Mapping_Status__c: status })
            });
            this.loadMappings();
        } catch (e) {
            console.error('Update status error:', e);
        }
    }

    closeEvidenceModal() { this.showEvidenceModal = false; }
    handleEvidenceText(event) { this.evidenceText = event.target.value; }
    handleEvidenceStatus(event) { this.evidenceStatus = event.detail.value; }

    async saveEvidence() {
        await this.updateClauseStatus(this.selectedClause.Id, this.evidenceStatus);
        this.showEvidenceModal = false;
    }

    async fileForReview() {
        try {
            await fileForReviewApex({ packId: this.packId });
        } catch (e) {
            console.error('File for review error:', e);
        }
    }
}
""")


# ── 6. pramaanReviewerLens ──
write_component("pramaanReviewerLens",
html="""<template>
    <lightning-card title="Step 4: Review Gates" icon-name="standard:approval">
        <div class="slds-p-around_medium">
            <template if:true={isLoading}>
                <lightning-spinner alternative-text="Loading..." size="medium"></lightning-spinner>
            </template>

            <template if:false={isLoading}>
                <template if:true={hasBriefs}>
                    <!-- Gate Progress -->
                    <div class="slds-grid slds-gutters slds-m-bottom_medium">
                        <div class="slds-col">
                            <lightning-progress-bar value={gateProgress} size="large"></lightning-progress-bar>
                            <p class="slds-text-body_small slds-text-color_weak slds-m-top_x-small">
                                {approvedCount} of {totalGates} gates approved
                            </p>
                        </div>
                    </div>

                    <!-- Gate Cards -->
                    <div class="slds-grid slds-gutters slds-wrap">
                        <template for:each={briefs} for:item="brief">
                            <div class="slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3 slds-p-around_x-small" key={brief.Id}>
                                <div class={brief.cardClass}>
                                    <div class="slds-grid slds-grid_align-spread slds-m-bottom_small">
                                        <h3 class="slds-text-heading_small">{brief.Lens__c}</h3>
                                        <lightning-badge label={brief.Approval_Status__c} class={brief.badgeClass}></lightning-badge>
                                    </div>

                                    <template if:true={brief.isPending}>
                                        <div class="slds-m-top_small">
                                            <lightning-textarea label="Reviewer Comments" data-brief-id={brief.Id} class="slds-m-bottom_small"></lightning-textarea>
                                            <div class="slds-grid slds-gutters">
                                                <div class="slds-col">
                                                    <lightning-button label="Approve" variant="success" data-brief-id={brief.Id} data-decision="Approved" onclick={handleDecision} class="slds-button_stretch"></lightning-button>
                                                </div>
                                                <div class="slds-col">
                                                    <lightning-button label="Rework" variant="neutral" data-brief-id={brief.Id} data-decision="Rework" onclick={handleDecision} class="slds-button_stretch"></lightning-button>
                                                </div>
                                                <div class="slds-col">
                                                    <lightning-button label="Reject" variant="destructive" data-brief-id={brief.Id} data-decision="Rejected" onclick={handleDecision} class="slds-button_stretch"></lightning-button>
                                                </div>
                                            </div>
                                        </div>
                                    </template>

                                    <template if:false={brief.isPending}>
                                        <template if:true={brief.Reviewer__r}>
                                            <p class="slds-text-body_small">Reviewed by: {brief.reviewerName}</p>
                                        </template>
                                        <template if:true={brief.Reviewer_Comments__c}>
                                            <p class="slds-text-body_small slds-m-top_x-small"><em>{brief.Reviewer_Comments__c}</em></p>
                                        </template>
                                    </template>
                                </div>
                            </div>
                        </template>
                    </div>
                </template>

                <template if:false={hasBriefs}>
                    <div class="slds-align_absolute-center slds-p-around_large">
                        <p class="slds-text-color_weak">No review gates found. File for review from the Compliance Map step.</p>
                    </div>
                </template>
            </template>
        </div>
    </lightning-card>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import recordDecision from '@salesforce/apex/PramaanGovernanceService.recordDecision';

export default class PramaanReviewerLens extends LightningElement {
    @api packId;
    @track briefs = [];
    @track isLoading = false;

    connectedCallback() {
        if (this.packId) this.loadBriefs();
    }

    async loadBriefs() {
        if (!this.packId) return;
        this.isLoading = true;
        try {
            const result = await fetch('/services/data/v62.0/query/?q=' +
                encodeURIComponent(`SELECT Id, Name, Lens__c, Approval_Status__c, Reviewer__r.Name, Decision_Date__c, Reviewer_Comments__c FROM Reviewer_Brief__c WHERE Governance_Pack__c = '${this.packId}' ORDER BY Lens__c`),
                { headers: { 'Authorization': 'Bearer ' + this.getSessionId() } }
            );
            if (result.ok) {
                const data = await result.json();
                this.briefs = (data.records || []).map(b => ({
                    ...b,
                    isPending: b.Approval_Status__c === 'Pending',
                    reviewerName: b.Reviewer__r ? b.Reviewer__r.Name : '',
                    cardClass: 'slds-box gate-card gate-' + (b.Approval_Status__c || 'pending').toLowerCase(),
                    badgeClass: 'badge-' + (b.Approval_Status__c || 'pending').toLowerCase()
                }));
            }
        } catch (e) {
            console.error('Load briefs error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    getSessionId() {
        const match = document.cookie.match(/sid=([^;]+)/);
        return match ? match[1] : '';
    }

    get hasBriefs() { return this.briefs.length > 0; }
    get totalGates() { return this.briefs.length; }
    get approvedCount() { return this.briefs.filter(b => b.Approval_Status__c === 'Approved').length; }
    get gateProgress() { return this.totalGates ? Math.round((this.approvedCount / this.totalGates) * 100) : 0; }

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
""")


# ── 7. pramaanGoLivePassport ──
write_component("pramaanGoLivePassport",
html="""<template>
    <lightning-card title="Step 5: Go-Live Passport" icon-name="standard:endorsement">
        <div class="slds-p-around_medium">
            <template if:true={isLoading}>
                <lightning-spinner alternative-text="Loading..." size="medium"></lightning-spinner>
            </template>

            <template if:false={isLoading}>
                <template if:true={passport}>
                    <div class="passport-container">
                        <div class="passport-header">
                            <lightning-icon icon-name="standard:endorsement" size="large"></lightning-icon>
                            <h2 class="slds-text-heading_large slds-m-left_medium">Go-Live Passport</h2>
                        </div>

                        <div class="passport-body">
                            <div class="passport-number">
                                <span class="passport-label">Passport Number</span>
                                <span class="passport-value">{passport.Passport_Number__c}</span>
                            </div>

                            <div class="slds-grid slds-gutters slds-wrap slds-m-top_medium">
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Pack</dt>
                                        <dd class="slds-text-heading_small">{passport.Name}</dd>
                                    </dl>
                                </div>
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Version</dt>
                                        <dd class="slds-text-heading_small">{passport.Version__c}</dd>
                                    </dl>
                                </div>
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Status</dt>
                                        <dd class="slds-text-heading_small">{passport.Pack_Status__c}</dd>
                                    </dl>
                                </div>
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Issued</dt>
                                        <dd class="slds-text-heading_small">{passport.Passport_Issued_At__c}</dd>
                                    </dl>
                                </div>
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Clauses Met</dt>
                                        <dd class="slds-text-heading_small">{passport.Clauses_Met__c} / {passport.Clauses_Total__c}</dd>
                                    </dl>
                                </div>
                                <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                                    <dl>
                                        <dt class="slds-text-color_weak">Gates</dt>
                                        <dd class="slds-text-heading_small">{passport.Gates_Approved__c} / {passport.Gates_Required__c}</dd>
                                    </dl>
                                </div>
                            </div>

                            <div class="passport-hash slds-m-top_medium">
                                <span class="slds-text-body_small slds-text-color_weak">Approved Config Hash (SHA-256):</span>
                                <code class="slds-m-left_x-small">{passport.Approved_Hash__c}</code>
                            </div>
                        </div>

                        <template if:true={chainResult}>
                            <div class="passport-footer slds-m-top_medium">
                                <template if:true={chainResult.verified}>
                                    <div class="chain-verified">
                                        <lightning-icon icon-name="utility:check" variant="success" size="small"></lightning-icon>
                                        <span class="slds-m-left_x-small">Audit chain verified ({chainResult.totalEvents} events, tamper-free)</span>
                                    </div>
                                </template>
                                <template if:false={chainResult.verified}>
                                    <div class="chain-broken">
                                        <lightning-icon icon-name="utility:error" variant="error" size="small"></lightning-icon>
                                        <span class="slds-m-left_x-small">Chain broken at event #{chainResult.brokenAt}</span>
                                    </div>
                                </template>
                            </div>
                        </template>
                    </div>
                </template>

                <template if:false={passport}>
                    <div class="slds-align_absolute-center slds-p-around_large">
                        <p class="slds-text-color_weak">No passport issued yet. All review gates must be approved first.</p>
                    </div>
                </template>
            </template>
        </div>
    </lightning-card>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import getPackStatus from '@salesforce/apex/PramaanGovernanceService.getPackStatus';
import verifyChain from '@salesforce/apex/PramaanAuditTrail.verifyChain';

export default class PramaanGoLivePassport extends LightningElement {
    @api packId;
    @track passport;
    @track chainResult;
    @track isLoading = false;

    connectedCallback() {
        if (this.packId) this.loadPassport();
    }

    async loadPassport() {
        if (!this.packId) return;
        this.isLoading = true;
        try {
            const status = await getPackStatus({ packId: this.packId });
            this.passport = status.pack;
            if (this.passport?.Passport_Number__c) {
                this.chainResult = await verifyChain({ governancePackId: this.packId });
            }
        } catch (e) {
            console.error('Load passport error:', e);
        } finally {
            this.isLoading = false;
        }
    }
}
""")


# ── 8. pramaanAuditTrail ──
write_component("pramaanAuditTrail",
html="""<template>
    <lightning-card title="Audit Trail" icon-name="standard:record_lookup">
        <div slot="actions">
            <lightning-button label="Verify Chain" variant="brand" icon-name="utility:check" onclick={verifyChainIntegrity}></lightning-button>
            <lightning-button label="Refresh" icon-name="utility:refresh" onclick={loadEvents} class="slds-m-left_x-small"></lightning-button>
        </div>
        <div class="slds-p-around_medium">
            <!-- Chain Status -->
            <template if:true={chainStatus}>
                <div class={chainStatusClass}>
                    <lightning-icon icon-name={chainStatusIcon} size="small"></lightning-icon>
                    <span class="slds-m-left_x-small">{chainStatusMessage}</span>
                </div>
            </template>

            <!-- Events Timeline -->
            <template if:true={hasEvents}>
                <div class="slds-timeline">
                    <template for:each={events} for:item="evt">
                        <div class="slds-timeline__item_expandable" key={evt.Id}>
                            <div class="slds-media slds-m-bottom_small">
                                <div class="slds-media__figure">
                                    <lightning-icon icon-name={evt.icon} size="small"></lightning-icon>
                                </div>
                                <div class="slds-media__body">
                                    <div class="slds-grid slds-grid_align-spread">
                                        <p class="slds-text-body_regular">
                                            <strong>#{evt.Sequence__c}</strong> &mdash; {evt.Event_Type__c}
                                        </p>
                                        <p class="slds-text-body_small slds-text-color_weak">{evt.Event_Timestamp__c}</p>
                                    </div>
                                    <p class="slds-text-body_small">{evt.Payload__c}</p>
                                    <p class="slds-text-body_small slds-text-color_weak">Actor: {evt.Actor__c}</p>
                                    <p class="slds-text-body_small slds-text-color_weak slds-truncate" title={evt.Event_Hash__c}>
                                        Hash: {evt.hashShort}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </template>
                </div>
            </template>

            <template if:false={hasEvents}>
                <div class="slds-align_absolute-center slds-p-around_large">
                    <p class="slds-text-color_weak">No audit events yet.</p>
                </div>
            </template>
        </div>
    </lightning-card>
</template>
""",
js="""import { LightningElement, api, track } from 'lwc';
import getAuditTrail from '@salesforce/apex/PramaanAuditTrail.getAuditTrail';
import verifyChain from '@salesforce/apex/PramaanAuditTrail.verifyChain';

export default class PramaanAuditTrail extends LightningElement {
    @api packId;
    @track events = [];
    @track chainStatus;

    eventIcons = {
        'Filing': 'standard:task2',
        'Mapping': 'standard:entitlement',
        'Approval': 'standard:approval',
        'Passport': 'standard:endorsement',
        'X-Ray': 'standard:scan_card',
    };

    connectedCallback() {
        if (this.packId) this.loadEvents();
    }

    async loadEvents() {
        if (!this.packId) return;
        try {
            const result = await getAuditTrail({ governancePackId: this.packId });
            this.events = result.map(e => ({
                ...e,
                icon: this.eventIcons[e.Event_Type__c] || 'standard:record',
                hashShort: e.Event_Hash__c ? e.Event_Hash__c.substring(0, 16) + '...' : ''
            }));
        } catch (e) {
            console.error('Load audit trail error:', e);
        }
    }

    get hasEvents() { return this.events.length > 0; }

    async verifyChainIntegrity() {
        if (!this.packId) return;
        try {
            this.chainStatus = await verifyChain({ governancePackId: this.packId });
        } catch (e) {
            console.error('Verify chain error:', e);
        }
    }

    get chainStatusClass() {
        return 'chain-status slds-box slds-m-bottom_medium ' +
            (this.chainStatus?.verified ? 'chain-ok' : 'chain-broken');
    }
    get chainStatusIcon() {
        return this.chainStatus?.verified ? 'utility:check' : 'utility:error';
    }
    get chainStatusMessage() {
        if (this.chainStatus?.verified) {
            return `Chain verified: ${this.chainStatus.totalEvents} events, tamper-free`;
        }
        return `Chain BROKEN at event #${this.chainStatus?.brokenAt}`;
    }
}
""")


print("All 7 LWC components generated successfully!")
print("Components created:")
for d in sorted(os.listdir(BASE)):
    if os.path.isdir(os.path.join(BASE, d)):
        print(f"  - {d}")
